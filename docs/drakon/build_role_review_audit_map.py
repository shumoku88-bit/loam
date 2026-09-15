#!/usr/bin/env python3
"""Build the Generation-2 Role Flow / Role Balance audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-role-review-audit.drn"

DIAGRAMS = {
    "G2.005.1 Role Review Sibling Comparison": {
        "description": "RoleFlowReview and RoleBalanceReview at one semantic scale.",
        "sources": "Loam/RoleFlowReview.lean; Loam/RoleBalanceReview.lean; Loam/TransactionsFlowReview.lean; Loam/BalanceReview.lean; Loam/CurrentQuantityAnchor.lean",
        "audit": "Role Flow is a thin AccountingRole overlay on one already-admitted Transactions-Flow answer. Role Balance owns a richer support partition because current quantity support may come from zero-origin, opening, current-anchor, or remain unsupported. Similar role classification does not justify merging the two report boundaries.",
        "nodes": [
            ("action", "ROLE FLOW"),
            ("insertion", "TransactionsFlowReview snapshot"),
            ("insertion", "AccountingRole map"),
            ("action", "classify represented coordinates"),
            ("action", "retain unresolved Effect witnesses"),
            ("action", "ROLE BALANCE"),
            ("insertion", "admit one current correction frontier"),
            ("insertion", "zero-origin + opening + current-anchor support"),
            ("decision", "support families separated?", "Refuse overlap"),
            ("action", "route each candidate ONCE"),
            ("action", "project supported quantities + unsupported frontier"),
            ("insertion", "AccountingRole map"),
            ("action", "classify supported and unsupported coordinates"),
        ],
    },
    "G2.005.2 Support Route DAG Runtime Alignment": {
        "description": "The existing proof-obligation DAG and the qualified runtime partition.",
        "sources": "Loam/RoleBalanceReview.lean",
        "audit": "The production supportRoute already has four proved leaves and one exhaustive root theorem. Before G2-005, project evaluated the same route through four independent filters. routeCandidates now applies supportRoute exactly once per candidate and places the coordinate into one bucket, matching the one-root/four-leaf DAG without adding proof-only state.",
        "nodes": [
            ("decision", "support families overlap?", "Refuse before routing"),
            ("action", "candidate coordinate"),
            ("decision", "supportRoute ONCE"),
            ("action", "zero-origin bucket"),
            ("action", "opening bucket"),
            ("action", "current-anchor bucket"),
            ("action", "unsupported bucket"),
            ("action", "DAG and runtime share one decision boundary"),
        ],
    },
    "G2.005.3 Quantity Basis Fanout": {
        "description": "Remaining quantity-world pressure after support routing is partitioned once.",
        "sources": "Loam/RoleBalanceReview.lean; Loam/BalanceReview.lean; Loam/CurrentQuantityAnchor.lean; Loam/Application/CorrectionFrontier.lean",
        "audit": "G2-005 deliberately does not collapse all supported rows onto one basis. Zero-origin and opening quantities use the ordinary current correction frontier, while current-anchor quantities use an explicit reflected-root cut and therefore a distinct delta frontier. The ordinary frontier is already admitted at the Role Balance root but is re-admitted by downstream helpers; anchor coordinates also recompute one shared cut world per row. This is a G2-006 candidate, not part of the routing refactor.",
        "nodes": [
            ("insertion", "ordinary correction frontier\nalready admitted at RoleBalance root"),
            ("action", "zero-origin rows\nBalanceReview.project"),
            ("action", "opening rows\ninspectQuantity per coordinate"),
            ("insertion", "current-anchor evidence\nshared reflectedRoots"),
            ("insertion", "anchor delta frontier\ndistinct semantic world"),
            ("action", "anchor quantities per coordinate"),
            ("action", "DO NOT merge ordinary + anchor worlds"),
            ("action", "G2-006 candidate:\nshare within each earned world"),
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
            ("LOAM G2.005 - Role review obligation topology",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(
                db, item_id, diagram_ids[name], name, spec
            )

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.005 Role Reviews")
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
            raise SystemExit("Role Review audit diagram count mismatch")
        if db.execute(
            "select count(*) from diagram_info where name='sources'"
        ).fetchone()[0] != len(names):
            raise SystemExit("missing Role Review source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
