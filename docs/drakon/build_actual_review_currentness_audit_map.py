#!/usr/bin/env python3
"""Build the Generation-2 Actual Review currentness audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-actual-review-currentness-audit.drn"

DIAGRAMS = {
    "G2.024.1 Actual Review Admission": {
        "description": "Show the fail-closed correction admission that precedes transient Actual review records.",
        "sources": "Loam/ActualReview.lean; Loam/Application/CorrectionFrontier.lean; Loam/Application/ReplacementFrontier.lean",
        "audit": "Currentness is simplified only after the full correction relation is admitted. Reference closure, successor uniqueness, predecessor uniqueness and acyclicity remain owned by CorrectionFrontier.",
        "nodes": [
            ("action", "Load normalized ActualEvidence"),
            ("insertion", "correctionFrontierMemory?"),
            ("decision", "Correction graph admitted?", "NO - refuse review"),
            ("insertion", "admittedActualValidityMemory?"),
            ("decision", "Current date frontier admitted?", "NO - refuse review"),
            ("action", "Project one transient Record per remembered Event"),
        ],
    },
    "G2.024.2 Replacement Determines Currentness": {
        "description": "Expose the exact dependency between outgoing correction identity and read-side currentness.",
        "sources": "Loam/ActualReview.lean; Loam/Application/CorrectionFrontier.lean; Loam/Tests/RecordReview.lean; Loam/Tests/StockFlowReview.lean; Loam/Tests/TransactionsFlowReview.lean",
        "audit": "After correction-frontier admission an Event is current iff no correction targets it. ActualReview replacement is the same target lookup, so Record.isCurrent is exactly replacement.isNone and need not be retained separately.",
        "nodes": [
            ("action", "Remembered EventId"),
            ("insertion", "Find Correction with target == EventId"),
            ("decision", "Replacement found?", "NO"),
            ("action", "replacement = none"),
            ("action", "derive isCurrent = true"),
            ("decision", "Replacement found?", "YES"),
            ("action", "retain successor EventId"),
            ("action", "derive isCurrent = false"),
            ("action", "No contradictory Bool copy in Record"),
        ],
    },
    "G2.024.3 Stop Point": {
        "description": "Record the distinctions intentionally retained after currentness compression.",
        "sources": "Loam/ActualReview.lean; Loam/Application/CorrectionFrontier.lean; Loam/Observations/Observation256.lean",
        "audit": "Keep replacement identity, whole-graph correction admission, date and description. Observation256 may still copy derived currentness into its local visible RegisterRow. Do not replace graph admission with a local Option check or add a generic status abstraction.",
        "nodes": [
            ("action", "KEEP correction-frontier admission"),
            ("action", "KEEP replacement EventId"),
            ("action", "KEEP date + description + Event"),
            ("action", "DERIVE Record.isCurrent"),
            ("decision", "Drop replacement too?", "NO - successor identity is visible evidence"),
            ("decision", "Skip frontier admission?", "NO - topology must fail closed"),
            ("decision", "Generalize status framework?", "NO - no shared invariant earned"),
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
            ("LOAM G2.024 - Actual Review currentness derivation",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.024 Actual Review currentness")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Actual Review currentness audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing Actual Review currentness source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
