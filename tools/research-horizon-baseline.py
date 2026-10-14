#!/usr/bin/env python3
"""One-off, synthetic-only 1/5/10/20/30-year HouseholdImage read baseline.

Reuses the existing qualified full-household Lean phase profile and the existing
temporary-fixture builder. This is *not* a temporal-correction/restore benchmark,
a cold-cache controlled experiment, or a proposal to partition authority.

Required on Ubuntu/macOS with GNU time installed:
  lake build loamTui
  lake env lean -c /tmp/loam-actual-read-profile.c tools/ActualReadProfile.lean
  # Compile using the loamTui.rsp link arguments as shown in
  # docs/research/TUI_RESOURCE_QUALITY_2026-10-09.md.
  python3 tools/research-horizon-baseline.py --profile /tmp/loam-actual-read-profile
"""
from __future__ import annotations

import argparse
import datetime
import importlib.util
import json
import os
from pathlib import Path
import platform
import re
import statistics
import subprocess
import tempfile
import time


ROOT = Path(__file__).resolve().parents[1]
PHASES = (
    "file IO",
    "outer framing",
    "Actual parse+construction+admission",
    "retained date validation alone",
    "re-admission alone",
    "full household selection",
    "Balance projection from generation",
    "fresh Record world",
)
PHASE_RE = re.compile(r"^(.+?): (\d+)ms$")
RSS_RE = re.compile(r"^HORIZON_MAXRSS_KIB=(\d+)$", re.MULTILINE)


def load_existing_fixture_tool():
    path = ROOT / "tools" / "benchmark-tui-resources.py"
    spec = importlib.util.spec_from_file_location("loam_synthetic_fixture", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("existing fixture builder cannot be imported")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def period_days(today: datetime.date, years: int) -> int:
    # Include both endpoints and account for leap years. On Feb 29, a prior
    # non-leap year uses Feb 28 rather than inventing an invalid date.
    try:
        start = today.replace(year=today.year - years)
    except ValueError:
        start = today.replace(year=today.year - years, day=28)
    return (today - start).days + 1


def inspect_profile(profile: Path, root: Path, timeout: float) -> dict:
    start = time.perf_counter()
    result = subprocess.run(
        ["/usr/bin/time", "-f", "HORIZON_MAXRSS_KIB=%M", str(profile), str(root)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=True,
    )
    total_ms = (time.perf_counter() - start) * 1000
    phases = {}
    for line in result.stdout.splitlines():
        match = PHASE_RE.fullmatch(line.strip())
        if match:
            phases[match.group(1)] = int(match.group(2))
    missing = set(PHASES) - set(phases)
    if missing:
        raise RuntimeError(f"profile omitted phases {sorted(missing)}: {result.stdout}")
    rss = RSS_RE.search(result.stderr)
    if rss is None:
        raise RuntimeError(f"GNU time did not report maximum RSS: {result.stderr}")
    return {
        "wall_ms": round(total_ms, 2),
        "maxrss_kib": int(rss.group(1)),
        "phase_ms": {phase: phases[phase] for phase in PHASES},
    }


def summarize(samples: list[dict]) -> dict:
    fields = {"wall_ms": [s["wall_ms"] for s in samples],
              "maxrss_kib": [s["maxrss_kib"] for s in samples]}
    for phase in PHASES:
        fields[phase] = [s["phase_ms"][phase] for s in samples]
    return {
        key: {
            "median": statistics.median(values),
            "min": min(values),
            "max": max(values),
        }
        for key, values in fields.items()
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", type=Path, required=True,
                        help="compiled tools/ActualReadProfile.lean probe")
    parser.add_argument("--years", nargs="+", type=int, default=[1, 5, 10, 20, 30])
    parser.add_argument("--events-per-day", type=int, default=2)
    parser.add_argument("--runs", type=int, default=3,
                        help="measured process runs, after one separate warm-up")
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("--output", type=Path, default=Path("horizon-results.json"))
    args = parser.parse_args()
    if not args.years or any(year < 1 or year > 50 for year in args.years):
        parser.error("years must be in 1..50")
    if not (1 <= args.events_per_day <= 20) or not (1 <= args.runs <= 10):
        parser.error("events-per-day must be in 1..20 and runs in 1..10")
    profile = args.profile.resolve()
    if not profile.is_file():
        parser.error("compiled Lean phase probe does not exist")
    probe = load_existing_fixture_tool()
    today = datetime.date.today()
    report = {
        "status": "synthetic compiled HouseholdImage READ baseline, not migration qualification",
        "date": today.isoformat(),
        "platform": platform.platform(),
        "hardware": platform.machine(),
        "profile": "tools/ActualReadProfile.lean (compiled; current main/PR head)",
        "fixture": "tools/benchmark-tui-resources.py fixture()",
        "runs_after_warmup": args.runs,
        "events_per_day": args.events_per_day,
        "limitations": [
            "Synthetic JPY-only records; initial fixture adds one seeded Event.",
            "No cross-year corrections/settlement/FX stress shape in this phase.",
            "Warm process samples after one warm-up; not controlled cold filesystem cache.",
            "Lean phase counters are integer ms; total wall clock separately measured.",
            "Read-only; publication and interrupted restore are not benchmarked.",
            "Peak RSS from GNU time is per compiled-profile process.",
        ],
        "cases": [],
    }
    with tempfile.TemporaryDirectory(prefix="loam-1969-horizon-") as scratch:
        for years in args.years:
            days = period_days(today, years)
            events = days * args.events_per_day
            root = Path(scratch) / f"synthetic-{years}y"
            probe.fixture(root, events, days)
            before = probe.digest(root)
            authority_bytes = (root / "household.loam").stat().st_size
            _ = inspect_profile(profile, root, args.timeout)  # exclude warm-up
            samples = [inspect_profile(profile, root, args.timeout)
                       for _ in range(args.runs)]
            if probe.digest(root) != before:
                raise AssertionError("read-only profile changed the synthetic authority")
            case = {
                "years": years,
                "date_buckets": days,
                "events_added": events,
                "authority_bytes": authority_bytes,
                "unchanged_sha256": True,
                "statistics": summarize(samples),
                "samples": samples,
            }
            report["cases"].append(case)
            median = case["statistics"]
            print(f"HORIZON years={years} events_added={events} "
                  f"bytes={authority_bytes} "
                  f"full_household_median_ms={median['full household selection']['median']} "
                  f"record_world_median_ms={median['fresh Record world']['median']} "
                  f"wall_median_ms={median['wall_ms']['median']} "
                  f"maxrss_median_kib={median['maxrss_kib']['median']}", flush=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write("## #1969 synthetic HouseholdImage horizon read baseline\n\n")
            f.write("| Years | Days | Added Events | Bytes | Full selection median ms | Fresh Record world median ms | Wall median ms | Max RSS median KiB |\n")
            f.write("| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n")
            for case in report["cases"]:
                m = case["statistics"]
                f.write(f"| {case['years']} | {case['date_buckets']} | {case['events_added']} | "
                        f"{case['authority_bytes']} | {m['full household selection']['median']} | "
                        f"{m['fresh Record world']['median']} | {m['wall_ms']['median']} | "
                        f"{m['maxrss_kib']['median']} |\n")
            f.write("\nRead-only synthetic probe; no cross-year correction, publication or recovery claim.\n")


if __name__ == "__main__":
    main()
