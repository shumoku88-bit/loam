#!/usr/bin/env python3
"""Checked Scheduled editing through the real terminal; only temporary synthetic data."""
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

repo = Path(__file__).resolve().parent.parent
exe = Path(sys.argv[1] if len(sys.argv) > 1 else repo / ".lake/build/bin/loamTui").resolve()
ansi = re.compile(rb"\x1b\[[0-?]*[ -/]*[@-~]")


def sections(wire):
    header, remaining = wire.split("\n", 1)
    assert header == "LOAM-HOUSEHOLD-IMAGE\t2"
    result = {}
    while remaining:
        framing, remaining = remaining.split("\n", 1)
        tag, name, length = framing.split("\t")
        assert tag == "SECTION"
        length = int(length)
        result[name], remaining = remaining[:length], remaining[length:]
    return result


with tempfile.TemporaryDirectory(prefix="loam-bulk-pty-") as temporary:
    root = Path(temporary) / "household"
    subprocess.run(["lake", "env", "lean", "--run", "Loam/Tests/ScheduledBatchReplacement.lean",
                    "setup", str(root)], cwd=repo, check=True)
    authority = root / "household.loam"
    before = authority.read_text()
    master, slave = pty.openpty()
    rows, columns = 24, 100
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", rows, columns, 0, 0))

    def controlling_terminal():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    process = subprocess.Popen([str(exe), str(root)], stdin=slave, stdout=slave, stderr=slave,
                               env=dict(os.environ, TERM="xterm-256color", LOAM_DATA_DIR=str(root)),
                               preexec_fn=controlling_terminal)
    os.close(slave)

    def capture(expected=None):
        output = b""
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            if select.select([master], [], [], 0.2)[0]:
                output += os.read(master, 65536)
            elif output and (expected is None or expected in ansi.sub(b"", output)):
                return output
        raise AssertionError((expected, output))

    def send(keys, expected=None):
        os.write(master, keys)
        return capture(expected)

    def configure_sheet():
        send(b"b", b"Batch amount edit")
        # Exact date range is explicit, not dependent on the host's current date.
        send(b"5200\t" + b"\x7f" * 10 + b"2026-11-01\r", b"0 checked / 3 candidates")

    def check_and_preview():
        send(b"a", b"3 checked")
        send(b"jj ", b"2 checked")  # retain the special January amount by unchecking it
        return send(b"\r", b"Preview: 2 replacements")

    try:
        capture(b"LOAM / Today")
        send(b"s", b"Series Calendar")
        send(b"v", b"Scheduled / Months")
        configure_sheet()
        preview = check_and_preview()
        clean = ansi.sub(b"", preview)
        assert b"4,800 -> 5,200" in clean and b"Unchecked: 1" in clean
        assert b"Paid Actual is untouched" in clean
        assert authority.read_text() == before, "selection or preview wrote authority"
        send(b"\x1b", b"2 checked")
        send(b"\x1b", b"Batch edit cancelled")
        assert authority.read_text() == before, "cancel changed authority"

        configure_sheet()
        # Resize the real editor, not only its pure widget.
        rows, columns = 18, 80
        fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", rows, columns, 0, 0))
        output = send(b"j")
        positions = re.findall(rb"\x1b\[(\d+);(\d+)H", output)
        assert positions and all(1 <= int(r) <= rows and 1 <= int(c) <= columns for r, c in positions)
        send(b"k")
        check_and_preview()
        send(b"\t\r", b"Revised 2 Scheduled occurrences")
        after = sections(authority.read_text())
        old = sections(before)
        for name, body in old.items():
            if name not in {"Scheduled", "ScheduledRouting"}:
                assert after[name] == body, f"batch changed {name}"
        assert after["Scheduled"] != old["Scheduled"]
        assert after["ScheduledRouting"] != old["ScheduledRouting"]
        # Original provenance and the unchecked exception remain in the payload.
        assert "exception" in after["Scheduled"] and "6000" in after["Scheduled"]
        assert "first" in after["Scheduled"] and "4800" in after["Scheduled"]
        send(b"q", b"LOAM / Today")
        os.write(master, b"q")
        while select.select([master], [], [], 0.2)[0]:
            try:
                if not os.read(master, 65536):
                    break
            except OSError:
                break
        os.close(master)
        master = -1
        assert process.wait(timeout=5) == 0
        print("Scheduled batch PTY: checked selection, preview/cancel, resize, atomic publish and paid-history preservation passed.")
    finally:
        if master >= 0:
            os.close(master)
        if process.poll() is None:
            process.kill()
            process.wait(timeout=5)
