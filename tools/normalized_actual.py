#!/usr/bin/env python3
"""Research-only normalized Actual wire and single-generation authority prototype.

This deliberately does not translate back into today's Movement families.  It asks
whether the white-sheet Actual model can stand on its own as admitted canonical
meaning without permanent compatibility vocabulary.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, replace
from pathlib import Path

HEADER = "LOAM-NORMALIZED-ACTUAL\t1"
HEX64 = re.compile(r"^[0-9a-f]{64}$")


class ActualError(RuntimeError):
    pass


@dataclass(frozen=True)
class Effect:
    key: str | None
    locus: str
    measure: str
    quanta: int


@dataclass(frozen=True)
class DateRevision:
    id: str
    valid_on: str
    predecessor_kind: str  # ROOT | REV
    predecessor: str | None


@dataclass(frozen=True)
class Relation:
    id: str
    source_key: str
    debtor: str
    creditor: str
    quantity: int


@dataclass(frozen=True)
class Discharge:
    relation: str
    quantity: int


@dataclass(frozen=True)
class Tx:
    event: str
    base_valid_on: str
    description: str | None
    replaces: str | None
    reversal_of: str | None
    effects: tuple[Effect, ...]
    date_revisions: tuple[DateRevision, ...]
    relations: tuple[Relation, ...]
    discharges: tuple[Discharge, ...]


@dataclass(frozen=True)
class Actual:
    txs: tuple[Tx, ...]


def _token(value: str, label: str) -> str:
    if not value or any(c in value for c in "\t\r\n"):
        raise ActualError(f"invalid {label}: {value!r}")
    return value


def _integer(value: str, label: str) -> int:
    try:
        return int(value)
    except ValueError as exc:
        raise ActualError(f"invalid {label}: {value!r}") from exc


def _endpoint(value: str) -> str:
    _token(value, "endpoint")
    if value == "household":
        return value
    if value.startswith("external:") and len(value) > len("external:"):
        _token(value[len("external:"):], "external endpoint id")
        return value
    raise ActualError(f"invalid endpoint: {value!r}")


def parse(data: bytes) -> Actual:
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ActualError("Actual wire is not UTF-8") from exc
    if not text.endswith("\n"):
        raise ActualError("Actual wire must end with newline")
    lines = text.splitlines()
    if not lines or lines[0] != HEADER:
        raise ActualError("unsupported Actual header")

    txs: list[Tx] = []
    seen_events: set[str] = set()
    i = 1
    while i < len(lines):
        fields = lines[i].split("\t", 4)
        if not fields or fields[0] != "TX":
            raise ActualError(f"expected TX, got {lines[i]!r}")
        if len(fields) == 4 and fields[3] == "NODESC":
            event = _token(fields[1], "EventId")
            base_date = _token(fields[2], "base date")
            description = None
        elif len(fields) == 5 and fields[3] == "DESC":
            event = _token(fields[1], "EventId")
            base_date = _token(fields[2], "base date")
            description = fields[4]
            if description == "":
                raise ActualError(f"{event}: empty description must use NODESC")
        else:
            raise ActualError(f"malformed TX row: {lines[i]!r}")
        if event in seen_events:
            raise ActualError(f"duplicate EventId: {event}")
        seen_events.add(event)
        i += 1

        replaces: str | None = None
        reversal_of: str | None = None
        effects: list[Effect] = []
        revisions: list[DateRevision] = []
        relations: list[Relation] = []
        discharges: list[Discharge] = []
        keyed: set[str] = set()

        while i < len(lines) and lines[i] != "ENDTX":
            row = lines[i].split("\t")
            tag = row[0] if row else ""
            if tag == "REPLACES" and len(row) == 2:
                if replaces is not None:
                    raise ActualError(f"{event}: duplicate REPLACES")
                replaces = _token(row[1], "replacement target")
            elif tag == "REVERSAL-OF" and len(row) == 2:
                if reversal_of is not None:
                    raise ActualError(f"{event}: duplicate REVERSAL-OF")
                reversal_of = _token(row[1], "reversal target")
            elif tag == "EFFECT" and len(row) == 4:
                effects.append(
                    Effect(
                        None,
                        _token(row[1], "LocusId"),
                        _token(row[2], "MeasureId"),
                        _integer(row[3], "effect quantity"),
                    )
                )
            elif tag == "KEYED-EFFECT" and len(row) == 5:
                key = _token(row[1], "EffectKey")
                if key in keyed:
                    raise ActualError(f"{event}: duplicate EffectKey {key}")
                keyed.add(key)
                effects.append(
                    Effect(
                        key,
                        _token(row[2], "LocusId"),
                        _token(row[3], "MeasureId"),
                        _integer(row[4], "effect quantity"),
                    )
                )
            elif tag == "DATE-REV" and len(row) in (5, 6):
                revision_id = _token(row[1], "ActualValidityRevisionId")
                valid_on = _token(row[2], "revision date")
                if row[3] != "REPLACES":
                    raise ActualError(f"{event}: malformed DATE-REV")
                if len(row) == 5 and row[4] == "ROOT":
                    revisions.append(DateRevision(revision_id, valid_on, "ROOT", None))
                elif len(row) == 6 and row[4] == "REV":
                    revisions.append(
                        DateRevision(
                            revision_id,
                            valid_on,
                            "REV",
                            _token(row[5], "predecessor revision"),
                        )
                    )
                else:
                    raise ActualError(f"{event}: malformed DATE-REV predecessor")
            elif tag == "RELATION" and len(row) == 7 and row[2] == "SOURCE":
                relations.append(
                    Relation(
                        _token(row[1], "RelationUnitId"),
                        _token(row[3], "relation source EffectKey"),
                        _endpoint(row[4]),
                        _endpoint(row[5]),
                        _integer(row[6], "relation quantity"),
                    )
                )
            elif tag == "DISCHARGE" and len(row) == 3:
                discharges.append(
                    Discharge(
                        _token(row[1], "discharge target RelationUnitId"),
                        _integer(row[2], "discharge quantity"),
                    )
                )
            else:
                raise ActualError(f"{event}: malformed row {lines[i]!r}")
            i += 1

        if i >= len(lines) or lines[i] != "ENDTX":
            raise ActualError(f"{event}: missing ENDTX")
        txs.append(
            Tx(
                event,
                base_date,
                description,
                replaces,
                reversal_of,
                tuple(effects),
                tuple(revisions),
                tuple(relations),
                tuple(discharges),
            )
        )
        i += 1

    actual = Actual(tuple(txs))
    admit(actual)
    return actual


def encode(actual: Actual) -> bytes:
    admit(actual)
    rows = [HEADER]
    for tx in actual.txs:
        if tx.description is None:
            rows.append(f"TX\t{tx.event}\t{tx.base_valid_on}\tNODESC")
        else:
            if "\n" in tx.description or "\r" in tx.description:
                raise ActualError(f"{tx.event}: description contains newline")
            rows.append(f"TX\t{tx.event}\t{tx.base_valid_on}\tDESC\t{tx.description}")
        if tx.replaces is not None:
            rows.append(f"REPLACES\t{tx.replaces}")
        if tx.reversal_of is not None:
            rows.append(f"REVERSAL-OF\t{tx.reversal_of}")
        for effect in tx.effects:
            if effect.key is None:
                rows.append(
                    f"EFFECT\t{effect.locus}\t{effect.measure}\t{effect.quanta}"
                )
            else:
                rows.append(
                    f"KEYED-EFFECT\t{effect.key}\t{effect.locus}\t{effect.measure}\t{effect.quanta}"
                )
        for revision in tx.date_revisions:
            if revision.predecessor_kind == "ROOT":
                rows.append(
                    f"DATE-REV\t{revision.id}\t{revision.valid_on}\tREPLACES\tROOT"
                )
            else:
                rows.append(
                    f"DATE-REV\t{revision.id}\t{revision.valid_on}\tREPLACES\tREV\t{revision.predecessor}"
                )
        for relation in tx.relations:
            rows.append(
                f"RELATION\t{relation.id}\tSOURCE\t{relation.source_key}\t{relation.debtor}\t{relation.creditor}\t{relation.quantity}"
            )
        for discharge in tx.discharges:
            rows.append(
                f"DISCHARGE\t{discharge.relation}\t{discharge.quantity}"
            )
        rows.append("ENDTX")
    return ("\n".join(rows) + "\n").encode("utf-8")


def _acyclic_successor(successor: dict[str, str], label: str) -> None:
    for start in successor:
        seen: set[str] = set()
        current = start
        while current in successor:
            if current in seen:
                raise ActualError(f"{label} cycle at {current}")
            seen.add(current)
            current = successor[current]


def _physical_counter(tx: Tx, sign: int = 1) -> Counter[tuple[str, str, int]]:
    return Counter(
        (effect.locus, effect.measure, sign * effect.quanta)
        for effect in tx.effects
    )


def admit(actual: Actual) -> None:
    events: dict[str, Tx] = {}
    for tx in actual.txs:
        _token(tx.event, "EventId")
        _token(tx.base_valid_on, "base date")
        if tx.event in events:
            raise ActualError(f"duplicate EventId: {tx.event}")
        events[tx.event] = tx

        keys = [effect.key for effect in tx.effects if effect.key is not None]
        if len(keys) != len(set(keys)):
            raise ActualError(f"{tx.event}: duplicate EffectKey")
        for effect in tx.effects:
            _token(effect.locus, "LocusId")
            _token(effect.measure, "MeasureId")
            if effect.key is not None:
                _token(effect.key, "EffectKey")

    # Event correction is a disjoint finite path relation.  The compact wire puts
    # the edge on the replacement Event, so replacement uniqueness is structural.
    correction: dict[str, str] = {}
    for replacement in actual.txs:
        target = replacement.replaces
        if target is None:
            continue
        if target not in events:
            raise ActualError(f"{replacement.event}: REPLACES absent Event {target}")
        if target == replacement.event:
            raise ActualError(f"{replacement.event}: self correction")
        if target in correction:
            raise ActualError(f"correction branch from {target}")
        correction[target] = replacement.event
    _acyclic_successor(correction, "correction")

    reversal_target: dict[str, str] = {}
    reversal_events: set[str] = set()
    for inverse in actual.txs:
        target = inverse.reversal_of
        if target is None:
            continue
        if target not in events:
            raise ActualError(f"{inverse.event}: REVERSAL-OF absent Event {target}")
        if target == inverse.event:
            raise ActualError(f"{inverse.event}: self reversal")
        if target in reversal_target:
            raise ActualError(f"Event {target} reversed more than once")
        if inverse.event in reversal_events:
            raise ActualError(f"reversal Event {inverse.event} explains more than one target")
        reversal_target[target] = inverse.event
        reversal_events.add(inverse.event)
        if _physical_counter(inverse) != _physical_counter(events[target], sign=-1):
            raise ActualError(
                f"{inverse.event}: reversal Effects are not exact inverse of {target}"
            )

    # Date revisions are Event-local but revision identity is globally stable.
    global_revision_ids: set[str] = set()
    for tx in actual.txs:
        revisions = {revision.id: revision for revision in tx.date_revisions}
        if len(revisions) != len(tx.date_revisions):
            raise ActualError(f"{tx.event}: duplicate date revision id")
        overlap = global_revision_ids & set(revisions)
        if overlap:
            raise ActualError(f"duplicate global date revision id: {sorted(overlap)[0]}")
        global_revision_ids.update(revisions)

        successor: dict[str, str] = {}
        for revision in tx.date_revisions:
            _token(revision.id, "ActualValidityRevisionId")
            _token(revision.valid_on, "revision date")
            if revision.predecessor_kind == "ROOT":
                predecessor = "@ROOT"
                if revision.predecessor is not None:
                    raise ActualError(f"{tx.event}: ROOT revision carries predecessor id")
            elif revision.predecessor_kind == "REV":
                if revision.predecessor is None or revision.predecessor not in revisions:
                    raise ActualError(
                        f"{tx.event}: revision {revision.id} names absent predecessor"
                    )
                predecessor = revision.predecessor
            else:
                raise ActualError(f"{tx.event}: invalid revision predecessor kind")
            if predecessor in successor:
                raise ActualError(f"{tx.event}: date correction branch at {predecessor}")
            successor[predecessor] = revision.id
        _acyclic_successor(successor, f"{tx.event} date correction")
        for revision_id in revisions:
            current = revision_id
            visited: set[str] = set()
            while True:
                if current in visited:
                    raise ActualError(f"{tx.event}: date correction cycle")
                visited.add(current)
                revision = revisions[current]
                if revision.predecessor_kind == "ROOT":
                    break
                assert revision.predecessor is not None
                current = revision.predecessor

    relation_by_id: dict[str, tuple[Tx, Relation, Effect]] = {}
    for tx in actual.txs:
        keyed = {effect.key: effect for effect in tx.effects if effect.key is not None}
        for relation in tx.relations:
            _token(relation.id, "RelationUnitId")
            if relation.id in relation_by_id:
                raise ActualError(f"duplicate RelationUnitId {relation.id}")
            if relation.source_key not in keyed:
                raise ActualError(
                    f"{tx.event}: Relation {relation.id} source EffectKey does not resolve"
                )
            _endpoint(relation.debtor)
            _endpoint(relation.creditor)
            if relation.debtor == relation.creditor:
                raise ActualError(f"{relation.id}: identical debtor and creditor")
            if relation.quantity <= 0:
                raise ActualError(f"{relation.id}: non-positive relation quantity")
            source = keyed[relation.source_key]
            if relation.quantity > abs(source.quanta):
                raise ActualError(f"{relation.id}: relation exceeds source Effect magnitude")
            relation_by_id[relation.id] = (tx, relation, source)

    discharge_sum: dict[str, int] = defaultdict(int)
    seen_discharge_pair: set[tuple[str, str]] = set()
    for tx in actual.txs:
        for discharge in tx.discharges:
            if discharge.relation not in relation_by_id:
                raise ActualError(
                    f"{tx.event}: DISCHARGE names absent Relation {discharge.relation}"
                )
            pair = (tx.event, discharge.relation)
            if pair in seen_discharge_pair:
                raise ActualError(
                    f"{tx.event}: duplicate discharge for {discharge.relation}"
                )
            seen_discharge_pair.add(pair)
            if discharge.quantity <= 0:
                raise ActualError(f"{tx.event}: non-positive discharge quantity")
            discharge_sum[discharge.relation] += discharge.quantity

    for relation_id, total in discharge_sum.items():
        quantity = relation_by_id[relation_id][1].quantity
        if total > quantity:
            raise ActualError(
                f"Relation {relation_id}: aggregate discharge {total} exceeds {quantity}"
            )


def current_date(tx: Tx) -> str:
    if not tx.date_revisions:
        return tx.base_valid_on
    successor: dict[str, DateRevision] = {}
    for revision in tx.date_revisions:
        predecessor = "@ROOT" if revision.predecessor_kind == "ROOT" else revision.predecessor
        assert predecessor is not None
        successor[predecessor] = revision
    current_ref = "@ROOT"
    current = tx.base_valid_on
    while current_ref in successor:
        revision = successor[current_ref]
        current = revision.valid_on
        current_ref = revision.id
    return current


def semantic_observation(actual: Actual) -> str:
    admit(actual)
    correction = sorted(
        (tx.replaces, tx.event) for tx in actual.txs if tx.replaces is not None
    )
    reversals = sorted(
        (tx.reversal_of, tx.event) for tx in actual.txs if tx.reversal_of is not None
    )

    relation_rows: list[tuple[str, str, str, str, str, int, int]] = []
    discharge_totals: dict[str, int] = defaultdict(int)
    for tx in actual.txs:
        for discharge in tx.discharges:
            discharge_totals[discharge.relation] += discharge.quantity
    for tx in actual.txs:
        for relation in tx.relations:
            relation_rows.append(
                (
                    relation.id,
                    tx.event,
                    relation.source_key,
                    relation.debtor,
                    relation.creditor,
                    relation.quantity,
                    relation.quantity - discharge_totals[relation.id],
                )
            )

    rows: list[str] = []
    for tx in sorted(actual.txs, key=lambda t: t.event):
        rows.append(
            "TX\t"
            + "\t".join(
                (
                    tx.event,
                    current_date(tx),
                    "NODESC" if tx.description is None else "DESC=" + tx.description,
                )
            )
        )
        effect_rows = sorted(
            (
                "" if effect.key is None else effect.key,
                effect.locus,
                effect.measure,
                effect.quanta,
            )
            for effect in tx.effects
        )
        for key, locus, measure, quanta in effect_rows:
            rows.append(f"EFFECT\t{tx.event}\t{key}\t{locus}\t{measure}\t{quanta}")
        for revision in sorted(tx.date_revisions, key=lambda r: r.id):
            predecessor = (
                "ROOT" if revision.predecessor_kind == "ROOT" else "REV:" + str(revision.predecessor)
            )
            rows.append(
                f"DATE-REV\t{tx.event}\t{revision.id}\t{revision.valid_on}\t{predecessor}"
            )
        for discharge in sorted(tx.discharges, key=lambda d: d.relation):
            rows.append(
                f"DISCHARGE\t{tx.event}\t{discharge.relation}\t{discharge.quantity}"
            )
    for target, replacement_event in correction:
        rows.append(f"CORRECTION\t{target}\t{replacement_event}")
    for target, inverse in reversals:
        rows.append(f"REVERSAL\t{target}\t{inverse}")
    for row in sorted(relation_rows):
        rows.append("RELATION\t" + "\t".join(map(str, row)))
    rows.append("STATUS\tcomplete")
    return "\n".join(rows) + "\n"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def stage_generation(root: Path, data: bytes) -> str:
    # Validation happens before bytes can become a candidate generation.
    actual = parse(data)
    canonical = encode(actual)
    generation = digest(canonical)
    directory = root / "generations" / generation
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / "actual.loam"
    if path.exists():
        if path.read_bytes() != canonical:
            raise ActualError(f"generation digest collision/mismatch: {generation}")
    else:
        path.write_bytes(canonical)
    return generation


def select_generation(root: Path, generation: str) -> None:
    if not HEX64.fullmatch(generation):
        raise ActualError("invalid generation id")
    path = root / "generations" / generation / "actual.loam"
    if not path.is_file():
        raise ActualError(f"generation not staged: {generation}")
    data = path.read_bytes()
    if digest(data) != generation:
        raise ActualError(f"generation content digest mismatch: {generation}")
    parse(data)
    root.mkdir(parents=True, exist_ok=True)
    temp = root / f".CURRENT.{os.getpid()}.tmp"
    temp.write_text(generation + "\n", encoding="utf-8")
    os.replace(temp, root / "CURRENT")


def load_selected(root: Path) -> Actual:
    current = root / "CURRENT"
    if not current.is_file():
        raise ActualError("missing CURRENT")
    generation = current.read_text(encoding="utf-8").strip()
    if not HEX64.fullmatch(generation):
        raise ActualError("malformed CURRENT")
    path = root / "generations" / generation / "actual.loam"
    if not path.is_file():
        raise ActualError("CURRENT selects missing generation")
    data = path.read_bytes()
    if digest(data) != generation:
        raise ActualError("CURRENT generation digest mismatch")
    return parse(data)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Validate/observe normalized Actual research wire")
    sub = parser.add_subparsers(dest="command", required=True)
    p_check = sub.add_parser("check")
    p_check.add_argument("actual", type=Path)
    p_observe = sub.add_parser("observe")
    p_observe.add_argument("actual", type=Path)
    p_stage = sub.add_parser("stage")
    p_stage.add_argument("store", type=Path)
    p_stage.add_argument("actual", type=Path)
    p_select = sub.add_parser("select")
    p_select.add_argument("store", type=Path)
    p_select.add_argument("generation")
    p_selected = sub.add_parser("observe-selected")
    p_selected.add_argument("store", type=Path)
    args = parser.parse_args(argv)

    try:
        if args.command == "check":
            actual = parse(args.actual.read_bytes())
            canonical = encode(actual)
            if parse(canonical) != actual:
                raise ActualError("encode/decode structural round trip changed Actual")
            print("normalized Actual admitted; structural round trip PASS")
        elif args.command == "observe":
            print(semantic_observation(parse(args.actual.read_bytes())), end="")
        elif args.command == "stage":
            print(stage_generation(args.store, args.actual.read_bytes()))
        elif args.command == "select":
            select_generation(args.store, args.generation)
        else:
            print(semantic_observation(load_selected(args.store)), end="")
    except (ActualError, OSError) as exc:
        print(f"normalized Actual failed: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
