#!/usr/bin/env python3
"""Home/Reports/Actuals live-resize regression on an isolated fixture.

Arguments: synthetic fixture directory, loamTui executable, optional --launcher.
Never use loam-data. The opt-in mode qualifies the visual launcher separately.
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
launcher_mode = sys.argv[3:] == ["--launcher"]


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
                           env=dict(os.environ, TERM="xterm-256color", LOAM_DATA_DIR=str(root),
                                    LOAM_HOME="launcher" if launcher_mode else ""),
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
    if launcher_mode:
        initial = capture(b"Calendar")
        bounded(initial, 40, 120)
        for marker in (b"Record", b"Scheduled", b"Actual", b"Balances", b"Daily Pace"):
            assert marker in ansi.sub(b"", initial), (marker, initial)
        assert "╭".encode() not in initial and b"Net:" not in initial
        assert b"\\___________/" in ansi.sub(b"", initial) and b"loam" in initial
        for rows, cols in ((9, 32), (14, 48), (23, 32), (24, 32), (45, 150), (40, 120)):
            resize(rows, cols)
            frame = capture(b"Calendar")
            bounded(frame, rows, cols)
            clean = ansi.sub(b"", frame)
            assert (b"\\___________/" in clean) == (rows >= 24), "bonsai resize did not fold/restore the whole tree"
            for marker in (b"Record", b"Scheduled", b"Actual", b"Balances", b"Daily Pace"):
                assert marker in clean, (rows, cols, marker)
        # Same publishers/workspaces, with safe cancellation and launcher return.
        for key, marker, back in (
            (b"r", b"Record / Edit", b"\x1b"),
            (b"s", b"Scheduled Series Calendar", b"q"),
            (b"a", b"Household Actuals Workspace", b"q"),
            (b"b", b"Balances / Current", b"q"),
            (b"d", b"Daily Pace / Trend", b"q"),
            (b"i", b"Attention / Manage", b"q"),
        ):
            os.write(master, key)
            bounded(capture(marker), 40, 120)
            os.write(master, back)
            bounded(capture(b"[Space] commands"), 40, 120)
        # Calendar context survives the root round trip, including tiny resize.
        os.write(master, b"g")
        calendar = ansi.sub(b"", capture(b"LOAM Home"))
        focus = re.search(rb"Focus: (\d{4}-\d{2}-\d{2})", calendar).group(1)
        expected = str(datetime.date.fromisoformat(focus.decode()) + datetime.timedelta(days=1)).encode()
        os.write(master, b"l")
        capture(b"Focus: " + expected)
        os.write(master, b"q")
        capture(b"[Space] commands")
        resize(9, 32)
        bounded(capture(b"Calendar"), 9, 32)
        os.write(master, b"\r")
        bounded(capture(b"LOAM Home"), 9, 32)
        resize(40, 120)
        restored = ansi.sub(b"", capture(b"LOAM Home"))
        assert b"Focus: " + expected in restored, "launcher lost navigated Calendar date"
        os.write(master, b"g")
        capture(b"[Space] commands")
        os.write(master, b" \x1b")
        capture(b"Calendar")
        os.write(master, b"q")
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
        assert b"\x1b[?7h" in cleanup
        assert digest() == before, "launcher navigation/cancellation changed household evidence"
        print("Home launcher: six entrances, live resize, Calendar return and cancellation; evidence unchanged.")
        sys.exit(0)
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
    assert b"[r] record" in clean_initial and b"[?] help" in clean_initial
    assert b"[a] actual" not in clean_initial, "Home retained the full persistent command deck"
    # Full help succeeds the command deck and legends. Its modal boundary must
    # not leak Record, analysis, Enter or Commands while resizing to a tiny tty.
    os.write(master, b"?")
    help_view = ansi.sub(b"", capture(b"Home / Help"))
    assert b"[a] actual" in help_view and b"[s] scheduled" in help_view
    assert b"amount too wide" in help_view and b"completeness claim" in help_view
    resize(9, 32)
    bounded(capture(b"LOAM Home"), 9, 32)
    os.write(master, b"rasidb \rj")
    captured = capture()
    bounded(captured, 9, 32)
    assert b"Record /" not in ansi.sub(b"", captured) and b"Household Day Workspace" not in captured
    os.write(master, b"q")
    closed = capture(b"[?] help")
    bounded(closed, 9, 32)
    resize(40, 120)
    restored = capture(b"LOAM Home")
    bounded(restored, 40, 120)
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
            assert b"[?] help" in restored and b"[Space] commands" in restored
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
    assert b"Day " in ansi.sub(b"", compact) and b"/ Detail" in ansi.sub(b"", compact)
    assert b"Actual: " not in ansi.sub(b"", compact), "compact Day merged an Actual preview into Calendar"
    os.write(master, b"/")
    bounded(capture(b"Jump to date"), 14, 48)
    os.write(master, b"2026-10-31\r")
    jumped = capture(b"Focus: 2026-10-31")
    bounded(jumped, 14, 48)
    assert b"Jumped to 2026-10-31" in ansi.sub(b"", jumped), "compact Home hid jump feedback"
    os.write(master, b"\t")
    bounded(capture(b"[j/k] select"), 14, 48)
    os.write(master, b"\x1b")
    bounded(capture(b"[h/l] day"), 14, 48)
    # Compact Day begins with the selected date already in view. Paging up
    # at the top is intentionally a no-op and may emit no terminal bytes.
    # First browse down, then back up, to verify actual viewport movement.
    os.write(master, b"\x04")
    bounded(capture(), 14, 48)
    os.write(master, b"\x15")
    bounded(capture(), 14, 48)
    os.write(master, b"h")
    bounded(capture(b"Focus: 2026-10-30"), 14, 48)
    # Both sides of the wide breakpoint and tiny/short layouts preserve the
    # date and expose separate selected-day content on idle resize.
    for rows, cols in ((30, 119), (30, 120), (30, 64), (9, 32), (22, 80)):
        resize(rows, cols)
        frame = capture(b"LOAM Home")
        bounded(frame, rows, cols)
        assert b"Focus: 2026-10-30" in ansi.sub(b"", frame)
        if cols >= 120:
            assert "┬".encode() in frame, "wide Home lost the month grid"
    # Numeric month labels reflow without hiding the selected month. Live resize
    # must not change the date, zoom, current-month styling or transaction counts.
    os.write(master, b"z")
    month = capture(b"View: Month")
    assert b"[10 Oct]" in ansi.sub(b"", month), "month zoom lost its numeric selected label"
    assert b"Months / 2026" in ansi.sub(b"", month) and b"[Enter] days" in ansi.sub(b"", month)
    for rows, cols in ((14, 48), (14, 32), (24, 80), (20, 120), (48, 160)):
        resize(rows, cols)
        month = capture(b"LOAM Home")
        bounded(month, rows, cols)
        clean = ansi.sub(b"", month)
        assert b"Focus: 2026-10-30" in clean and b"[10 Oct]" in clean
    for label in (b"01 Jan", b"02 Feb", b"03 Mar", b"04 Apr", b"05 May", b"06 Jun",
                  b"07 Jul", b"08 Aug", b"09 Sep", b"10 Oct", b"11 Nov", b"12 Dec"):
        assert label in clean, ("month label clipped on wide resize", label)
    assert b"0 records" in clean and b"underline = current month" not in clean
    # Year zoom uses the same restrained hierarchy: aligned year/count columns,
    # no repeated inset title/legend, and unchanged selection across live resize.
    os.write(master, b"z")
    year = capture(b"View: Year")
    clean_year = ansi.sub(b"", year)
    assert b"Years" in clean_year and b"Records" in clean_year and b"[2026]" in clean_year
    assert b"[Enter] months" in clean_year and b"Years Overview" not in clean_year
    for rows, cols in ((24, 80), (14, 48), (9, 32), (32, 116), (48, 160)):
        resize(rows, cols)
        year = capture(b"LOAM Home")
        bounded(year, rows, cols)
        clean_year = ansi.sub(b"", year)
        assert b"Focus: 2026-10-30" in clean_year and b"[2026]" in clean_year
    os.write(master, b"z")
    day_flow = capture(b"Month Flow (2026-10)")
    bounded(day_flow, 48, 160)
    assert b"No recorded income/expense flow." in ansi.sub(b"", day_flow), (
        "empty day-calendar flow became a balance or invented zero", day_flow
    )
    resize(22, 80)
    bounded(capture(b"LOAM Home"), 22, 80)
    # Selected Day owns separate Actual/Scheduled lists and a focusable Detail.
    os.write(master, b"\r")
    day = capture(b"Household Day Workspace")
    bounded(day, 22, 80)
    assert "╭".encode() in day and b"====" not in day, "Selected Day retained heavy rules"
    for rows, cols in ((14, 48), (24, 80), (30, 99), (40, 144), (10, 48)):
        resize(rows, cols)
        bounded(capture(b"Household Day Workspace"), rows, cols)
        os.write(master, b"i")
        bounded(capture(b"Selected Actual [active]"), rows, cols)
        os.write(master, b"\x1b")
        bounded(capture(b"Actual [active]"), rows, cols)
        os.write(master, b"l")
        plan = capture(b"Scheduled")
        bounded(plan, rows, cols)
        assert b"Unknown" in ansi.sub(b"", plan), "empty Scheduled became a completeness claim"
        os.write(master, b"\t")
        bounded(capture(b"Selected Scheduled [active]"), rows, cols)
        os.write(master, b"q")
        bounded(capture(b"Scheduled"), rows, cols)
        os.write(master, b"h")
        bounded(capture(b"Actual [active]"), rows, cols)
    os.write(master, b"q")
    restored_home = capture(b"LOAM Home")
    bounded(restored_home, 10, 48)
    assert b"[Space] cmds" in ansi.sub(b"", restored_home), "parent Home returned with stale wide geometry"
    resize(22, 80)
    bounded(capture(b"LOAM Home"), 22, 80)
    # Direct Stock–Flow entrance, with no intermediate Reports chooser.
    os.write(master, b" jj\rjjjj\r")
    report = capture(b"Stock")
    assert b"Reports" in report and b"[y] copy screen" not in report
    resize(10, 48)
    report = capture(b"Reports")
    bounded(report, 10, 48)
    # Repeated report scrolling stays within the viewport.
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
    # UI-16: the compact editing screen keeps Preview/Cancel in its fixed
    # action row, without requiring a larger terminal to reach these controls.
    resize(14, 48)
    bounded(capture(b"Scheduled Series Calendar"), 14, 48)
    os.write(master, b"n")
    compact_edit = capture(b"Scheduled / New / Edit")
    bounded(compact_edit, 14, 48)
    assert b"[Preview]" in ansi.sub(b"", compact_edit)
    assert b"[Cancel]" in ansi.sub(b"", compact_edit)
    # UI-16: resize an *open* Scheduled editor, without closing or losing focus.
    resize(10, 32)
    shrunk_edit = capture(b"Scheduled / New / Edit")
    bounded(shrunk_edit, 10, 32)
    assert b"Due:" in ansi.sub(b"", shrunk_edit), shrunk_edit
    resize(14, 48)
    grown_edit = capture(b"Scheduled / New / Edit")
    bounded(grown_edit, 14, 48)
    assert b"[Preview]" in ansi.sub(b"", grown_edit)
    os.write(master, b"\x1b")
    bounded(capture(b"Scheduled Series Calendar"), 14, 48)
    resize(36, 140)
    bounded(capture(b"Scheduled Series Calendar"), 36, 140)
    # UI-16: review signed Scheduled postings in a real PTY, then cancel.
    # No canonical Scheduled or Actual evidence may be published by preview.
    os.write(master, b"n")
    opened = capture(b"Scheduled / New / Edit")
    assert b"\x1b[2J" not in opened, "roomy Scheduled create unexpectedly cleared parent"
    assert b"Scheduled / New" in ansi.sub(b"", opened)
    edit = ansi.sub(b"", opened)
    assert b"Due:" in edit and b"Posting 1" in edit, edit
    os.write(master, b"\tpaypay\t-700\tfood\t700\r")
    preview = ansi.sub(b"", capture(b"[Publish Scheduled]"))
    assert b"Scheduled / New / Preview" in preview
    assert b"Expected postings" in preview
    assert b"-700 jpy" in preview and b"+700 jpy" in preview, preview
    # Resize the open confirmation before Enter. Its publish gate must use
    # the *current* terminal height, not the earlier wide entrance geometry.
    resize(9, 48)
    short_preview = capture(b"Scheduled / New / Preview")
    bounded(short_preview, 9, 48)
    os.write(master, b"\r")
    short_refusal = capture(b"Enlarge terminal")
    assert b"Enlarge terminal" in ansi.sub(b"", short_refusal)
    resize(36, 140)
    restored_preview = capture(b"Scheduled / New / Preview")
    bounded(restored_preview, 36, 140)
    assert b"Expected postings" in ansi.sub(b"", restored_preview)
    os.write(master, b"\x1b")
    bounded(capture(b"Scheduled Series Calendar"), 36, 140)
    # At a very short terminal the review must reject Enter on Publish,
    # even if keyboard navigation can technically reach the action.
    resize(9, 48)
    bounded(capture(b"Scheduled Series Calendar"), 9, 48)
    os.write(master, b"n")
    capture(b"Scheduled / New / Edit")
    os.write(master, b"\tpaypay\t-700\tfood\t700\r")
    capture(b"Scheduled / New / Preview")
    os.write(master, b"\r")
    refusal = ansi.sub(b"", capture(b"Enlarge terminal"))
    assert b"Enlarge terminal" in refusal, refusal
    os.write(master, b"\x1b")
    capture(b"Scheduled Series Calendar")
    resize(36, 140)
    bounded(capture(b"Scheduled Series Calendar"), 36, 140)
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
    print("Home/Selected Day/Reports/Scheduled/Actuals: two-role Home, modal help, compact feedback, details and idle resize; evidence unchanged.")
finally:
    if master >= 0:
        os.close(master)
    if process.poll() is None:
        process.kill()
        process.wait(timeout=5)
