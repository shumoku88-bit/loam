#!/usr/bin/env python3
"""Experimental semantic compression of Event + base date + description."""

from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path

MOVEMENT_MAGIC = "LOAM-MOVEMENT-MANIFEST\t2"
EVENT_HEADER = "LOAM-EVENT-MEMORY\t1"
VALIDITY_HEADER = "LOAM-ACTUAL-VALIDITY-HISTORY\t3"
DESCRIPTION_HEADER = "LOAM-EVENT-DESCRIPTION-MEMORY\t1"
COMPACT_HEADER = "LOAM-COMPACT-ACTUAL\t1"
TARGET_FAMILIES = ("Event", "ActualValidity", "EventDescription")


class CompactError(RuntimeError):
    pass


@dataclass(frozen=True)
class EffectRow:
    key: str
    locus: str
    measure: str
    quanta: str


@dataclass(frozen=True)
class Tx:
    event: str
    valid_on: str
    description: str | None
    effects: tuple[EffectRow, ...]


@dataclass(frozen=True)
class CompactActual:
    txs: tuple[Tx, ...]
    sparse_validity: tuple[str, ...]


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def selected_family_paths(root: Path) -> tuple[list[str], dict[str, tuple[str, str]]]:
    current = root / "movement-authority" / "CURRENT"
    if not current.is_file():
        raise CompactError(f"missing selector: {current}")
    lines = current.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != MOVEMENT_MAGIC:
        raise CompactError(f"{current}: unsupported manifest")
    order: list[str] = []
    result: dict[str, tuple[str, str]] = {}
    for line in lines[1:]:
        if not line:
            continue
        fields = line.split("\t")
        if len(fields) != 3:
            raise CompactError(f"{current}: malformed row {line!r}")
        family, relative, digest = fields
        if family in result:
            raise CompactError(f"{current}: duplicate family {family}")
        rel = Path(relative)
        if rel.is_absolute() or ".." in rel.parts:
            raise CompactError(f"{current}: unsafe path {relative!r}")
        object_path = root / "movement-authority" / rel
        if not object_path.is_file():
            raise CompactError(f"selected object missing: {object_path}")
        data = object_path.read_bytes()
        if sha256(data) != digest:
            raise CompactError(f"selected object digest mismatch: {family}")
        order.append(family)
        result[family] = (relative, digest)
    for family in TARGET_FAMILIES:
        if family not in result:
            raise CompactError(f"CURRENT does not select required family {family}")
    return order, result


def selected_bytes(root: Path, family: str) -> bytes:
    _, families = selected_family_paths(root)
    relative, _ = families[family]
    return (root / "movement-authority" / relative).read_bytes()


def decoded_lines(data: bytes, header: str, label: str) -> list[str]:
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise CompactError(f"{label}: not UTF-8") from exc
    if not text.endswith("\n"):
        raise CompactError(f"{label}: missing trailing newline")
    lines = text.splitlines()
    if not lines or lines[0] != header:
        raise CompactError(f"{label}: unsupported header")
    return lines[1:]


def parse_events(data: bytes) -> tuple[tuple[str, tuple[EffectRow, ...]], ...]:
    lines = decoded_lines(data, EVENT_HEADER, "Event")
    events: list[tuple[str, tuple[EffectRow, ...]]] = []
    current_id: str | None = None
    current_effects: list[EffectRow] = []
    seen_events: set[str] = set()
    seen_keys: set[str] = set()

    def finish() -> None:
        nonlocal current_id, current_effects, seen_keys
        if current_id is not None:
            events.append((current_id, tuple(current_effects)))
        current_id = None
        current_effects = []
        seen_keys = set()

    for line in lines:
        fields = line.split("\t")
        if len(fields) == 2 and fields[0] == "EVENT":
            finish()
            event = fields[1]
            if not event or event in seen_events:
                raise CompactError(f"Event: duplicate/empty event {event!r}")
            seen_events.add(event)
            current_id = event
        elif len(fields) == 5 and fields[0] == "EFFECT":
            if current_id is None:
                raise CompactError("Event: EFFECT before EVENT")
            _, key, locus, measure, quanta = fields
            if not key or not locus or not measure or key in seen_keys:
                raise CompactError(f"Event {current_id}: invalid/duplicate effect key")
            try:
                int(quanta)
            except ValueError as exc:
                raise CompactError(f"Event {current_id}: invalid quanta {quanta!r}") from exc
            seen_keys.add(key)
            current_effects.append(EffectRow(key, locus, measure, quanta))
        else:
            raise CompactError(f"Event: malformed row {line!r}")
    finish()
    return tuple(events)


def parse_validity(data: bytes) -> tuple[dict[str, str], tuple[str, ...]]:
    lines = decoded_lines(data, VALIDITY_HEADER, "ActualValidity")
    base: dict[str, str] = {}
    sparse: list[str] = []
    for line in lines:
        fields = line.split("\t")
        if len(fields) == 3 and fields[0] == "BASE":
            _, event, valid_on = fields
            if not event or event in base:
                raise CompactError(f"ActualValidity: duplicate/empty BASE {event!r}")
            base[event] = valid_on
        elif fields and fields[0] in ("REVISION", "CORRECTION"):
            # Sparse date-revision topology remains explicit. The compact format
            # does not reinterpret, infer, or collapse it.
            sparse.append(line)
        else:
            raise CompactError(f"ActualValidity: malformed row {line!r}")
    return base, tuple(sparse)


def parse_descriptions(data: bytes) -> dict[str, str]:
    lines = decoded_lines(data, DESCRIPTION_HEADER, "EventDescription")
    descriptions: dict[str, str] = {}
    for line in lines:
        fields = line.split("\t", 2)
        if len(fields) != 3 or fields[0] != "DESC":
            raise CompactError(f"EventDescription: malformed row {line!r}")
        _, event, escaped = fields
        if not event or event in descriptions:
            raise CompactError(f"EventDescription: duplicate/empty event {event!r}")
        descriptions[event] = escaped
    return descriptions


def load_semantic(root: Path) -> CompactActual:
    events = parse_events(selected_bytes(root, "Event"))
    base, sparse = parse_validity(selected_bytes(root, "ActualValidity"))
    descriptions = parse_descriptions(selected_bytes(root, "EventDescription"))

    event_ids = {event for event, _ in events}
    if set(base) != event_ids:
        raise CompactError(
            "ActualValidity BASE support differs from Event support: "
            f"events-only={sorted(event_ids - set(base))}, "
            f"base-only={sorted(set(base) - event_ids)}"
        )
    unknown_descriptions = set(descriptions) - event_ids
    if unknown_descriptions:
        raise CompactError(
            f"EventDescription targets absent Event(s): {sorted(unknown_descriptions)}"
        )

    txs = tuple(
        Tx(event, base[event], descriptions.get(event), effects)
        for event, effects in events
    )
    return CompactActual(txs, sparse)


def encode_compact(model: CompactActual) -> bytes:
    rows: list[str] = [COMPACT_HEADER]
    for tx in model.txs:
        if tx.description is None:
            rows.append(f"TX\t{tx.event}\t{tx.valid_on}\tNODESC")
        else:
            rows.append(f"TX\t{tx.event}\t{tx.valid_on}\tDESC\t{tx.description}")
        for effect in tx.effects:
            rows.append(
                "EFFECT\t"
                + "\t".join((effect.key, effect.locus, effect.measure, effect.quanta))
            )
        rows.append("ENDTX")
    for row in model.sparse_validity:
        rows.append("VALIDITY\t" + row)
    return ("\n".join(rows) + "\n").encode("utf-8")


def decode_compact(data: bytes) -> CompactActual:
    lines = decoded_lines(data, COMPACT_HEADER, "CompactActual")
    txs: list[Tx] = []
    sparse: list[str] = []
    i = 0
    seen_events: set[str] = set()
    while i < len(lines):
        line = lines[i]
        fields = line.split("\t")
        if fields and fields[0] == "TX":
            if len(fields) == 4 and fields[3] == "NODESC":
                event, valid_on, description = fields[1], fields[2], None
            elif len(fields) == 5 and fields[3] == "DESC":
                event, valid_on, description = fields[1], fields[2], fields[4]
            else:
                raise CompactError(f"CompactActual: malformed TX {line!r}")
            if not event or event in seen_events:
                raise CompactError(f"CompactActual: duplicate/empty event {event!r}")
            seen_events.add(event)
            i += 1
            effects: list[EffectRow] = []
            seen_keys: set[str] = set()
            while i < len(lines) and lines[i] != "ENDTX":
                effect_fields = lines[i].split("\t")
                if len(effect_fields) != 5 or effect_fields[0] != "EFFECT":
                    raise CompactError(
                        f"CompactActual: expected EFFECT/ENDTX, got {lines[i]!r}"
                    )
                _, key, locus, measure, quanta = effect_fields
                if not key or key in seen_keys:
                    raise CompactError(f"CompactActual {event}: duplicate/empty effect key")
                try:
                    int(quanta)
                except ValueError as exc:
                    raise CompactError(f"CompactActual {event}: invalid quanta") from exc
                seen_keys.add(key)
                effects.append(EffectRow(key, locus, measure, quanta))
                i += 1
            if i >= len(lines) or lines[i] != "ENDTX":
                raise CompactError(f"CompactActual {event}: missing ENDTX")
            txs.append(Tx(event, valid_on, description, tuple(effects)))
            i += 1
        elif line.startswith("VALIDITY\t"):
            sparse.append(line.removeprefix("VALIDITY\t"))
            i += 1
        else:
            raise CompactError(f"CompactActual: malformed row {line!r}")
    return CompactActual(tuple(txs), tuple(sparse))


def old_family_bytes(model: CompactActual) -> dict[str, bytes]:
    event_rows = [EVENT_HEADER]
    validity_rows = [VALIDITY_HEADER]
    description_rows = [DESCRIPTION_HEADER]
    for tx in model.txs:
        event_rows.append(f"EVENT\t{tx.event}")
        for effect in tx.effects:
            event_rows.append(
                "EFFECT\t"
                + "\t".join((effect.key, effect.locus, effect.measure, effect.quanta))
            )
        validity_rows.append(f"BASE\t{tx.event}\t{tx.valid_on}")
        if tx.description is not None:
            description_rows.append(f"DESC\t{tx.event}\t{tx.description}")
    validity_rows.extend(model.sparse_validity)
    return {
        "Event": ("\n".join(event_rows) + "\n").encode("utf-8"),
        "ActualValidity": ("\n".join(validity_rows) + "\n").encode("utf-8"),
        "EventDescription": ("\n".join(description_rows) + "\n").encode("utf-8"),
    }


def pack(root: Path, output: Path) -> None:
    model = load_semantic(root)
    compact = encode_compact(model)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(compact)
    source_size = sum(len(selected_bytes(root, family)) for family in TARGET_FAMILIES)
    saved = source_size - len(compact)
    percent = (saved * 100.0 / source_size) if source_size else 0.0
    print(
        f"compact Actual: {len(model.txs)} transactions, "
        f"{len(model.sparse_validity)} sparse validity rows; "
        f"{source_size} -> {len(compact)} bytes "
        f"({saved:+d}, {percent:.1f}% smaller)"
    )


def apply(compact_path: Path, root: Path) -> None:
    model = decode_compact(compact_path.read_bytes())
    encoded = old_family_bytes(model)
    order, families = selected_family_paths(root)
    authority = root / "movement-authority"

    replacements: dict[str, tuple[str, str]] = {}
    for family in TARGET_FAMILIES:
        data = encoded[family]
        digest = sha256(data)
        relative = f"objects/{family}/{digest}.loam"
        path = authority / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        replacements[family] = (relative, digest)

    rows = [MOVEMENT_MAGIC]
    for family in order:
        relative, digest = replacements.get(family, families[family])
        rows.append(f"{family}\t{relative}\t{digest}")
    (authority / "CURRENT").write_text("\n".join(rows) + "\n", encoding="utf-8")


def check(root: Path, work: Path) -> None:
    work.mkdir(parents=True, exist_ok=True)
    compact_path = work / "actual.compact"
    rebuilt = work / "rebuilt"
    pack(root, compact_path)
    shutil.copytree(root, rebuilt)
    apply(compact_path, rebuilt)
    before = load_semantic(root)
    after = load_semantic(rebuilt)
    if before != after:
        raise CompactError("semantic Actual model changed after compact round trip")
    print("compact Actual semantic round trip preserved Event/date/description/effects/revisions")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Fuse LOAM Event + BASE date + description into compact Actual transactions."
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_pack = sub.add_parser("pack")
    p_pack.add_argument("data_root", type=Path)
    p_pack.add_argument("output", type=Path)

    p_apply = sub.add_parser("apply")
    p_apply.add_argument("compact_actual", type=Path)
    p_apply.add_argument("data_root", type=Path)

    p_check = sub.add_parser("check")
    p_check.add_argument("data_root", type=Path)
    p_check.add_argument("work_dir", type=Path)

    args = parser.parse_args(argv)
    try:
        if args.command == "pack":
            pack(args.data_root, args.output)
        elif args.command == "apply":
            apply(args.compact_actual, args.data_root)
        else:
            check(args.data_root, args.work_dir)
    except (OSError, CompactError) as exc:
        print(f"compact Actual projection failed: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
