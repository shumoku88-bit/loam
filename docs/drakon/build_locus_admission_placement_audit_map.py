#!/usr/bin/env python3
"""Build the Generation-2 Locus admission placement audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-locus-admission-placement-audit.drn"

DIAGRAMS = {
    "G2.014.1 Current Locus Admission Publication": {
        "description": "Show the current production policy path and its authority/persistence ownership split.",
        "sources": "Loam/LocusAdmissionPublisher.lean; Loam/LocusAdmissionAuthority.lean; Loam/Persistence/LocusAdmissionPersistence.lean; Loam/Tests/LocusAdmissionPublisher.lean",
        "audit": "The publisher owns add-only policy proposal semantics. LocusAdmissionAuthority owns the canonical locus-admission.loam placement, writer ownership, and read/modify/write protocol. Persistence only encodes and decodes a vocabulary at a caller-supplied path. The three layers therefore retain independent reasons to exist.",
        "nodes": [
            ("action", "HouseholdCommand / TUI administration"),
            ("action", "LocusAdmissionPublisher.publishAdmission"),
            ("insertion", "validate stable token + reject duplicate"),
            ("action", "LocusAdmissionAuthority.updateCurrent?"),
            ("insertion", "locusAdmissionPath(root)"),
            ("action", "root/locus-admission.loam"),
            ("insertion", "writer ownership"),
            ("action", "load current vocabulary"),
            ("action", "apply add-only proposal"),
            ("action", "save current vocabulary"),
            ("insertion", "Persistence receives canonical path"),
        ],
    },
    "G2.014.2 Dead EventMemory Sidecar Topology": {
        "description": "Contrast the current authority path with the unused legacy EventMemory-sidecar path helper.",
        "sources": "Loam/Persistence/LocusAdmissionPersistence.lean; repository-wide symbol reachability search; commits 768c5715ff5f25168834638919b8c7f34746cc9e and f403602476274a3c16527253643ad1d20e638b76",
        "audit": "Persistence retained locusAdmissionVocabularyPathForEventMemory(memoryPath) = memoryPath + '.locus-admission'. Its documentation calls it a legacy sidecar writer surface and repository-wide search finds no live caller. Production placement has moved behind LocusAdmissionAuthority, so keeping this helper preserves an obsolete physical topology without behavior.",
        "nodes": [
            ("action", "OLD EventMemory path"),
            ("insertion", "append .locus-admission"),
            ("action", "legacy sidecar location"),
            ("decision", "any live caller?"),
            ("action", "NO"),
            ("decision", "does production authority use it?"),
            ("action", "NO"),
            ("action", "obsolete physical-topology concept"),
            ("action", "RETIRE"),
        ],
    },
    "G2.014.3 Minimal Stop Point": {
        "description": "Record exactly what is removed and why the local authority boundary remains.",
        "sources": "Loam/LocusAdmissionPublisher.lean; Loam/LocusAdmissionAuthority.lean; Loam/Persistence/LocusAdmissionPersistence.lean; Loam/Tests/LocusAdmissionPublisher.lean",
        "audit": "Delete only the unreachable legacy sidecar path helper. Keep publisher proposal semantics, canonical authority placement, writer ownership, and persistence representation separate. Adding a compatibility alias would preserve the dead concept and is therefore rejected.",
        "nodes": [
            ("action", "DELETE legacy sidecar path helper"),
            ("action", "KEEP Publisher proposal semantics"),
            ("action", "KEEP Authority path ownership"),
            ("action", "KEEP writer ownership + R/M/W"),
            ("action", "KEEP Persistence encode/decode"),
            ("decision", "add compatibility alias?"),
            ("action", "NO"),
            ("action", "qualification: compile + integration tests"),
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
            ("LOAM G2.014 - Locus admission placement",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.014 Locus admission placement")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Locus admission placement audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing Locus admission placement source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
