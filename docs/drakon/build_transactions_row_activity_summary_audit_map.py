#!/usr/bin/env python3
"""Build the Generation-2 Transactions RowActivity summary audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-transactions-row-activity-summary-audit.drn"

DIAGRAMS = {
    "G2.023.1 Row Activity Result": {
        "description": "Separate independent two-sided row activity from exact derived summary values.",
        "sources": "Loam/TransactionsFlowReview.lean; Loam/Tui/Reports.lean; Loam/Tests/TransactionsFlowReview.lean",
        "audit": "RowActivity retains positive, negative and activeEvents. net and gross are exact functions of the signed partitions and no longer need independently representable state.",
        "nodes": [
            ("action", "selected current Event columns"),
            ("action", "read quantityAt exact coordinate"),
            ("decision", "quantity positive?", "YES / NO"),
            ("action", "accumulate positive partition"),
            ("decision", "quantity negative?", "YES / NO"),
            ("action", "accumulate negative partition"),
            ("action", "count nonzero contributing Events"),
            ("action", "retain positive + negative + activeEvents"),
            ("action", "derive net = positive + negative"),
            ("action", "derive gross = positive - negative"),
        ],
    },
    "G2.023.2 Contradiction Removal": {
        "description": "Show why retained net and gross were duplicate degrees of freedom.",
        "sources": "Loam/TransactionsFlowReview.lean; Loam/Tests/TransactionsFlowReview.lean",
        "audit": "The old public structure could carry net/gross values inconsistent with its own signed partitions. Same-named derived functions preserve read syntax while making those contradictions unrepresentable.",
        "nodes": [
            ("action", "positive partition P"),
            ("action", "negative partition N"),
            ("decision", "retain net separately?", "NO - P + N"),
            ("action", "derive net"),
            ("decision", "retain gross separately?", "NO - P - N"),
            ("action", "derive gross"),
            ("action", "presentation keeps activity.net / activity.gross"),
            ("action", "contradictory summary copies removed"),
        ],
    },
    "G2.023.3 Stop Point": {
        "description": "Record the exact simplification boundary and the distinctions intentionally retained.",
        "sources": "Loam/TransactionsFlowReview.lean; Loam/Tui/Reports.lean; experiments/236_transactions_flow_sparse_presentation.md",
        "audit": "G2-023 removes only arithmetic echoes. Two-sided signed partitions remain because they expose cancellation-hidden activity; activeEvents remains because quantity totals do not determine contributor count.",
        "nodes": [
            ("action", "KEEP positive partition"),
            ("action", "KEEP negative partition"),
            ("action", "KEEP activeEvents"),
            ("action", "DERIVE net"),
            ("action", "DERIVE gross"),
            ("decision", "collapse signed partitions to net?", "NO - loses two-sided activity"),
            ("decision", "derive activeEvents from quantities?", "NO - not determined"),
            ("decision", "add generic report summary abstraction?", "NO - no shared invariant earned"),
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
            ("LOAM G2.023 - Transactions RowActivity derived summaries",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.023 Transactions RowActivity summaries")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Transactions RowActivity summary audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing Transactions RowActivity summary source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
