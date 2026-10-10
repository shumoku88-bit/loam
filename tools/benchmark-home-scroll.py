#!/usr/bin/env python3
"""Compiled Home Year-scroll tail probe; temporary synthetic authority only.

Measures output tail until an ordered Space sentinel opens Commands. No events
are dropped: the sentinel must be processed after the complete navigation burst.
"""
from __future__ import annotations

import argparse
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import statistics
import struct
import tempfile
import termios
import time

spec = importlib.util.spec_from_file_location("resources", Path(__file__).with_name("benchmark-tui-resources.py"))
resources = importlib.util.module_from_spec(spec)
spec.loader.exec_module(resources)


def selected_title(output: bytes) -> str:
    clean = resources.ANSI.sub(b"", output).decode("utf-8")
    match = resources.re.search(r"▶ - ([^│\n]+)", clean)
    assert match, clean[-4000:]
    return match.group(1).strip()


def return_home(terminal) -> str:
    os.write(terminal.fd, b"\x1b")
    _, output = terminal.capture(b"LOAM Home")
    return selected_title(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, default=resources.ROOT / ".lake/build/bin/loamTui")
    parser.add_argument("--events", type=int, default=10000)
    parser.add_argument("--days", type=int, default=500)
    parser.add_argument("--burst", type=int, default=20)
    parser.add_argument("--rounds", type=int, default=3)
    parser.add_argument("--check", action="store_true", help="require each ordered burst to finish within 2s")
    args = parser.parse_args()
    assert args.events >= 12 and args.days > 0 and args.burst > 0 and args.rounds > 0
    with tempfile.TemporaryDirectory(prefix="loam-home-scroll-") as tmp:
        root = Path(tmp) / "household"
        resources.fixture(root, args.events, args.days)
        before = resources.digest(root)
        terminal = resources.Terminal(args.binary.resolve(), root)
        try:
            terminal.send(b"zz\t", b"/ Detail [active]")
            samples = {}
            selections = {}
            for name, keys in [("keys", b"j" * args.burst),
                               ("wheel", b"\x1b[<65;130;12M" * args.burst),
                               ("pages", b"\x1b[6~" * args.burst),
                               ("reverse", b"j" * args.burst + b"k" * args.burst),
                               ("wheel_reverse", b"\x1b[<65;130;12M" * args.burst +
                                b"\x1b[<64;130;12M" * args.burst)]:
                elapsed = []
                for _ in range(args.rounds):
                    # Home selects the newest record, so every burst has room to move.
                    terminal.send(b"\x1b[F\x1b[H ", b"Home / Commands")
                    initial_title = return_home(terminal)
                    start = time.monotonic()
                    os.write(terminal.fd, keys + b" ")
                    _, output = terminal.capture(b"Home / Commands", timeout=120)
                    elapsed.append(round((time.monotonic() - start) * 1000, 1))
                    assert b"Home / Commands" in resources.ANSI.sub(b"", output)
                    final_title = return_home(terminal)
                    if name in ("reverse", "wheel_reverse"):
                        assert final_title == initial_title, (name, initial_title, final_title)
                    selections.setdefault(name, []).append(final_title)
                samples[name] = {"ms": elapsed, "median_ms": statistics.median(elapsed)}
                if args.check:
                    assert max(elapsed) < 2000, (name, elapsed)
            assert selections["keys"] == selections["wheel"], "wheel/key final selection differs"
            # Width and height changes rewrap the viewport without losing focus.
            for rows, cols in [(24, 80), (14, 48), (48, 160)]:
                fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
                terminal.capture(b"LOAM Home")
                start = time.monotonic()
                os.write(terminal.fd, b"jk\x1b[6~\x1b[5~ ")
                _, output = terminal.capture(b"Home / Commands")
                elapsed = round((time.monotonic() - start) * 1000, 1)
                samples[f"resize_{cols}x{rows}"] = {"ms": [elapsed]}
                positions = resources.re.findall(rb"\x1b\[(\d+);(\d+)H", output)
                assert all(1 <= int(r) <= rows and 1 <= int(c) <= cols for r, c in positions)
                if args.check:
                    assert elapsed < 2000, (rows, cols, elapsed)
                assert return_home(terminal) == initial_title, "resize/pages changed final selection"
            assert terminal.idle(.3) == 0, "post-sentinel movement/output"
            terminal.quit()
            assert before == resources.digest(root), "read-only probe changed fixture"
            print(json.dumps({"events": args.events, "days": args.days, "burst": args.burst,
                              "samples": samples, "fixture_unchanged": True}, indent=2))
        finally:
            terminal.close()


if __name__ == "__main__":
    main()
