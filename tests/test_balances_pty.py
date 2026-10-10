#!/usr/bin/env python3
"""Balances selection, resize and bounded Print; temporary synthetic data only."""
from __future__ import annotations

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


def resize(terminal, rows, cols):
    fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))


def send(terminal, keys, expected):
    os.write(terminal.fd, keys)
    _, output = terminal.capture(expected)
    return probe.ANSI.sub(b"", output)


def bounded(output, rows, cols):
    positions = re.findall(rb"\x1b\[(\d+);(\d+)H", output)
    assert positions and all(1 <= int(r) <= rows and 1 <= int(c) <= cols for r, c in positions), positions
    assert b"\n" not in output and b"\r" not in output, "frame moved the terminal screen"


def main():
    with tempfile.TemporaryDirectory(prefix="loam-balances-pty-") as tmp:
        root = Path(tmp)
        probe.fixture(root, events=0)
        locus = "long-balance-" + "x" * 100 + "-locus-tail"
        measure = "measure-" + "m" * 50 + "-measure-tail"
        quantity = -12345678901234567890123456789012345678901234567890123456789012345678901234567890
        subprocess.run(["lake", "env", "lean", "--run", "Loam/Tests/TuiHouseholdCutoverFixture.lean",
                        str(root), "set-current-anchor", locus, measure, str(quantity)],
                       cwd=ROOT, check=True)
        selection = f"{locus}\t{measure}\n" + "".join(f"PTY-BAL-{i}\tjpy\n" for i in range(1, 30))
        config = root / "config/balance-view.tsv"
        config.write_text(selection)
        before = probe.digest(root)
        terminal = probe.Terminal(ROOT / ".lake/build/bin/loamTui", root)
        try:
            initial = send(terminal, b"b", b"Balances / Current")
            assert "╭".encode() in initial and b"see details" in initial and "…".encode() in initial
            send(terminal, b"i", b"Selected balance")
            resize(terminal, 14, 48)
            _, frame = terminal.capture(b"Selected balance")
            bounded(frame, 14, 48)
            assert b"Balances [active]" not in probe.ANSI.sub(b"", frame), "compact Detail was clipped by a table"
            send(terminal, b"\x1b[F", b"State: exact")
            send(terminal, b"q", b"Balances [active]")
            send(terminal, b"\x1b[F", b"PTY-BAL-29")
            send(terminal, b"p", b"Print to scrollback?")
            cancelled = send(terminal, b"n\r", b"Press Enter to return to LOAM:")
            assert b"No report lines emitted" in cancelled and locus.encode() not in cancelled
            send(terminal, b"\r", b"Balances / Current")
            # Printing must include the first coordinate's full amount, although
            # only the final rows are currently visible in the bounded table.
            send(terminal, b"p", b"Print to scrollback?")
            printed = send(terminal, b"y\r", b"Press Enter to return to LOAM:")
            assert locus.encode() in printed and measure.encode() in printed
            assert f"{quantity:,}".encode() in printed and b"PTY-BAL-1 " in printed and b"PTY-BAL-29 " in printed
            assert b"? jpy  unsupported" in printed
            send(terminal, b"\r", b"Balances / Current")
            os.write(terminal.fd, b"q")
            _, home = terminal.capture(b"LOAM Home")
            bounded(home, 14, 48)  # parent must not redraw with its pre-child bounds
            assert probe.digest(root) == before, "read-only navigation/Print changed fixture bytes"
            # A too-large selection refuses in the TUI before leaving raw/alt
            # screen mode; no partial report, scrollback prompt or store write.
            config.write_text("".join(f"overflow-{i}\tjpy\n" for i in range(195)))
            refusal_before = probe.digest(root)
            send(terminal, b"b", b"Balances / Current")
            refused = send(terminal, b"p", b"Print refused:")
            assert b"more than 200 lines" in refused and b"Print to scrollback?" not in refused
            send(terminal, b"q", b"LOAM Home")
            assert probe.digest(root) == refusal_before, "Print refusal changed fixture bytes"
            config.write_text(selection)
            terminal.quit()
            assert probe.digest(root) == before, "Balances navigation/Print changed household or configuration bytes"
        finally:
            terminal.close()
    print("Balances PTY: selection/Detail, child/parent resize, full bounded Print and unchanged fixture passed.")


if __name__ == "__main__":
    main()
