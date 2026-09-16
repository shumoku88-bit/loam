#!/usr/bin/env python3
"""Build the Generation-2 Conditional Liquidity summary audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-conditional-liquidity-summary-audit.drn"

DIAGRAMS = {
    "G2.022.1 Conditional Liquidity Result": {
        "description": "Separate retained conditional-path state from exact derived summary values.",
        "sources": "Loam/ConditionalBalancePathReview.lean; Loam/Tui/Reports.lean; Loam/Tests/ConditionalBalancePathReview.lean",
        "audit": "The conditional answer retains asOf, assumption horizon, measure, current selected balance and dated cumulative points. finalAtHorizon and lowWater add no independent evidence and are derived from currentSelected plus points.",
        "nodes": [
            ("action", "BalanceReview selected current quantities"),
            ("action", "ScheduledReview current-open evidence"),
            ("action", "G2-007: observe both under one Actual generation"),
            ("action", "net selected Scheduled changes by day"),
            ("action", "build chronological cumulative points"),
            ("action", "retain currentSelected + points"),
            ("decision", "retain finalAtHorizon separately?", "NO - exact consequence"),
            ("action", "derive finalAtHorizon from last point or current baseline"),
            ("decision", "retain lowWater separately?", "NO - exact consequence"),
            ("action", "derive lowWater from current baseline and point balances"),
        ],
    },
    "G2.022.2 Empty Path and Consistency": {
        "description": "Show why derived summaries remove contradictory result states while preserving the empty-path identity.",
        "sources": "Loam/ConditionalBalancePathReview.lean; Loam/Tests/ConditionalBalancePathReview.lean; Loam/Tests/TuiReports.lean",
        "audit": "With no points both summaries equal currentSelected by construction. With points, the final summary is the last cumulative balance and low-water is the minimum over the same path. Callers can no longer provide mutually inconsistent copies.",
        "nodes": [
            ("action", "currentSelected"),
            ("decision", "points empty?", "YES"),
            ("action", "finalAtHorizon = currentSelected"),
            ("action", "lowWater = currentSelected"),
            ("decision", "points present?", "YES"),
            ("action", "finalAtHorizon = final point.balance"),
            ("action", "lowWater = min(currentSelected, point balances)"),
            ("action", "no contradictory summary fields remain"),
        ],
    },
    "G2.022.3 Stop Point": {
        "description": "Record the exact simplification boundary and the distinctions intentionally retained.",
        "sources": "Loam/ConditionalBalancePathReview.lean; docs/research/LIQUIDITY_BUDGET_OBLIGATION_DAG.md; Loam/Tui/Reports.lean",
        "audit": "G2-022 removes only duplicated summary state. It does not alter G2-007 temporal consistency, the conditional epistemic label, overdue refusal, assumption semantics, Point.balance, or create a generic report-summary layer.",
        "nodes": [
            ("action", "KEEP asOf / horizon / measure"),
            ("action", "KEEP currentSelected"),
            ("action", "KEEP dated cumulative points"),
            ("action", "DERIVE finalAtHorizon"),
            ("action", "DERIVE lowWater"),
            ("decision", "remove Point.balance too?", "NO - visible point-level result"),
            ("decision", "generalize report summaries?", "NO - no shared invariant earned"),
            ("action", "KEEP G2-007 same-Actual-generation boundary"),
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
            ("LOAM G2.022 - Conditional Liquidity derived summaries",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.022 Conditional Liquidity summaries")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Conditional Liquidity summary audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing Conditional Liquidity summary source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
