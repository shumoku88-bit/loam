#!/usr/bin/env python3
"""Build the Generation-2 Actual Review frontier-materialization audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-actual-review-frontier-materialization-audit.drn"

DIAGRAMS = {
    "G2.025.1 Actual Review Dependency": {
        "description": "Show the Actual Review read path after currentness became a consequence of retained replacement identity.",
        "sources": "Loam/ActualReview.lean; Loam/Application/CorrectionFrontier.lean; Loam/Application/ActualValidityFrontier.lean",
        "audit": "Actual Review still needs full correction topology admission, but it does not consume a current-frontier EventMemory after G2-024. The review projects every remembered Event and derives currentness from its outgoing correction edge.",
        "nodes": [
            ("action", "Load normalized ActualEvidence"),
            ("insertion", "correctionFrontierAdmissible"),
            ("decision", "Correction topology admitted?", "NO - refuse review"),
            ("insertion", "admittedActualValidityMemory?"),
            ("decision", "Current date frontier admitted?", "NO - refuse review"),
            ("action", "Project EVERY remembered Event"),
            ("action", "retain replacement EventId if targeted"),
            ("action", "derive Record.isCurrent := replacement.isNone"),
            ("action", "Return transient Records"),
        ],
    },
    "G2.025.2 Materialize Only When Consumed": {
        "description": "Separate admission-only callers from callers that genuinely need the current Event frontier value.",
        "sources": "Loam/ActualReview.lean; Loam/BalanceReview.lean; Loam/BudgetWindowReview.lean; Loam/RoleBalanceReview.lean; Loam/Application/CorrectionFrontier.lean",
        "audit": "The simplification is intentionally local. Balance, Budget and Role projections consume the filtered current EventMemory for quantity semantics, so correctionFrontierMemory? remains their correct boundary.",
        "nodes": [
            ("action", "Correction relation"),
            ("decision", "Caller needs current Event collection?", "NO - Actual Review"),
            ("action", "Use correctionFrontierAdmissible only"),
            ("decision", "Caller needs current Event collection?", "YES - quantity/effective projection"),
            ("action", "Use correctionFrontierMemory?"),
            ("action", "Consume frontier EventMemory"),
            ("action", "No repository-wide replacement"),
        ],
    },
    "G2.025.3 Fail-Closed Stop Point": {
        "description": "Pin the graph obligations that remain after removing unused frontier construction from Actual Review.",
        "sources": "Loam/Application/CorrectionFrontier.lean; Loam/Core/EventCorrectionMemory.lean; Loam/Tests/RecordReview.lean",
        "audit": "Raw correction storage admits distinct sibling edges. Actual Review must still reject branching, merging, cycles and missing endpoints through CorrectionFrontier admission before any transient Record is returned.",
        "nodes": [
            ("action", "Raw EventCorrectionMemory\nexact-edge uniqueness only"),
            ("decision", "Closed + one successor + one predecessor + acyclic?", "NO - refuse review"),
            ("action", "Topology admitted"),
            ("action", "Proceed without building unused frontier memory"),
            ("decision", "Replace graph gate with local replacement.isNone?", "NO - would weaken admission"),
            ("decision", "Delete correctionFrontierMemory??", "NO - other callers consume it"),
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
            ("LOAM G2.025 - Actual Review frontier materialization",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.025 Actual Review frontier materialization")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Actual Review frontier-materialization audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing Actual Review frontier-materialization source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
