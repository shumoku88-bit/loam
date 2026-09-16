#!/usr/bin/env python3
"""Build the Generation-2 routing publication append audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-routing-publication-append-audit.drn"

DIAGRAMS = {
    "G2.018.1 Actual / Scheduled Routing": {
        "description": "Compare the two production routing writers at one semantic scale without erasing their different subjects, time coordinates, or authority policies.",
        "sources": "Loam/ActualRoutingPublisher.lean; Loam/ScheduledRoutingPublisher.lean; Loam/Core/HistoricalRouting.lean; docs/research/SEMANTIC_AUDIT_SA003_TEMPORAL_EVIDENCE.md",
        "audit": "Actual and Scheduled routing already share one generic RoutingHistory algebra, but their publication entrances remain independently earned: Actual routes bare Locus over initial|dated time and may initialize missing routing storage; Scheduled routes ScheduledId×Locus over dated time, requires an occurrence-local membership witness, and requires existing routing storage.",
        "nodes": [
            ("action", "ACTUAL ROUTING"),
            ("action", "subject = LocusId"),
            ("action", "time = initial | dated"),
            ("action", "missing routing storage -> empty history"),
            ("action", "SCHEDULED ROUTING"),
            ("action", "subject = ScheduledId × LocusId"),
            ("action", "time = dated"),
            ("decision", "retained ScheduledId exists and contains Locus?", "refuse invalid subject"),
            ("action", "missing routing storage -> refuse"),
            ("action", "KEEP semantic entrances separate"),
        ],
    },
    "G2.018.2 Shared Append Invariant": {
        "description": "Expose the one duplicated operation that belongs to RoutingHistory itself.",
        "sources": "Loam/Core/HistoricalRouting.lean; Loam/ActualRoutingPublisher.lean; Loam/ScheduledRoutingPublisher.lean; Loam/Core/EventMemory.lean",
        "audit": "Both publishers previously rebuilt `ofEntries? (history.entries ++ [entry])`. Failure means exactly the generic RoutingHistory coordinate invariant was violated. Core now owns that transition as `RoutingHistory.add?`, matching the existing EventMemory.add? ownership pattern.",
        "nodes": [
            ("action", "publisher validates local draft"),
            ("action", "construct RoutingEntry"),
            ("insertion", "RoutingHistory.add? entry"),
            ("decision", "new (subject,effectiveOn) coordinate unique?", "refuse duplicate coordinate"),
            ("action", "return updated typed history"),
            ("action", "family-specific persistence save"),
            ("action", "SHARE only this Core invariant"),
        ],
    },
    "G2.018.3 Stop Point": {
        "description": "Record the tempting similarities that do not earn broader routing publication abstraction.",
        "sources": "experiments/212_locus_admission_vocabulary.md; docs/research/ACCOUNTING_ROLE_ROUTING_OBLIGATION_DAG.md; Loam/ScheduledReplacementPublisher.lean; Loam/ScheduledTerminalPublisher.lean",
        "audit": "Current Locus admission is a new quantity-write vocabulary, not a universal routing foreign key. Scheduled occurrence membership remains stable because current lifecycle writers retain existing occurrence content. These facts reject both a generic LocusAdmission gate and speculative Scheduled-lifecycle locking.",
        "nodes": [
            ("decision", "share Target / validation / persistence orchestration?", "NO: adapters exceed common law"),
            ("decision", "gate all Actual routing on current Locus admission?", "NO: historical retired-Locus interpretation must remain possible"),
            ("decision", "add Scheduled lifecycle ownership?", "NO: validated occurrence membership is stable under current append-only lifecycle writers"),
            ("decision", "generic RoutingPublisher?", "NO: subject, time, missing-storage and validation policies differ"),
            ("action", "KEEP two publishers"),
            ("action", "KEEP two authority/persistence owners"),
            ("action", "SHARE RoutingHistory.add? only"),
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
            ("LOAM G2.018 - routing publication append",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.018 routing publication append")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("routing publication append audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing routing publication source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
