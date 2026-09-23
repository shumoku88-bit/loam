#!/usr/bin/env python3
"""Build the Scheduled deferred-continuation audit map."""

from pathlib import Path
import sqlite3
import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-scheduled-deferred-continuation-audit.drn"

DIAGRAMS = {
    "S1053.1 Deferred Scheduled continuation": {
        "description": "Observe the post-completion no-candidate branch and the smallest explicit Defer path.",
        "sources": "Loam/Tui/ScheduledContinuationSession.lean; Loam/HouseholdCommand.lean; Loam/AttentionPublisher.lean; Loam/AttentionReview.lean; issue #1053",
        "audit": "Completion remains authoritative before continuation begins. Existing later-plan awareness stays unchanged. Only the no-candidate branch gains an explicit Defer choice. Done writes nothing; Add uses ordinary Scheduled creation; Defer publishes one ordinary Attention item with dueUndetermined through HouseholdCommand.addAttention. No next date, cadence, recurrence, series identity, or second task authority is created.",
        "nodes": [
            ("action", "Scheduled completion already published"),
            ("insertion", "reload ScheduledReview current-open evidence"),
            ("decision", "later similar current-open Scheduled exists?", "YES"),
            ("action", "YES: Keep as is / Add another / Review"),
            ("action", "NO: Done / Defer / Add next"),
            ("decision", "user chooses Defer?", "YES"),
            ("insertion", "HouseholdCommand.addAttention"),
            ("action", "Attention context identifies completed Scheduled\ndue = dueUndetermined"),
            ("decision", "Attention publication refused?", "YES -> return explicit refusal notice"),
            ("action", "NO -> deferred intent remains visible in Attention / Manage"),
            ("decision", "infer recurrence/date/cadence?", "NO"),
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
        db.executemany("insert into info values (?,?)", [
            ("type", "drakon"), ("version", "2"), ("start_version", "1"), ("language", "Lean")])
        db.execute("insert into state values (1,1,?)", ("LOAM issue 1053 - deferred Scheduled continuation",))
        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)
        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "Scheduled deferred continuation")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])
        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")
        assert db.execute("pragma integrity_check").fetchone()[0] == "ok"
        assert db.execute("select count(*) from diagrams").fetchone()[0] == len(names)
        assert db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] == len(names)
    print(OUTPUT)


if __name__ == "__main__":
    build()
