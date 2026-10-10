#!/usr/bin/env python3
"""Compiled Daily Pace range/input probe on disposable synthetic households only."""
from __future__ import annotations

import argparse
import datetime
import importlib.util
import json
import os
from pathlib import Path
import re
import statistics
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("pace_pty", ROOT / "tests/test_daily_pace_pty.py")
pace = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pace)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--events", type=int, default=10000)
    parser.add_argument("--days", type=int, default=500)
    parser.add_argument("--cycle-days", type=int, default=31)
    parser.add_argument("--rounds", type=int, default=3)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    assert args.events >= 0 and args.days > 0 and args.cycle_days >= 25 and args.rounds > 0
    with tempfile.TemporaryDirectory(prefix="loam-daily-pace-bench-") as tmp:
        root = Path(tmp)
        pace.fixture(root, args.events, args.days)
        today = datetime.date.today()
        first = today - datetime.timedelta(days=args.cycle_days - 1)
        prior = first - datetime.timedelta(days=35)
        (root / "config/boundary-presets.tsv").write_text(
            f"Synthetic\t{prior}\t{first}\t{today + datetime.timedelta(days=30)}\n")
        before = pace.probe.digest(root)
        terminal = pace.probe.Terminal(ROOT / ".lake/build/bin/loamTui", root)
        samples = {}
        try:
            samples["entry_ms"] = [terminal.send(b"d", b"Daily Pace / Trend")]
            terminal.send(b"4", b"Daily Pace / Trend")
            for name, keys, offset in [("keys20", b"j" * 20, 20),
                                      ("wheel20", b"\x1b[<65;30;30M" * 20, 20),
                                      ("reverse20", b"j" * 20 + b"k" * 20, 0),
                                      ("pages_reverse", b"\x1b[6~\x1b[5~", 0)]:
                samples[name] = []
                for _ in range(args.rounds):
                    # End then Home guarantees an observable reset, including after reversal.
                    terminal.send(b"\x1b[F\x1b[H", b"Selected " + str(first).encode())
                    start = time.monotonic()
                    os.write(terminal.fd, keys + b"i")  # Ordered sentinel; no input discarded.
                    _, output = terminal.capture(b"Selected day [active]")
                    samples[name].append(round((time.monotonic() - start) * 1000, 1))
                    selected = re.findall(rb"Selected (\d{4}-\d{2}-\d{2})", pace.probe.ANSI.sub(b"", output))
                    assert selected and selected[-1].decode() == str(first + datetime.timedelta(days=offset)), (name, selected)
                    assert terminal.idle(.1) == 0, "input tail after ordered sentinel"
                    terminal.send(b"i", b"Trend [active]")
                if args.check:
                    assert max(samples[name]) < 2000, (name, samples[name])
            samples["preset_switch_ms"] = []
            for _ in range(args.rounds):
                samples["preset_switch_ms"].append(terminal.send(b"5", b"Daily Pace / Trend"))
                terminal.send(b"4", b"Daily Pace / Trend")
            for rows, cols in [(14, 48), (24, 80), (48, 160)]:
                pace.resize(terminal, rows, cols, b"Daily Pace")
                terminal.send(b"li", b"Selected day [active]")
                terminal.send(b"i", b"Trend [active]")
            assert terminal.idle(.3) == 0
            terminal.send(b"q", b"LOAM Home")
            samples["fresh_reentry_ms"] = [terminal.send(b"d", b"Daily Pace / Trend")]
            terminal.send(b"q", b"LOAM Home")
            terminal.quit()
            assert before == pace.probe.digest(root)
            print(json.dumps({"events": args.events, "date_buckets": args.days,
                              "cycle_days": args.cycle_days, "rounds": args.rounds,
                              "samples": samples,
                              "medians_ms": {key: round(statistics.median(values), 1) for key, values in samples.items()},
                              "fixture_unchanged": True}, indent=2))
        finally:
            terminal.close()


if __name__ == "__main__":
    main()
