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


def fixture_text(events: int, shape: str) -> str:
    rows = ["LOAM-NORMALIZED-ACTUAL\t1"]
    for index in range(events):
        event_id = f"bench-{index:08d}"
        if shape == "described":
            tx = f"TX\t{event_id}\t2026-01-01\tDESC\tbenchmark description {index:08d}"
        else:
            tx = f"TX\t{event_id}\t2026-01-01\tNODESC"
        rows.append(tx)

        if shape == "corrected" and index % 2 == 1:
            rows.append(f"REPLACES\tbench-{index - 1:08d}")

        rows.extend(
            [
                "EFFECT\tcash\tjpy\t-1",
                "EFFECT\texpense\tjpy\t1",
                "ENDTX",
            ]
        )
    return "\n".join(rows) + "\n"


def measure(binary: Path, root: Path, repeat: int, timeout: float) -> list[float]:
    samples: list[float] = []
    for _ in range(repeat):
        started = time.perf_counter()
        completed = subprocess.run(
            [str(binary), "review", str(root), "t"],
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
        "--shape",
        choices=["plain", "described", "corrected"],
        default="plain",
        help=(
            "synthetic history shape: plain has no descriptions/corrections; "
            "described gives every Event a description; corrected makes every "
            "odd Event replace the preceding Event"
        ),
    )
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
    parser.add_argument(
        "--compare-binary",
        type=Path,
        default=None,
        help="path to candidate binary for direct paired comparison against baseline",
    )
    args = parser.parse_args()

    if args.repeat < 1 or any(size < 1 for size in args.sizes):
        parser.error("sizes and repeat must be positive")

    if not args.no_build:
        subprocess.run(["lake", "build", "loam"], cwd=ROOT, check=True)
    if not BINARY.is_file():
        raise SystemExit("loam binary is missing; run lake build loam first")
    if args.compare_binary is not None and not args.compare_binary.is_file():
        raise SystemExit(f"candidate binary not found: {args.compare_binary}")

    print(f"shape\t{args.shape}")
    if args.compare_binary is not None:
        print(f"baseline\t{BINARY}")
        print(f"candidate\t{args.compare_binary}")
        print("events\tbytes\tbase_median_s\tcand_median_s\tspeedup\tbase_ratio\tcand_ratio")
    else:
        print("events\tbytes\tmedian_s\tmin_s\tmax_s\tratio_to_previous")

    previous_median: float | None = None
    previous_cand_median: float | None = None

    with tempfile.TemporaryDirectory(prefix="loam-actual-bench-") as tmp:
        tmpdir = Path(tmp)
        for size in args.sizes:
            case_root = tmpdir / f"case-{size}"
            case_root.mkdir()
            path = case_root / "actual.loam"
            path.write_text(fixture_text(size, args.shape), encoding="utf-8")
            try:
                samples = measure(BINARY, case_root, args.repeat, args.timeout)
            except subprocess.TimeoutExpired:
                print(f"{size}\t{path.stat().st_size}\tTIMEOUT\t-\t-\t-")
                return 2

            median = statistics.median(samples)
            if args.compare_binary is not None:
                try:
                    cand_samples = measure(args.compare_binary, case_root, args.repeat, args.timeout)
                except subprocess.TimeoutExpired:
                    print(f"{size}\t{path.stat().st_size}\t{median:.6f}\tTIMEOUT\t-\t-\t-")
                    return 2
                cand_median = statistics.median(cand_samples)
                speedup = f"{median / cand_median:.2f}x" if cand_median > 0 else "∞"
                base_ratio = "-" if previous_median is None else f"{median / previous_median:.2f}x"
                cand_ratio = "-" if previous_cand_median is None else f"{cand_median / previous_cand_median:.2f}x"
                print(
                    f"{size}\t{path.stat().st_size}\t{median:.6f}\t{cand_median:.6f}\t"
                    f"{speedup}\t{base_ratio}\t{cand_ratio}"
                )
                previous_cand_median = cand_median
            else:
                ratio = "-" if previous_median is None else f"{median / previous_median:.2f}x"
                print(
                    f"{size}\t{path.stat().st_size}\t{median:.6f}\t"
                    f"{min(samples):.6f}\t{max(samples):.6f}\t{ratio}"
                )
            previous_median = median

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
