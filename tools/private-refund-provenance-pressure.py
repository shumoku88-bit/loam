#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass, field
from hashlib import sha256
from pathlib import Path
import re
import sys

HEADER = re.compile(r"^(\d{4}-\d{2}-\d{2})(?:\s|$)")
INTEGER = re.compile(r"^[+-]?\d+$")

Posting = tuple[str, str, int]


class Refusal(Exception):
    pass


@dataclass
class Record:
    postings: list[Posting] = field(default_factory=list)
    unsupported_posting: bool = False


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

            if current is None or stripped.startswith(";"):
                continue

            parts = stripped.split()
            if len(parts) < 3 or not INTEGER.fullmatch(parts[-2]):
                current.unsupported_posting = True
                continue

            locus = " ".join(parts[:-2])
            if not locus:
                current.unsupported_posting = True
                continue

            current.postings.append((locus, parts[-1], int(parts[-2])))

    return records


def two_posting_view(record: Record) -> tuple[Posting, Posting] | None:
    if record.unsupported_posting or len(record.postings) != 2:
        return None
    return record.postings[0], record.postings[1]


def reversal_view(record: Record) -> tuple[Posting, Posting] | None:
    view = two_posting_view(record)
    if view is None:
        return None

    expense = [posting for posting in view if posting[0].startswith("expenses:")]
    other = [posting for posting in view if not posting[0].startswith("expenses:")]
    if len(expense) != 1 or len(other) != 1:
        return None

    expense_posting = expense[0]
    other_posting = other[0]
    if expense_posting[1] != other_posting[1]:
        return None
    if expense_posting[2] >= 0 or other_posting[2] <= 0:
        return None

    return expense_posting, other_posting


def source_candidate(
    record: Record,
    reversal: tuple[Posting, Posting],
) -> tuple[bool, bool]:
    view = two_posting_view(record)
    if view is None:
        return False, False

    reverse_expense, reverse_other = reversal
    by_locus = {posting[0]: posting for posting in view}
    if len(by_locus) != 2:
        return False, False
    if set(by_locus) != {reverse_expense[0], reverse_other[0]}:
        return False, False

    source_expense = by_locus[reverse_expense[0]]
    source_other = by_locus[reverse_other[0]]
    if source_expense[1] != reverse_expense[1] or source_other[1] != reverse_other[1]:
        return False, False
    if source_expense[2] <= 0 or source_other[2] >= 0:
        return False, False

    shape_compatible = True
    exact_opposite = (
        source_expense[2] == -reverse_expense[2]
        and source_other[2] == -reverse_other[2]
    )
    return shape_compatible, exact_opposite


def bucket(count: int) -> str:
    if count == 0:
        return "zero"
    if count == 1:
        return "one"
    return "multiple"


def summarize(records: list[Record]) -> list[str]:
    exact_buckets = {"zero": 0, "one": 0, "multiple": 0}
    shape_buckets = {"zero": 0, "one": 0, "multiple": 0}
    reversal_count = 0
    two_posting_count = 0
    unsupported_count = 0

    for index, record in enumerate(records):
        if record.unsupported_posting:
            unsupported_count += 1
        if two_posting_view(record) is not None:
            two_posting_count += 1

        reversal = reversal_view(record)
        if reversal is None:
            continue

        reversal_count += 1
        shape_candidates = 0
        exact_candidates = 0
        for prior in records[:index]:
            shape_compatible, exact_opposite = source_candidate(prior, reversal)
            if shape_compatible:
                shape_candidates += 1
            if exact_opposite:
                exact_candidates += 1

        shape_buckets[bucket(shape_candidates)] += 1
        exact_buckets[bucket(exact_candidates)] += 1

    return [
        "LOAM private refund provenance pressure observer",
        f"records observed: {len(records)}",
        f"two-posting records observed: {two_posting_count}",
        f"records with unsupported posting syntax: {unsupported_count}",
        f"expense-reversal-shaped records observed: {reversal_count}",
        f"exact-opposite prior candidate count zero: {exact_buckets['zero']}",
        f"exact-opposite prior candidate count one: {exact_buckets['one']}",
        f"exact-opposite prior candidate count multiple: {exact_buckets['multiple']}",
        f"same-coordinate opposite-direction prior candidate count zero: {shape_buckets['zero']}",
        f"same-coordinate opposite-direction prior candidate count one: {shape_buckets['one']}",
        f"same-coordinate opposite-direction prior candidate count multiple: {shape_buckets['multiple']}",
        "refund semantics assigned from reversal shape: no",
        "source provenance inferred from physical candidates: no",
        "descriptions used for classification: no",
        "private identities/content: withheld",
    ]


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: private-refund-provenance-pressure.py ACTUAL_JOURNAL", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    if not path.is_file():
        print("LOAM private refund provenance pressure observer: source file not found", file=sys.stderr)
        return 2

    before = digest(path)
    try:
        records = scan(path)
        output = summarize(records)
    except (OSError, UnicodeError, Refusal):
        after = digest(path) if path.is_file() else None
        print("LOAM private refund provenance pressure observer: REFUSED")
        print(f"sources unchanged: {'yes' if after == before else 'no'}")
        print("private identities/content: withheld")
        print("private parser stderr: withheld")
        return 2

    after = digest(path)
    if before != after:
        print("LOAM private refund provenance pressure observer: REFUSED")
        print("sources unchanged: no")
        print("private identities/content: withheld")
        return 2

    print("\n".join(output))
    print("sources unchanged: yes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
