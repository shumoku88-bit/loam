#!/usr/bin/env python3
"""Build the Generation-2 Event construction ownership audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-event-construction-audit.drn"

DIAGRAMS = {
    "G2.019.1 Event Construction Owners": {
        "description": "Place Record, Correction, Scheduled Completion and Actual Reversal at the same Event-construction scale.",
        "sources": "Loam/MovementAdmission.lean; Loam/CorrectionPublisher.lean; Loam/ScheduledTerminalPublisher.lean; Loam/ActualReversalPublisher.lean; Loam/Core/Event.lean",
        "audit": "The four paths keep different operation semantics and EventId policies, but Event-local retained EffectKey uniqueness has one existing Core owner: Event.ofEffects?.",
        "nodes": [
            ("action", "Record Movement\noperation-specific admission"),
            ("action", "Correction\nreplacement-specific guards"),
            ("action", "Scheduled Completion\ncurrent-open + retry protocol"),
            ("action", "Actual Reversal\nexact inverse + relation guards"),
            ("action", "Each path obtains Effects + EventId"),
            ("insertion", "Event.ofEffects?\nretained EffectKeys unique"),
            ("decision", "Event admitted?", "refuse duplicate retained Effect identity"),
            ("action", "Continue operation-specific evidence publication"),
        ],
    },
    "G2.019.2 Before and After": {
        "description": "Show the duplicated publisher-local proof obligation removed by delegating Event admission to Core.",
        "sources": "Loam/Core/Event.lean; Loam/CorrectionPublisher.lean; Loam/ScheduledTerminalPublisher.lean; Loam/ActualReversalPublisher.lean; Loam/SparseEffectIdentity.lean",
        "audit": "Before G2-019 three publishers directly constructed Event and supplied keyNodup proofs. Correction and Completion had already erased unearned keys; Reversal used anonymous Effects. The proofs repeated Event's own admission law.",
        "nodes": [
            ("action", "BEFORE\nmanual Event { id, effects, keyNodup := by ... }"),
            ("action", "Correction local canonicalized-key proof"),
            ("action", "Completion local canonicalized-key proof"),
            ("action", "Reversal private anonymous-inverse theorem"),
            ("decision", "independent publisher semantics?", "NO - same Event-local invariant"),
            ("action", "AFTER\nEvent.ofEffects? eventId effects"),
            ("action", "Core owns fail-closed retained-key uniqueness"),
        ],
    },
    "G2.019.3 Minimal Stop Point": {
        "description": "Record why the audit stops at Event construction rather than introducing a generic Actual append or publisher framework.",
        "sources": "Loam/MovementAdmission.lean; Loam/ActualEvidence.lean; Loam/Core/EventMemory.lean; Loam/Core/ActualValidityHistory.lean; Loam/Core/EventDescription.lean",
        "audit": "EventMemory.add?, ActualValidityHistory.addFact? and EventDescriptionMemory.add? already own their local invariants. Remaining repetition is operation orchestration with distinct diagnostics, identity choices and neighboring evidence relations, so no larger append abstraction is earned.",
        "nodes": [
            ("action", "Event.ofEffects?\nshared Core invariant"),
            ("action", "EventMemory.add?\nexisting memory invariant"),
            ("action", "ActualValidityHistory.addFact?\nexisting validity invariant"),
            ("action", "EventDescriptionMemory.add?\nexisting description invariant"),
            ("decision", "one new shared semantic law across the whole sequence?", "NO"),
            ("action", "KEEP publisher orchestration local"),
            ("action", "DO NOT ADD generic ActualAppend / Publisher framework"),
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
            ("LOAM G2.019 - Event construction ownership",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.019 Event construction")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Event construction audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing Event construction source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
