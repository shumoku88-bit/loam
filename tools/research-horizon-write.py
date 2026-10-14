#!/usr/bin/env python3
"""#1969: isolated native HouseholdImage write cost and cross-year correction probe.

Reuses the current synthetic HouseholdImage fixture builder, *not* loam-data.
Runs the existing HouseholdCommand writer inside a small compiled Lean probe.
This intentionally does not alter production code or infer archive safety.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import re
import shutil
import statistics
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
PHASE = re.compile(r"HORIZON_WRITE mode=(\w+) publish_ms=(\d+)")
RSS = re.compile(r"HORIZON_WRITE_MAXRSS_KIB=(\d+)")
SUCCESS = re.compile(
    r"HORIZON_WRITE_VERIFIED mode=(\w+) bytes_before=(\d+) "
    r"bytes_after=(\d+) prev_identical=true stale_refused=true"
)
MODES = ("record", "correct", "date")


def fixture_builder():
    spec = importlib.util.spec_from_file_location(
        "synthetic_household", ROOT / "tools" / "benchmark-tui-resources.py"
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load existing synthetic fixture tool")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def days_in_years(today: datetime.date, years: int) -> int:
    try:
        start = today.replace(year=today.year - years)
    except ValueError:
        start = today.replace(year=today.year - years, day=28)
    return (today - start).days + 1


def hashes(root: Path) -> dict[str, str]:
    return {str(f.relative_to(root)): hashlib.sha256(f.read_bytes()).hexdigest()
            for f in root.rglob("*") if f.is_file()}


def run_once(binary: Path, root: Path, mode: str, target: str,
             date: str, timeout: float) -> dict:
    starting = time.perf_counter()
    result = subprocess.run(
        ["/usr/bin/time", "-f", "HORIZON_WRITE_MAXRSS_KIB=%M",
         str(binary), str(root), mode, target, date],
        cwd=ROOT, capture_output=True, text=True, check=False, timeout=timeout,
    )
    wall_ms = round((time.perf_counter() - starting) * 1000, 2)
    if result.returncode != 0:
        raise RuntimeError(
            f"{mode} failed rc={result.returncode} at {root}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    p = PHASE.search(result.stdout)
    s = SUCCESS.search(result.stdout)
    rss = RSS.search(result.stderr)
    if p is None or s is None or rss is None or p.group(1) != mode or s.group(1) != mode:
        raise RuntimeError(f"missing qualified markers: {result.stdout}\n{result.stderr}")
    return {
        "publish_ms": int(p.group(2)),
        "wall_ms": wall_ms,
        "maxrss_kib": int(rss.group(1)),
        "before_bytes": int(s.group(2)),
        "after_bytes": int(s.group(3)),
        "verified_previous_and_stale_refusal": True,
    }


def stats(samples: list[dict]) -> dict:
    return {key: {"median": statistics.median([s[key] for s in samples]),
                  "min": min(s[key] for s in samples),
                  "max": max(s[key] for s in samples)}
            for key in ("publish_ms", "wall_ms", "maxrss_kib")}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--binary", type=Path, required=True)
    ap.add_argument("--years", nargs="+", type=int, default=[1, 10, 20, 30])
    ap.add_argument("--events-per-day", type=int, default=2)
    ap.add_argument("--runs", type=int, default=2)
    ap.add_argument("--timeout", type=float, default=240)
    ap.add_argument("--output", type=Path, default=Path("horizon-write-results.json"))
    args = ap.parse_args()
    if not args.years or any(y < 1 or y > 50 for y in args.years):
        ap.error("years must be in 1..50")
    if not 1 <= args.events_per_day <= 10 or not 1 <= args.runs <= 5:
        ap.error("events-per-day must be 1..10; runs 1..5")
    binary = args.binary.resolve()
    if not binary.is_file():
        ap.error("compiled writer profile is missing")
    builder = fixture_builder()
    today = datetime.date.today()
    out = {
        "status": "synthetic isolated HouseholdCommand write benchmark, not archive migration",
        "platform": platform.platform(),
        "date": today.isoformat(),
        "events_per_day": args.events_per_day,
        "trials_per_operation": args.runs,
        "limitations": [
            "One-JPY-Measure ordinary history; no dense multi-family correction stress.",
            "One successful mutation per isolated fixture, not a 20-year write history.",
            "No crash/kill/fsync or migration test; previous generation is checked only.",
            "Machine/OS cache and process launch costs uncontrolled.",
            "Publish timer surrounds HouseholdCommand; verification happens outside timer.",
            "Synthetic seed contains a Scheduled completion; generated old target is unrelated.",
        ],
        "cases": [],
    }
    with tempfile.TemporaryDirectory(prefix="loam-1969-write-") as tmp:
        temp = Path(tmp)
        for years in args.years:
            days = days_in_years(today, years)
            events = days * args.events_per_day
            source = temp / f"seed-{years}y"
            builder.fixture(source, events, days)
            source_hashes = hashes(source)
            sample_map = {mode: [] for mode in MODES}
            for mode in MODES:
                for trial in range(args.runs):
                    case_root = temp / f"{years}y-{mode}-{trial}"
                    shutil.copytree(source, case_root)
                    before = hashes(case_root)
                    target = f"resource-{events-1}"
                    result = run_once(binary, case_root, mode, target,
                                      today.isoformat(), args.timeout)
                    after = hashes(case_root)
                    if after.get("household.loam.prev") != before["household.loam"]:
                        raise AssertionError("previous authority not equal to old full generation")
                    if after.get("household.loam") == before["household.loam"]:
                        raise AssertionError("successful mutation did not replace HouseholdImage")
                    if any(name not in ("household.loam", "household.loam.prev")
                           and after.get(name) != value for name, value in before.items()):
                        raise AssertionError("mutation changed unrelated fixture files")
                    if any(name.endswith(".loam-stage") for name in after):
                        raise AssertionError("successful write left a staged authority")
                    sample_map[mode].append(result)
            case = {
                "years": years, "days": days, "events_added": events,
                "seed_authority_bytes": source.joinpath("household.loam").stat().st_size,
                "initial_fixture_has_sha256": bool(source_hashes),
                "modes": {mode: {"statistics": stats(samples), "samples": samples}
                          for mode, samples in sample_map.items()},
            }
            out["cases"].append(case)
            print(f"HORIZON_WRITE_CASE years={years} events={events} "
                  + " ".join(
                      f"{mode}_median_ms={case['modes'][mode]['statistics']['publish_ms']['median']}"
                      for mode in MODES
                  ), flush=True)
    args.output.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write("\n## #1969 synthetic publication / historic amendment\n\n")
            f.write("| Years | Added Events | Record median ms | Old Event amount correction median ms | Old Event date revision median ms |\n")
            f.write("| ---: | ---: | ---: | ---: | ---: |\n")
            for case in out["cases"]:
                m = case["modes"]
                f.write(f"| {case['years']} | {case['events_added']} | "
                        f"{m['record']['statistics']['publish_ms']['median']} | "
                        f"{m['correct']['statistics']['publish_ms']['median']} | "
                        f"{m['date']['statistics']['publish_ms']['median']} |\n")
            f.write("\nEach case verified full previous generation and stale-generation refusal; no power-loss recovery claim.\n")


if __name__ == "__main__":
    main()
