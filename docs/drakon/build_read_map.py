#!/usr/bin/env python3
"""Build the LOAM read-path DRAKON atlas.

This atlas is deliberately separate from ``loam-system-map.drn`` while the
read-side visual vocabulary is still being audited. It reuses the stable DRAKON
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
        "description": "Read-side atlas: compare how production answers are derived without introducing report authority.",
        "sources": "Loam/ActualReview.lean; Loam/BalanceReview.lean; Loam/RoleBalanceReview.lean; Loam/StockFlowReview.lean; Loam/TransactionsFlowReview.lean; Loam/BudgetWindowReview.lean; Loam/CurrentCoverageReview.lean; Loam/CycleBudgetReview.lean",
        "audit": "Read answers should expose dependency shape, refusal boundaries, repeated evidence selection, and accidental mixing of local and query-global work. Current Coverage remains the first detailed path because it composes Capacity, Actual, Scheduled, routing, and AccountingRole evidence.",
        "nodes": [
            ("action", "ACTUAL REVIEW\ncorrection-aware current records"),
            ("action", "BALANCE / ROLE BALANCE\nquantity support + role evidence"),
            ("action", "STOCK-FLOW / TRANSACTIONS FLOW\ncompose admitted read answers"),
            ("action", "BUDGET WINDOW\nhistorical bounded projection"),
            ("action", "CURRENT COVERAGE\nCapacity + Actual + Scheduled"),
            ("action", "CYCLE BUDGET\nindependent visible read failures"),
            ("action", "AUDIT TARGET\nseparate production lanes from compatibility lanes"),
        ],
    },
    "07.7.1 Current Coverage Read Boundary": {
        "description": "Production CurrentCoverageReview.loadSnapshotAt after the Scheduled-pressure single-partition refactor.",
        "sources": "Loam/CurrentCoverageReview.lean; Loam/Application/CurrentCoverageInspection.lean; Loam/Application/ScheduledCommitmentInspection.lean; Loam/ActualAuthority.lean; Loam/CapacityAuthority.lean; Loam/Persistence/ActualRoutingPersistence.lean; Loam/Persistence/ScheduledLifecyclePersistence.lean; Loam/Persistence/ScheduledRoutingPersistence.lean; Loam/Persistence/AccountingRolePersistence.lean",
        "audit": "Scheduled lifecycle selection and routing/role classification now happen once per snapshot. Query-global frontiers and actionable rows are projected once from that partition; Purpose rows read only managed Commitment from the shared partition. No per-Purpose frontier copies or consistency repair remain.",
        "nodes": [
            ("decision", "Current window coordinates are valid and ordered?", "Refuse\ninvalid current coverage coordinates"),
            ("insertion", "Load CapacityAuthority\nmovements + effective evidence"),
            ("decision", "Capacity effective evidence complete?", "Refuse\nincomplete Capacity evidence"),
            ("insertion", "Load authoritative ActualEvidence\nand admit validity frontier"),
            ("decision", "One current date per Event justified?", "Refuse\ninvalid Actual validity frontier"),
            ("insertion", "Load Actual routing + Scheduled lifecycle\n+ Scheduled routing + AccountingRole"),
            ("decision", "All required read authorities decode?", "Refuse\nmalformed or unsupported evidence"),
            ("insertion", "currentScheduledPressurePartition?\nselect + classify Scheduled ONCE"),
            ("decision", "One current-open Scheduled partition justified?", "Refuse\nScheduled pressure not justified"),
            ("action", "Project query-global answers ONCE\nfrontier + actionable rows"),
            ("action", "Recover remembered Purposes\nfrom Capacity memory"),
            ("insertion", "For each Purpose: managedFor pressure\n+ Capacity/Actual projection"),
            ("decision", "Every Purpose projection succeeds?", "Refuse\ncoverage not justified for one Purpose"),
            ("action", "Return Snapshot\nrows + one frontier + actionable rows"),
        ],
    },
    "07.7.2 Per-Purpose Coverage Projection": {
        "description": "One CurrentCoverageReview.projectPurpose? call after Scheduled partitioning has already completed.",
        "sources": "Loam/CurrentCoverageReview.lean; Loam/Application/CurrentCoverageInspection.lean; Loam/Application/CapacityWindowInspection.lean; Loam/Application/ConsumptionInspection.lean; Loam/Application/ScheduledCommitmentInspection.lean",
        "audit": "The Purpose-local projection now receives only one managed Commitment derived from the shared Scheduled partition. Entitlement, Consumption, and managed Commitment are independent inputs; Remaining and Headroom are derived accessors. No query-global Scheduled frontier is carried through this lane.",
        "nodes": [
            ("action", "Select one Purpose + JPY\ninside explicit current elapsed window"),
            ("insertion", "managedFor shared Scheduled partition\nPurpose-local Commitment only"),
            ("insertion", "Consumption\ncorrection frontier + historical Actual routing"),
            ("decision", "Consumption justified?", "No per-Purpose projection"),
            ("insertion", "Entitlement\neffective Capacity through observedAt"),
            ("decision", "Entitlement justified?", "No per-Purpose projection"),
            ("action", "Assemble CurrentCoverageView\nentitlement + consumption + commitment"),
            ("action", "Derive Remaining / Headroom on read\nnever retain them"),
            ("action", "Return Row\nPurpose-local quantities only"),
        ],
    },
    "07.7.3 Scheduled Pressure Partition": {
        "description": "One current-open Scheduled selection and classification feeding all pressure projections.",
        "sources": "Loam/Application/ScheduledCommitmentInspection.lean; Loam/Application/ScheduledInspection.lean; Loam/Core/ScheduledRouting.lean; Loam/Core/AccountingRole.lean",
        "audit": "Selected Scheduled coordinates and pressure classes are query-global for a fixed Measure and horizon. Purpose affects only managedFor. Aggregate unresolved eligibility is derived from unresolved rows, and actionable rows share the same classified partition rather than re-running selection or classification.",
        "nodes": [
            ("insertion", "Resolve currentOpenScheduled\ncurrent lifecycle only"),
            ("decision", "One current-open Scheduled set justified?", "No pressure partition"),
            ("action", "Enumerate selected positive coordinates\nMeasure + horizon + Locus aggregation"),
            ("insertion", "classifyScheduledPressure ONCE\nrouting status then AccountingRole fallback"),
            ("action", "ScheduledPressurePartition\none classified row per selected coordinate"),
            ("action", "managedFor Purpose\nonly Purpose-dependent projection"),
            ("action", "unmanaged / unrouted\nquery-global aggregates"),
            ("action", "unresolvedRows\ncanonical unresolved subjects"),
            ("action", "unresolvedEligibility\nSUM of unresolvedRows"),
            ("action", "actionableRows\nunrouted + unresolved subjects"),
            ("action", "Lean laws\nrow sums = aggregate frontiers"),
        ],
    },
    "07.7.4 Current Coverage Compatibility Entrances": {
        "description": "The remaining ordinary-routing compatibility entrance that accepts raw Scheduled evidence for one Purpose.",
        "sources": "Loam/Application/CurrentCoverageInspection.lean; Loam/Tests/CurrentCoverageInspection.lean; Loam/Tests/CounterpointFiveWorlds.lean; Loam/Tests/FourVoiceCompatibilityV1.lean; Loam/Tests/FourVoiceCompatibilityV2.lean; Loam/Tests/FourVoiceCompatibilityV3.lean",
        "audit": "Production CurrentCoverageReview uses the narrower EffectiveRouting WithCommitment boundary after Scheduled pressure is partitioned once. The raw-Scheduled EffectiveRouting shell had no current caller and is retired. The ordinary currentCoverageAtCorrectionFrontier? entrance remains exercised by compatibility, counterpoint, and regression stories; its visibility here does not by itself imply another subtraction.",
        "nodes": [
            ("action", "Compatibility caller asks ONE Purpose\nwith ordinary-time Actual routing"),
            ("action", "Caller supplies raw Scheduled evidence\nfor the compatibility story"),
            ("insertion", "currentScheduledCommitment?\nresolve + select + classify for this call"),
            ("decision", "Scheduled Commitment justified?", "No compatibility answer"),
            ("action", "Take commitment.managed\ndiscard global frontiers here"),
            ("insertion", "WithCommitment helper\nCapacity + Actual + managed Commitment"),
            ("decision", "Capacity / Actual projection justified?", "No compatibility answer"),
            ("action", "Return CurrentCoverageView\nPurpose-local answer"),
            ("action", "CURRENT STATUS\nexercised compatibility / regression contract"),
        ],
    },
    "07.7.5 Headroom Compatibility Composition": {
        "description": "Legacy all-current Remaining plus current-open Scheduled Headroom composition after derived-field compression.",
        "sources": "Loam/Application/ScheduledCommitmentInspection.lean; Loam/Application/ConsumptionInspection.lean; Loam/Tests/ScheduledCommitmentHeadroom.lean; Loam/Tests/ScheduledReplacementReaders.lean",
        "audit": "This boundary uses a different coordinate composition from windowed Current Coverage, so it remains semantically distinct. HeadroomView now retains only independent Remaining plus ScheduledCommitmentView; commitment, headroom, and global pressure aliases are derived and cannot contradict their components.",
        "nodes": [
            ("insertion", "remainingAtCorrectionFrontier?\nall-current Actual Remaining"),
            ("decision", "Remaining justified?", "No Headroom answer"),
            ("insertion", "currentScheduledCommitment?\ncurrent-open future pressure"),
            ("decision", "Scheduled pressure justified?", "No Headroom answer"),
            ("action", "Retain HeadroomView\nremaining + ScheduledCommitmentView"),
            ("action", "Derive commitment\nfrom scheduled.managed"),
            ("action", "Derive headroom\nremaining - commitment"),
            ("action", "Derive global pressure aliases\nfrom retained Scheduled answer"),
        ],
    },
    "07.8.1 Cycle Budget Read Boundary": {
        "description": "CycleBudgetReview.loadSnapshotAt composition after the one-Actual-observation refactor.",
        "sources": "Loam/CycleBudgetReview.lean; Loam/ActualAuthority.lean; Loam/Tui/CycleBudget.lean; Loam/BoundaryPresetConfig.lean; Loam/CurrentCoverageReview.lean; Loam/BalanceReview.lean; Loam/CycleFundingConfig.lean; Loam/CycleFundingInspection.lean",
        "audit": "Window, coverage, physical balances, funding selection, and funding summary remain separately visible failure boundaries in the TUI. CurrentCoverage and Balance evidence reads now share one short Actual ownership interval, pinning one normalized Actual generation across both branches without adding a second evidence API. Balance evidence remains shared by physical and funding. Other authorities keep their existing independent reads and failure semantics; no cross-authority atomic snapshot is claimed.",
        "nodes": [
            ("insertion", "loadCurrentWindow\nBoundaryPresetConfig"),
            ("action", "Retain window Except\nvisible boundary status"),
            ("insertion", "Enter Actual observation interval\nlock selected actual.loam"),
            ("insertion", "Coverage attempt\nwindow -> CurrentCoverageReview.loadSnapshotAt"),
            ("action", "Retain coverage Except\nCurrentCoverage visible independently"),
            ("insertion", "BalanceReview.loadEvidence ONCE\nsame Actual interval + zero-origin coverage"),
            ("action", "Leave Actual observation interval\nwriter may proceed"),
            ("action", "Share loaded balance evidence\nphysical + funding branches"),
            ("insertion", "Physical attempt\nbalance-view selection -> BalanceReview.project"),
            ("action", "Retain physical Except\noptional display balances"),
            ("insertion", "CycleFundingConfig.load\nexplicit backing selection"),
            ("action", "Retain selection Except\noptional funding configuration"),
            ("insertion", "CycleFundingInspection.project\ncoverage + selection + shared balance evidence"),
            ("action", "Retain funding Except\nfunding arithmetic answer"),
            ("action", "Return Snapshot\nall failure boundaries stay visible"),
        ],
    },
    "07.8.2 Cycle Funding Composition": {
        "description": "Pure CycleFundingInspection.project composition after derived-summary compression.",
        "sources": "Loam/CycleFundingInspection.lean; Loam/CycleBudgetReview.lean; Loam/CurrentCoverageReview.lean; Loam/BalanceReview.lean; Loam/Tui/CycleBudget.lean",
        "audit": "Summary retains only budgetable backing and remaining assigned. JPY is fixed by admission and residualBeforeUnresolved is derived from the retained pair. CurrentCoverage keeps ownership of the three query-global Scheduled frontier quantities; CycleBudget reads them from the sibling coverage snapshot instead of a funding copy. Parent CycleBudget composition now pins the CurrentCoverage and Balance Actual reads to one normalized Actual generation before this pure funding projection runs.",
        "nodes": [
            ("action", "Inputs\nBalance evidence + selection + CurrentCoverage"),
            ("decision", "JPY / selection / Purpose uniqueness valid?", "No funding answer"),
            ("insertion", "Require CurrentCoverage.scheduledFrontier", "No funding answer\nfrontier unavailable"),
            ("insertion", "BalanceReview.project\nselected budgetable coordinates"),
            ("action", "Fold budgetableBacking\nselected signed balances"),
            ("action", "Fold remainingAssigned\nsum max(row.remaining, 0)"),
            ("action", "Retain Summary\nbacking + assigned only"),
            ("action", "Derive residualBeforeUnresolved\nbacking - assigned"),
            ("action", "Read future pressure beside Summary\nfrom CurrentCoverage frontier"),
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
            ("LOAM Read Path Atlas v0.5 - Current Coverage and Cycle Budget",),
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
            "07.7.4 Current Coverage Compatibility Entrances",
            "07.7.5 Headroom Compatibility Composition",
        ]:
            node_id = base.add_tree_node(
                db, node_id, current_coverage, "item", diagram_id=diagram_ids[name]
            )

        cycle_budget = node_id
        node_id = base.add_tree_node(
            db, node_id, root, "folder", "07.8 Cycle Budget"
        )
        for name in [
            "07.8.1 Cycle Budget Read Boundary",
            "07.8.2 Cycle Funding Composition",
        ]:
            node_id = base.add_tree_node(
                db, node_id, cycle_budget, "item", diagram_id=diagram_ids[name]
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
        if db.execute(
            "select count(*) from tree_nodes where type='folder' and name='07.8 Cycle Budget'"
        ).fetchone()[0] != 1:
            raise SystemExit("Cycle Budget read-path folder missing")

    print(OUTPUT)


if __name__ == "__main__":
    build()
