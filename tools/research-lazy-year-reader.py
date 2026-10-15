#!/usr/bin/env python3
"""Synthetic, non-production lazy-reader closure research for LOAM (#1969).

No household image is read. Segment by *learned/publication* year, never by
Event validity year. Only an admitted/qualified manifest could justify pruning.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import tempfile


class Unavailable(ValueError):
    """Missing, unqualified, contradictory or corrupted historical evidence."""


def packed(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def bucket(year: int, width: int) -> int:
    if width <= 0:
        raise ValueError("positive width required")
    return year // width * width


@dataclass(frozen=True)
class Change:
    learned: int
    order: int
    action: str            # open, revise, retire
    source: str            # stable Actual/Scheduled source id
    valid: int | None = None
    amount: int | None = None
    kind: str | None = None  # actual, scheduled (only when opening)


# A deliberately awkward specimen: late entry, repeated cross-year changes,
# Scheduled completion paired with its resulting Actual, and idle years.
SPECIMEN = (
    Change(2023, 1, "open", "opening", 2023, 500, "actual"),
    Change(2025, 2, "open", "old", 2025, -40, "actual"),
    Change(2025, 3, "open", "due", 2026, 70, "scheduled"),
    Change(2026, 4, "retire", "due"),
    Change(2026, 5, "open", "payment", 2026, -70, "actual"),
    Change(2027, 6, "revise", "old", 2025, -44),
    Change(2027, 7, "open", "late", 2025, 7, "actual"),
    Change(2028, 8, "revise", "old", 2028, -46),
    Change(2028, 9, "revise", "old", 2025, -47),
    Change(2028, 10, "revise", "old", 2028, -48),
    Change(2031, 11, "open", "later", 2031, 15, "actual"),
)


def state_after(changes: list[dict], cutoff: int, sources: set[str] | None = None) -> dict[str, tuple[str, int, int] | None]:
    """Full semantic oracle for specimen operations; not LOAM's Review."""
    state: dict[str, tuple[str, int, int] | None] = {}
    for c in sorted(changes, key=lambda r: (r["learned"], r["order"])):
        if c["learned"] > cutoff or (sources is not None and c["source"] not in sources):
            continue
        src, action = c["source"], c["action"]
        if action == "open":
            if src in state or c["kind"] not in ("actual", "scheduled"):
                raise Unavailable("duplicate or malformed original")
            state[src] = (c["kind"], c["valid"], c["amount"])
        elif action == "revise":
            if src not in state or state[src] is None:
                raise Unavailable("revision without live source")
            state[src] = (state[src][0], c["valid"], c["amount"])
        elif action == "retire":
            if src not in state or state[src] is None:
                raise Unavailable("terminal without live source")
            state[src] = None
        else:
            raise Unavailable("unknown action")
    return state


def rows_with_affected_years(changes: tuple[Change, ...]) -> list[dict]:
    """Compute a disposable index at seal time, not new canonical money facts."""
    prior: dict[str, tuple[str, int, int] | None] = {}
    result: list[dict] = []
    for r in sorted(changes, key=lambda c: (c.learned, c.order)):
        row = vars(r).copy()
        if r.action == "open":
            if r.source in prior or r.kind not in ("actual", "scheduled") or r.valid is None or r.amount is None:
                raise Unavailable("invalid original")
            affected = {r.valid}
            prior[r.source] = (r.kind, r.valid, r.amount)
        elif r.action in ("revise", "retire"):
            earlier = prior.get(r.source)
            if earlier is None:
                raise Unavailable("invalid revision/retirement")
            affected = {earlier[1]}
            if r.action == "revise":
                if r.valid is None or r.amount is None:
                    raise Unavailable("revision missing replacement")
                affected.add(r.valid)
                prior[r.source] = (earlier[0], r.valid, r.amount)
            else:
                prior[r.source] = None
        else:
            raise Unavailable("unknown action")
        row["affected"] = sorted(affected)
        result.append(row)
    return result


def seal(root: Path, changes: tuple[Change, ...], width: int) -> dict:
    """Experiment-only segment writer; physical multi-file atomicity NOT proven."""
    by_bucket: dict[int, list[dict]] = {}
    for row in rows_with_affected_years(changes):
        by_bucket.setdefault(bucket(row["learned"], width), []).append(row)
    index = []
    for yr, rows in sorted(by_bucket.items()):
        body = packed(rows)
        (root / f"{yr}.json").write_bytes(body)
        index.append({"year": yr, "sha256": digest(body), "count": len(rows),
                      "affected": sorted({y for row in rows for y in row["affected"]}),
                      "sources": sorted({row["source"] for row in rows})})
    metadata = {"width": width, "entries": index}
    manifest = {**metadata, "qualified_seal": digest(packed(metadata))}
    (root / "manifest.json").write_bytes(packed(manifest))
    return manifest


class Reader:
    def __init__(self, root: Path):
        self.root = root
        self.reads: set[int] = set()
        self.cache: dict[int, list[dict]] = {}
        try:
            manifest = json.loads((root / "manifest.json").read_bytes())
            metadata = {k: manifest[k] for k in ("width", "entries")}
            if manifest["qualified_seal"] != digest(packed(metadata)):
                raise Unavailable("unqualified manifest content")
            if manifest["width"] <= 0 or len({e["year"] for e in manifest["entries"]}) != len(manifest["entries"]):
                raise Unavailable("invalid segment layout")
            self.index = {e["year"]: e for e in manifest["entries"]}
            self.width = manifest["width"]
        except (OSError, KeyError, TypeError, ValueError) as exc:
            raise Unavailable("missing or invalid manifest") from exc

    def load(self, year: int) -> list[dict]:
        if year in self.cache:
            return self.cache[year]
        entry = self.index.get(year)
        if entry is None:
            raise Unavailable("segment is absent from qualified index")
        try:
            body = (self.root / f"{year}.json").read_bytes()
            if digest(body) != entry["sha256"]:
                raise Unavailable("segment integrity mismatch")
            rows = json.loads(body)
            if len(rows) != entry["count"]:
                raise Unavailable("segment row-count mismatch")
            if {r["source"] for r in rows} != set(entry["sources"]):
                raise Unavailable("segment identity summary mismatch")
            if {y for r in rows for y in r["affected"]} != set(entry["affected"]):
                raise Unavailable("segment affected-year summary mismatch")
            if any(bucket(r["learned"], self.width) != year for r in rows):
                raise Unavailable("record belongs to different publication partition")
        except (OSError, KeyError, TypeError, ValueError) as exc:
            raise Unavailable(f"missing or corrupt segment {year}") from exc
        self.reads.add(year)
        self.cache[year] = rows
        return rows

    def transaction_year(self, year: int, as_known_by: int) -> dict[str, tuple[str, int, int]]:
        """Selective closure from signed summaries, including all revisions per ID."""
        relevant = [e["year"] for e in self.index.values()
                    if e["year"] <= bucket(as_known_by, self.width)
                    and year in e["affected"]]
        sources: set[str] = set()
        for part in relevant:
            sources.update(r["source"] for r in self.load(part)
                           if r["learned"] <= as_known_by and year in r["affected"])
        closure = {e["year"] for e in self.index.values()
                   if e["year"] <= bucket(as_known_by, self.width)
                   and sources.intersection(e["sources"])}
        selected = [r for segment in sorted(closure) for r in self.load(segment)
                    if r["source"] in sources]
        state = state_after(selected, as_known_by, sources)
        return {src: value for src, value in state.items()
                if value is not None and value[0] == "actual" and value[1] == year}

    def full_prefix(self, as_known_by: int) -> dict[str, tuple[str, int, int] | None]:
        """Conservative full-prefix plan for balance, Scheduled and Daily Pace.

        Exact balance and Daily Pace need an admitted opening/checkpoint and
        current-support/policy proof before partial-prefix pruning is safe.
        """
        parts = sorted(year for year in self.index if year <= bucket(as_known_by, self.width))
        return state_after([r for year in parts for r in self.load(year)], as_known_by)


def check() -> dict:
    results = []
    materialized = rows_with_affected_years(SPECIMEN)
    for width in (1, 5, 10):
        with tempfile.TemporaryDirectory(prefix="loam-lazy-year-test-") as tmp:
            root = Path(tmp)
            manifest = seal(root, SPECIMEN, width)
            reader = Reader(root)
            all_segments = len(manifest["entries"])
            checks = 0
            for cutoff in (2023, 2025, 2026, 2027, 2028, 2031):
                for valid in (2023, 2025, 2026, 2028, 2031):
                    oracle = state_after(materialized, cutoff)
                    expected = {k: v for k, v in oracle.items()
                                if v is not None and v[0] == "actual" and v[1] == valid}
                    actual = reader.transaction_year(valid, cutoff)
                    assert actual == expected, (width, valid, cutoff, actual, expected)
                    checks += 1
            assert reader.full_prefix(2031) == state_after(materialized, 2031)
            # No file was created for idle years 2024, 2029 or 2030 (width=1).
            if width == 1:
                assert all(y not in reader.index for y in (2024, 2029, 2030))
                isolated = Reader(root)
                isolated.transaction_year(2023, 2023)
                assert isolated.reads == {2023}
                assert len(isolated.reads) < all_segments
                # Missing *required* history refuses; never silently returns 0.
                (root / "2027.json").unlink()
                try:
                    Reader(root).transaction_year(2025, 2028)
                except Unavailable:
                    pass
                else:
                    raise AssertionError("missing correction partition was accepted")
            else:
                # Corrupt one index summary and fail before pruning.
                altered = json.loads((root / "manifest.json").read_text())
                altered["entries"][0]["affected"] = []
                (root / "manifest.json").write_bytes(packed(altered))
                try:
                    Reader(root)
                except Unavailable:
                    pass
                else:
                    raise AssertionError("tampered manifest was accepted")
            results.append({"width": width, "year_queries_checked": checks,
                            "partition_count": all_segments,
                            "idle_years_do_not_write": True,
                            "cross_year_replay_equals_full_scan": True,
                            "required_missing_or_tampered_refused": True})
    return {"status": "synthetic annual-lazy query closure PASS", "cases": results,
            "limits": "not production LOAM codec, no durable multi-file commit/restore, no qualified checkpoint or Daily Pace projection"}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check:
        print(json.dumps(check(), indent=2))
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
