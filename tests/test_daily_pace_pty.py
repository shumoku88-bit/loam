#!/usr/bin/env python3
"""Daily Pace navigation, read failures and idle resize on synthetic data only."""
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
import time

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("loam_resource_probe", ROOT / "tools/benchmark-tui-resources.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


def send(terminal, keys, expected):
    os.write(terminal.fd, keys)
    _, output = terminal.capture(expected)
    return probe.ANSI.sub(b"", output)


def resize(terminal, rows, cols, expected):
    fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    if not expected:
        time.sleep(.3)  # One-row views have no printable payload to wait for.
    _, output = terminal.capture(expected)
    bounded(output, rows, cols)
    return probe.ANSI.sub(b"", output)


def bounded(output, rows, cols):
    positions = re.findall(rb"\x1b\[(\d+);(\d+)H", output)
    assert (positions or rows == 1) and all(1 <= int(r) <= rows and 1 <= int(c) <= cols for r, c in positions), positions
    assert b"\n" not in output and b"\r" not in output, "frame moved terminal screen"


def fixture(root, events=0, days=180):
    probe.fixture(root, events=events, days=days)
    # The resource fixture deliberately retains an undated cancellation. For
    # this positive reconstruction specimen, install a separate admitted synthetic
    # Scheduled image with no retirement/replacement. Never modify operational data.
    subprocess.run(["lake", "env", "lean", "--run", "Loam/Tests/TuiHouseholdCutoverFixture.lean",
                    str(root), "set-scheduled", str(datetime.date.today())], cwd=ROOT, check=True)
    today = datetime.date.today()
    (root / "config/boundary-presets.tsv").write_text(
        f"Synthetic\t{today - datetime.timedelta(days=47)}\t"
        f"{today - datetime.timedelta(days=12)}\t{today + datetime.timedelta(days=18)}\n")


def check_loaded(root):
    before = probe.digest(root)
    terminal = probe.Terminal(ROOT / ".lake/build/bin/loamTui", root)
    try:
        initial = send(terminal, b"d", b"Daily Pace / Trend")
        assert "╭ Trend [active]".encode() in initial and "╭ Selected day".encode() in initial
        assert b"Chart unavailable" not in initial and b"history unavailable" not in initial, initial
        assert any(0x2800 <= ord(char) <= 0x28ff for char in initial.decode())
        latest = datetime.date.fromisoformat(re.search(rb"Selected (\d{4}-\d{2}-\d{2})", initial).group(1).decode())
        first = latest - datetime.timedelta(days=9)
        assert b"1:10d*" in initial and b"5:Previous Cycle" in initial
        # Every preset remains daily and endpoint selection uses inclusive ranges.
        choices = [(b"2", b"30d", latest - datetime.timedelta(days=29), latest),
                   (b"3", b"Month", latest.replace(day=1), latest),
                   (b"4", b"Cycle", latest - datetime.timedelta(days=12), latest),
                   (b"5", b"Previous Cycle", latest - datetime.timedelta(days=47),
                    latest - datetime.timedelta(days=13)),
                   (b"1", b"10d", first, latest)]
        for key, label, start, through in choices:
            changed = send(terminal, key, b"Daily Pace / Trend")
            assert label in changed and b"history unavailable" not in changed, changed
            if start != through:
                send(terminal, b"\x1b[F\x1b[H", b"Selected " + str(start).encode())
                send(terminal, b"\x1b[F", b"Selected " + str(through).encode())
        # Unbatched mixed movements must retain all 8 requested actions.
        send(terminal, b"\x1b[H", b"Selected " + str(first).encode())
        send(terminal, b"jjjjkkjj", b"Selected " + str(first + datetime.timedelta(days=4)).encode())
        assert terminal.idle(.3) == 0, "continuous input left residual scrolling"
        send(terminal, b"\x1b[F", b"Selected " + str(latest).encode())
        send(terminal, b"h", str(latest - datetime.timedelta(days=1)).encode())
        send(terminal, b"l", str(latest).encode())
        send(terminal, b"\x1b[H", b"Selected " + str(first).encode())
        send(terminal, b"\x1b[F", b"Selected " + str(latest).encode())
        send(terminal, b"i", b"Selected day")
        compact = resize(terminal, 14, 48, b"Selected day")
        assert "╭ Trend".encode() not in compact and str(latest).encode() in compact
        assert b"/day" in compact and b"current" in compact
        send(terminal, b"\x1b[F", b"no separate daily snapshot is kept.")
        send(terminal, b"q", b"Trend [active]")
        compact = resize(terminal, 16, 60, b"Daily Pace / Trend")
        assert str(latest).encode() in compact and b"[q] back" in compact
        assert terminal.idle(.3) == 0, "idle Daily Pace emitted redundant frames"
        for rows, cols in [(24, 80), (40, 120), (48, 160), (8, 24), (5, 12), (1, 32), (16, 60)]:
            resize(terminal, rows, cols, b"Daily" if rows >= 8 else b"[h/l]" if rows >= 5 else b"")
        os.write(terminal.fd, b"q")
        _, home = terminal.capture(b"LOAM Home")
        bounded(home, 16, 60)
        terminal.quit()
        assert probe.digest(root) == before, "Daily Pace navigation/resize changed fixture bytes"
    finally:
        terminal.close()


def check_failed(root):
    # Explicit unsupported pool: shared reconstruction must refuse, not display
    # a fake zero. A long UTF-8 coordinate must remain reviewable in Detail.
    token = "界" * 80 + "-pace-cause-tail"
    (root / "config/daily-pace.tsv").write_text(f"{token}\tjpy\n")
    before = probe.digest(root)
    terminal = probe.Terminal(ROOT / ".lake/build/bin/loamTui", root)
    try:
        opened = send(terminal, b"d", b"Daily Pace / Trend")
        assert b"history unavailable" in opened and b"0 jpy/day" not in opened
        send(terminal, b"i", b"Selected day")
        resize(terminal, 14, 48, b"Selected day")
        send(terminal, b"\x1b[F", b"pace-cause-tail")
        send(terminal, b"q", b"Trend [active]")
        send(terminal, b"q", b"LOAM Home")
        terminal.quit()
        assert probe.digest(root) == before, "Daily Pace refusal navigation changed fixture bytes"
    finally:
        terminal.close()


def check_missing_previous(root):
    today = datetime.date.today()
    # Keep current boundaries but deliberately omit the predecessor; never infer it.
    (root / "config/boundary-presets.tsv").write_text(
        f"Synthetic\t{today - datetime.timedelta(days=12)}\t{today + datetime.timedelta(days=18)}\n")
    before = probe.digest(root)
    terminal = probe.Terminal(ROOT / ".lake/build/bin/loamTui", root)
    try:
        initial = send(terminal, b"d", b"Daily Pace / Trend")
        assert b"history unavailable" not in initial
        refused = send(terminal, b"5", b"history unavailable")
        assert b"not explicitly configured" in refused and b"0 jpy/day" not in refused
        restored = send(terminal, b"1", b"Selected " + str(today).encode())
        assert b"history unavailable" not in restored
        send(terminal, b"q", b"LOAM Home")
        terminal.quit()
        assert probe.digest(root) == before
    finally:
        terminal.close()


def main():
    with tempfile.TemporaryDirectory(prefix="loam-daily-pace-pty-") as tmp:
        root = Path(tmp)
        fixture(root)
        check_loaded(root)
        check_missing_previous(root)
        check_failed(root)
    print("Daily Pace PTY: reconstructed graph/day selection, Detail/refusal, idle/parent resize and unchanged fixture passed.")


if __name__ == "__main__":
    main()
