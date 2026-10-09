#!/usr/bin/env python3
"""Record cancel/publish/activation reload boundaries, isolated synthetic household only."""
import fcntl
import os
from pathlib import Path
import pty
import re
import select
import struct
import subprocess
import sys
import tempfile
import termios
import time

REPO = Path(__file__).resolve().parent.parent
EXE = Path(sys.argv[1] if len(sys.argv) > 1 else REPO / ".lake/build/bin/loamTui").resolve()
ANSI = re.compile(rb"\x1b\[[0-?]*[ -/]*[@-~]")


class Terminal:
    def __init__(self, root):
        self.fd, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 48, 160, 0, 0))

        def setup():
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

        self.process = subprocess.Popen([str(EXE), str(root)], stdin=slave, stdout=slave,
                                        stderr=slave, preexec_fn=setup,
                                        env=dict(os.environ, TERM="xterm-256color"))
        os.close(slave)
        self.capture(b"LOAM Home")

    def capture(self, expected):
        output = b""
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if select.select([self.fd], [], [], .05)[0]:
                try:
                    chunk = os.read(self.fd, 65536)
                except OSError:
                    break
                if not chunk:
                    break
                output += chunk
            elif expected in ANSI.sub(b"", output):
                return output
        assert expected in ANSI.sub(b"", output), (expected, output)
        return output

    def send(self, keys, expected):
        os.write(self.fd, keys)
        return self.capture(expected)

    def close(self):
        if self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=5)
        os.close(self.fd)


with tempfile.TemporaryDirectory(prefix="loam-record-reload-") as tmp:
    root = Path(tmp) / "household"
    subprocess.run(["lake", "env", "lean", "--run", "Loam/Tests/ScheduledBatchReplacement.lean",
                    "setup", str(root)], cwd=REPO, check=True)
    authority = root / "household.loam"
    before = authority.read_bytes()
    # Removing the read authority while the editor is open makes any unwanted
    # caller reload deterministic, without asserting a machine-specific latency.
    for route in ("home", "actual", "selected-day"):
        terminal = Terminal(root)
        hidden = root / "held-image"
        try:
            if route == "actual":
                terminal.send(b"a", b"Actual")
                terminal.send(b"n", b"Description")
            elif route == "selected-day":
                terminal.send(b"\r", b"Selected")
                terminal.send(b"n", b"Description")
            else:
                terminal.send(b"r", b"Record movement")
            authority.rename(hidden)
            terminal.send(b"\x1b", b"Record cancelled.")
            assert terminal.process.poll() is None, route
            assert not authority.exists(), "cancel published a replacement image"
        finally:
            if hidden.exists():
                hidden.rename(authority)
            terminal.close()
        assert authority.read_bytes() == before, route

    terminal = Terminal(root)
    try:
        terminal.send(b"r", b"Record movement")
        terminal.send(b"reload-specimen\t\tbank\t-10\twifi\t10\r", b"Record / Preview")
        terminal.send(b"\r", b"Recorded ")
        assert authority.read_bytes() != before, "confirmed Record did not publish"
        # The new row in Summary's recent Actual list requires a refreshed snapshot.
        terminal.send(b"g", b"reload-specimen")
    finally:
        terminal.close()

    terminal = Terminal(root)
    hidden = root / "held-image"
    try:
        terminal.send(b"r", b"Record movement")
        terminal.send(b"\x15", b"Enable")  # Ctrl-U, first-use suspense admission
        terminal.send(b"\r", b"Unresolved recording enabled")
        assert b"suspense" in authority.read_bytes(), "activation did not publish policy"
        authority.rename(hidden)
        terminal.send(b"\x1b", b"Reload failed")
        assert terminal.process.wait(timeout=5) != 0, "activation followed by cancel skipped reload"
    finally:
        if hidden.exists():
            hidden.rename(authority)
        terminal.close()

    # Even a failed activation may have published before the authoritative reload
    # failed. Its later cancellation must not take the read-only fast path.
    authority.write_bytes(before)
    terminal = Terminal(root)
    hidden = root / "held-image"
    try:
        terminal.send(b"r", b"Record movement")
        terminal.send(b"\x15", b"Enable")
        authority.rename(hidden)
        terminal.send(b"\r", b"Unresolved recording was not enabled")
        terminal.send(b"\x1b", b"Reload failed")
        assert terminal.process.wait(timeout=5) != 0, "failed activation/cancel skipped reload"
    finally:
        if hidden.exists():
            hidden.rename(authority)
        terminal.close()

print("Record reload PTY: three cancel entrances, publication and successful/failed activation passed.")
