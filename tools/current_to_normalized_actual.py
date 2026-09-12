#!/usr/bin/env python3
"""READ-ONLY research projection from current LOAM Actual authority to normalized wire.

This is differential/migration research only. It must not become a permanent runtime
compatibility reader. Current selected object digests are verified before projection.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from collections import defaultdict
from pathlib import Path

from normalized_actual import (
    Actual,
    ActualError,
    DateRevision,
    Discharge,
    Effect,
    Relation,
    Tx,
    encode,
    parse,
)


class ProjectionError(RuntimeError):
    pass


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def unescape_description(value: str) -> str:
    out: list[str] = []
    i = 0
    while i < len(value):
        c = value[i]
        if c != "\\":
            out.append(c)
            i += 1
            continue
        i += 1
        if i >= len(value):
            raise ProjectionError("dangling description escape")
        escaped = value[i]
        mapping = {"\\": "\\", "n": "\n", "r": "\r", "t": "\t"}
        if escaped not in mapping:
            raise ProjectionError(f"unsupported description escape \\{escaped}")
        out.append(mapping[escaped])
        i += 1
    return "".join(out)


def read_selected_objects(root: Path) -> dict[str, bytes]:
    authority = root / "movement-authority"
    current = authority / "CURRENT"
    if not current.is_file():
        raise ProjectionError("missing Movement CURRENT")
    lines = current.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] not in ("LOAM-MOVEMENT-MANIFEST\t1", "LOAM-MOVEMENT-MANIFEST\t2"):
        raise ProjectionError("unsupported Movement CURRENT")
    selected: dict[str, bytes] = {}
    for line in lines[1:]:
        if not line:
            continue
        fields = line.split("\t")
        if len(fields) != 3:
            raise ProjectionError(f"malformed CURRENT row {line!r}")
        family, relative, digest = fields
        if family == "LocusAdmission":
            continue
        expected = f"objects/{family}/{digest}.loam"
        if relative != expected:
            raise ProjectionError(f"noncanonical CURRENT object path for {family}")
        path = authority / relative
        if not path.is_file():
            raise ProjectionError(f"selected {family} object missing")
        data = path.read_bytes()
        if sha256(data) != digest:
            raise ProjectionError(f"selected {family} digest mismatch")
        selected[family] = data
    required = {"Event", "ActualValidity", "EventDescription", "RelationUnit", "RelationDischarge"}
    missing = required - selected.keys()
    if missing:
        raise ProjectionError(f"CURRENT missing families: {sorted(missing)}")
    return selected


def decoded_lines(data: bytes, header: str) -> list[str]:
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ProjectionError(f"{header}: non-UTF8 object") from exc
    if not text.endswith("\n"):
        raise ProjectionError(f"{header}: missing trailing newline")
    lines = text.splitlines()
    if not lines or lines[0] != header:
        raise ProjectionError(f"expected {header}")
    return lines[1:]


def parse_events(data: bytes) -> tuple[list[str], dict[str, list[tuple[str, str, str, int]]]]:
    lines = decoded_lines(data, "LOAM-EVENT-MEMORY\t1")
    order: list[str] = []
    effects: dict[str, list[tuple[str, str, str, int]]] = {}
    current: str | None = None
    for line in lines:
        fields = line.split("\t")
        if len(fields) == 2 and fields[0] == "EVENT":
            current = fields[1]
            if current in effects:
                raise ProjectionError(f"duplicate Event {current}")
            order.append(current)
            effects[current] = []
        elif len(fields) == 5 and fields[0] == "EFFECT" and current is not None:
            try:
                quanta = int(fields[4])
            except ValueError as exc:
                raise ProjectionError(f"invalid Effect quantity {fields[4]!r}") from exc
            effects[current].append((fields[1], fields[2], fields[3], quanta))
        else:
            raise ProjectionError(f"malformed Event row {line!r}")
    return order, effects


def parse_validity(data: bytes):
    lines = decoded_lines(data, "LOAM-ACTUAL-VALIDITY-HISTORY\t3")
    bases: dict[str, str] = {}
    revisions: dict[str, tuple[str, str]] = {}
    correction_by_replacement: dict[str, tuple[str, str]] = {}
    for line in lines:
        fields = line.split("\t")
        if len(fields) == 3 and fields[0] == "BASE":
            if fields[1] in bases:
                raise ProjectionError(f"duplicate BASE for {fields[1]}")
            bases[fields[1]] = fields[2]
        elif len(fields) == 4 and fields[0] == "REVISION":
            if fields[1] in revisions:
                raise ProjectionError(f"duplicate revision {fields[1]}")
            revisions[fields[1]] = (fields[2], fields[3])
        elif len(fields) == 4 and fields[0] == "CORRECTION" and fields[1] in ("ROOT", "REVISION"):
            replacement = fields[3]
            if replacement in correction_by_replacement:
                raise ProjectionError(f"revision {replacement} has multiple predecessors")
            correction_by_replacement[replacement] = (fields[1], fields[2])
        else:
            raise ProjectionError(f"malformed ActualValidity row {line!r}")
    result: dict[str, list[DateRevision]] = defaultdict(list)
    for revision_id, (event, valid_on) in revisions.items():
        predecessor = correction_by_replacement.get(revision_id)
        if predecessor is None:
            raise ProjectionError(f"revision {revision_id} lacks predecessor edge")
        kind, target = predecessor
        if kind == "ROOT":
            if target != event:
                raise ProjectionError(f"revision {revision_id} root belongs to another Event")
            result[event].append(DateRevision(revision_id, valid_on, "ROOT", None))
        else:
            if target not in revisions:
                raise ProjectionError(f"revision {revision_id} predecessor absent")
            if revisions[target][0] != event:
                raise ProjectionError(f"revision {revision_id} predecessor belongs to another Event")
            result[event].append(DateRevision(revision_id, valid_on, "REV", target))
    return bases, result


def parse_descriptions(data: bytes) -> dict[str, str]:
    lines = decoded_lines(data, "LOAM-EVENT-DESCRIPTION-MEMORY\t1")
    descriptions: dict[str, str] = {}
    for line in lines:
        fields = line.split("\t", 2)
        if len(fields) != 3 or fields[0] != "DESC" or fields[1] in descriptions:
            raise ProjectionError(f"malformed/duplicate description row {line!r}")
        descriptions[fields[1]] = unescape_description(fields[2])
    return descriptions


def endpoint(kind: str, token: str) -> str:
    if kind == "H" and token == "":
        return "household"
    if kind == "E" and token:
        return "external:" + token
    raise ProjectionError(f"invalid relation endpoint {kind!r}/{token!r}")


def parse_relations(data: bytes):
    lines = decoded_lines(data, "LOAM-RELATION-UNIT-MEMORY\t1")
    by_event: dict[str, list[Relation]] = defaultdict(list)
    source_keys: set[tuple[str, str]] = set()
    ids: set[str] = set()
    for line in lines:
        fields = line.split("\t")
        if len(fields) != 9 or fields[0] != "RELATION":
            raise ProjectionError(f"malformed Relation row {line!r}")
        relation_id, event_id, effect_key = fields[1], fields[2], fields[3]
        if relation_id in ids:
            raise ProjectionError(f"duplicate RelationUnitId {relation_id}")
        ids.add(relation_id)
        try:
            quantity = int(fields[8])
        except ValueError as exc:
            raise ProjectionError(f"invalid relation quantity {fields[8]!r}") from exc
        by_event[event_id].append(
            Relation(
                relation_id,
                effect_key,
                endpoint(fields[4], fields[5]),
                endpoint(fields[6], fields[7]),
                quantity,
            )
        )
        source_keys.add((event_id, effect_key))
    return by_event, source_keys, ids


def parse_discharges(data: bytes, known_relations: set[str]):
    lines = decoded_lines(data, "LOAM-RELATION-DISCHARGE-MEMORY\t1")
    by_event: dict[str, list[Discharge]] = defaultdict(list)
    for line in lines:
        fields = line.split("\t")
        if len(fields) != 4 or fields[0] != "DISCHARGE":
            raise ProjectionError(f"malformed Discharge row {line!r}")
        if fields[2] not in known_relations:
            raise ProjectionError(f"Discharge targets absent relation {fields[2]}")
        try:
            quantity = int(fields[3])
        except ValueError as exc:
            raise ProjectionError(f"invalid discharge quantity {fields[3]!r}") from exc
        by_event[fields[1]].append(Discharge(fields[2], quantity))
    return by_event


def parse_corrections(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    lines = decoded_lines(path.read_bytes(), "LOAM-EVENT-CORRECTION-MEMORY\t2")
    by_replacement: dict[str, str] = {}
    targets: set[str] = set()
    for line in lines:
        fields = line.split("\t")
        if len(fields) != 3 or fields[0] != "CORRECTION":
            raise ProjectionError(f"malformed EventCorrection row {line!r}")
        if fields[1] in targets or fields[2] in by_replacement:
            raise ProjectionError("correction topology is not a disjoint path set")
        targets.add(fields[1])
        by_replacement[fields[2]] = fields[1]
    return by_replacement


def parse_reversals(path: Path) -> dict[str, str]:
    if not path.is_file():
        raise ProjectionError("current Actual reversal authority is missing")
    lines = decoded_lines(path.read_bytes(), "LOAM-ACTUAL-REVERSAL-MEMORY\t1")
    by_reversal: dict[str, str] = {}
    targets: set[str] = set()
    for line in lines:
        fields = line.split("\t")
        if len(fields) != 3 or fields[0] != "REVERSE":
            raise ProjectionError(f"malformed reversal row {line!r}")
        if fields[1] in targets or fields[2] in by_reversal:
            raise ProjectionError("reversal topology is not endpoint-functional")
        targets.add(fields[1])
        by_reversal[fields[2]] = fields[1]
    return by_reversal


def project(root: Path) -> Actual:
    selected = read_selected_objects(root)
    event_order, event_effects = parse_events(selected["Event"])
    bases, revisions = parse_validity(selected["ActualValidity"])
    descriptions = parse_descriptions(selected["EventDescription"])
    relations, source_keys, relation_ids = parse_relations(selected["RelationUnit"])
    discharges = parse_discharges(selected["RelationDischarge"], relation_ids)
    corrections = parse_corrections(root / "corrections.loam")
    reversals = parse_reversals(root / "actual-reversals.loam")

    known_events = set(event_order)
    for mapping_name, mapping in (("correction", corrections), ("reversal", reversals)):
        for later, target in mapping.items():
            if later not in known_events or target not in known_events:
                raise ProjectionError(f"open {mapping_name} endpoint")

    txs: list[Tx] = []
    for event in event_order:
        if event not in bases:
            raise ProjectionError(f"Event {event} lacks base occurrence date")
        projected_effects = tuple(
            Effect(key if (event, key) in source_keys else None, locus, measure, quanta)
            for key, locus, measure, quanta in event_effects[event]
        )
        txs.append(
            Tx(
                event=event,
                base_valid_on=bases[event],
                description=descriptions.get(event),
                replaces=corrections.get(event),
                reversal_of=reversals.get(event),
                effects=projected_effects,
                date_revisions=tuple(revisions.get(event, [])),
                relations=tuple(relations.get(event, [])),
                discharges=tuple(discharges.get(event, [])),
            )
        )

    extra = (set(bases) | set(revisions) | set(descriptions) | set(relations) | set(discharges)) - known_events
    if extra:
        raise ProjectionError(f"selected evidence names absent Events: {sorted(extra)}")

    actual = Actual(tuple(txs))
    # Reparse canonical bytes so the new model itself is the final admission gate.
    return parse(encode(actual))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("current_root", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args(argv)
    try:
        actual = project(args.current_root)
        data = encode(actual)
        args.output.write_bytes(data)
        print(f"projected {len(actual.txs)} current Events into {len(data)} normalized bytes")
    except (OSError, ActualError, ProjectionError) as exc:
        print(f"current-to-normalized projection failed: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
