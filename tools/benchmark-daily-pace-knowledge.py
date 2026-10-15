#!/usr/bin/env python3
"""Synthetic-only comparison of two proposed Daily Pace knowledge encodings.

This is NOT a LOAM production codec or a benchmark of Lean/HouseholdImage I/O.
Run: python3 tools/benchmark-daily-pace-knowledge.py --check
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import date, timedelta
import json
from pathlib import Path
import random
import statistics
import tempfile
from time import perf_counter_ns


@dataclass(frozen=True)
class Entry:
    day: int
    kind: str  # K: retained fact reference; V: retained changed policy/support version
    identity: str
    payload: str = ""  # for V only; never duplicate movement quantities
    commit: str = ""  # synthetic publication group; not a persisted new ID


def make_entries(years: int, per_year: int, seed: int = 381) -> tuple[int, list[Entry]]:
    """Synthetic sources and replacement revisions; no real household data."""
    if years < 1 or per_year < 0:
        raise ValueError("years >= 1 and publications/year >= 0 required")
    days = years * 365
    rng = random.Random(seed + years * 100003 + per_year)
    rows: list[Entry] = []
    for i in range(years * per_year):
        learned = rng.randrange(days)
        if i % 9 == 0:
            # One admitted Scheduled completion publishes two existing IDs.
            rows.extend([
                Entry(learned, "K", f"scheduled:terminal:{i:09d}", commit=f"actual-op:{i}"),
                Entry(learned, "K", f"actual:completion:{i:09d}", commit=f"actual-op:{i}"),
            ])
        else:
            rows.append(Entry(learned, "K", f"actual:event:{i:09d}", commit=f"actual-op:{i}"))
    # The previous values of these replaceable authorities are NOT in today's
    # source image. The version payload is genuinely additional history.
    # Same-day revisions intentionally occur and their order must be retained.
    for i in range(years * 12):
        day = rng.randrange(days)
        rows.append(Entry(day, "V", f"pool:{i:07d}", f"bank={'yes' if i % 2 else 'no'}", f"pool-op:{i}"))
    for i in range(years * 6):
        day = rng.randrange(days)
        rows.append(Entry(day, "V", f"cycle:{i:07d}", f"end-index={30 + i % 31}", f"cycle-op:{i}"))
    for i in range(years * 6):
        day = rng.randrange(days)
        rows.append(Entry(day, "V", f"anchor:{i:07d}", f"root={i:07d}", f"anchor-op:{i}"))
    for i in range(years * 6):
        day = rng.randrange(days)
        rows.append(Entry(day, "V", f"support:{i:07d}", f"from={i % 365:03d}", f"support-op:{i}"))
    # Python stable sort preserves within-day accepted-publication order.
    return days, sorted(rows, key=lambda e: e.day)


def iso(index: int) -> str:
    return (date(2026, 1, 1) + timedelta(days=index)).isoformat()


def encode_tagged(rows: list[Entry]) -> bytes:
    return "".join(f"{r.kind}\t{iso(r.day)}\t{r.identity}\t{r.payload}\n" for r in rows).encode("ascii")


def encode_bucketed(rows: list[Entry]) -> bytes:
    output: list[str] = []
    prior = -1
    for r in rows:
        if r.day != prior:
            output.append(f"D\t{iso(r.day)}\n")
            prior = r.day
        output.append(f"{r.kind}\t{r.identity}\t{r.payload}\n")
    return "".join(output).encode("ascii")


def decode_tagged(blob: bytes) -> list[tuple[str, str, str, str]]:
    result = []
    for line in blob.decode("ascii").splitlines():
        kind, learned, identity, payload = line.split("\t")
        assert kind in ("K", "V")
        result.append((learned, kind, identity, payload))
    return result


def decode_bucketed(blob: bytes) -> list[tuple[str, str, str, str]]:
    result = []
    day = None
    for line in blob.decode("ascii").splitlines():
        fields = line.split("\t")
        if fields[0] == "D":
            assert len(fields) == 2
            day = fields[1]
        else:
            assert day is not None and fields[0] in ("K", "V") and len(fields) == 3
            result.append((day, fields[0], fields[1], fields[2]))
    return result


def day_end_summaries(decoded: list[tuple[str, str, str, str]], days: int) -> list[tuple[int, tuple]]:
    """One sequential replay over days; stores summaries solely for benchmark checks."""
    pos = 0
    latest: dict[str, str] = {}
    n_refs = 0
    result = []
    for d in range(days):
        today = iso(d)
        while pos < len(decoded) and decoded[pos][0] <= today:
            _, kind, identity, payload = decoded[pos]
            if kind == "K":
                n_refs += 1
            else:
                # Version identities have a policy family prefix; last accepted
                # revision in publication order wins on the same day.
                latest[identity.split(":", 1)[0]] = identity + "=" + payload
            pos += 1
        result.append((n_refs, tuple(sorted(latest.items()))))
    assert pos == len(decoded)
    return result


def metadata_rewrite_bytes(rows: list[Entry], mode: str, base_bytes: int) -> int:
    """Modeled full-image rewrite after each accepted *publication group*.

    Counts metadata plus an illustrative fixed synthetic base. It excludes
    pre-existing source bodies and is NOT a measured production write count.
    """
    total = 0
    size = base_bytes
    prior_day = -1
    for pos, r in enumerate(rows):
        if mode == "A":
            size += len(f"{r.kind}\t{iso(r.day)}\t{r.identity}\t{r.payload}\n")
        else:
            if prior_day != r.day:
                size += len(f"D\t{iso(r.day)}\n")
                prior_day = r.day
            size += len(f"{r.kind}\t{r.identity}\t{r.payload}\n")
        # A completion's Actual+Scheduled references share *one* commit.
        if pos + 1 == len(rows) or rows[pos + 1].commit != r.commit:
            total += size
    return total


def stage_readback_ms(blob: bytes, rounds: int) -> float:
    """Synthetic metadata-only stage + readback + atomic rename sample."""
    results = []
    with tempfile.TemporaryDirectory(prefix="loam-knowledge-synthetic-") as name:
        root = Path(name)
        current = root / "synthetic-knowledge"
        stage = root / "synthetic-knowledge.stage"
        for _ in range(rounds):
            start = perf_counter_ns()
            stage.write_bytes(blob)
            assert stage.read_bytes() == blob
            stage.replace(current)
            results.append((perf_counter_ns() - start) / 1e6)
    return round(statistics.median(results), 3)


def run_one(years: int, per_year: int, rounds: int, check: bool) -> dict:
    days, rows = make_entries(years, per_year)
    a, b = encode_tagged(rows), encode_bucketed(rows)
    t0 = perf_counter_ns()
    da = decode_tagged(a)
    ta = (perf_counter_ns() - t0) / 1e6
    t0 = perf_counter_ns()
    db = decode_bucketed(b)
    tb = (perf_counter_ns() - t0) / 1e6
    assert da == db, "encoding must retain exactly the same ordered learned facts and revisions"
    t0 = perf_counter_ns()
    sa = day_end_summaries(da, days)
    ra = (perf_counter_ns() - t0) / 1e6
    t0 = perf_counter_ns()
    sb = day_end_summaries(db, days)
    rb = (perf_counter_ns() - t0) / 1e6
    assert sa == sb, "each day-end query must match including policy winners"
    active_days = len(set(x.day for x in rows))
    assert len(sa) == days
    assert len(da) == len(rows)
    assert sum(kind == "K" for _, kind, _, _ in da) >= per_year * years
    # Zero accepted publications on idle calendar days: not one D row per day.
    assert active_days <= days
    if check:
        # Explicit test: the same-day last policy revision must win.
        collision = [Entry(2, "V", "pool:000001", "bank=yes"),
                     Entry(2, "V", "pool:000002", "bank=no")]
        assert decode_tagged(encode_tagged(collision)) == decode_bucketed(encode_bucketed(collision))
        assert day_end_summaries(decode_bucketed(encode_bucketed(collision)), 4)[2][1] == (
            ("pool", "pool:000002=bank=no"),)
    # Synthetic fixed-size base is used only to expose amplification scaling.
    # It is NOT a measured LOAM household baseline or existing-event byte size.
    synthetic_base_bytes = 4096
    return {
        "years": years, "calendar_days": days, "publications_per_year_assumed": per_year,
        "source_and_version_rows": len(rows), "accepted_publications": len({r.commit for r in rows}), "active_days": active_days,
        "idle_days": days - active_days, "metadata_tagged_bytes": len(a),
        "metadata_bucketed_bytes": len(b),
        "bucketed_savings_pct": round(100 * (1 - len(b) / len(a)), 2),
        "modeled_rewrite_tagged_mib": round(metadata_rewrite_bytes(rows, "A", synthetic_base_bytes) / 1048576, 2),
        "modeled_rewrite_bucketed_mib": round(metadata_rewrite_bytes(rows, "B", synthetic_base_bytes) / 1048576, 2),
        "decode_tagged_ms": round(ta, 3), "decode_bucketed_ms": round(tb, 3),
        "daily_scan_tagged_ms": round(ra, 3), "daily_scan_bucketed_ms": round(rb, 3),
        "stage_readback_tagged_ms": stage_readback_ms(a, rounds),
        "stage_readback_bucketed_ms": stage_readback_ms(b, rounds),
        "ordered_as_known_equivalence": True,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--years", type=int, nargs="+", default=[1, 10, 20])
    parser.add_argument("--per-year", type=int, nargs="+", default=[50, 730, 5000])
    parser.add_argument("--rounds", type=int, default=3)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.rounds < 1 or any(y < 1 for y in args.years) or any(n < 0 for n in args.per_year):
        parser.error("years >= 1, per-year >= 0, rounds >= 1")
    results = [run_one(y, n, args.rounds, args.check) for y in args.years for n in args.per_year]
    print(json.dumps({"fixture": "deterministic synthetic metadata only, not LOAM runtime",
                      "tagged_vs_ordered_bucketed": results}, indent=2))


if __name__ == "__main__":
    main()
