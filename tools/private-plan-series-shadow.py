#!/usr/bin/env python3
from __future__ import annotations

from collections import Counter, defaultdict
from dataclasses import dataclass, field
from hashlib import sha256
from pathlib import Path
import re
import sys

HEADER = re.compile(r"^(\d{4}-\d{2}-\d{2})(?:\s|$)")
PLAN_ID = re.compile(r"^;\s*plan-id\s*:\s*(\S(?:.*\S)?)\s*$")
SERIES = re.compile(r"^;\s*series\s*:\s*(\S(?:.*\S)?)\s*$")
RECUR = re.compile(r"^;\s*recur\s*:\s*(\S(?:.*\S)?)\s*$")


class Refusal(Exception):
    pass


@dataclass
class Record:
    plan_ids: list[str] = field(default_factory=list)
    series: list[str] = field(default_factory=list)
    recur: list[str] = field(default_factory=list)


def digest(path: Path) -> str:
    h = sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(65536), b""):
            h.update(block)
    return h.hexdigest()


def scan(path: Path) -> list[Record]:
    records: list[Record] = []
    current: Record | None = None

    with path.open("r", encoding="utf-8") as handle:
        for raw in handle:
            line = raw.rstrip("\n")
            stripped = line.strip()
            if not stripped:
                continue

            indented = len(line) != len(line.lstrip())
            if not indented:
                if HEADER.match(stripped):
                    current = Record()
                    records.append(current)
                else:
                    current = None
                continue

            if current is None:
                continue

            match = PLAN_ID.match(stripped)
            if match:
                current.plan_ids.append(match.group(1))
                continue

            match = SERIES.match(stripped)
            if match:
                current.series.append(match.group(1))
                continue

            match = RECUR.match(stripped)
            if match:
                current.recur.append(match.group(1))

    return records


def summarize(records: list[Record]) -> list[str]:
    if any(len(record.plan_ids) > 1 for record in records):
        raise Refusal("plan record has multiple plan-id fields")
    if any(len(record.series) > 1 for record in records):
        raise Refusal("plan record has multiple series fields")
    if any(len(record.recur) > 1 for record in records):
        raise Refusal("plan record has multiple recur fields")

    plan_ids = [record.plan_ids[0] for record in records if record.plan_ids]
    if len(set(plan_ids)) != len(plan_ids):
        raise Refusal("plan-id is not unique in plan source")

    series_counts: Counter[str] = Counter()
    series_recur_presence: dict[str, set[bool]] = defaultdict(set)
    series_recur_values: dict[str, set[str]] = defaultdict(set)
    recur_series: dict[str, set[str]] = defaultdict(set)

    with_series = 0
    with_recur = 0
    with_series_and_recur = 0
    with_series_without_recur = 0

    for record in records:
        series = record.series[0] if record.series else None
        recur = record.recur[0] if record.recur else None

        if recur is not None:
            with_recur += 1

        if series is None:
            continue

        with_series += 1
        series_counts[series] += 1
        series_recur_presence[series].add(recur is not None)

        if recur is None:
            with_series_without_recur += 1
            continue

        with_series_and_recur += 1
        series_recur_values[series].add(recur)
        recur_series[recur].add(series)

    unique_series = len(series_counts)
    single_member_series = sum(1 for count in series_counts.values() if count == 1)
    multi_member_series = sum(1 for count in series_counts.values() if count >= 2)
    mixed_recur_presence = sum(
        1 for values in series_recur_presence.values() if values == {False, True}
    )
    multi_recur_series = sum(
        1 for values in series_recur_values.values() if len(values) >= 2
    )
    shared_recur_classes = sum(
        1 for values in recur_series.values() if len(values) >= 2
    )

    return [
        "LOAM private Plan Series shadow",
        f"plan records observed: {len(records)}",
        f"plan records with explicit plan-id: {len(plan_ids)}",
        f"plan records with explicit series: {with_series}",
        f"plan records without explicit series: {len(records) - with_series}",
        f"unique explicit series observed: {unique_series}",
        f"series with exactly one observed Plan member: {single_member_series}",
        f"series with multiple observed Plan members: {multi_member_series}",
        f"plan records with explicit recurrence classification: {with_recur}",
        f"series-tagged Plans with explicit recurrence classification: {with_series_and_recur}",
        f"series-tagged Plans without explicit recurrence classification: {with_series_without_recur}",
        f"series spanning recurrence-present and recurrence-absent members: {mixed_recur_presence}",
        f"series spanning multiple distinct explicit recurrence classifications: {multi_recur_series}",
        f"explicit recurrence classifications shared by multiple series: {shared_recur_classes}",
        "series membership inferred from Plan content: no",
        "private identities/content: withheld",
    ]


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: private-plan-series-shadow.py PLAN_JOURNAL", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    if not path.is_file():
        print("LOAM private Plan Series shadow: source file not found", file=sys.stderr)
        return 2

    try:
        before = digest(path)
        records = scan(path)
        lines = summarize(records)
        after = digest(path)
    except Refusal as exc:
        print("LOAM private Plan Series shadow: REFUSED")
        print(f"reason: {exc}")
        print("private identities/content: withheld")
        print("private parser stderr: withheld")
        return 2
    except Exception:
        print("LOAM private Plan Series shadow: REFUSED")
        print("reason: private source could not be summarized safely")
        print("private identities/content: withheld")
        print("private parser stderr: withheld")
        return 2

    if before != after:
        print("LOAM private Plan Series shadow: REFUSED")
        print("reason: source changed during observation")
        print("sources unchanged: no")
        print("private identities/content: withheld")
        return 2

    for line in lines:
        print(line)
    print("sources unchanged: yes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
