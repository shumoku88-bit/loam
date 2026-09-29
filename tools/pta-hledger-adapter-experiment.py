#!/usr/bin/env python3
"""Small hledger-backed normalization experiment for Observation 385.

This is deliberately not a production importer. It asks hledger to parse and
materialize posting amounts, while separately retaining a tiny inventory of
source features that hledger's tabular print output can otherwise flatten.

Output is a narrow TSV consumed by Loam/Tests/PtaMigrationClassifier.lean:

    T<TAB>txnidx<TAB>YYYY-MM-DD<TAB>feature,feature
    P<TAB>txnidx<TAB>account<TAB>measure<TAB>exact-quanta

The experiment intentionally supports only the synthetic fixture family checked
into tests/fixtures/pta-import.
"""

from __future__ import annotations

import csv
import re
import subprocess
import sys
from dataclasses import dataclass
from decimal import Decimal
from pathlib import Path


DATE_HEADER = re.compile(r"^(\d{4}[-/]\d{2}[-/]\d{2})(?:=\d{4}[-/]\d{2}[-/]\d{2})?(?:\s+|$)")
ASSERTION = re.compile(r"\s(?:==\*?|=\*?)\s*")
COST = re.compile(r"\s@@?\s")
POSTING_DATE_TAG = re.compile(r";.*\bdate2?\s*:", re.IGNORECASE)


@dataclass(frozen=True)
class SourceBlock:
    header: str
    postings: tuple[str, ...]


def fail(message: str) -> "None":
    raise SystemExit(f"pta-hledger-adapter-experiment: {message}")


def source_blocks(text: str) -> list[SourceBlock]:
    blocks: list[SourceBlock] = []
    header: str | None = None
    postings: list[str] = []

    for raw in text.splitlines():
        if DATE_HEADER.match(raw):
            if header is not None:
                blocks.append(SourceBlock(header, tuple(postings)))
            header = raw
            postings = []
            continue

        if header is None:
            if raw.strip() and not raw.lstrip().startswith((";", "#")):
                fail(f"unsupported top-level source line before first transaction: {raw!r}")
            continue

        if raw.startswith((" ", "\t")):
            postings.append(raw)
        elif raw.strip():
            fail(f"unsupported inter-transaction source line: {raw!r}")

    if header is not None:
        blocks.append(SourceBlock(header, tuple(postings)))

    return blocks


def posting_tail_without_comment(raw: str) -> str:
    return raw.split(";", 1)[0].strip()


def has_omitted_amount(raw: str) -> bool:
    text = posting_tail_without_comment(raw)
    if not text:
        return False

    if text.startswith(("* ", "! ")):
        text = text[2:].lstrip()

    # For this bounded fixture, account names contain no double-space runs.
    # hledger journal syntax uses two or more spaces to separate account and
    # amount fields, so no such separator means the amount was omitted.
    return re.search(r"\s{2,}", text) is None


def features_for(block: SourceBlock) -> list[str]:
    features: set[str] = set()

    rest = DATE_HEADER.sub("", block.header, count=1).lstrip()
    if rest.startswith(("* ", "! ")):
        features.add("status")

    for raw in block.postings:
        text = posting_tail_without_comment(raw)
        stripped = text.lstrip()
        if stripped.startswith(("* ", "! ")):
            stripped = stripped[2:].lstrip()

        if stripped.startswith(("(", "[")):
            features.add("virtualPosting")

        if ASSERTION.search(text):
            features.add("balanceAssertion")

        if COST.search(text) or "{" in text or "}" in text:
            features.add("cost")

        if POSTING_DATE_TAG.search(raw):
            features.add("postingDate")

        if has_omitted_amount(raw):
            features.add("inferredAmount")

    order = [
        "inferredAmount",
        "sourceComposition",
        "unconfirmedMeasureScale",
        "cost",
        "status",
        "metadata",
        "postingDate",
        "balanceAssertion",
        "balanceAssignment",
        "virtualPosting",
        "automatedRule",
        "periodicRule",
        "priceOrLot",
    ]
    return [name for name in order if name in features]


def read_scales(path: Path) -> dict[str, int]:
    result: dict[str, int] = {}
    for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not raw or raw.startswith("#"):
            continue
        parts = raw.split("\t")
        if len(parts) != 2:
            fail(f"{path}:{line_no}: expected MEASURE<TAB>SCALE")
        measure, scale_text = parts
        try:
            scale = int(scale_text)
        except ValueError:
            fail(f"{path}:{line_no}: invalid integer scale {scale_text!r}")
        if not measure or scale < 0 or scale > 9 or measure in result:
            fail(f"{path}:{line_no}: invalid or duplicate measure scale")
        result[measure] = scale
    return result


def exact_quanta(amount_text: str, measure: str, scales: dict[str, int]) -> int:
    if measure not in scales:
        fail(f"no confirmed Measure scale for {measure!r}")
    try:
        amount = Decimal(amount_text)
    except Exception as exc:
        fail(f"could not parse exact amount {amount_text!r}: {exc}")

    scale = scales[measure]
    scaled = amount * (Decimal(10) ** scale)
    integral = scaled.to_integral_value()
    if scaled != integral:
        fail(
            f"amount {amount_text!r} {measure} exceeds confirmed scale {scale}; "
            "rounding is forbidden"
        )
    return int(integral)


def hledger_rows(hledger: str, journal: Path) -> list[dict[str, str]]:
    completed = subprocess.run(
        [hledger, "-f", str(journal), "print", "-x", "-O", "csv"],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        fail("hledger refused fixture:\n" + completed.stderr.strip())

    rows = list(csv.DictReader(completed.stdout.splitlines()))
    required = {
        "txnidx",
        "date",
        "status",
        "description",
        "account",
        "amount",
        "commodity",
    }
    if not rows:
        fail("hledger produced no posting rows")
    missing = required.difference(rows[0].keys())
    if missing:
        fail(f"hledger CSV is missing expected columns: {sorted(missing)}")
    return rows


def normalize_date(text: str) -> str:
    return text.replace("/", "-")


def main(argv: list[str]) -> int:
    if len(argv) != 5:
        fail(
            "usage: pta-hledger-adapter-experiment.py "
            "<hledger> <journal> <measure-scales.tsv> <output.tsv>"
        )

    _, hledger, journal_text, scales_text, output_text = argv
    journal = Path(journal_text)
    scales_path = Path(scales_text)
    output = Path(output_text)

    blocks = source_blocks(journal.read_text(encoding="utf-8"))
    rows = hledger_rows(hledger, journal)
    scales = read_scales(scales_path)

    txn_ids: list[str] = []
    for row in rows:
        idx = row["txnidx"]
        if idx not in txn_ids:
            txn_ids.append(idx)

    if len(txn_ids) != len(blocks):
        fail(
            f"source transaction count {len(blocks)} != "
            f"hledger normalized transaction count {len(txn_ids)}"
        )

    out: list[str] = []
    for position, idx in enumerate(txn_ids):
        tx_rows = [row for row in rows if row["txnidx"] == idx]
        block = blocks[position]
        source_date_match = DATE_HEADER.match(block.header)
        if source_date_match is None:
            fail(f"internal source-date mismatch at transaction {idx}")
        source_date = normalize_date(source_date_match.group(1))
        normalized_date = normalize_date(tx_rows[0]["date"])
        if normalized_date != source_date:
            fail(
                f"transaction {idx}: hledger date {normalized_date} "
                f"!= source date {source_date}"
            )

        features = features_for(block)
        if tx_rows[0]["status"] and "status" not in features:
            features.append("status")

        out.append(
            "\t".join(
                [
                    "T",
                    idx,
                    normalized_date,
                    ",".join(features) if features else "-",
                ]
            )
        )

        for row in tx_rows:
            account = row["account"]
            measure = row["commodity"]
            amount = row["amount"]
            if not account or not measure or not amount:
                fail(f"transaction {idx}: hledger emitted an incomplete posting row")
            if any(ch in account for ch in "\t\n\r") or any(
                ch in measure for ch in "\t\n\r"
            ):
                fail(f"transaction {idx}: tab/newline token not supported by experiment wire")
            quanta = exact_quanta(amount, measure, scales)
            out.append("\t".join(["P", idx, account, measure, str(quanta)]))

    output.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(
        f"PTA hledger adapter experiment: normalized {len(txn_ids)} transactions "
        f"through {len(rows)} posting rows."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
