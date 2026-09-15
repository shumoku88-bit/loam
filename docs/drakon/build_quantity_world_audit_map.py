#!/usr/bin/env python3
"""Build the Generation-2 quantity-world sharing audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-quantity-world-sharing-audit.drn"

DIAGRAMS = {
    "G2.006.1 Two Earned Quantity Worlds": {
        "description": "Ordinary current frontier and current-anchor cut world at one semantic scale.",
        "sources": "Loam/RoleBalanceReview.lean; Loam/BalanceReview.lean; Loam/CurrentQuantityAnchor.lean; Loam/Application/CorrectionFrontier.lean",
        "audit": "Role Balance contains two earned quantity worlds. Zero-origin and opening support use the ordinary current correction frontier. Current-anchor support starts from an asserted reconciliation image that already reflects selected stable roots, so it must use a delta frontier excluding those roots. The worlds must not be merged.",
        "nodes": [
            ("insertion", "Event + Correction evidence"),
            ("insertion", "ordinary current correction frontier"),
            ("action", "zero-origin support"),
            ("action", "opening support"),
            ("insertion", "CurrentQuantityAnchor Evidence\nasserted quantities + reflectedRoots"),
            ("insertion", "anchor delta frontier\nexclude reflected roots"),
            ("action", "current-anchor support"),
            ("action", "KEEP worlds separate\ndifferent quantity meaning"),
        ],
    },
    "G2.006.2 Ordinary Frontier Ownership": {
        "description": "Share the ordinary frontier only where semantic ownership permits it.",
        "sources": "Loam/RoleBalanceReview.lean; Loam/BalanceReview.lean; Loam/Application/CorrectionFrontier.lean",
        "audit": "RoleBalance already admits one ordinary correction frontier before validating opening witnesses and routing support. Opening rows are RoleBalance-owned and can project directly from that frontier. Zero-origin rows remain delegated to BalanceReview, which independently admits its own basis. That extra boundary is retained because BalanceReview owns zero-origin projection semantics; bypassing it would duplicate a semantic owner merely to remove one admission.",
        "nodes": [
            ("insertion", "RoleBalance admits ordinary frontier ONCE"),
            ("action", "opening rows\nquantityAtRecorded on SAME frontier"),
            ("insertion", "zero-origin bucket"),
            ("insertion", "BalanceReview.project"),
            ("action", "BalanceReview owns zero-origin basis + refusal semantics"),
            ("action", "KEEP one boundary re-admission"),
        ],
    },
    "G2.006.3 Shared Anchor Cut": {
        "description": "One reflected-root cut is shared by every selected assertion from one reconciliation image.",
        "sources": "Loam/CurrentQuantityAnchor.lean; Loam/RoleBalanceReview.lean; Loam/Application/CorrectionFrontier.lean",
        "audit": "CurrentQuantityAnchor Evidence represents one reconciliation image, so its reflectedRoots are query-global across selected assertions. G2-006 adds inspectQuantities: requested assertions are identified first, one delta frontier is admitted only when at least one assertion is present, and every selected quantity projects from that same frontier. Point inspection keeps its previous absence behavior through the same private deltaFrontier helper.",
        "nodes": [
            ("insertion", "selected anchor coordinates"),
            ("action", "lookup assertions\nmissing stays none"),
            ("decision", "any asserted coordinate?", "Return all none\ndo not force correction world"),
            ("insertion", "validate reflected roots ONCE"),
            ("insertion", "derive one delta frontier ONCE"),
            ("action", "project all selected assertions\nfrom SAME delta frontier"),
            ("action", "RoleBalance anchor rows"),
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
            ("LOAM G2.006 - Quantity world sharing",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(
                db, item_id, diagram_ids[name], name, spec
            )

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.006 Quantity Worlds")
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
            raise SystemExit("Quantity-world audit diagram count mismatch")
        if db.execute(
            "select count(*) from diagram_info where name='sources'"
        ).fetchone()[0] != len(names):
            raise SystemExit("missing quantity-world source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
