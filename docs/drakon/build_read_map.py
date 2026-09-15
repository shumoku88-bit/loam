#!/usr/bin/env python3
"""Build the first LOAM read-path DRAKON atlas.

This atlas is deliberately separate from ``loam-system-map.drn`` while the
read-side visual vocabulary is still being audited.  It reuses the stable DRAKON
SQLite helpers from ``build_map.py`` but does not change production code or make
this diagram a semantic authority.
"""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-read-path-map.drn"

READ_FLOW_DIAGRAMS = {
    "07.0 Read Path Comparison": {
        "description": "First read-side atlas: compare how production answers are derived without introducing report authority.",
        "sources": "Loam/ActualReview.lean; Loam/BalanceReview.lean; Loam/RoleBalanceReview.lean; Loam/StockFlowReview.lean; Loam/TransactionsFlowReview.lean; Loam/BudgetWindowReview.lean; Loam/CurrentCoverageReview.lean; Loam/CycleBudgetReview.lean",
        "audit": "Read answers should expose dependency shape, refusal boundaries, and repeated projection work. This first atlas is intentionally incomplete; Current Coverage is the first detailed path because it composes Capacity, Actual, Scheduled, routing, and AccountingRole evidence.",
        "nodes": [
            ("action", "ACTUAL REVIEW\ncorrection-aware current records"),
            ("action", "BALANCE / ROLE BALANCE\nquantity support + role evidence"),
            ("action", "STOCK-FLOW / TRANSACTIONS FLOW\ncompose admitted read answers"),
            ("action", "BUDGET WINDOW\nhistorical bounded projection"),
            ("action", "CURRENT COVERAGE\nCapacity + Actual + Scheduled"),
            ("action", "CYCLE BUDGET\nindependent visible read failures"),
            ("action", "AUDIT TARGET\nlook for repeated evidence selection and mixed local/global work"),
        ],
    },
    "07.7.1 Current Coverage Read Boundary": {
        "description": "Production CurrentCoverageReview.loadSnapshotAt path from explicit coordinates to one immutable answer.",
        "sources": "Loam/CurrentCoverageReview.lean; Loam/ActualAuthority.lean; Loam/CapacityAuthority.lean; Loam/Persistence/ActualRoutingPersistence.lean; Loam/Persistence/ScheduledLifecyclePersistence.lean; Loam/Persistence/ScheduledRoutingPersistence.lean; Loam/Persistence/AccountingRolePersistence.lean",
        "audit": "The current implementation derives actionable unresolved Scheduled rows once globally, but projectPurpose? also returns the same Scheduled frontier with every Purpose row. The copies are checked by consistentFrontier and only the first is retained. This is an observation, not yet a refactor conclusion.",
        "nodes": [
            ("decision", "Current window coordinates are valid and ordered?", "Refuse\ninvalid current coverage coordinates"),
            ("insertion", "Load CapacityAuthority\nmovements + effective evidence"),
            ("decision", "Capacity effective evidence complete?", "Refuse\nincomplete Capacity evidence"),
            ("insertion", "Load authoritative ActualEvidence\nand admit validity frontier"),
            ("decision", "One current date per Event justified?", "Refuse\ninvalid Actual validity frontier"),
            ("insertion", "Load Actual routing + Scheduled lifecycle\n+ Scheduled routing + AccountingRole"),
            ("decision", "All required read authorities decode?", "Refuse\nmalformed or unsupported evidence"),
            ("insertion", "currentActionableScheduledPressure?\nGLOBAL unresolved Scheduled rows"),
            ("decision", "Actionable Scheduled pressure justified?", "Refuse\nScheduled pressure unresolved structurally"),
            ("action", "Recover remembered Purposes\nfrom Capacity memory"),
            ("insertion", "For each Purpose: projectPurpose?\nrow + Scheduled frontier"),
            ("decision", "Every Purpose projection succeeds?", "Refuse\ncoverage not justified for one Purpose"),
            ("decision", "All per-Purpose frontier copies equal?\nconsistentFrontier", "Refuse\nScheduled frontier changed across Purpose projections"),
            ("action", "Return Snapshot\nrows + first frontier + global unresolved rows"),
        ],
    },
    "07.7.2 Per-Purpose Coverage Projection": {
        "description": "One CurrentCoverageReview.projectPurpose? call and the Application composition beneath it.",
        "sources": "Loam/CurrentCoverageReview.lean; Loam/Application/CurrentCoverageInspection.lean; Loam/Application/CapacityWindowInspection.lean; Loam/Application/ConsumptionInspection.lean; Loam/Application/ScheduledCommitmentInspection.lean",
        "audit": "Entitlement, Consumption, and managed Commitment are Purpose-local. Remaining and Headroom are derived accessors. The returned Scheduled frontier is bundled beside the Purpose row even though its unmanaged, unrouted, and unresolved-eligibility totals do not depend on the queried Purpose.",
        "nodes": [
            ("action", "Select one Purpose + JPY\ninside explicit current window"),
            ("insertion", "Consumption\ncorrection frontier + historical Actual routing"),
            ("decision", "Consumption justified?", "No per-Purpose projection"),
            ("insertion", "Scheduled Commitment\ncurrent-open lifecycle + routing + roles"),
            ("decision", "Scheduled Commitment justified?", "No per-Purpose projection"),
            ("insertion", "Entitlement\neffective Capacity through observedAt"),
            ("decision", "Entitlement justified?", "No per-Purpose projection"),
            ("action", "Assemble CurrentCoverageView\nentitlement + consumption + managed commitment"),
            ("action", "Derive Remaining / Headroom on read\nnever retain them"),
            ("action", "Build Row\nPurpose-local independent quantities"),
            ("action", "Build ScheduledFrontier\nunmanaged + unrouted + unresolved eligibility"),
            ("action", "Return ProjectedRow\nlocal Row + global-shaped frontier"),
        ],
    },
    "07.7.3 Scheduled Pressure Partition": {
        "description": "How one current-open Scheduled selection becomes managed Commitment plus visible pressure frontiers.",
        "sources": "Loam/Application/ScheduledCommitmentInspection.lean; Loam/Application/ScheduledInspection.lean; Loam/Core/ScheduledRouting.lean; Loam/Core/AccountingRole.lean",
        "audit": "Selected Scheduled coordinates and their pressure class are query-global for a fixed Measure and horizon. Only the managed total asks whether routedPurpose equals the queried Purpose. Unmanaged, unroutedPressure, and unresolvedEligibility totals are invariant under the queried Purpose; resolved non-pressure contributes nowhere.",
        "nodes": [
            ("insertion", "Resolve currentOpenScheduled\ncurrent lifecycle only"),
            ("decision", "One current-open Scheduled set justified?", "No Commitment view"),
            ("action", "Enumerate selected positive coordinates\nMeasure + horizon + Locus aggregation"),
            ("insertion", "classifyScheduledPressure\nusing routing status then AccountingRole fallback"),
            ("action", "managed(routedPurpose)\nadd only when routedPurpose = queried Purpose"),
            ("action", "unmanaged\nadd to query-global unmanaged total"),
            ("action", "unroutedPressure\nadd to query-global unrouted total"),
            ("action", "unresolvedEligibility\nadd to query-global unresolved total"),
            ("action", "resolvedNonPressure\ncontributes no pressure"),
            ("action", "Return ScheduledCommitmentView\nmanaged + three visible frontiers"),
            ("action", "Separate actionable-row projection\nreuses the same selection/classification semantics"),
            ("action", "Lean law\nunresolved row sum = aggregate unresolved total"),
        ],
    },
}


def build() -> None:
    if OUTPUT.exists():
        OUTPUT.unlink()

    names = list(READ_FLOW_DIAGRAMS)
    diagram_ids = {name: index for index, name in enumerate(names, 1)}

    with sqlite3.connect(OUTPUT) as db:
        db.executescript(base.SCHEMA)
        db.executemany(
            "insert into info values (?,?)",
            [
                ("type", "drakon"),
                ("version", "2"),
                ("start_version", "1"),
                ("language", "SPARK"),
            ],
        )
        db.execute(
            "insert into state values (1,1,?)",
            ("LOAM Read Path Atlas v0.1 - Current Coverage observation",),
        )

        item_id = 1
        for name, spec in READ_FLOW_DIAGRAMS.items():
            item_id = base.add_flow_diagram(
                db, item_id, diagram_ids[name], name, spec
            )

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "LOAM Read Path Atlas")
        node_id = base.add_tree_node(
            db, node_id, root, "item", diagram_id=diagram_ids["07.0 Read Path Comparison"]
        )

        current_coverage = node_id
        node_id = base.add_tree_node(
            db, node_id, root, "folder", "07.7 Current Coverage"
        )
        for name in [
            "07.7.1 Current Coverage Read Boundary",
            "07.7.2 Per-Purpose Coverage Projection",
            "07.7.3 Scheduled Pressure Partition",
        ]:
            node_id = base.add_tree_node(
                db, node_id, current_coverage, "item", diagram_id=diagram_ids[name]
            )

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("read-path diagram count mismatch")
        if db.execute(
            "select count(*) from diagram_info where name='sources'"
        ).fetchone()[0] != len(names):
            raise SystemExit("missing read-path source traceability metadata")
        if db.execute(
            "select count(*) from tree_nodes where type='folder' and name='07.7 Current Coverage'"
        ).fetchone()[0] != 1:
            raise SystemExit("Current Coverage read-path folder missing")

    print(OUTPUT)


if __name__ == "__main__":
    build()
