#!/usr/bin/env python3
"""Read-only measurement of current LOAM EffectKey persistence pressure."""

from __future__ import annotations

import argparse
from pathlib import Path

MANIFEST = "LOAM-MOVEMENT-MANIFEST\t2"
EVENT_HEADER = "LOAM-EVENT-MEMORY\t1"
RELATION_HEADER = "LOAM-RELATION-UNIT-MEMORY\t1"


def selected(root: Path) -> dict[str, Path]:
    authority = root / "movement-authority"
    lines = (authority / "CURRENT").read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != MANIFEST:
        raise ValueError("unsupported Movement manifest")
    result: dict[str, Path] = {}
    for row in lines[1:]:
        if not row:
            continue
        family, relative, _digest = row.split("\t")
        result[family] = authority / relative
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("data_root", type=Path)
    args = parser.parse_args()

    families = selected(args.data_root)
    event_lines = families["Event"].read_text(encoding="utf-8").splitlines()
    relation_lines = families["RelationUnit"].read_text(encoding="utf-8").splitlines()
    if not event_lines or event_lines[0] != EVENT_HEADER:
        raise ValueError("unsupported Event memory")
    if not relation_lines or relation_lines[0] != RELATION_HEADER:
        raise ValueError("unsupported RelationUnit memory")

    event_count = 0
    effect_count = 0
    key_token_bytes = 0
    key_wire_bytes = 0
    keys: list[str] = []
    for row in event_lines[1:]:
        fields = row.split("\t")
        if fields[0] == "EVENT":
            event_count += 1
        elif fields[0] == "EFFECT":
            effect_count += 1
            key = fields[1]
            keys.append(key)
            encoded = key.encode("utf-8")
            key_token_bytes += len(encoded)
            # In both current Event wire and compact Actual, one tab separates
            # the key from the next field. A keyless row removes token + tab.
            key_wire_bytes += len(encoded) + 1
        else:
            raise ValueError(f"unexpected Event row: {row!r}")

    relation_rows = [row for row in relation_lines[1:] if row]
    avg = key_token_bytes / effect_count if effect_count else 0.0
    max_len = max((len(k.encode("utf-8")) for k in keys), default=0)
    min_len = min((len(k.encode("utf-8")) for k in keys), default=0)

    print(f"events\t{event_count}")
    print(f"effects\t{effect_count}")
    print(f"relation_units\t{len(relation_rows)}")
    print(f"effect_key_token_bytes\t{key_token_bytes}")
    print(f"effect_key_wire_bytes\t{key_wire_bytes}")
    print(f"effect_key_avg_token_bytes\t{avg:.3f}")
    print(f"effect_key_min_token_bytes\t{min_len}")
    print(f"effect_key_max_token_bytes\t{max_len}")
    print(f"current_compact_actual_bytes\t65466")
    print(f"hypothetical_keyless_compact_bytes\t{65466 - key_wire_bytes}")
    print(f"hypothetical_keyless_saving_pct\t{(key_wire_bytes * 100.0 / 65466):.2f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
