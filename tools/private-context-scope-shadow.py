#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass, field
from hashlib import sha256
from pathlib import Path
import re
import sys

HEADER = re.compile(r"^(\d{4}-\d{2}-\d{2})(?:\s|$)")


class Refusal(Exception):
    pass


@dataclass
class Record:
    description_present: bool
    metadata_comments: int = 0
    postings: int = 0
    posting_inline_comments: int = 0


def digest(path: Path) -> str:
    h = sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(65536), b""):
            h.update(block)
    return h.hexdigest()


def header_description(line: str) -> str | None:
    stripped = line.strip()
    match = HEADER.match(stripped)
    if match is None:
        return None
    remainder = stripped[match.end():].lstrip()
    if remainder[:1] in {"*", "!"}:
        remainder = remainder[1:].lstrip()
    return remainder


def scan(path: Path) -> list[Record]:
    records: list[Record] = []
    current: Record | None = None

    with path.open("r", encoding="utf-8") as handle:
        for raw in handle:
            line = raw.rstrip("\n")
            stripped = line.strip()

            if not stripped:
                current = None
                continue

            indented = len(line) != len(line.lstrip())
            if not indented:
                description = header_description(line)
                if description is not None:
                    if not description:
                        raise Refusal("transaction header has no description")
                    current = Record(description_present=True)
                    records.append(current)
                else:
                    current = None
                continue

            if current is None:
                continue

            if stripped.startswith(";"):
                current.metadata_comments += 1
                continue

            current.postings += 1
            if ";" in stripped:
                current.posting_inline_comments += 1

    if any(record.postings == 0 for record in records):
        raise Refusal("transaction record has no posting lines")

    return records


def summarize(records: list[Record]) -> list[str]:
    records_with_metadata = sum(1 for r in records if r.metadata_comments > 0)
    metadata_lines = sum(r.metadata_comments for r in records)
    posting_lines = sum(r.postings for r in records)
    multi_posting_records = sum(1 for r in records if r.postings >= 3)
    inline_comment_lines = sum(r.posting_inline_comments for r in records)
    records_with_inline_comments = sum(
        1 for r in records if r.posting_inline_comments > 0
    )

    return [
        "LOAM private context scope shadow",
        f"transaction records observed: {len(records)}",
        f"records with nonempty header description: {sum(r.description_present for r in records)}",
        f"records with transaction-block metadata comments: {records_with_metadata}",
        f"transaction-block metadata comment lines observed: {metadata_lines}",
        f"posting lines observed: {posting_lines}",
        f"records with three-or-more postings: {multi_posting_records}",
        f"posting lines with inline comments: {inline_comment_lines}",
        f"records with posting inline comments: {records_with_inline_comments}",
        "human context ontology assigned: no",
        "effect-level context inferred from source shape: no",
        "private identities/content: withheld",
    ]


def refuse() -> int:
    print("LOAM private context scope shadow: REFUSED", file=sys.stderr)
    print("private identities/content: withheld", file=sys.stderr)
    print("private parser detail: withheld", file=sys.stderr)
    return 2


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        return refuse()

    path = Path(argv[1])
    try:
        before = digest(path)
        records = scan(path)
        after = digest(path)
    except (OSError, UnicodeError, Refusal):
        return refuse()

    if before != after:
        return refuse()

    for line in summarize(records):
        print(line)
    print("sources unchanged: yes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
