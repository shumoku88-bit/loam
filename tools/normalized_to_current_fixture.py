#!/usr/bin/env python3
"""TEST-ONLY bridge from normalized Actual research wire to current LOAM fixture layout.

This file is differential-test scaffolding, not a migration codec and not a supported
compatibility path.  It deliberately writes today's persistence objects so existing
production readers can observe the same synthetic world.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

from normalized_actual import ActualError, parse

MANIFEST_HEADER = "LOAM-MOVEMENT-MANIFEST\t2"
FAMILIES = ("Event", "ActualValidity", "EventDescription", "RelationUnit", "RelationDischarge")


class BridgeError(RuntimeError):
    pass


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def escaped_description(text: str) -> str:
    return (
        text.replace("\\", "\\\\")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )


def endpoint_fields(endpoint: str) -> tuple[str, str]:
    if endpoint == "household":
        return "H", ""
    prefix = "external:"
    if endpoint.startswith(prefix) and len(endpoint) > len(prefix):
        return "E", endpoint[len(prefix):]
    raise BridgeError(f"unsupported normalized endpoint {endpoint!r}")


def read_manifest(root: Path) -> tuple[list[str], dict[str, tuple[str, str]]]:
    current = root / "movement-authority" / "CURRENT"
    if not current.is_file():
        raise BridgeError("initialize current Movement authority before differential bridge")
    lines = current.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != MANIFEST_HEADER:
        raise BridgeError("unsupported Movement manifest")
    order: list[str] = []
    rows: dict[str, tuple[str, str]] = {}
    for line in lines[1:]:
        if not line:
            continue
        fields = line.split("\t")
        if len(fields) != 3:
            raise BridgeError(f"malformed CURRENT row {line!r}")
        family, relative, sha = fields
        order.append(family)
        rows[family] = (relative, sha)
    for family in FAMILIES:
        if family not in rows:
            raise BridgeError(f"CURRENT lacks {family}")
    return order, rows


def materialize(normalized: Path, root: Path) -> None:
    actual = parse(normalized.read_bytes())
    order, rows = read_manifest(root)

    event_rows = ["LOAM-EVENT-MEMORY\t1"]
    validity_facts = ["LOAM-ACTUAL-VALIDITY-HISTORY\t3"]
    validity_corrections: list[str] = []
    description_rows = ["LOAM-EVENT-DESCRIPTION-MEMORY\t1"]
    relation_rows = ["LOAM-RELATION-UNIT-MEMORY\t1"]
    discharge_rows = ["LOAM-RELATION-DISCHARGE-MEMORY\t1"]
    correction_rows = ["LOAM-EVENT-CORRECTION-MEMORY\t2"]
    reversal_rows = ["LOAM-ACTUAL-REVERSAL-MEMORY\t1"]

    for tx in actual.txs:
        explicit_keys = {effect.key for effect in tx.effects if effect.key is not None}
        generated_index = 1
        bridge_keys: list[str] = []
        for effect in tx.effects:
            if effect.key is not None:
                bridge_keys.append(effect.key)
                continue
            while True:
                candidate = f"differential-effect-{generated_index}"
                generated_index += 1
                if candidate not in explicit_keys:
                    explicit_keys.add(candidate)
                    bridge_keys.append(candidate)
                    break

        event_rows.append(f"EVENT\t{tx.event}")
        for key, effect in zip(bridge_keys, tx.effects, strict=True):
            event_rows.append(
                f"EFFECT\t{key}\t{effect.locus}\t{effect.measure}\t{effect.quanta}"
            )

        validity_facts.append(f"BASE\t{tx.event}\t{tx.base_valid_on}")
        for revision in tx.date_revisions:
            validity_facts.append(
                f"REVISION\t{revision.id}\t{tx.event}\t{revision.valid_on}"
            )
            if revision.predecessor_kind == "ROOT":
                validity_corrections.append(
                    f"CORRECTION\tROOT\t{tx.event}\t{revision.id}"
                )
            else:
                assert revision.predecessor is not None
                validity_corrections.append(
                    f"CORRECTION\tREVISION\t{revision.predecessor}\t{revision.id}"
                )

        if tx.description is not None:
            description_rows.append(
                f"DESC\t{tx.event}\t{escaped_description(tx.description)}"
            )

        if tx.replaces is not None:
            correction_rows.append(f"CORRECTION\t{tx.replaces}\t{tx.event}")
        if tx.reversal_of is not None:
            reversal_rows.append(f"REVERSE\t{tx.reversal_of}\t{tx.event}")

        for relation in tx.relations:
            debtor_kind, debtor_token = endpoint_fields(relation.debtor)
            creditor_kind, creditor_token = endpoint_fields(relation.creditor)
            relation_rows.append(
                "\t".join(
                    [
                        "RELATION",
                        relation.id,
                        tx.event,
                        relation.source_key,
                        debtor_kind,
                        debtor_token,
                        creditor_kind,
                        creditor_token,
                        str(relation.quantity),
                    ]
                )
            )

        for discharge in tx.discharges:
            discharge_rows.append(
                f"DISCHARGE\t{tx.event}\t{discharge.relation}\t{discharge.quantity}"
            )

    validity_rows = validity_facts + validity_corrections
    payloads = {
        "Event": "\n".join(event_rows) + "\n",
        "ActualValidity": "\n".join(validity_rows) + "\n",
        "EventDescription": "\n".join(description_rows) + "\n",
        "RelationUnit": "\n".join(relation_rows) + "\n",
        "RelationDischarge": "\n".join(discharge_rows) + "\n",
    }

    authority = root / "movement-authority"
    replacements: dict[str, tuple[str, str]] = {}
    for family, text in payloads.items():
        data = text.encode("utf-8")
        sha = digest(data)
        relative = f"objects/{family}/{sha}.loam"
        path = authority / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        replacements[family] = (relative, sha)

    current_rows = [MANIFEST_HEADER]
    for family in order:
        relative, sha = replacements.get(family, rows[family])
        current_rows.append(f"{family}\t{relative}\t{sha}")
    (authority / "CURRENT").write_text("\n".join(current_rows) + "\n", encoding="utf-8")

    (root / "corrections.loam").write_text(
        "\n".join(correction_rows) + "\n", encoding="utf-8"
    )
    (root / "actual-reversals.loam").write_text(
        "\n".join(reversal_rows) + "\n", encoding="utf-8"
    )

    print(
        f"differential bridge materialized {len(actual.txs)} normalized TXs "
        "into current production persistence fixtures"
    )


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("normalized", type=Path)
    parser.add_argument("current_fixture_root", type=Path)
    args = parser.parse_args(argv)
    try:
        materialize(args.normalized, args.current_fixture_root)
    except (OSError, ActualError, BridgeError) as exc:
        print(f"differential fixture bridge failed: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
