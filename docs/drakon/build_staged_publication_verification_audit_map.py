#!/usr/bin/env python3
"""Build the Generation-3 staged publication verification audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-staged-publication-verification-audit.drn"

DIAGRAMS = {
    "G3.P1.1 Four staged publication paths": {
        "description": "Compare current complete-image/config staged publication protocols at one procedural scale.",
        "sources": "Loam/ActualAuthority.lean; Loam/CapacityAuthority.lean; Loam/Persistence/ScheduledLifecyclePersistence.lean; Loam/ScheduledCoverageConfig.lean; Loam/Persistence/SiblingStage.lean",
        "audit": "All four use sibling staging and one rename, but only Actual, Capacity, and Scheduled Coverage currently run the staged bytes back through their production typed decoder before rename. Scheduled lifecycle performs readback plus byte equality but no publication-local typed re-decode.",
        "nodes": [
            ("action", "ACTUAL"),
            ("insertion", "encode normalized Actual"),
            ("action", "write sibling stage"),
            ("insertion", "read stage + byte equality"),
            ("insertion", "typed decode staged bytes"),
            ("action", "rename -> actual.loam"),
            ("action", "CAPACITY"),
            ("insertion", "encode normalized Capacity"),
            ("action", "write sibling stage"),
            ("insertion", "read stage + byte equality"),
            ("insertion", "typed decode staged bytes"),
            ("action", "rename -> capacity.loam"),
            ("action", "SCHEDULED COVERAGE CONFIG"),
            ("insertion", "encode rules"),
            ("action", "write sibling stage"),
            ("insertion", "read stage + byte equality"),
            ("insertion", "typed decode staged bytes"),
            ("action", "rename -> config"),
            ("action", "SCHEDULED LIFECYCLE"),
            ("insertion", "encode lifecycle image"),
            ("action", "write sibling stage"),
            ("insertion", "read stage + byte equality"),
            ("action", "rename -> scheduled.loam"),
        ],
    },
    "G3.P1.2 Scheduled lifecycle residual": {
        "description": "Expose the one verification decision absent from Scheduled lifecycle publication.",
        "sources": "Loam/Persistence/ScheduledLifecyclePersistence.lean; Loam/Tests/ScheduledLifecyclePersistence.lean; docs/research/SEMANTIC_AUDIT_SA006_PERSISTENCE.md",
        "audit": "The lifecycle codec has direct encode/decode regression coverage, but saveScheduledLifecycleImage? can currently rename staged bytes without asking the production lifecycle decoder to admit those exact bytes. A local re-decode would strengthen fail-closed publication without changing the wire format or semantic transition.",
        "nodes": [
            ("insertion", "encodeScheduledLifecycleImage?"),
            ("decision", "encode succeeds?", "refuse"),
            ("action", "write .loam-stage"),
            ("insertion", "read .loam-stage"),
            ("decision", "staged bytes == intended bytes?", "refuse"),
            ("decision", "decodeScheduledLifecycleImage? staged succeeds?", "CURRENTLY ABSENT"),
            ("action", "rename stage -> scheduled.loam"),
            ("action", "authority becomes visible"),
        ],
    },
    "G3.P1.3 Sharing stop point": {
        "description": "Separate a local safety repair from speculative staging-framework growth.",
        "sources": "Loam/Persistence/SiblingStage.lean; docs/research/COMPRESSION_AUDIT_PHASE3.md; docs/research/SEMANTIC_AUDIT_SA009_PROTOCOL_ECHO.md",
        "audit": "SiblingStage already owns ordinary write+rename. Stronger protocols differ in typed codec, error surface, parent creation, authority semantics, and return type. First add or reject the one missing lifecycle verification. Reconsider a verified-stage helper only if concrete duplication remains after that repair.",
        "nodes": [
            ("decision", "Does lifecycle staged typed decode add a missing fail-closed gate?", "test local change"),
            ("action", "KEEP authority-specific codec and refusal text"),
            ("action", "KEEP SiblingStage minimal"),
            ("decision", "Create generic verified-stage callback framework now?", "NO"),
            ("action", "measure remaining repeated mechanics after local repair"),
            ("action", "STOP unless another concrete consumer pressure appears"),
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
            ("LOAM G3.P1 - staged publication verification",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G3.P1 staged publication verification")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("staged publication audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing staged publication source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
