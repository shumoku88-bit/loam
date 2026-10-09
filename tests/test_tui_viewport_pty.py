#!/usr/bin/env python3
"""Home/Reports live-resize and grouped-command regression on an isolated fixture.

Arguments: synthetic fixture directory, loamTui executable. Never use loam-data.
"""
import datetime
import fcntl
import hashlib
import os
from pathlib import Path
import pty
import re
import select
import struct
import subprocess
import sys
import termios
import time

root = Path(sys.argv[1]).resolve()
exe = Path(sys.argv[2]).resolve()


def digest():
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob("*") if p.is_file()}


before = digest()
master, slave = pty.openpty()


def resize(rows, cols):
    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))


resize(40, 120)


def controlling_terminal():
    os.setsid()
    fcntl.ioctl(slave, termios.TIOCSCTTY, 0)


process = subprocess.Popen([str(exe), str(root)], stdin=slave, stdout=slave, stderr=slave,
                           env=dict(os.environ, TERM="xterm-256color", LOAM_DATA_DIR=str(root)),
                           preexec_fn=controlling_terminal)
os.close(slave)
ansi = re.compile(rb"\x1b\[[0-?]*[ -/]*[@-~]")


def capture(expected=None):
    output = b""
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        if select.select([master], [], [], 0.2)[0]:
            output += os.read(master, 65536)
        elif output and (expected is None or expected in ansi.sub(b"", output)):
            return output
    raise AssertionError((expected, output))


def bounded(output, rows, cols):
    positions = re.findall(rb"\x1b\[(\d+);(\d+)H", output)
    assert positions, output
    assert all(1 <= int(r) <= rows and 1 <= int(c) <= cols for r, c in positions), positions
    assert b"\n" not in output and b"\r" not in output, "screen-moving newline in frame"


try:
    initial = capture(b"LOAM Home")
    assert b"\x1b[?7l" in initial, "application left terminal auto-wrap armed"
    clean_initial = ansi.sub(b"", initial)
    assert b"[g]" not in clean_initial and b"[Space] commands" in clean_initial, (
        "Home retained Summary or lost the command hub entrance"
    )
    assert b"[y] copy screen" not in clean_initial and b"Shift+drag" not in clean_initial
    assert b"[a] actual" in clean_initial and b"[s] scheduled" in clean_initial
    # Retired g/G must be ignored; the following key still navigates Calendar.
    focus = re.search(rb"Focus: (\d{4}-\d{2}-\d{2})", clean_initial).group(1)
    expected = str(datetime.date.fromisoformat(focus.decode()) + datetime.timedelta(days=1)).encode()
    os.write(master, b"gGl")
    moved = ansi.sub(b"", capture(b"Focus:"))
    assert b"LOAM / Summary" not in moved and b"Focus: " + expected in moved, (
        "retired g/G changed Home or swallowed subsequent Calendar navigation"
    )
    # Resizing while idle must reflow Calendar Home, not wait for a non-navigation key.
    resize(22, 80)
    output = capture(b"LOAM Home")
    bounded(output, 22, 80)
    os.write(master, b"l")
    bounded(capture(), 22, 80)
    # Reports now lives in Space -> Reports and analysis -> Reports.
    os.write(master, b" jj\rjj\r")
    report = capture(b"Stock")
    assert b"Reports" in report and b"[y] copy screen" not in report
    resize(10, 48)
    report = capture(b"Reports")
    bounded(report, 10, 48)
    # Repeated menu navigation stays within the new viewport.
    os.write(master, b"jjj")
    bounded(capture(), 10, 48)
    resize(36, 140)
    report = capture(b"Reports")
    bounded(report, 36, 140)
    os.write(master, b"q")
    bounded(capture(b"LOAM Home"), 36, 140)
    os.write(master, b"q")
    # Drain cleanup bytes before waiting: a macOS tty can hold an exiting child
    # until its pending output is consumed or the master is closed.
    cleanup = b""
    while select.select([master], [], [], 0.2)[0]:
        try:
            chunk = os.read(master, 65536)
            if not chunk:
                break
            cleanup += chunk
        except OSError:
            break
    os.close(master)
    master = -1
    assert process.wait(timeout=5) == 0
    assert b"\x1b[?7h" in cleanup, "application did not restore terminal auto-wrap"
    assert digest() == before, "read-only viewport navigation changed fixture evidence"
    print("Home/Reports: idle resize, palette navigation, retired copy help; evidence unchanged.")
finally:
    if master >= 0:
        os.close(master)
    if process.poll() is None:
        process.kill()
        process.wait(timeout=5)
