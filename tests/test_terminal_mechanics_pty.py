#!/usr/bin/env python3
"""Compiled native terminal mechanics: batching boundaries and resize-safe output.

Run after lake build terminalProbe. Uses synthetic text only, never household data.
"""
import fcntl
import os
from pathlib import Path
import pty
import re
import select
import struct
import subprocess
import termios
import time

EXE = Path(__file__).resolve().parent.parent / ".lake/build/bin/terminalProbe"


def run(mode, payload, resize=None):
    master, slave = pty.openpty()
    attrs = termios.tcgetattr(slave)
    attrs[3] &= ~(termios.ICANON | termios.ECHO)
    attrs[6][termios.VMIN] = 0
    attrs[6][termios.VTIME] = 1
    termios.tcsetattr(slave, termios.TCSANOW, attrs)
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
    process = subprocess.Popen([str(EXE), mode], stdin=slave, stdout=slave, stderr=slave)
    try:
        pending = b""
        deadline = time.monotonic() + 10
        while b"ready\r\n" not in pending:
            assert time.monotonic() < deadline and select.select([master], [], [], 1)[0], pending
            pending += os.read(master, 65536)
        assert pending == b"ready\r\n", pending
        if resize:
            rows, cols = resize
            fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
        os.write(master, payload)
        output = b""
        while time.monotonic() < deadline:
            if select.select([master], [], [], 0.05)[0]:
                output += os.read(master, 65536)
            elif process.poll() is not None:
                break
        assert process.wait(timeout=1) == 0, output
        return output
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        os.close(slave)
        os.close(master)


wheel_down = b"\x1b[<65;10;10M"
wheel_up = b"\x1b[<64;10;10M"
output = run("wheel", wheel_down * 3 + b"\x1b[A" + wheel_up * 2 + b"q")
assert output.splitlines() == [
    b"key:Loam.Tui.Terminal.Key.down count:3",
    b"key:Loam.Tui.Terminal.Key.up count:1",
    b"key:Loam.Tui.Terminal.Key.up count:2",
    b"key:Loam.Tui.Terminal.Key.input 'q' count:1",
], output
print("Native wheel batching: count preserved; keyboard and following keys not swallowed.")

for geometry in [(9, 32), (55, 160), (1, 10)]:
    output = run("resize", b"g", geometry)
    rows, cols = geometry
    cursors = re.findall(rb"\x1b\[(\d+);(\d+)H", output)
    assert cursors, output
    assert all(1 <= int(row) <= rows and 1 <= int(col) <= cols for row, col in cursors), cursors
    assert b"\n" not in output and b"\r" not in output, output
    if rows > 1:
        assert f"geometry {cols}x{rows}".encode() in output, output
        assert b"footer [q] back" in output, output
    print(f"Resize {cols}x{rows}: live geometry, bounded cursor writes, no newline scrolling.")
