#!/usr/bin/env python3
"""Build the Generation-2 AccountingRole / ActualRouting audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-accounting-role-routing-audit.drn"

DIAGRAMS = {
    "G2.008.1 AccountingRole / ActualRouting Comparison": {
        "description": "Initial AccountingRole candidates and current Actual routing administration at one semantic scale.",
        "sources": "Loam/AccountingRoleReview.lean; Loam/AccountingRolePublisher.lean; Loam/ActualRoutingReview.lean; Loam/LocusAdmissionAuthority.lean",
        "audit": "AccountingRoleReview is a thin canonical evidence loader that delegates candidate semantics to AccountingRolePublisher.eligibleInitialLoci. ActualRoutingReview owns a richer presentation partition over current Locus admission, AccountingRole, routing history and Capacity-derived Purpose candidates. Similar overlay vocabulary does not justify a shared report abstraction.",
        "nodes": [
            ("action", "ACCOUNTING ROLE REVIEW"),
            ("insertion", "selected Movement world\nActual + Locus admission"),
            ("insertion", "Scheduled lifecycle"),
            ("insertion", "AccountingRole map"),
            ("action", "delegate to eligibleInitialLoci"),
            ("action", "return initial-role candidates"),
            ("action", "ACTUAL ROUTING REVIEW"),
            ("insertion", "current Locus admission"),
            ("insertion", "AccountingRole map + routing history"),
            ("insertion", "Capacity Purpose candidates"),
            ("decision", "roleOf? admitted Locus ONCE"),
            ("action", "Expense default row"),
            ("action", "known non-Expense optional row"),
            ("action", "unknown-role diagnostic"),
            ("action", "historical-only routes remain independent"),
        ],
    },
    "G2.008.2 ActualRouting Role Partition": {
        "description": "Align one AccountingRole decision with three mutually exclusive runtime surfaces.",
        "sources": "Loam/ActualRoutingReview.lean; Loam/Core/AccountingRole.lean; Loam/Persistence/AccountingRolePersistence.lean; Loam/Persistence/ActualRoutingPersistence.lean",
        "audit": "Before G2-008 the same approved Locus list was traversed three times and roleOf? was re-evaluated independently for default Expense rows, optional known non-Expense rows and unresolved-role diagnostics. The three outcomes are one exhaustive role classification. partitionApproved now evaluates the retained role once per admitted Locus and routes it to exactly one surface while preserving admission order.",
        "nodes": [
            ("action", "currently admitted Locus"),
            ("decision", "roleOf? ONCE"),
            ("decision", "Expense?", "known non-Expense or unresolved"),
            ("action", "default Expense row\nstatusAt observedAt"),
            ("action", "optional known-role row\nstatusAt observedAt"),
            ("action", "unresolvedRoleLoci"),
            ("action", "exactly one partition leaf"),
        ],
    },
    "G2.008.3 Independent Routing Side Evidence": {
        "description": "Keep routing-history and Capacity side projections outside the AccountingRole partition.",
        "sources": "Loam/ActualRoutingReview.lean; Loam/CapacityReview.lean; Loam/LocusAdmissionAuthority.lean; Loam/Persistence/ActualRoutingPersistence.lean",
        "audit": "historicalOnlyRouteLoci answers a different question: routing subjects that are no longer currently admitted. Purpose candidates are derived from retained Capacity evidence. Neither is a leaf of current AccountingRole classification, so G2-008 keeps both as independent side projections rather than forcing a generic routing context or larger partition type.",
        "nodes": [
            ("insertion", "routing history subjects"),
            ("insertion", "current admission set"),
            ("action", "historical-only route loci"),
            ("insertion", "Capacity snapshot"),
            ("action", "distinct Purpose candidates"),
            ("action", "KEEP separate from role partition"),
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
            ("LOAM G2.008 - AccountingRole / ActualRouting obligation topology",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.008 AccountingRole / Routing")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("AccountingRole/Routing audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing AccountingRole/Routing source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
