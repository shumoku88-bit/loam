#!/usr/bin/env python3
"""Eleven direct analysis entrances and resize/return parity; synthetic data only."""
from __future__ import annotations

import datetime
import fcntl
import importlib.util
import os
from pathlib import Path
import re
import struct
import subprocess
import tempfile
import termios

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("loam_resource_probe", ROOT / "tools/benchmark-tui-resources.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
ANALYSIS = b" jj\r"
LABELS = ["Daily Pace", "Balances / Current", "Income & Expense", "Transactions Flow",
          "Stock–Flow", "Trend / Locus comparison", "Balances / Accounting", "Liquidity",
          "Budget Window", "Multicurrency Spend", "Fava Projection (external)"]
MARKERS = [b"Daily Pace / Trend", b"Balances / Current", b"Reports / Income & Expense",
           b"Reports / Transactions Flow", "Reports / Stock–Flow".encode(), b"Trend   cycle average / day",
           b"Reports / Balances", b"Reports / Liquidity", b"Reports / Budget Window",
           b"Reports / Multicurrency Spend", b"Fava server unavailable:"]


def send(terminal, keys, expected):
    os.write(terminal.fd, keys)
    _, output = terminal.capture(expected)
    return probe.ANSI.sub(b"", output)


def resize(terminal, rows, cols, expected):
    fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    _, output = terminal.capture(expected)
    positions = re.findall(rb"\x1b\[(\d+);(\d+)H", output)
    assert positions and all(1 <= int(r) <= rows and 1 <= int(c) <= cols for r, c in positions), positions
    assert b"\n" not in output and b"\r" not in output
    return probe.ANSI.sub(b"", output)


def open_report(terminal, index):
    opened = send(terminal, ANALYSIS + b"j" * index + b"\r", MARKERS[index])
    assert b"Reports menu" not in opened and b"Home > Reports" not in opened, opened
    return opened


def main():
    with tempfile.TemporaryDirectory(prefix="loam-reports-navigation-pty-") as tmp:
        root = Path(tmp) / "household"
        probe.fixture(root, events=12)
        # Use the positive Daily Pace specimen, without undated retirement evidence.
        for action in ["set-scheduled", "set-capacity", "set-scheduled-routing", "set-actual-routing"]:
            arguments = [str(root), action]
            if action != "set-actual-routing":
                arguments.append(str(datetime.date.today()))
            subprocess.run(["lake", "env", "lean", "--run", "Loam/Tests/TuiHouseholdCutoverFixture.lean",
                            *arguments], cwd=ROOT, check=True)
        subprocess.run(["lake", "env", "lean", "--run", "Loam/Tests/TuiReportLaunch.lean",
                        str(root), str(datetime.date.today())], cwd=ROOT, check=True)
        frozen = probe.digest(root)
        # Deterministically exercise the real exporter + external-server refusal,
        # without installing a service or opening the user's browser. Success and
        # owned-server cleanup have a separate live Fava lifecycle qualification.
        commands = Path(tmp) / "commands"
        commands.mkdir()
        for name, body in {"uvx": "exit 1", "curl": "exit 1", "lsof": "exit 1"}.items():
            command = commands / name
            command.write_text("#!/bin/sh\n" + body + "\n")
            command.chmod(0o755)
        old_path = os.environ["PATH"]
        os.environ["PATH"] = str(commands) + os.pathsep + old_path
        terminal = probe.Terminal(ROOT / ".lake/build/bin/loamTui", root)
        try:
            # Each independent expected label must be selectable and visible,
            # moving down with both key grammars and back up across the viewport.
            send(terminal, ANALYSIS, b"> Daily Pace")
            for index, label in enumerate(LABELS[1:], 1):
                key = b"j" if index % 2 else b"\x1b[B"
                frame = send(terminal, key, ("> " + label).encode())
                assert ("> " + label).encode() in frame
            assert terminal.idle(.3) == 0, "idle palette emitted redundant frames"
            for rows, cols in [(10, 48), (6, 32), (3, 32), (1, 32), (13, 80), (40, 120)]:
                frame = resize(terminal, rows, cols, b"> Fava Projection")
                assert b"> Fava Projection" in frame
                if rows <= 13:
                    assert b"Daily Pace" not in frame, "palette did not scroll its viewport"
            for index in range(9, -1, -1):
                key = b"k" if index % 2 else b"\x1b[A"
                send(terminal, key, ("> " + LABELS[index]).encode())
            send(terminal, b"\x1b", b"Home / Commands")
            send(terminal, b"\x1b", b"LOAM Home")
            # Preserve a non-today selected Home date across every entrance/exit.
            home = send(terminal, b"h", b"Focus:")
            focus = re.search(rb"Focus: (\d{4}-\d{2}-\d{2})", home).group(1)
            selected = datetime.date.fromisoformat(focus.decode())
            month_start = str(selected.replace(day=1)).encode()
            for index in range(11):
                opened = open_report(terminal, index)
                if index in [2, 3, 4, 8, 9]:
                    assert b"Start: " + month_start in opened, (index, opened)
                if index == 10:
                    # External failure is a Home notice, never a report/menu loop.
                    assert b"LOAM Home" in opened
                    assert b"Focus: " + focus in opened
                    continue
                returned = send(terminal, b"q" if index % 2 else b"\x1b", b"LOAM Home")
                assert b"Focus: " + focus in returned and b"Reports menu" not in returned
            # Income & Expense display modes and comparison return to its own root.
            open_report(terminal, 2)
            send(terminal, b"\r", b"Income:")
            send(terminal, b"g", b"Monthly")
            send(terminal, b"g", b"Daily")
            send(terminal, b"g", b"Summary")
            send(terminal, b"c", b"Compare")
            send(terminal, b"\r", b"Left")
            send(terminal, b"q", b"Reports / Income & Expense")
            send(terminal, b"q", b"LOAM Home")
            # Stock–Flow comparison and explicit window preset/shift still work.
            open_report(terminal, 4)
            send(terminal, b"]", b"Synthetic")
            send(terminal, b"c", b"Compare")
            send(terminal, b"\r", b"Left")
            send(terminal, b"\x1b", "Reports / Stock–Flow".encode())
            send(terminal, b"q", b"LOAM Home")
            # Transactions Flow summary -> contributors -> summary -> Home.
            open_report(terminal, 3)
            send(terminal, b"\r", b"Coordinate")
            send(terminal, b"\r", b"Focused coordinate:")
            send(terminal, b"q", b"Coordinate")
            send(terminal, b"\x1b", b"LOAM Home")
            # Trend's series picker remains reachable on direct initialization.
            open_report(terminal, 5)
            send(terminal, b"a", b"bank")
            send(terminal, b"q", b"q/Esc Home")
            send(terminal, b"]]", b"daily amount")
            send(terminal, b"o", b"Overlay")
            send(terminal, b"q", b"q")  # Free-text editor retains q as input, Esc cancels.
            send(terminal, b"\x1b", b"q/Esc Home")
            os.write(terminal.fd, b"q")
            _, returned = terminal.capture(b"LOAM Home")
            assert b"\x1b[?1002l" in returned, "Trend left mouse motion enabled after exit"
            # Accounting evidence/Print is distinct from Current Balances.
            opened = open_report(terminal, 6)
            assert b"Qualified Net Worth" in opened
            send(terminal, b"p", b"Print to scrollback?")
            send(terminal, b"n\r", b"Press Enter to return to LOAM:")
            send(terminal, b"\r", b"Reports / Balances")
            resize(terminal, 6, 32, b"q / Esc Home")
            send(terminal, b"\x1b", b"[Spac")
            resize(terminal, 40, 120, b"LOAM Home")
            # Opening Commands from transaction focus preserves the Home pane/date.
            send(terminal, b"\t", b"[Esc/Tab/w]")
            open_report(terminal, 4)
            returned = send(terminal, b"q", b"LOAM Home")
            assert b"[Esc/Tab/w]" in returned and b"Focus: " + focus in returned
            # Re-enter the external action to retry without revisiting a dead menu.
            open_report(terminal, 10)
            assert terminal.idle(.2) == 0
            terminal.quit()
            assert probe.digest(root) == frozen, "read-only report navigation changed household/config bytes"
        finally:
            terminal.close()
            os.environ["PATH"] = old_path
    print("Reports PTY: eleven direct entrances, selection scroll/idle resize (32×1), modes/details/compare/Print, Fava refusal/retry, Home date and unchanged fixture passed.")


if __name__ == "__main__":
    main()
