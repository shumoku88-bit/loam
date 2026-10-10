#!/usr/bin/env python3
"""Home/Reports/Actuals live-resize regression on an isolated fixture.

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
    assert "╭".encode() in clean_initial and "╰".encode() in clean_initial and b"====" not in clean_initial, (
        "Home retained heavy rules or lost quiet rounded panels", clean_initial
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
    # Only i/d/b are restored from the palette-only analysis shortcuts. Both cases
    # work from Calendar and transaction focus without changing the selected date.
    for detail in (False, True):
        if detail:
            os.write(master, b"\t")
            capture(b"[Esc/Tab/w]")
        for key, marker, back in (
            (b"i", b"Attention / Manage", b"q"),
            (b"I", b"Attention / Manage", b"\x1b"),
            (b"d", b"Daily Pace / Trend", b"q"),
            (b"D", b"Daily Pace / Trend", b"\x1b"),
            (b"b", b"Balances / Current", b"q"),
            (b"B", b"Balances / Current", b"\x1b"),
        ):
            os.write(master, key)
            workspace = ansi.sub(b"", capture(marker))
            assert b"Home / Commands" not in workspace, "direct shortcut opened the palette"
            os.write(master, back)
            restored = ansi.sub(b"", capture(b"LOAM Home"))
            assert b"Focus: " + expected in restored, "analysis shortcut changed Calendar focus"
            assert (b"[Esc/Tab/w]" in restored) == detail, "analysis shortcut changed Home pane"
            assert b"[i] attention" in restored and b"[d] daily pace" in restored and b"[b] balances" in restored
    os.write(master, b"\t")
    capture(b"[h/l] day")
    # The grouped entrances still reach the same existing workspaces.
    for keys, marker in (
        (b" jj\r\r", b"Daily Pace / Trend"),
        (b" jj\rj\r", b"Balances / Current"),
    ):
        os.write(master, keys)
        capture(marker)
        os.write(master, b"q")
        capture(b"LOAM Home")
    # Other formerly direct keys remain ignored, including retired Summary.
    os.write(master, b"xuvmocepgGl")
    moved = ansi.sub(b"", capture(b"Focus:"))
    expected = str(datetime.date.fromisoformat(expected.decode()) + datetime.timedelta(days=1)).encode()
    assert b"Focus: " + expected in moved and b"LOAM / Summary" not in moved
    # Resizing while idle must reflow Calendar Home, not wait for a non-navigation key.
    resize(22, 80)
    output = capture(b"LOAM Home")
    bounded(output, 22, 80)
    os.write(master, b"l")
    bounded(capture(), 22, 80)
    # Compact Home keeps a visible focused pane, feedback and bounded jump input.
    resize(14, 48)
    compact = capture(b"LOAM Home")
    bounded(compact, 14, 48)
    assert b"Calendar [active]" in ansi.sub(b"", compact)
    os.write(master, b"/")
    bounded(capture(b"Jump to date"), 14, 48)
    os.write(master, b"2026-10-31\r")
    jumped = capture(b"Focus: 2026-10-31")
    bounded(jumped, 14, 48)
    assert b"Jumped to 2026-10-31" in ansi.sub(b"", jumped), "compact Home hid jump feedback"
    os.write(master, b"\t")
    bounded(capture(b"Detail [active]"), 14, 48)
    os.write(master, b"\x1b")
    bounded(capture(b"Calendar [active]"), 14, 48)
    # Manual browsing and subsequent date navigation remain distinct.
    os.write(master, b"\x15")
    bounded(capture(), 14, 48)
    os.write(master, b"h")
    bounded(capture(b"Focus: 2026-10-30"), 14, 48)
    resize(22, 80)
    bounded(capture(b"LOAM Home"), 22, 80)
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
    os.write(master, b"s")
    scheduled = capture(b"Scheduled Series Calendar")
    bounded(scheduled, 36, 140)
    assert "╭".encode() in scheduled and b"====" not in scheduled, (
        "Series Calendar retained heavy rules or lost its rounded frame", scheduled
    )
    # The main Scheduled frame must reflow while idle too, including abbreviated
    # help and narrower month columns, without touching household evidence.
    for rows, cols in ((24, 80), (10, 48), (40, 144), (36, 140)):
        resize(rows, cols)
        bounded(capture(b"Scheduled Series Calendar"), rows, cols)
    os.write(master, b"q")
    bounded(capture(b"LOAM Home"), 36, 140)
    os.write(master, b"a")
    actual = capture(b"Household Actuals Workspace")
    bounded(actual, 36, 140)
    assert ("╭".encode() in actual or "┌".encode() in actual) and b"====" not in actual
    # Resize with no keypress: cross both width and height breakpoints, then
    # return to a wide layout. Pane switching remains reachable in compact mode.
    for rows, cols in ((24, 80), (10, 48), (30, 99), (40, 144)):
        resize(rows, cols)
        bounded(capture(b"Household Actuals Workspace"), rows, cols)
        os.write(master, b"h")
        bounded(capture(b"Loci [active]"), rows, cols)
        os.write(master, b"l")
        bounded(capture(b"Actuals [active]"), rows, cols)
        # Details must be the visible focus even when the normal details region
        # does not fit; Esc restores the Actual list without leaving the workspace.
        os.write(master, b"i")
        details = capture(b"Details [active]")
        bounded(details, rows, cols)
        os.write(master, b"\x1b")
        bounded(capture(b"Actuals [active]"), rows, cols)
    os.write(master, b"q")
    capture(b"LOAM Home")
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
    print("Home/Reports/Scheduled/Actuals: quiet frames, compact jump/feedback, shortcuts and idle resize; evidence unchanged.")
finally:
    if master >= 0:
        os.close(master)
    if process.poll() is None:
        process.kill()
        process.wait(timeout=5)
