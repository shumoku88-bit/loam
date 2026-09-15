#!/usr/bin/env python3
"""Build the Generation-2 Stock/Transactions Flow audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-flow-review-audit.drn"

DIAGRAMS = {
    "G2.004.1 Flow Review Sibling Comparison": {
        "description": "StockFlowReview and TransactionsFlowReview at one semantic scale.",
        "sources": "Loam/StockFlowReview.lean; Loam/TransactionsFlowReview.lean; Loam/ActualReview.lean; Loam/BalanceReview.lean",
        "audit": "Transactions Flow observes one ActualReview answer. Stock Flow composes BalanceReview and ActualReview, so both Actual-backed answers must belong to one Actual generation. Similar date/window shapes do not imply identical admissibility scope.",
        "nodes": [
            ("action", "TRANSACTIONS FLOW"),
            ("insertion", "ActualReview.loadRecordsFromActual\nONE Actual read"),
            ("decision", "all current quantity Events dated?", "Refuse Transactions-Flow"),
            ("action", "select half-open window\nsort Event columns"),
            ("action", "derive rows/cells/activity"),
            ("action", "STOCK FLOW"),
            ("insertion", "Enter ONE Actual observation interval"),
            ("insertion", "BalanceReview.loadSnapshot\nActual-backed balances"),
            ("insertion", "ActualReview.loadRecordsFromActual\nActual-backed records"),
            ("decision", "selected contributing current Events dated?", "Refuse Stock-Flow"),
            ("action", "reconstruct start/end + signed changes"),
            ("decision", "start + net = end?", "Refuse parity failure"),
        ],
    },
    "G2.004.2 Stock Flow Same-Generation Obligation": {
        "description": "Temporal obligation joining Stock Flow balances and Actual records.",
        "sources": "Loam/StockFlowReview.lean; Loam/BalanceReview.lean; Loam/ActualReview.lean; Loam/ActualAuthority.lean; Loam/WriterOwnership.lean",
        "audit": "The Stock-Flow answer relates current selected balances to historical boundaries reconstructed from Actual records. The two projections may decode separately, but writer publication must not switch actual.loam between them. One short ownership interval provides that obligation without a new Evidence API.",
        "nodes": [
            ("insertion", "Lock selected actual.loam\nwithActualFileOwnership"),
            ("insertion", "Read BalanceReview\nselected current balances"),
            ("insertion", "Read ActualReview\ncorrection-aware dated records"),
            ("action", "Both reads observe same published generation"),
            ("action", "Release Actual ownership"),
            ("action", "Pure StockFlowReview.project"),
        ],
    },
    "G2.004.3 Date Admissibility Scope": {
        "description": "Why the sibling date validators should remain distinct.",
        "sources": "Loam/StockFlowReview.lean; Loam/TransactionsFlowReview.lean",
        "audit": "Stock Flow only requires dates for current Events whose net contribution to selected balance coordinates is nonzero. Transactions Flow requires dates for every current quantity-bearing Event because any such Event may become a column. A generic shared validator would erase this semantic distinction or need policy parameters larger than the duplication it removes.",
        "nodes": [
            ("action", "Stock Flow record"),
            ("decision", "current?", "ignore"),
            ("decision", "nonzero on selected coordinates?", "ignore"),
            ("decision", "usable date?", "refuse Stock-Flow"),
            ("action", "Transactions Flow record"),
            ("decision", "current + effects nonempty?", "ignore"),
            ("decision", "usable date?", "refuse Transactions-Flow"),
            ("action", "KEEP separate validators\ndifferent proof domains"),
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
            ("LOAM G2.004 - Flow review obligation topology",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(
                db, item_id, diagram_ids[name], name, spec
            )

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.004 Flow Reviews")
        for name in names:
            node_id = base.add_tree_node(
                db, node_id, root, "item", diagram_id=diagram_ids[name]
            )

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Flow Review audit diagram count mismatch")
        if db.execute(
            "select count(*) from diagram_info where name='sources'"
        ).fetchone()[0] != len(names):
            raise SystemExit("missing Flow Review source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
