#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path


def rows(path: Path) -> Counter[str]:
    return Counter(line for line in path.read_text(encoding="utf-8").splitlines() if line)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("normalized", type=Path)
    parser.add_argument("production", type=Path)
    args = parser.parse_args()

    left = rows(args.normalized)
    right = rows(args.production)
    if left == right:
        print("normalized/current production semantic observation parity PASS")
        return 0

    print("normalized/current production semantic observation parity FAILED")
    only_left = left - right
    only_right = right - left
    if only_left:
        print("only normalized:")
        for row, count in sorted(only_left.items()):
            print(f"  {count}x {row}")
    if only_right:
        print("only production:")
        for row, count in sorted(only_right.items()):
            print(f"  {count}x {row}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
