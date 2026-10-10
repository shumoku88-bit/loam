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
    # Explicit read-side monitoring, not an inferred recurrence or fixture writer.
    coverage_config = root / "config" / "scheduled-coverage.tsv"
    coverage_config.parent.mkdir(exist_ok=True)
    coverage_definition = "wifi\t2026-11-08\t1\tbank\twifi\n"
    coverage_config.write_text(coverage_definition)
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
        capture(b"LOAM Home")
        send(b"s", b"Series Calendar")
        feedback = send(b"j", b"No next recurring plan.")
        changed_rows = {int(r) for r, _ in re.findall(rb"\x1b\[(\d+);(\d+)H", feedback)}
        assert changed_rows == {rows - 3}, "Calendar boundary feedback moved the table/footer"
        plan = ansi.sub(b"", send(b"\r", b"Scheduled / Plan / wifi"))
        assert "╭ Occurrences / monitored gaps".encode() in plan and b"====" not in plan
        assert b"Date/Month" in plan and b"Quanta" in plan and b"4,800 jpy" in plan
        send(b"\x1b[F", b"MISSING")  # End reaches a presentation-only monitored gap.
        for rows, columns in ((10, 48), (24, 100)):
            fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", rows, columns, 0, 0))
            output = capture(b"Scheduled / Plan / wifi")
            positions = re.findall(rb"\x1b\[(\d+);(\d+)H", output)
            assert positions and all(1 <= int(r) <= rows and 1 <= int(c) <= columns
                                     for r, c in positions)
            assert re.search(rb"> \d{4}-\d{2}\s+MISSING", ansi.sub(b"", output)), (
                "resize hid the selected monitored gap", output
            )
        feedback = send(b"j", b"Already at the last plan entry.")
        changed_rows = {int(r) for r, _ in re.findall(rb"\x1b\[(\d+);(\d+)H", feedback)}
        assert changed_rows == {rows - 3}, "Plan boundary feedback moved the table/footer"
        send(b"x", b"missing monitored month")
        assert authority.read_text() == before, "viewing or trying to cancel a gap changed authority"
        assert coverage_config.read_text() == coverage_definition, "navigation changed monitoring"
        send(b"q", b"Series Calendar")
        months = ansi.sub(b"", send(b"v", b"Scheduled / Months"))
        assert len(re.findall("╭ ".encode() + rb"\d{4}-\d{2}", months)) == 6
        assert b"Selected Scheduled" in months and b"-4,800 jpy" in months and b"+4,800 jpy" in months
        for rows, columns in ((18, 80), (10, 48), (30, 120), (24, 100)):
            fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", rows, columns, 0, 0))
            output = capture(b"Scheduled / Months")
            clean_months = ansi.sub(b"", output)
            positions = re.findall(rb"\x1b\[(\d+);(\d+)H", output)
            assert positions and all(1 <= int(r) <= rows and 1 <= int(c) <= columns
                                     for r, c in positions)
            if columns >= 80:
                assert len(re.findall("╭ ".encode() + rb"\d{4}-\d{2}", clean_months)) == 6
            else:
                assert b"Months [compact]" in clean_months and b"[v] List" in clean_months
        assert authority.read_text() == before, "Months idle resize changed household evidence"
        listed = ansi.sub(b"", send(b"v", b"Scheduled / List"))
        assert "╭ Loci".encode() in listed and "╭ Scheduled (4)".encode() in listed
        # The shared Selected pane can stay byte-identical across the mode switch,
        # so a dirty diff need not emit its title again.
        assert b"Date" in listed and b"Quanta" in listed, listed
        send(b"hj", b"Locus: bank")
        send(b"l")
        for rows, columns in ((24, 80), (10, 48), (30, 120), (24, 100)):
            fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", rows, columns, 0, 0))
            output = capture(b"Scheduled / List")
            clean_list = ansi.sub(b"", output)
            positions = re.findall(rb"\x1b\[(\d+);(\d+)H", output)
            assert positions and all(1 <= int(r) <= rows and 1 <= int(c) <= columns
                                     for r, c in positions)
            assert b"> 2026-11-08" in clean_list and b"4,800 jpy" in clean_list
            if rows >= 24:
                assert b"Selected Scheduled" in clean_list and b"ID: first" in clean_list
            if columns < 80:
                assert "╭ Loci".encode() not in clean_list, "compact List showed an inactive sidebar"
        feedback = send(b"k", b"No previous Scheduled row.")
        changed_rows = {int(r) for r, _ in re.findall(rb"\x1b\[(\d+);(\d+)H", feedback)}
        assert changed_rows == {rows - 3}, "List boundary feedback moved its panes/footer"
        assert authority.read_text() == before and coverage_config.read_text() == coverage_definition
        send(b"v", b"Series Calendar")
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
        send(b"q", b"LOAM Home")
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
        print("Scheduled PTY: fixed footers, framed Plan/Months/List, Locus filtering, idle resize, gap refusal and batch publication passed.")
    finally:
        if master >= 0:
            os.close(master)
        if process.poll() is None:
            process.kill()
            process.wait(timeout=5)
