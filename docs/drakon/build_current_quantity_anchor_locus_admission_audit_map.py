#!/usr/bin/env python3
"""Build the Generation-2 CurrentQuantityAnchor Locus-admission audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-current-quantity-anchor-locus-admission-audit.drn"

DIAGRAMS = {
    "G2.020.1 Anchor Admission Gap": {
        "description": "Show how a syntactically valid but unapproved Locus could enter canonical current-anchor evidence before G2-020, and where the current admission gate belongs.",
        "sources": "Loam/CurrentQuantityAnchorPublisher.lean; Loam/Tui/CurrentQuantityAnchor.lean; Loam/Core/LocusAdmission.lean; Loam/LocusCatalog.lean; experiments/212_locus_admission_vocabulary.md",
        "audit": "CurrentQuantityAnchor was added after Observation 212. Before G2-020, validToken plus support/frontier/uniqueness checks could persist a typo Locus such as detb. Because anchor coordinates feed RoleBalance and AccountingRole virginity, this is canonical semantic evidence rather than presentation-only input. Re-read current LocusAdmissionVocabulary and refuse unapproved assertion Loci before anchor construction.",
        "nodes": [
            ("action", "human / CLI enters\nLocus × Measure × Quantity"),
            ("decision", "token syntax valid?", "refuse malformed token"),
            ("action", "re-read current\nLocusAdmissionVocabulary"),
            ("decision", "every assertion Locus admitted?", "refuse unapproved Locus"),
            ("decision", "coordinate overlaps zero/opening support?", "refuse overlap"),
            ("action", "derive stable correction-root cut"),
            ("decision", "roots + coordinates unique?", "refuse malformed anchor"),
            ("action", "persist complete current anchor image"),
            ("action", "RoleBalance / AccountingRole consume canonical coordinate"),
        ],
    },
    "G2.020.2 Write vs Read Boundary": {
        "description": "Keep new-write admission separate from historical readability of already-retained anchor evidence.",
        "sources": "Loam/CurrentQuantityAnchor.lean; Loam/CurrentQuantityAnchorPublisher.lean; Loam/Core/LocusAdmission.lean; Loam/LocusCatalog.lean; Loam/Tests/CurrentQuantityAnchor.lean",
        "audit": "Current admission is publication policy, not a structural invariant of retained CurrentQuantityAnchor.Evidence. An older anchor may mention a Locus that later becomes read-only and must remain readable. Only a new anchor publication requires current admission; history, display metadata and AccountingRole never auto-re-admit a Locus.",
        "nodes": [
            ("action", "retained old anchor\nmay mention historical/read-only Locus"),
            ("decision", "new publication?", "NO -> keep readable without admission check"),
            ("action", "YES: proposed new assertion"),
            ("decision", "currently admitted Locus?", "NO -> explicit admission required first"),
            ("action", "YES: continue reconciliation publication"),
            ("action", "DO NOT infer admission from Actual history"),
            ("action", "DO NOT infer admission from display metadata / AccountingRole"),
        ],
    },
    "G2.020.3 Ownership Stop Point": {
        "description": "Explain why publication re-reads current Locus policy but does not add another writer lock under the present add-only policy lifecycle.",
        "sources": "Loam/CurrentQuantityAnchorPublisher.lean; Loam/LocusAdmissionAuthority.lean; Loam/LocusAdmissionPublisher.lean; repository-wide publishCurrent?/updateCurrent? caller reachability",
        "audit": "Anchor publication keeps Actual -> Anchor ownership. LocusAdmission is re-read during that interval, but the reachable production policy mutation is add-only. A concurrent add can make the read conservatively stale only toward refusal; retry can succeed. No production revocation/replacement writer can invalidate an observed approval today. Reopen ownership if revocation or whole-vocabulary replacement becomes production-reachable.",
        "nodes": [
            ("insertion", "acquire Actual ownership"),
            ("insertion", "acquire current-anchor ownership"),
            ("action", "load current Locus admission snapshot"),
            ("decision", "production policy mutation add-only?", "NO -> reopen ownership audit"),
            ("action", "YES today"),
            ("decision", "concurrent new admission after read?", "YES -> conservative refusal; retry"),
            ("action", "no success-then-revocation race reachable"),
            ("action", "KEEP Actual -> Anchor locks"),
            ("action", "DO NOT ADD speculative Locus-policy lock"),
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
            ("LOAM G2.020 - CurrentQuantityAnchor Locus admission",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(
            db, node_id, 0, "folder", "G2.020 CurrentQuantityAnchor Locus admission"
        )
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
            raise SystemExit("CurrentQuantityAnchor Locus-admission diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing CurrentQuantityAnchor Locus-admission source metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
