#!/usr/bin/env python3
"""Real PTY qualification for explicit TUI first-run, using isolated roots only."""
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


class Session:
    def __init__(self, root):
        self.master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 14, 95, 0, 0))

        def setup():
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

        self.proc = subprocess.Popen(
            [str(EXE), str(root)], stdin=slave, stdout=slave, stderr=slave,
            preexec_fn=setup, env=dict(os.environ, TERM="xterm-256color"),
        )
        os.close(slave)

    def until(self, expected, timeout=25):
        output = b""
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if select.select([self.master], [], [], 0.1)[0]:
                try:
                    block = os.read(self.master, 65536)
                except OSError:
                    break
                if not block:
                    break
                output += block
                if expected in ANSI.sub(b"", output):
                    return output
            elif expected in ANSI.sub(b"", output):
                return output
        raise AssertionError((expected, ANSI.sub(b"", output)[-3000:]))

    def send(self, data, expected):
        os.write(self.master, data)
        return self.until(expected)

    def close(self):
        if self.proc.poll() is None:
            self.proc.terminate()
            self.proc.wait(timeout=7)
        os.close(self.master)


with tempfile.TemporaryDirectory(prefix="loam-tui-first-run-") as temp:
    temp = Path(temp)
    fresh = temp / "fresh"
    s = Session(fresh)
    try:
        s.until(b"Start a household")
        assert not fresh.exists(), "opening startup prompt created a household"
        s.send(b"\r", b"Create an INDEPENDENT household?")
        assert not fresh.exists(), "the REVIEW step unexpectedly wrote household data"
        s.send(b"\r", b"LOAM Home")
        authority = fresh / "household.loam"
        assert authority.is_file(), "the confirmed TUI did not create an admitted household"
        body = authority.read_bytes()
        os.write(s.master, b"q")
        assert s.proc.wait(timeout=10) == 0, "newly created household did not exit normally"
    finally:
        s.close()

    reopened = Session(fresh)
    try:
        reopened.until(b"LOAM Home")
        os.write(reopened.master, b"q")
        assert reopened.proc.wait(timeout=10) == 0
    finally:
        reopened.close()
    assert authority.read_bytes() == body, "normal reopen changed fresh canonical bytes"

    # A source that exists but cannot load must never get initialized in place.
    damaged = temp / "damaged"
    damaged.mkdir()
    old = damaged / "household.loam"
    old.write_bytes(b"invalid-old-household-do-not-touch\n")
    alternative = temp / "separate"
    s = Session(damaged)
    try:
        s.until(b"Start a household")
        s.send(str(alternative).encode() + b"\r",
               b"Create an INDEPENDENT household?")
        assert old.read_bytes() == b"invalid-old-household-do-not-touch\n"
        s.send(b"\r", b"LOAM Home")
        assert (alternative / "household.loam").is_file(), "separate root was not created"
        assert old.read_bytes() == b"invalid-old-household-do-not-touch\n"
        os.write(s.master, b"q")
        assert s.proc.wait(timeout=10) == 0
    finally:
        s.close()

    # Cancel and non-TTY operation may never create a household.
    cancelled = temp / "cancelled"
    s = Session(cancelled)
    try:
        s.until(b"Start a household")
        os.write(s.master, b"\x1b")
        assert s.proc.wait(timeout=10) == 0, "Escape did not cancel startup"
    finally:
        s.close()
    assert not cancelled.exists(), "cancelled startup published a root"

    non_tty = temp / "non-tty"
    plain = subprocess.run([str(EXE), str(non_tty)], stdin=subprocess.DEVNULL,
                           capture_output=True, timeout=10)
    assert plain.returncode == 2, "non-interactive missing-root startup should refuse"
    assert b"loam init" in plain.stderr
    assert not non_tty.exists(), "non-interactive startup unexpectedly created data"

print("TUI first-run PTY: two-key create/Home/reopen, separate recovery root, cancel, non-TTY refusal, and byte preservation passed.")
