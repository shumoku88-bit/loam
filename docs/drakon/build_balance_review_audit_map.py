#!/usr/bin/env python3
"""Build the Generation-2 Balance Review DRAKON audit map.

This map is an audit instrument only. It visualizes the production BalanceReview
path and the obligation topology exposed by the G2-002/G2-003 audit. It is not
production authority and is not a code-generation source.
"""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-balance-review-audit.drn"

DIAGRAMS = {
    "G2.002.1 Balance Review Read Boundary": {
        "description": "G2-002 production BalanceReview load/project path before shared-basis qualification.",
        "sources": "Loam/BalanceReview.lean; Loam/ActualAuthority.lean; Loam/Application/ZeroOriginQuantity.lean; Loam/Application/QuantityInspection.lean; Loam/Application/CorrectionFrontier.lean; Loam/Persistence/ZeroOriginCoveragePersistence.lean; Loam/BalanceViewConfig.lean",
        "audit": "At the G2-002 baseline, Actual and zero-origin evidence were loaded once, but correction-world admission was reached from inside the per-coordinate row loop. The map separated coordinate-local coverage from query-global correction topology.",
        "nodes": [
            ("insertion", "Load normalized Actual evidence ONCE\nevents + corrections"),
            ("decision", "Actual authority decodes?", "Refuse\nActual evidence unavailable"),
            ("insertion", "Load zero-origin coverage ONCE\nmissing file => explicit empty evidence"),
            ("decision", "Coverage file valid if present?", "Refuse\nmalformed zero-origin evidence"),
            ("insertion", "Load balance-view coordinates"),
            ("decision", "View config decodes?", "Refuse\nmalformed balance-view config"),
            ("action", "eraseDups\npresentation normalization"),
            ("action", "For each selected coordinate\nleft-to-right"),
            ("insertion", "inspectZeroOriginQuantity\ncoverage gate + quantity inspection"),
            ("decision", "Current quantity returned?", "Refuse\ncoverage / correction diagnostic"),
            ("action", "Append Row\ncoordinate + quantity"),
            ("action", "Return Snapshot\nrows only"),
        ],
    },
    "G2.002.2 One Coordinate Quantity Obligation": {
        "description": "One G2-002 BalanceReview row obligation through zero-origin and correction-aware quantity inspection.",
        "sources": "Loam/Application/ZeroOriginQuantity.lean; Loam/Application/QuantityInspection.lean; Loam/Application/CorrectionFrontier.lean",
        "audit": "Zero-origin is coordinate-local. Correction references and frontier shape depend only on the shared Event/correction world, not on the selected coordinate. Quantity projection is coordinate-local only after that world is resolved.",
        "nodes": [
            ("decision", "Zero-origin covers coordinate?", "Refuse\ncoverageMissing"),
            ("decision", "Any correction facts?", "Use recorded EventMemory directly"),
            ("decision", "Correction references closed?", "Refuse\nmissingEventCorrectionEndpoint"),
            ("insertion", "correctionFrontierMemory?\nsource/successor unique + closed + acyclic"),
            ("decision", "One Event frontier admitted?", "Refuse\neventFrontierRequired"),
            ("action", "quantityAtRecorded\non chosen EventMemory"),
            ("action", "Return current Quantity"),
        ],
    },
    "G2.002.3 Cross-Row Shared Obligation Pressure": {
        "description": "G2-002 visual comparison of row-local and query-global work inside BalanceReview.project.",
        "sources": "Loam/BalanceReview.lean; Loam/Application/ZeroOriginQuantity.lean; Loam/Application/QuantityInspection.lean",
        "audit": "At the G2-002 baseline, each row had its own zero-origin gate and quantity coordinate while every covered row evaluated the same correction-world admission. The DAG therefore exposed one shared correction-world node and a refusal-order constraint on any future sharing.",
        "nodes": [
            ("action", "ROW A\nzero-origin(A)"),
            ("insertion", "correction world\nevents + corrections"),
            ("action", "quantity(A)"),
            ("action", "ROW B\nzero-origin(B)"),
            ("insertion", "SAME correction world\nre-evaluated at G2.002 baseline"),
            ("action", "quantity(B)"),
            ("action", "ROW C ...\nrepeat same global obligation"),
            ("action", "DAG PRESSURE\none shared correction-world node\nfan-out to covered rows"),
            ("action", "CAUTION\ndo not resolve before first row coverage\nif refusal ordering is to remain unchanged"),
        ],
    },
    "G2.003 Qualified Shared Quantity Basis": {
        "description": "Qualified production shape after sharing one correction-aware Event basis across Balance Review rows.",
        "sources": "Loam/BalanceReview.lean; Loam/Tests/BalanceReview.lean; Loam/Application/CorrectionFrontier.lean; docs/research/BALANCE_REVIEW_OBLIGATION_DAG.md",
        "audit": "An uncovered row terminates the whole projection immediately, so a non-empty answer needs only the first coordinate coverage gate before the query-global correction world may be resolved once. After that admission, later coordinates keep their left-to-right coverage gates while all quantities read the same admitted Event basis. Empty selection never forces correction admission.",
        "nodes": [
            ("action", "eraseDups\nselected coordinates"),
            ("decision", "Any selected coordinate?", "Return empty Snapshot\nno correction obligation"),
            ("decision", "FIRST coordinate covered?", "Refuse FIRST\nzero-origin diagnostic"),
            ("insertion", "quantityBasis ONCE\nno corrections => original EventMemory\notherwise closure + correction frontier"),
            ("decision", "Shared quantity basis admitted?", "Refuse\ncorrection diagnostic"),
            ("action", "Project FIRST row\nquantityAtRecorded(shared basis)"),
            ("action", "For each remaining coordinate\nleft-to-right"),
            ("decision", "Coordinate covered?", "Refuse\nzero-origin diagnostic"),
            ("action", "Project quantity\nfrom SAME shared basis"),
            ("action", "Return Snapshot\nno public context / Evidence API added"),
            ("action", "QUALIFICATION\nvalid multi-row correction + empty selection\n+ both refusal-order cases pinned"),
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
                ("language", "SPARK"),
            ],
        )
        db.execute(
            "insert into state values (1,1,?)",
            ("LOAM G2.002/G2.003 - Balance Review obligation topology",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(
                db, item_id, diagram_ids[name], name, spec
            )

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2 Balance Review")
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
            raise SystemExit("Balance Review audit diagram count mismatch")
        if db.execute(
            "select count(*) from diagram_info where name='sources'"
        ).fetchone()[0] != len(names):
            raise SystemExit("missing Balance Review source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
