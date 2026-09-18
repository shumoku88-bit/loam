#!/usr/bin/env python3
"""Manual scaling benchmark for the production normalized Actual read path.

This deliberately benchmarks the compiled `loam review` entrance rather than an
isolated helper, so the result includes normalized decode, semantic admission,
and ActualReview projection. Fixture generation and `lake build` are outside
the timed region.

Examples:
  python3 tools/benchmark-actual-read.py
  python3 tools/benchmark-actual-read.py --sizes 1000 5000 10000 50000 --repeat 3
"""

from __future__ import annotations

import argparse
import statistics
import subprocess
import tempfile
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BINARY = ROOT / ".lake" / "build" / "bin" / "loam"


def fixture_text(events: int) -> str:
    rows = ["LOAM-NORMALIZED-ACTUAL\t1"]
    for index in range(events):
        event_id = f"bench-{index:08d}"
        rows.extend(
            [
                f"TX\t{event_id}\t2026-01-01\tNODESC",
                "EFFECT\tcash\tjpy\t-1",
                "EFFECT\texpense\tjpy\t1",
                "ENDTX",
            ]
        )
    return "\n".join(rows) + "\n"


def measure(path: Path, repeat: int, timeout: float) -> list[float]:
    samples: list[float] = []
    for _ in range(repeat):
        started = time.perf_counter()
        completed = subprocess.run(
            [str(BINARY), "review", str(path), "t"],
            cwd=ROOT,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
            check=False,
        )
        elapsed = time.perf_counter() - started
        if completed.returncode != 0:
            raise RuntimeError(
                f"loam review failed with {completed.returncode}: {completed.stderr.strip()}"
            )
        samples.append(elapsed)
    return samples


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Measure production Actual read scaling without changing household data."
    )
    parser.add_argument(
        "--sizes",
        nargs="+",
        type=int,
        default=[1000, 5000, 10000],
        help="synthetic Event counts; add 50000 explicitly for the long-horizon probe",
    )
    parser.add_argument("--repeat", type=int, default=3)
    parser.add_argument(
        "--timeout",
        type=float,
        default=300.0,
        help="per-run timeout in seconds",
    )
    parser.add_argument(
        "--no-build",
        action="store_true",
        help="reuse an existing .lake/build/bin/loam binary",
    )
    args = parser.parse_args()

    if args.repeat < 1 or any(size < 1 for size in args.sizes):
        parser.error("sizes and repeat must be positive")

    if not args.no_build:
        subprocess.run(["lake", "build", "loam"], cwd=ROOT, check=True)
    if not BINARY.is_file():
        raise SystemExit("loam binary is missing; run lake build loam first")

    print("events\tbytes\tmedian_s\tmin_s\tmax_s\tratio_to_previous")
    previous_median: float | None = None

    with tempfile.TemporaryDirectory(prefix="loam-actual-bench-") as tmp:
        tmpdir = Path(tmp)
        for size in args.sizes:
            path = tmpdir / f"actual-{size}.loam"
            path.write_text(fixture_text(size), encoding="utf-8")
            try:
                samples = measure(path, args.repeat, args.timeout)
            except subprocess.TimeoutExpired:
                print(f"{size}\t{path.stat().st_size}\tTIMEOUT\t-\t-\t-")
                return 2

            median = statistics.median(samples)
            ratio = "-" if previous_median is None else f"{median / previous_median:.2f}x"
            print(
                f"{size}\t{path.stat().st_size}\t{median:.6f}\t"
                f"{min(samples):.6f}\t{max(samples):.6f}\t{ratio}"
            )
            previous_median = median

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
