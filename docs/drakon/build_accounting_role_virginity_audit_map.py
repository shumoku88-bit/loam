#!/usr/bin/env python3
"""Build the Generation-2 initial AccountingRole virginity audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-accounting-role-virginity-audit.drn"

DIAGRAMS = {
    "G2.015.1 Initial AccountingRole Virginity": {
        "description": "Compare the original first-assignment guards with the retained quantity families that now exist in production.",
        "sources": "Loam/AccountingRolePublisher.lean; Loam/AccountingRoleReview.lean; Loam/CurrentQuantityAnchor.lean; Loam/Tests/CurrentQuantityAnchor.lean",
        "audit": "The first-role publisher intentionally refuses retroactive classification because no AccountingRole history is qualified. Actual and Scheduled were the original retained quantity guards. CurrentQuantityAnchor later added an independent exact-current-quantity family that can mention a Locus absent from both. The virginity predicate must therefore include anchor assertions while keeping one shared pure eligibility decision for review and publication.",
        "nodes": [
            ("action", "admitted unresolved Locus"),
            ("decision", "used by Actual Effects?"),
            ("action", "yes -> refuse retroactive role"),
            ("decision", "used by Scheduled movement?"),
            ("action", "yes -> refuse retroactive role"),
            ("decision", "used by CurrentQuantityAnchor?"),
            ("action", "yes -> refuse retroactive role"),
            ("action", "no retained quantity use -> first role allowed"),
            ("insertion", "eligibleInitialLoci + propose? share same guards"),
        ],
    },
    "G2.015.2 Anchor-only Counterexample": {
        "description": "Show the concrete state that falsifies Actual-plus-Scheduled as a complete virginity test.",
        "sources": "Loam/CurrentQuantityAnchor.lean; Loam/Tests/CurrentQuantityAnchor.lean; Loam/AccountingRolePublisher.lean; Loam/Tests/AccountingRolePublisher.lean",
        "audit": "CurrentQuantityAnchor can retain a coordinate that is absent from the selected Actual Events. The existing anchor test already retains cash/jpy while its Event fixture uses debt only. Therefore an admitted unresolved Locus may be absent from Actual and Scheduled yet already carry retained current quantity evidence. Under the old predicate such a Locus was incorrectly eligible for an initial AccountingRole.",
        "nodes": [
            ("action", "Locus anchor-used admitted"),
            ("action", "AccountingRole unresolved"),
            ("action", "no Actual Effect at anchor-used"),
            ("action", "no Scheduled change at anchor-used"),
            ("insertion", "CurrentQuantityAnchor: anchor-used / jpy = 750"),
            ("decision", "old virginity guards pass?"),
            ("action", "YES"),
            ("action", "old publisher could classify retained quantity later"),
            ("action", "ADD anchor-use refusal"),
        ],
    },
    "G2.015.3 Ownership Closure / Stop Point": {
        "description": "Show the compatible ownership extension needed to make the new anchor guard race-free without adding role history or a new authority abstraction.",
        "sources": "Loam/AccountingRolePublisher.lean; Loam/ScheduledActualOwnership.lean; Loam/CurrentQuantityAnchorPublisher.lean; Loam/Persistence/CurrentQuantityAnchorPersistence.lean",
        "audit": "CurrentQuantityAnchor publication already owns Actual then Anchor. AccountingRole publication already owns Scheduled then Actual then Role. Extending the chain to Scheduled -> Actual -> Anchor -> Role preserves both relative orders and closes the read/check/write race. Locus admission stays outside because it is add-only. No AccountingRoleAuthority or generic evidence registry is earned.",
        "nodes": [
            ("action", "Scheduled ownership"),
            ("action", "Actual ownership"),
            ("action", "CurrentQuantityAnchor ownership"),
            ("action", "AccountingRole ownership"),
            ("insertion", "re-read Actual + Scheduled + Anchor + Role"),
            ("decision", "all virginity guards pass?"),
            ("action", "publish first role"),
            ("action", "KEEP add-only Locus policy outside lock chain"),
            ("action", "KEEP virgin-only semantics"),
            ("action", "DO NOT ADD role history / generic authority layer"),
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
            ("LOAM G2.015 - Initial AccountingRole virginity",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.015 AccountingRole virginity")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("AccountingRole virginity audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing AccountingRole virginity source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
