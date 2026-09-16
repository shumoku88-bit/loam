#!/usr/bin/env python3
"""Build the Generation-2 Locus-admission writer-closure audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-locus-admission-writer-closure-audit.drn"

DIAGRAMS = {
    "G2.021.1 Locus-bound Quantity Writers": {
        "description": "Place every reachable production entrance that introduces Locus-bound quantity evidence at one semantic scale.",
        "sources": "Loam/MovementAdmission.lean; Loam/CorrectionPublisher.lean; Loam/ActualReversalPublisher.lean; Loam/ScheduledCreationPublisher.lean; Loam/ScheduledReplacementPublisher.lean; Loam/ScheduledTerminalPublisher.lean; Loam/CurrentQuantityAnchorPublisher.lean",
        "audit": "After G2-020 all seven quantity-bearing Locus writers consume the current LocusAdmissionVocabulary before publication. The writer-specific value shapes differ, so the useful shared law is the policy itself rather than one generic publisher.",
        "nodes": [
            ("action", "Movement record\nEffect list"),
            ("action", "Actual correction\nreplacement Effects"),
            ("action", "Actual reversal\ninverse Effects"),
            ("action", "Scheduled create\nBalancedMovement"),
            ("action", "Scheduled replace\nBalancedMovement"),
            ("action", "Scheduled complete\nActual Effects"),
            ("action", "Current anchor\nAssertion coordinates"),
            ("insertion", "current LocusAdmissionVocabulary"),
            ("decision", "all proposed Loci admitted?", "NO -> refuse"),
            ("action", "YES -> continue operation-local laws"),
            ("action", "publish operation-specific evidence"),
        ],
    },
    "G2.021.2 Write Policy / Historical Read": {
        "description": "Keep current write permission separate from historical readability.",
        "sources": "Loam/Core/LocusAdmission.lean; Loam/LocusCatalog.lean; experiments/212_locus_admission_vocabulary.md; docs/research/CURRENT_QUANTITY_ANCHOR_LOCUS_ADMISSION_OBLIGATION_DAG.md",
        "audit": "Observation 212 established that historically referenced Loci and currently approved new-write Loci are independent. New writes cross the policy gate; retained evidence remains readable without re-admission.",
        "nodes": [
            ("action", "retained Actual / Scheduled / Anchor evidence"),
            ("decision", "reading retained evidence?", "YES -> do not consult current admission"),
            ("action", "historical/read-only Locus remains visible"),
            ("action", "new quantity publication request"),
            ("decision", "introduces Locus-bound quantity?", "NO -> no Locus gate"),
            ("insertion", "current admission policy"),
            ("decision", "Locus approved now?", "NO -> refuse"),
            ("action", "YES -> publish under operation-local semantics"),
        ],
    },
    "G2.021.3 Abstraction Stop Point": {
        "description": "Record why closure does not earn a generic quantity-writer layer or a policy lock today.",
        "sources": "Loam/Core/LocusAdmission.lean; Loam/CapacityPublisher.lean; Loam/LocusAdmissionPublisher.lean; repository-wide production publisher reachability",
        "audit": "Core already owns allows/admitEffect/admitEffects. Scheduled movements and current-anchor assertions have different shapes, while Capacity uses Purpose coordinates rather than Locus. Current production Locus mutation is add-only, so a stale read can only cause conservative refusal. No larger wrapper or lock topology is earned.",
        "nodes": [
            ("action", "existing Core policy primitives\nallows / admitsEffect / admitsEffects"),
            ("decision", "one shared orchestration invariant across all writers?", "NO"),
            ("action", "KEEP operation-local guard placement"),
            ("decision", "Capacity uses LocusId?", "NO -> Purpose / unallocated domain"),
            ("action", "KEEP Capacity outside Locus policy"),
            ("decision", "production Locus policy can revoke?", "NO today: add-only"),
            ("action", "DO NOT ADD Locus-policy lock"),
            ("action", "Reopen if revocation / whole-vocabulary replacement becomes production"),
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
            ("LOAM G2.021 - Locus admission writer closure",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.021 Locus admission writer closure")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Locus-admission writer-closure audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing Locus-admission writer-closure source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
