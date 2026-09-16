#!/usr/bin/env python3
"""Build the Generation-2 CurrentQuantityAnchor publication audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-current-quantity-anchor-publication-audit.drn"

DIAGRAMS = {
    "G2.017.1 Current Anchor Publication": {
        "description": "Show the current production observation path and the ownership interval that protects its correction-root cut.",
        "sources": "Loam/CurrentQuantityAnchorPublisher.lean; Loam/CurrentQuantityAnchor.lean; Loam/Persistence/CurrentQuantityAnchorPersistence.lean; Loam/ActualAuthority.lean",
        "audit": "The reflected-root cut is derived from the exact normalized Actual generation observed under writer ownership. The replaceable anchor image is also locked. These are the two current mutable production authorities whose coherence is required by publication.",
        "nodes": [
            ("action", "HouseholdCommand.observeCurrentQuantities / CLI"),
            ("insertion", "acquire Actual ownership"),
            ("insertion", "acquire current-anchor ownership"),
            ("action", "load normalized Actual"),
            ("action", "load ZeroOriginCoverage snapshot"),
            ("action", "load OpeningSupport snapshot"),
            ("decision", "any asserted coordinate already supported?", "refuse overlap"),
            ("action", "derive stable correction roots from locked Actual"),
            ("decision", "one admitted correction-root set?", "refuse unresolved correction world"),
            ("action", "construct one complete anchor image"),
            ("action", "atomically replace current-quantity-anchor.loam"),
        ],
    },
    "G2.017.2 Ownership Pressure": {
        "description": "Compare semantic inputs with actual production-writer reachability before adding locks.",
        "sources": "Loam/CurrentQuantityAnchorPublisher.lean; Loam/Persistence/OpeningSupportPersistence.lean; Loam/Persistence/ZeroOriginCoveragePersistence.lean; repository-wide save-call reachability; shumoku88-bit/loam-data",
        "audit": "ZeroOriginCoverage and OpeningSupport are real overlap guards, but neither has a current LOAM production writer. OpeningSupport save has no production caller and ZeroOriginCoverage save is fixture-only. Canonical household copies are Git-managed evidence/policy. Adding support locks now would protect no reachable runtime race.",
        "nodes": [
            ("action", "Actual\nmutable production authority"),
            ("action", "Anchor\nmutable production authority"),
            ("action", "ZeroOriginCoverage\nconfigured evidence snapshot"),
            ("action", "OpeningSupport\nconfigured evidence snapshot"),
            ("decision", "production writer for Coverage?", "YES -> reopen G2-017 ownership"),
            ("action", "NO today"),
            ("decision", "production writer for OpeningSupport?", "YES -> reopen G2-017 ownership"),
            ("action", "NO today"),
            ("action", "KEEP Actual -> Anchor ownership only"),
            ("action", "DO NOT ADD speculative support locks"),
        ],
    },
    "G2.017.3 Fresh Observation Stop Point": {
        "description": "Record why a fresh observation replaces the current image without creating anchor revision history.",
        "sources": "Loam/CurrentQuantityAnchorPublisher.lean; Loam/Tests/FourVoiceCompatibilityV4.lean; docs/research/LOAM_FOUR_VOICE_COMPATIBILITY_2026-09.md",
        "audit": "Four-Voice V4 already qualifies a fresh observation as a new complete reflected-root cut, not a historical revision of the previous anchor. A revision graph would add identity, chronology and selection semantics without independent product pressure.",
        "nodes": [
            ("action", "existing current anchor image"),
            ("action", "fresh observed quantities"),
            ("action", "derive fresh complete reflected-root cut"),
            ("action", "build fresh complete anchor image"),
            ("action", "replace current image atomically"),
            ("decision", "retain old anchor as revision history?", "Only if future product pressure earns history semantics"),
            ("action", "NO today"),
            ("action", "KEEP complete-image replacement"),
        ],
    },
}


def build() -> None:
    if OUTPUT.exists():
        OUTPUT.unlink()

    names = list(DIAGRAMS)
    diagram_ids = {name: index for index, name in enumerate(names, 1)}

    with sqlite3.connect(OUTPUT) as db:
        db.executescript(base.SCHEMA)
        db.executemany(
            "insert into info values (?,?)",
            [
                ("type", "drakon"),
                ("version", "2"),
                ("start_version", "1"),
                ("language", "Lean"),
            ],
        )
        db.execute(
            "insert into state values (1,1,?)",
            ("LOAM G2.017 - CurrentQuantityAnchor publication",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.017 CurrentQuantityAnchor publication")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("CurrentQuantityAnchor publication audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing CurrentQuantityAnchor publication source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
