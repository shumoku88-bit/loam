#!/usr/bin/env python3
"""Same-runner cold full-file acceptance comparison for LOAM, hledger and Beancount.

This is measurement-only. It intentionally compares nearby but not identical
semantic work:
- LOAM: production `loam review` (decode + fail-closed admission + review projection)
- hledger: `hledger check` basic journal checks
- Beancount: standard loader (parse + standard validations/plugins)

Fixture generation is outside the timed region. Each synthetic transaction/Event
has two balanced JPY postings/effects.
"""

from __future__ import annotations

import argparse
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def loam_fixture(events: int) -> str:
    rows = ["LOAM-NORMALIZED-ACTUAL\t1"]
    for i in range(events):
        eid = f"bench-{i:08d}"
        rows.extend([
            f"TX\t{eid}\t2026-01-01\tNODESC",
            "EFFECT\tcash\tjpy\t-1",
            "EFFECT\texpense\tjpy\t1",
            "ENDTX",
        ])
    return "\n".join(rows) + "\n"


def hledger_fixture(events: int) -> str:
    out: list[str] = []
    for i in range(events):
        out.extend([
            f"2026-01-01 bench-{i:08d}",
            "    assets:cash      -1 JPY",
            "    expenses:test     1 JPY",
            "",
        ])
    return "\n".join(out)


def beancount_fixture(events: int) -> str:
    out = [
        'option "title" "LOAM PTA benchmark"',
        "2000-01-01 open Assets:Cash JPY",
        "2000-01-01 open Expenses:Test JPY",
        "",
    ]
    for i in range(events):
        out.extend([
            f'2026-01-01 * "bench-{i:08d}"',
            "  Assets:Cash      -1 JPY",
            "  Expenses:Test     1 JPY",
            "",
        ])
    return "\n".join(out)


def run_checked(cmd: list[str], timeout: float) -> float:
    started = time.perf_counter()
    p = subprocess.run(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout,
        check=False,
    )
    elapsed = time.perf_counter() - started
    if p.returncode != 0:
        raise RuntimeError(f"{cmd[0]} failed ({p.returncode}): {p.stderr[-4000:]}")
    return elapsed


def measure(cmd: list[str], repeat: int, timeout: float) -> list[float]:
    return [run_checked(cmd, timeout) for _ in range(repeat)]


def bean_worker(path: str, expected: int) -> int:
    from beancount import loader
    from beancount.core import data

    entries, errors, _ = loader.load_file(path)
    if errors:
        for err in errors[:20]:
            print(err, file=sys.stderr)
        return 2
    count = sum(1 for entry in entries if isinstance(entry, data.Transaction))
    if count != expected:
        print(f"expected {expected} transactions, loaded {count}", file=sys.stderr)
        return 3
    return 0


def print_row(size: int, nbytes: int, samples: list[float], previous: float | None) -> float:
    median = statistics.median(samples)
    ratio = "-" if previous is None else f"{median / previous:.2f}x"
    print(
        f"{size}\t{nbytes}\t{median:.6f}\t{min(samples):.6f}\t"
        f"{max(samples):.6f}\t{ratio}",
        flush=True,
    )
    return median


def main() -> int:
    if len(sys.argv) >= 2 and sys.argv[1] == "_bean_worker":
        return bean_worker(sys.argv[2], int(sys.argv[3]))

    ap = argparse.ArgumentParser()
    ap.add_argument("--tool", choices=["loam", "hledger", "beancount"], required=True)
    ap.add_argument("--loam", type=Path, default=Path(".lake/build/bin/loam"))
    ap.add_argument("--hledger", type=Path, default=Path("/tmp/hledger-bin/hledger"))
    ap.add_argument("--bean-python", type=Path, default=Path("/tmp/beancount-venv/bin/python"))
    ap.add_argument("--sizes", nargs="+", type=int, default=[50000, 100000, 250000, 500000, 1000000])
    ap.add_argument("--repeat", type=int, default=3)
    ap.add_argument("--timeout", type=float, default=600.0)
    args = ap.parse_args()

    print(f"tool\t{args.tool}")
    print("items\tbytes\tmedian_s\tmin_s\tmax_s\tratio_to_previous")
    previous: float | None = None

    with tempfile.TemporaryDirectory(prefix="loam-pta-compare-") as tmp:
        root = Path(tmp)
        for size in args.sizes:
            if args.tool == "loam":
                case = root / f"loam-{size}"
                case.mkdir()
                path = case / "actual.loam"
                path.write_text(loam_fixture(size), encoding="utf-8")
                cmd = [str(args.loam), "review", str(case), "t"]
            elif args.tool == "hledger":
                path = root / f"hledger-{size}.journal"
                path.write_text(hledger_fixture(size), encoding="utf-8")
                cmd = [str(args.hledger), "-f", str(path), "check"]
            else:
                path = root / f"beancount-{size}.beancount"
                path.write_text(beancount_fixture(size), encoding="utf-8")
                cmd = [
                    str(args.bean_python),
                    str(Path(__file__).resolve()),
                    "_bean_worker",
                    str(path),
                    str(size),
                ]

            try:
                samples = measure(cmd, args.repeat, args.timeout)
            except subprocess.TimeoutExpired:
                print(f"{size}\t{path.stat().st_size}\tTIMEOUT\t-\t-\t-", flush=True)
                return 2
            previous = print_row(size, path.stat().st_size, samples, previous)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
