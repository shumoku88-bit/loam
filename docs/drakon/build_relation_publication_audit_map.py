#!/usr/bin/env python3
"""Build the Generation-2 Relation opening / discharge publication audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-relation-publication-audit.drn"

DIAGRAMS = {
    "G2.011.1 Relation Opening / Discharge Comparison": {
        "description": "Place open-relation and discharge admission beside each other at one production semantic scale.",
        "sources": "Loam/MovementAdmission.lean; Loam/SparseEffectIdentity.lean; Loam/Application/OpenRelationFrontier.lean; Loam/Application/RelationDischargeFrontier.lean",
        "audit": "Both evidence families are appended inside one admitted Movement world, but they answer different questions. Opening attaches positive RelationUnit evidence to one durably keyed source Effect; discharge targets an already-current RelationUnit from the later Event. Sparse Effect identity makes retained source keys relation-earned. Discharge keeps independent activation, target-currentness, duplicate-event and aggregate-bound obligations.",
        "nodes": [
            ("action", "Record Movement draft"),
            ("insertion", "canonicalizeDraft\nretain only Relation-earned EffectKeys"),
            ("insertion", "Event.ofEffects?\nretained keys unique"),
            ("action", "OPEN RELATIONS"),
            ("insertion", "materialize fresh RelationUnit ids"),
            ("action", "append candidate RelationUnits"),
            ("decision", "every new RelationUnit\nknownPositive?"),
            ("action", "DISCHARGES"),
            ("insertion", "materialize Event-scoped discharges"),
            ("action", "append candidate discharges"),
            ("decision", "exact new discharge appears\nin admitted target frontier?"),
            ("action", "return one admitted Movement world"),
        ],
    },
    "G2.011.2 Derived Source-Resolution Gate": {
        "description": "Show why the old whole-Event source-resolution pass is derived after sparse identity canonicalization.",
        "sources": "Loam/MovementAdmission.lean; Loam/SparseEffectIdentity.lean; Loam/Application/OpenRelationFrontier.lean",
        "audit": "A retained Event EffectKey survives canonicalizeDraft only when some RelationDraft names that exact key. Materialization preserves the sourceEffect on a new RelationUnit. If every new RelationUnit reaches knownPositive, the same currentRelationState query for every retained key is necessarily isSome. Anonymous Effects already pass the old gate. The separate event.effects.all relationSourceResolved pass therefore adds no independent refusal on the production construction path.",
        "nodes": [
            ("decision", "Effect key retained?"),
            ("action", "yes -> key occurs in RelationDraft sources"),
            ("action", "materialize RelationUnit with same sourceEffect"),
            ("decision", "new RelationUnit knownPositive?"),
            ("action", "currentRelationState isSome"),
            ("action", "old source-resolved check follows"),
            ("action", "no key -> old check already true"),
            ("action", "DELETE derived whole-Event pass"),
        ],
    },
    "G2.011.3 Discharge KEEP / Stop Point": {
        "description": "Record why the nearby discharge frontier remains explicit instead of being folded into opening admission.",
        "sources": "Loam/Application/RelationDischargeFrontier.lean; Loam/Tests/RelationDischargeFrontier.lean; Loam/MovementAdmission.lean",
        "audit": "Discharge resolves a current RelationUnit target, activates only rows whose later Event is authoritative, refuses source-Event self-discharge, nonpositive and over-target quantities, repeated active Event/target correspondence and aggregate over-discharge. Pre-Event crash residue is deliberately inert. None of these obligations follows from sparse Effect identity or open-relation positive admission, so the discharge frontier and opening/discharge semantic split remain justified.",
        "nodes": [
            ("insertion", "resolve current RelationUnit target"),
            ("decision", "later Event authoritative?"),
            ("action", "no -> inert crash residue"),
            ("decision", "distinct later Event + positive bounded quantity?"),
            ("decision", "active Event unique for target?"),
            ("decision", "aggregate discharge <= target quantity?"),
            ("action", "admit exact discharge rows"),
            ("action", "KEEP discharge frontier"),
            ("action", "KEEP opening/discharge distinction"),
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
            ("LOAM G2.011 - Relation opening / discharge publication",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.011 Relation publication")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Relation publication audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing Relation publication source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
