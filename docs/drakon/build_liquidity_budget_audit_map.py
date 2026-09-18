#!/usr/bin/env python3
"""Build the Generation-2 conditional-liquidity / Budget Window audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-liquidity-budget-audit.drn"

DIAGRAMS = {
    "G2.007.1 Liquidity / Budget Window Comparison": {
        "description": "Conditional Liquidity and Budget Window at one semantic scale.",
        "sources": "Loam/ConditionalBalancePathReview.lean; Loam/BudgetWindowReview.lean; Loam/BalanceReview.lean; Loam/ScheduledReview.lean; Loam/Application/CapacityWindowInspection.lean",
        "audit": "Conditional Liquidity composes two Actual-backed readers and therefore needs one Actual generation across both reads. Budget Window now consumes one admitted ActualAuthority.Image and fans its carried current Event/validity views directly into Purpose-local arithmetic. Similar report surfaces expose different obligation pressure.",
        "nodes": [
            ("action", "CONDITIONAL LIQUIDITY"),
            ("insertion", "one Actual ownership interval"),
            ("insertion", "BalanceReview current selected balances"),
            ("insertion", "ScheduledReview lifecycle + Actual Event identities"),
            ("action", "conditional day-boundary path"),
            ("action", "BUDGET WINDOW"),
            ("insertion", "one loaded Evidence image\nCapacity + admitted Actual + Routing"),
            ("action", "remembered Purposes"),
            ("decision", "any Purpose?", "return empty Snapshot"),
            ("insertion", "reuse carried currentEvents + currentValidities"),
            ("action", "Purpose-local Entitlement + Consumption"),
        ],
    },
    "G2.007.2 Liquidity Same-Generation Obligation": {
        "description": "Temporal obligation joining selected balances and Scheduled terminal admission.",
        "sources": "Loam/ConditionalBalancePathReview.lean; Loam/BalanceReview.lean; Loam/ScheduledReview.lean; Loam/ActualAuthority.lean",
        "audit": "BalanceReview reads Actual for current correction-aware quantities. ScheduledReview independently reads Actual Event identities while admitting completion/retirement/replacement evidence. One conditional answer must not combine those two reads across an Actual publication boundary. Existing Actual file ownership supplies the smallest repair.",
        "nodes": [
            ("insertion", "resolve selected actual.loam path"),
            ("insertion", "withActualFileOwnership"),
            ("insertion", "BalanceReview.loadSnapshot"),
            ("insertion", "ScheduledReview.loadHouseholdEvidence"),
            ("action", "both reads observe one published Actual generation"),
            ("action", "release ownership"),
            ("action", "pure ConditionalBalancePathReview.project"),
        ],
    },
    "G2.007.3 Budget Window Shared Frontier": {
        "description": "Reuse the admitted Actual read image across Purpose-local window arithmetic.",
        "sources": "Loam/BudgetWindowReview.lean; Loam/ActualAuthority.lean; Loam/Application/CapacityWindowInspection.lean; Loam/Application/ConsumptionInspection.lean",
        "audit": "Normalized Actual loading already carries the correction-aware current Event memory and current validity memory. Budget Window therefore no longer performs report-local Correction or ActualValidity admission. Purpose arithmetic remains local and is not replaced by a new aggregation engine.",
        "nodes": [
            ("insertion", "load immutable Budget Window Evidence"),
            ("insertion", "ActualAuthority.Image\ncurrentEvents + currentValidities"),
            ("action", "remembered Purposes"),
            ("decision", "Purpose list empty?", "return empty Snapshot"),
            ("action", "Purpose rows left-to-right"),
            ("decision", "Purpose Entitlement admitted?", "refuse projection"),
            ("insertion", "Consumption from carried Actual views"),
            ("decision", "Purpose Consumption admitted?", "refuse projection"),
            ("action", "return Snapshot"),
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
            ("LOAM G2.007 - Liquidity / Budget Window obligation topology",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(
                db, item_id, diagram_ids[name], name, spec
            )

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.007 Liquidity / Budget")
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
            raise SystemExit("Liquidity/Budget audit diagram count mismatch")
        if db.execute(
            "select count(*) from diagram_info where name='sources'"
        ).fetchone()[0] != len(names):
            raise SystemExit("missing Liquidity/Budget source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
