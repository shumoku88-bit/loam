#!/usr/bin/env python3
"""Compiled native terminal mechanics: batching, bounded regions and live cursors.

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


def run(mode, payload, resize=None, resize_after_paint=None):
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
        if resize_after_paint:
            while b"painted" not in output:
                assert time.monotonic() < deadline and select.select([master], [], [], 1)[0], output
                output += os.read(master, 65536)
            # Synchronize the shrink after painting, before the final cursor move.
            assert output.endswith(b"painted"), output
            rows, cols = resize_after_paint
            fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
            os.write(master, b"c")
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

assert run("regions", b"g") == b"regions-ok"
print("Pure region boundaries: offscreen/zero/partial, CJK clipping and rectangular padding.")

output = run("text-caret", b"g")
entered, rest = output.split(b"stable", 1)
idle, rest = rest.split(b"review", 1)
review, rest = rest.split(b"direct", 1)
direct, stale = rest.split(b"stale", 1)
assert entered.endswith(b"\x1b[3;8H\x1b[?25h"), entered
assert idle == b"", ("unchanged input frame emitted cursor churn", idle)
assert b"\x1b[?25l" in review and b"\x1b[?25h" not in review, review
assert direct.endswith(b"\x1b[1;5H\x1b[?25h"), direct
assert stale == b"\x1b[?25l", ("offscreen field addressed unrelated cells", stale)
print("Shared text caret: semantic floating/direct CJK anchors, idle, review and clipped-pane hiding.")

for geometry in [(9, 32), (14, 48), (24, 80), (36, 120), (55, 160), (1, 10)]:
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

for rows, cols in [(9, 32), (14, 48), (24, 80), (36, 120)]:
    output = run("output-bounds", b"g", (rows, cols))
    offscreen, visible = output.split(b"offscreen-done")
    assert offscreen == b"", offscreen
    region, diff = visible.split(b"region-done")
    first = f"\x1b[{rows - 1};{cols - 4}H".encode()
    second = f"\x1b[{rows};{cols - 4}H".encode()
    # Exactly two visible rows, four columns each; no clear-to-EOL in overlays.
    assert region == (
        first + "\x1b[0ma日\x1b[0m ".encode()
        + second + "\x1b[0m日本\x1b[0m".encode()
    ), region
    assert diff == (
        first + "\x1b[0ma日\x1b[0m\x1b[K".encode()
        + second + "\x1b[0m日本\x1b[0m\x1b[K".encode()
    ), diff
    print(f"Regions {cols}x{rows}: offscreen emits nothing; partial writes stay in visible rectangle.")

for painted_geometry, live_geometry in [
    ((40, 120), (36, 120)),
    ((36, 120), (24, 80)),
    ((24, 80), (14, 48)),
    ((14, 48), (9, 32)),
    ((9, 32), (1, 1)),
]:
    output = run("cursor", b"g", painted_geometry, live_geometry)
    painted, cursor = output.split(b"painted")
    rows, cols = painted_geometry
    addresses = re.findall(rb"\x1b\[(\d+);(\d+)H", painted)
    assert addresses, painted
    assert all(1 <= int(row) <= rows and 1 <= int(col) <= cols
               for row, col in addresses), addresses
    rows, cols = live_geometry
    assert b"\x1b[?25h" in painted, "painted field never acquired its insertion anchor"
    assert cursor == b"\x1b[?25l", ("stale field was clamped instead of hidden", cursor)
    print(f"Caret shrink to {cols}x{rows}: stale field hides without addressing unrelated cells.")
