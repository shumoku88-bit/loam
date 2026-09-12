#!/usr/bin/env python3
"""Research-only unified Actual wire.

Reads the currently selected admitted-shaped Actual evidence from LOAM's split
persistence topology and projects it into one transaction-local semantic stream.
It does not re-expand through current codecs and intentionally has no compatibility
EffectKey vocabulary.
"""

from __future__ import annotations

import argparse
import hashlib
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path

MOVEMENT_MAGIC = "LOAM-MOVEMENT-MANIFEST\t2"
EVENT_HEADER = "LOAM-EVENT-MEMORY\t1"
VALIDITY_HEADER = "LOAM-ACTUAL-VALIDITY-HISTORY\t3"
DESCRIPTION_HEADER = "LOAM-EVENT-DESCRIPTION-MEMORY\t1"
RELATION_HEADER = "LOAM-RELATION-UNIT-MEMORY\t1"
DISCHARGE_HEADER = "LOAM-RELATION-DISCHARGE-MEMORY\t1"
CORRECTION_HEADER = "LOAM-EVENT-CORRECTION-MEMORY\t2"
REVERSAL_HEADER = "LOAM-ACTUAL-REVERSAL-MEMORY\t1"
UNIFIED_HEADER = "LOAM-UNIFIED-ACTUAL\t1"

REQUIRED_FAMILIES = (
    "Event",
    "ActualValidity",
    "EventDescription",
    "RelationUnit",
    "RelationDischarge",
)


class UnifiedActualError(RuntimeError):
    pass


@dataclass(frozen=True, order=True)
class Effect:
    key: str | None
    locus: str
    measure: str
    quanta: int


@dataclass(frozen=True, order=True)
class DateRevision:
    id: str
    valid_on: str
    predecessor_kind: str  # ROOT | REVISION
    predecessor: str


@dataclass(frozen=True, order=True)
class Relation:
    id: str
    source_key: str
    debtor_kind: str
    debtor_token: str
    creditor_kind: str
    creditor_token: str
    quanta: int


@dataclass(frozen=True, order=True)
class Discharge:
    relation_id: str
    quanta: int


@dataclass(frozen=True)
class Tx:
    event: str
    base_date: str
    description: str | None
    replaces: str | None
    reversal_of: str | None
    effects: tuple[Effect, ...]
    revisions: tuple[DateRevision, ...]
    relations: tuple[Relation, ...]
    discharges: tuple[Discharge, ...]


@dataclass(frozen=True)
class Model:
    txs: tuple[Tx, ...]


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def lines_with_header(data: bytes, header: str, label: str) -> list[str]:
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise UnifiedActualError(f"{label}: not UTF-8") from exc
    if not text.endswith("\n"):
        raise UnifiedActualError(f"{label}: missing trailing newline")
    lines = text.splitlines()
    if not lines or lines[0] != header:
        raise UnifiedActualError(f"{label}: unsupported header")
    return lines[1:]


def unescape_text(text: str) -> str:
    out: list[str] = []
    i = 0
    while i < len(text):
        ch = text[i]
        if ch != "\\":
            out.append(ch)
            i += 1
            continue
        if i + 1 >= len(text):
            raise UnifiedActualError("description: dangling escape")
        nxt = text[i + 1]
        table = {"\\": "\\", "n": "\n", "r": "\r", "t": "\t"}
        if nxt not in table:
            raise UnifiedActualError(f"description: invalid escape \\{nxt}")
        out.append(table[nxt])
        i += 2
    return "".join(out)


def escape_text(text: str) -> str:
    return (
        text.replace("\\", "\\\\")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )


def selected_family_bytes(root: Path) -> dict[str, bytes]:
    current = root / "movement-authority" / "CURRENT"
    if not current.is_file():
        raise UnifiedActualError(f"missing Movement selector: {current}")
    rows = current.read_text(encoding="utf-8").splitlines()
    if not rows or rows[0] != MOVEMENT_MAGIC:
        raise UnifiedActualError("unsupported Movement manifest")
    result: dict[str, bytes] = {}
    for row in rows[1:]:
        if not row:
            continue
        fields = row.split("\t")
        if len(fields) != 3:
            raise UnifiedActualError(f"malformed Movement selector row: {row!r}")
        family, relative, expected = fields
        path = root / "movement-authority" / relative
        if Path(relative).is_absolute() or ".." in Path(relative).parts:
            raise UnifiedActualError(f"unsafe selected path: {relative!r}")
        if not path.is_file():
            raise UnifiedActualError(f"missing selected object: {path}")
        data = path.read_bytes()
        if sha256(data) != expected:
            raise UnifiedActualError(f"digest mismatch for selected family {family}")
        if family in result:
            raise UnifiedActualError(f"duplicate selected family {family}")
        result[family] = data
    missing = set(REQUIRED_FAMILIES) - set(result)
    if missing:
        raise UnifiedActualError(f"missing selected family/families: {sorted(missing)}")
    return result


def parse_events(data: bytes) -> dict[str, list[tuple[str, str, str, int]]]:
    rows = lines_with_header(data, EVENT_HEADER, "Event")
    result: dict[str, list[tuple[str, str, str, int]]] = {}
    current: str | None = None
    keys: set[str] = set()
    for row in rows:
        fields = row.split("\t")
        if len(fields) == 2 and fields[0] == "EVENT":
            current = fields[1]
            if not current or current in result:
                raise UnifiedActualError(f"Event: duplicate/empty id {current!r}")
            result[current] = []
            keys = set()
        elif len(fields) == 5 and fields[0] == "EFFECT":
            if current is None:
                raise UnifiedActualError("Event: EFFECT before EVENT")
            _, key, locus, measure, quanta_text = fields
            if not key or key in keys or not locus or not measure:
                raise UnifiedActualError(f"Event {current}: malformed/duplicate Effect")
            try:
                quanta = int(quanta_text)
            except ValueError as exc:
                raise UnifiedActualError(f"Event {current}: invalid quanta") from exc
            keys.add(key)
            result[current].append((key, locus, measure, quanta))
        else:
            raise UnifiedActualError(f"Event: malformed row {row!r}")
    return result


def parse_validity(data: bytes) -> tuple[dict[str, str], dict[str, tuple[str, str]], dict[str, tuple[str, str]]]:
    rows = lines_with_header(data, VALIDITY_HEADER, "ActualValidity")
    base: dict[str, str] = {}
    revisions: dict[str, tuple[str, str]] = {}  # rev -> (event,date)
    replacement_predecessor: dict[str, tuple[str, str]] = {}  # rev -> (kind,token)
    for row in rows:
        fields = row.split("\t")
        if len(fields) == 3 and fields[0] == "BASE":
            _, event, valid_on = fields
            if not event or event in base:
                raise UnifiedActualError(f"ActualValidity: duplicate/empty BASE {event!r}")
            base[event] = valid_on
        elif len(fields) == 4 and fields[0] == "REVISION":
            _, revision, event, valid_on = fields
            if not revision or revision in revisions:
                raise UnifiedActualError(f"ActualValidity: duplicate/empty revision {revision!r}")
            revisions[revision] = (event, valid_on)
        elif len(fields) == 4 and fields[0] == "CORRECTION" and fields[1] in ("ROOT", "REVISION"):
            _, kind, target, replacement = fields
            if replacement in replacement_predecessor:
                raise UnifiedActualError(f"ActualValidity: revision {replacement} has multiple predecessors")
            replacement_predecessor[replacement] = (kind, target)
        else:
            raise UnifiedActualError(f"ActualValidity: malformed row {row!r}")
    if set(revisions) != set(replacement_predecessor):
        raise UnifiedActualError(
            "ActualValidity: admitted-shaped projection requires every revision to have exactly one predecessor"
        )
    for revision, (kind, target) in replacement_predecessor.items():
        event, _ = revisions[revision]
        if kind == "ROOT":
            if target != event or target not in base:
                raise UnifiedActualError("ActualValidity: cross-event or missing ROOT correction")
        else:
            target_row = revisions.get(target)
            if target_row is None or target_row[0] != event:
                raise UnifiedActualError("ActualValidity: cross-event or missing REVISION correction")
    return base, revisions, replacement_predecessor


def parse_descriptions(data: bytes) -> dict[str, str]:
    rows = lines_with_header(data, DESCRIPTION_HEADER, "EventDescription")
    result: dict[str, str] = {}
    for row in rows:
        fields = row.split("\t", 2)
        if len(fields) != 3 or fields[0] != "DESC":
            raise UnifiedActualError(f"EventDescription: malformed row {row!r}")
        _, event, escaped = fields
        if event in result or not event:
            raise UnifiedActualError(f"EventDescription: duplicate/empty event {event!r}")
        result[event] = unescape_text(escaped)
    return result


def parse_relations(data: bytes) -> list[tuple[str, str, str, str, str, str, str, str, int]]:
    rows = lines_with_header(data, RELATION_HEADER, "RelationUnit")
    result = []
    ids: set[str] = set()
    for row in rows:
        if not row:
            continue
        fields = row.split("\t")
        if len(fields) != 9 or fields[0] != "RELATION":
            raise UnifiedActualError(f"RelationUnit: malformed row {row!r}")
        _, rid, event, key, dk, dt, ck, ct, quanta_text = fields
        if rid in ids or not rid or not event or not key:
            raise UnifiedActualError(f"RelationUnit: duplicate/empty identity in {row!r}")
        try:
            q = int(quanta_text)
        except ValueError as exc:
            raise UnifiedActualError("RelationUnit: invalid quantity") from exc
        ids.add(rid)
        result.append((rid, event, key, dk, dt, ck, ct, q))
    return result


def parse_discharges(data: bytes) -> list[tuple[str, str, int]]:
    rows = lines_with_header(data, DISCHARGE_HEADER, "RelationDischarge")
    result = []
    pairs: set[tuple[str, str]] = set()
    for row in rows:
        if not row:
            continue
        fields = row.split("\t")
        if len(fields) != 4 or fields[0] != "DISCHARGE":
            raise UnifiedActualError(f"RelationDischarge: malformed row {row!r}")
        _, event, relation, quanta_text = fields
        pair = (event, relation)
        if pair in pairs:
            raise UnifiedActualError(f"RelationDischarge: duplicate admitted pair {pair}")
        try:
            q = int(quanta_text)
        except ValueError as exc:
            raise UnifiedActualError("RelationDischarge: invalid quantity") from exc
        pairs.add(pair)
        result.append((event, relation, q))
    return result


def parse_event_corrections(path: Path) -> list[tuple[str, str]]:
    if not path.is_file():
        return []
    rows = lines_with_header(path.read_bytes(), CORRECTION_HEADER, "EventCorrection")
    result: list[tuple[str, str]] = []
    targets: set[str] = set()
    replacements: set[str] = set()
    for row in rows:
        fields = row.split("\t")
        if len(fields) != 3 or fields[0] != "CORRECTION":
            raise UnifiedActualError(f"EventCorrection: malformed row {row!r}")
        _, target, replacement = fields
        if target in targets or replacement in replacements:
            raise UnifiedActualError("EventCorrection: branching/merging not admitted by unified projection")
        targets.add(target)
        replacements.add(replacement)
        result.append((target, replacement))
    return result


def parse_reversals(path: Path) -> list[tuple[str, str]]:
    if not path.is_file():
        return []
    rows = lines_with_header(path.read_bytes(), REVERSAL_HEADER, "ActualReversal")
    result: list[tuple[str, str]] = []
    targets: set[str] = set()
    inverses: set[str] = set()
    for row in rows:
        if not row:
            continue
        fields = row.split("\t")
        if len(fields) != 3 or fields[0] != "REVERSAL":
            raise UnifiedActualError(f"ActualReversal: malformed row {row!r}")
        _, target, inverse = fields
        if target in targets or inverse in inverses:
            raise UnifiedActualError("ActualReversal: non-functional relation")
        targets.add(target)
        inverses.add(inverse)
        result.append((target, inverse))
    return result


def load_split_model(root: Path) -> Model:
    families = selected_family_bytes(root)
    events = parse_events(families["Event"])
    base, revisions, predecessors = parse_validity(families["ActualValidity"])
    descriptions = parse_descriptions(families["EventDescription"])
    relations_raw = parse_relations(families["RelationUnit"])
    discharges_raw = parse_discharges(families["RelationDischarge"])
    corrections = parse_event_corrections(root / "corrections.loam")
    reversals = parse_reversals(root / "actual-reversals.loam")

    event_ids = set(events)
    if set(base) != event_ids:
        raise UnifiedActualError("unified admitted Actual requires one base date per Event")
    if not set(descriptions) <= event_ids:
        raise UnifiedActualError("description targets absent Event")

    replaces_by_replacement: dict[str, str] = {}
    for target, replacement in corrections:
        if target not in event_ids or replacement not in event_ids:
            raise UnifiedActualError("EventCorrection names absent Event")
        replaces_by_replacement[replacement] = target

    reversal_by_inverse: dict[str, str] = {}
    for target, inverse in reversals:
        if target not in event_ids or inverse not in event_ids:
            raise UnifiedActualError("ActualReversal names absent Event")
        reversal_by_inverse[inverse] = target

    relation_sources: set[tuple[str, str]] = set()
    relations_by_event: dict[str, list[Relation]] = defaultdict(list)
    relation_ids: set[str] = set()
    for rid, event, key, dk, dt, ck, ct, q in relations_raw:
        if rid in relation_ids:
            raise UnifiedActualError("duplicate RelationUnit identity")
        relation_ids.add(rid)
        effect_rows = events.get(event)
        if effect_rows is None or not any(effect_key == key for effect_key, *_ in effect_rows):
            raise UnifiedActualError("RelationUnit source does not resolve")
        relation_sources.add((event, key))
        relations_by_event[event].append(Relation(rid, key, dk, dt, ck, ct, q))

    discharges_by_event: dict[str, list[Discharge]] = defaultdict(list)
    for event, relation, q in discharges_raw:
        if event not in event_ids or relation not in relation_ids:
            raise UnifiedActualError("RelationDischarge names absent Event/Relation")
        discharges_by_event[event].append(Discharge(relation, q))

    revisions_by_event: dict[str, list[DateRevision]] = defaultdict(list)
    for revision, (event, valid_on) in revisions.items():
        kind, predecessor = predecessors[revision]
        revisions_by_event[event].append(DateRevision(revision, valid_on, kind, predecessor))

    txs: list[Tx] = []
    for event, rows in events.items():
        projected_effects = tuple(
            Effect(key if (event, key) in relation_sources else None, locus, measure, q)
            for key, locus, measure, q in rows
        )
        txs.append(
            Tx(
                event=event,
                base_date=base[event],
                description=descriptions.get(event),
                replaces=replaces_by_replacement.get(event),
                reversal_of=reversal_by_inverse.get(event),
                effects=projected_effects,
                revisions=tuple(sorted(revisions_by_event[event])),
                relations=tuple(sorted(relations_by_event[event])),
                discharges=tuple(sorted(discharges_by_event[event])),
            )
        )
    return Model(tuple(txs))


def encode_unified(model: Model) -> bytes:
    rows = [UNIFIED_HEADER]
    for tx in model.txs:
        if tx.description is None:
            rows.append(f"TX\t{tx.event}\t{tx.base_date}\tNODESC")
        else:
            rows.append(f"TX\t{tx.event}\t{tx.base_date}\tDESC\t{escape_text(tx.description)}")
        if tx.replaces is not None:
            rows.append(f"REPLACES\t{tx.replaces}")
        if tx.reversal_of is not None:
            rows.append(f"REVERSAL-OF\t{tx.reversal_of}")
        for effect in tx.effects:
            if effect.key is None:
                rows.append(f"EFFECT\t{effect.locus}\t{effect.measure}\t{effect.quanta}")
            else:
                rows.append(f"KEYED-EFFECT\t{effect.key}\t{effect.locus}\t{effect.measure}\t{effect.quanta}")
        for rev in tx.revisions:
            rows.append(
                f"DATE-REV\t{rev.id}\t{rev.valid_on}\t{rev.predecessor_kind}\t{rev.predecessor}"
            )
        for rel in tx.relations:
            rows.append(
                "\t".join(
                    [
                        "RELATION",
                        rel.id,
                        "SOURCE",
                        rel.source_key,
                        rel.debtor_kind,
                        rel.debtor_token,
                        rel.creditor_kind,
                        rel.creditor_token,
                        str(rel.quanta),
                    ]
                )
            )
        for discharge in tx.discharges:
            rows.append(f"DISCHARGE\t{discharge.relation_id}\t{discharge.quanta}")
        rows.append("ENDTX")
    return ("\n".join(rows) + "\n").encode("utf-8")


def decode_unified(data: bytes) -> Model:
    rows = lines_with_header(data, UNIFIED_HEADER, "UnifiedActual")
    txs: list[Tx] = []
    i = 0
    event_ids: set[str] = set()
    while i < len(rows):
        fields = rows[i].split("\t")
        if not fields or fields[0] != "TX":
            raise UnifiedActualError(f"UnifiedActual: expected TX, got {rows[i]!r}")
        if len(fields) == 4 and fields[3] == "NODESC":
            event, base_date, description = fields[1], fields[2], None
        elif len(fields) == 5 and fields[3] == "DESC":
            event, base_date, description = fields[1], fields[2], unescape_text(fields[4])
        else:
            raise UnifiedActualError(f"UnifiedActual: malformed TX {rows[i]!r}")
        if not event or event in event_ids:
            raise UnifiedActualError(f"UnifiedActual: duplicate/empty Event {event!r}")
        event_ids.add(event)
        i += 1

        replaces: str | None = None
        reversal_of: str | None = None
        effects: list[Effect] = []
        revisions: list[DateRevision] = []
        relations: list[Relation] = []
        discharges: list[Discharge] = []
        stable_keys: set[str] = set()
        relation_ids: set[str] = set()

        while i < len(rows) and rows[i] != "ENDTX":
            fields = rows[i].split("\t")
            tag = fields[0] if fields else ""
            if tag == "REPLACES" and len(fields) == 2 and replaces is None:
                replaces = fields[1]
            elif tag == "REVERSAL-OF" and len(fields) == 2 and reversal_of is None:
                reversal_of = fields[1]
            elif tag == "EFFECT" and len(fields) == 4:
                try:
                    q = int(fields[3])
                except ValueError as exc:
                    raise UnifiedActualError("UnifiedActual: invalid Effect quantity") from exc
                effects.append(Effect(None, fields[1], fields[2], q))
            elif tag == "KEYED-EFFECT" and len(fields) == 5:
                key = fields[1]
                if not key or key in stable_keys:
                    raise UnifiedActualError("UnifiedActual: duplicate/empty stable EffectKey")
                try:
                    q = int(fields[4])
                except ValueError as exc:
                    raise UnifiedActualError("UnifiedActual: invalid Effect quantity") from exc
                stable_keys.add(key)
                effects.append(Effect(key, fields[2], fields[3], q))
            elif tag == "DATE-REV" and len(fields) == 5 and fields[3] in ("ROOT", "REVISION"):
                revisions.append(DateRevision(fields[1], fields[2], fields[3], fields[4]))
            elif tag == "RELATION" and len(fields) == 9 and fields[2] == "SOURCE":
                rid = fields[1]
                if not rid or rid in relation_ids:
                    raise UnifiedActualError("UnifiedActual: duplicate/empty RelationUnit id in TX")
                try:
                    q = int(fields[8])
                except ValueError as exc:
                    raise UnifiedActualError("UnifiedActual: invalid Relation quantity") from exc
                relation_ids.add(rid)
                relations.append(Relation(rid, fields[3], fields[4], fields[5], fields[6], fields[7], q))
            elif tag == "DISCHARGE" and len(fields) == 3:
                try:
                    q = int(fields[2])
                except ValueError as exc:
                    raise UnifiedActualError("UnifiedActual: invalid Discharge quantity") from exc
                discharges.append(Discharge(fields[1], q))
            else:
                raise UnifiedActualError(f"UnifiedActual: malformed TX row {rows[i]!r}")
            i += 1
        if i >= len(rows) or rows[i] != "ENDTX":
            raise UnifiedActualError(f"UnifiedActual {event}: missing ENDTX")
        txs.append(
            Tx(
                event,
                base_date,
                description,
                replaces,
                reversal_of,
                tuple(effects),
                tuple(sorted(revisions)),
                tuple(sorted(relations)),
                tuple(sorted(discharges)),
            )
        )
        i += 1

    model = Model(tuple(txs))
    validate_unified(model)
    return model


def validate_unified(model: Model) -> None:
    tx_by_event = {tx.event: tx for tx in model.txs}
    if len(tx_by_event) != len(model.txs):
        raise UnifiedActualError("UnifiedActual: duplicate Event")

    correction_targets: set[str] = set()
    reversal_targets: set[str] = set()
    global_relation_ids: set[str] = set()
    revisions: dict[str, tuple[str, DateRevision]] = {}

    for tx in model.txs:
        if tx.replaces is not None:
            if tx.replaces not in tx_by_event or tx.replaces in correction_targets:
                raise UnifiedActualError("UnifiedActual: invalid/branching REPLACES")
            correction_targets.add(tx.replaces)
        if tx.reversal_of is not None:
            if tx.reversal_of not in tx_by_event or tx.reversal_of in reversal_targets:
                raise UnifiedActualError("UnifiedActual: invalid/non-functional REVERSAL-OF")
            reversal_targets.add(tx.reversal_of)

        keyed = {effect.key for effect in tx.effects if effect.key is not None}
        if len(keyed) != sum(1 for effect in tx.effects if effect.key is not None):
            raise UnifiedActualError("UnifiedActual: duplicate stable EffectKey in Event")
        for rel in tx.relations:
            if rel.id in global_relation_ids or rel.source_key not in keyed:
                raise UnifiedActualError("UnifiedActual: Relation id duplicate or source not keyed in parent TX")
            global_relation_ids.add(rel.id)
        for rev in tx.revisions:
            if rev.id in revisions:
                raise UnifiedActualError("UnifiedActual: duplicate date revision id")
            revisions[rev.id] = (tx.event, rev)

    for tx in model.txs:
        for rev in tx.revisions:
            if rev.predecessor_kind == "ROOT":
                if rev.predecessor != tx.event:
                    raise UnifiedActualError("UnifiedActual: date revision ROOT belongs to different Event")
            else:
                prior = revisions.get(rev.predecessor)
                if prior is None or prior[0] != tx.event:
                    raise UnifiedActualError("UnifiedActual: date revision predecessor missing/cross-event")
        seen_discharge_targets: set[str] = set()
        for discharge in tx.discharges:
            if discharge.relation_id not in global_relation_ids or discharge.relation_id in seen_discharge_targets:
                raise UnifiedActualError("UnifiedActual: discharge target missing or duplicate in later Event")
            seen_discharge_targets.add(discharge.relation_id)


def normal_form(model: Model) -> tuple:
    """Order-insensitive semantic observation preserving multiplicity."""
    tx_rows = []
    for tx in model.txs:
        effect_multiset = tuple(sorted(Counter(tx.effects).items()))
        tx_rows.append(
            (
                tx.event,
                tx.base_date,
                tx.description,
                tx.replaces,
                tx.reversal_of,
                effect_multiset,
                tuple(sorted(tx.revisions)),
                tuple(sorted(tx.relations)),
                tuple(sorted(tx.discharges)),
            )
        )
    return tuple(sorted(tx_rows))


def project(root: Path, output: Path) -> None:
    model = load_split_model(root)
    validate_unified(model)
    encoded = encode_unified(model)
    decoded = decode_unified(encoded)
    if normal_form(decoded) != normal_form(model):
        raise UnifiedActualError("unified wire changed normalized Actual meaning")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(encoded)

    families = selected_family_bytes(root)
    split_bytes = sum(len(families[name]) for name in REQUIRED_FAMILIES)
    correction = root / "corrections.loam"
    reversal = root / "actual-reversals.loam"
    if correction.is_file():
        split_bytes += correction.stat().st_size
    if reversal.is_file():
        split_bytes += reversal.stat().st_size

    keyed = sum(1 for tx in model.txs for effect in tx.effects if effect.key is not None)
    keyless = sum(1 for tx in model.txs for effect in tx.effects if effect.key is None)
    print(
        f"unified Actual: {len(model.txs)} transactions, {keyless} keyless Effects, "
        f"{keyed} stable-key Effects; {split_bytes} -> {len(encoded)} bytes"
    )
    print("unified Actual semantic normal form round trip passed")


def check(root: Path) -> None:
    model = load_split_model(root)
    validate_unified(model)
    encoded = encode_unified(model)
    decoded = decode_unified(encoded)
    if normal_form(decoded) != normal_form(model):
        raise UnifiedActualError("normalized Actual mismatch")
    print("unified Actual semantic normal form parity passed")


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    p_project = sub.add_parser("project")
    p_project.add_argument("root", type=Path)
    p_project.add_argument("output", type=Path)
    p_check = sub.add_parser("check")
    p_check.add_argument("root", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "project":
            project(args.root, args.output)
        else:
            check(args.root)
        return 0
    except UnifiedActualError as exc:
        print(f"unified Actual experiment failed: {exc}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
