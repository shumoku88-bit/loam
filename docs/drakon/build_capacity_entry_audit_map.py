#!/usr/bin/env python3
"""Build the Generation-2 Capacity entry symmetry audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-capacity-entry-audit.drn"

DIAGRAMS = {
    "G2.013.1 Binary / Balanced Capacity Entry Comparison": {
        "description": "Compare the binary and multi-coordinate Capacity publication entrances at one semantic scale before they join the shared admitted tail.",
        "sources": "Loam/CapacityPublisher.lean; Loam/Application/CapacityInspection.lean; Loam/CapacityAuthority.lean; Loam/Persistence/CapacityPersistence.lean",
        "audit": "Earlier compression correctly shared fresh identity, append, and effective-first persistence mechanics. Same-scale comparison shows that binary construction derives nonempty/nonzero/distinct/exact-balance movement shape from positive quanta and distinct endpoints, while BalancedDraft must validate those independently. Both entrances nevertheless share one independent representation obligation: every Purpose coordinate must satisfy the existing persistence token syntax before the effective-first tail begins writing.",
        "nodes": [
            ("action", "BINARY Draft"),
            ("decision", "real date + positive quanta + distinct endpoints?"),
            ("decision", "source/destination coordinates persistable?"),
            ("insertion", "derive exactly two nonzero balanced changes"),
            ("decision", "named source entitlement sufficient?"),
            ("action", "BALANCED Draft"),
            ("decision", "real date + nonempty/nonzero/unique/exact balance?"),
            ("decision", "all coordinates persistable?"),
            ("decision", "every Purpose remains nonnegative?"),
            ("action", "JOIN: publishAdmittedMovement"),
            ("insertion", "fresh CapacityMovementId + append candidate families"),
            ("action", "publish effective evidence FIRST"),
            ("action", "publish Capacity movement SECOND"),
        ],
    },
    "G2.013.2 Missing Binary Persistence Gate": {
        "description": "Show the pre-G2-013 path by which one directly constructed binary Draft could make the publisher create recover-required incomplete evidence.",
        "sources": "Loam/CapacityPublisher.lean; Loam/Application/CapacityInspection.lean; Loam/Persistence/CapacityPersistence.lean; Loam/Persistence/TokenSyntax.lean",
        "audit": "Before G2-013, binary validateDraft did not validate Purpose token syntax. With source=unallocated, destination=Purpose invalidToken, and positive quanta, source admission also succeeds. The shared tail can then publish CapacityEffective successfully because it contains only movement id/date, while CapacityPersistence later rejects the invalid Purpose row. The writer itself could therefore leave inert orphan effective evidence and force explicit recovery on the next write.",
        "nodes": [
            ("action", "binary Draft:\nunallocated -> invalid Purpose token"),
            ("decision", "old validateDraft passes?"),
            ("action", "yes: date / q / endpoint shape all valid"),
            ("decision", "canMoveCapacityFrom unallocated?"),
            ("action", "yes for positive quanta"),
            ("action", "publishAdmittedMovement"),
            ("action", "saveEffective? succeeds"),
            ("decision", "Capacity movement encodable?"),
            ("action", "NO: invalid Purpose token"),
            ("action", "movement write refused"),
            ("action", "orphan effective row remains inert"),
            ("action", "next writer requires explicit recovery"),
        ],
    },
    "G2.013.3 Minimal Repair / Stop Point": {
        "description": "Record the smallest production repair and the boundaries that should remain distinct.",
        "sources": "Loam/CapacityPublisher.lean; Loam/Tests/CapacityPublisher.lean; commit fa1542688a1680af0d3994f0f3d18b451368f85f",
        "audit": "Share only coordinatePersistable between binary and BalancedDraft validation. Keep binary positive-amount, distinct-endpoint, and source-entitlement diagnostics local; keep BalancedDraft nonempty/nonzero/unique/exact-balance and per-Purpose nonnegative obligations local. Keep the first-generation shared publication tail unchanged. The regression pins that an invalid binary Purpose token changes neither Capacity movements nor effective entries.",
        "nodes": [
            ("insertion", "coordinatePersistable"),
            ("action", "unallocated -> true"),
            ("action", "Purpose -> Persistence.validToken"),
            ("action", "reuse in binary validateDraft"),
            ("action", "reuse in validateBalancedDraft"),
            ("action", "KEEP binary-local semantic checks"),
            ("action", "KEEP BalancedDraft-local semantic checks"),
            ("action", "KEEP shared admitted publication tail"),
            ("insertion", "regression: invalid binary Purpose token"),
            ("decision", "both retained family counts unchanged?"),
            ("action", "yes -> FIX QUALIFIED when CI passes"),
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
            ("LOAM G2.013 - Capacity entry symmetry",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.013 Capacity entry symmetry")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Capacity entry audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing Capacity entry source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
