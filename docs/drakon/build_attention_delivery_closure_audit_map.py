#!/usr/bin/env python3
"""Build the Generation-2 G2-032 Attention delivery closure audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-attention-delivery-closure-audit.drn"

DIAGRAMS = {
    "G2.032.1 Current Attention End-to-End": {
        "description": "Current read/write Attention topology after the G2-009 maturation writer landed.",
        "sources": "Loam/Core/Attention.lean; Loam/Persistence/AttentionPersistence.lean; Loam/Application/AttentionInspection.lean; Loam/AttentionReview.lean; Loam/AttentionPublisher.lean; Loam/HouseholdCommand.lean; Loam/Tui/AttentionAdministrationSession.lean; PR #927",
        "audit": "The G2-009 authority gap is closed. Durable Add/Close intents cross HouseholdCommand into AttentionPublisher, are re-admitted under WriterOwnership against a fresh complete image, saved through the existing persistence boundary, and then reloaded through AttentionReview. No second lifecycle engine or TUI-owned canonical state appears.",
        "nodes": [
            ("action", "Attention administration intent"),
            ("action", "HouseholdCommand selects attention.loam"),
            ("action", "AttentionPublisher"),
            ("action", "WriterOwnership"),
            ("action", "re-read complete image"),
            ("decision", "command admitted?", "Refuse without publication"),
            ("action", "save complete image"),
            ("action", "AttentionReview reload"),
            ("action", "canonical visible answer"),
            ("action", "G2-009 DELIVERY GAP CLOSED"),
        ],
    },
    "G2.032.2 Attention Surface Stop Point": {
        "description": "Why the integrated read workspace and standalone administration surface remain separate for now.",
        "sources": "Loam/Tui/Attention.lean; Loam/Tui/Cli.lean; Loam/Tui/AttentionAdministration.lean; Loam/Tui/AttentionAdministrationSession.lean; Loam/Tui/AttentionCli.lean; lakefile.lean; PR #927",
        "audit": "Integrated loamTui owns a recognition-only Attention workspace; standalone loamAttention owns the first practical management entrance. They consume the same AttentionReview answer and share no duplicated lifecycle semantics. Their navigation contracts and product responsibilities differ, so extracting a shared presentation layer or forcing administration into the root TUI would add adapter surface without removing a semantic duplication.",
        "nodes": [
            ("action", "shared AttentionReview.Availability"),
            ("decision", "product entrance"),
            ("action", "loamTui\nread-only recognition"),
            ("action", "loamAttention\nAdd / Resolve / Drop"),
            ("action", "no lifecycle semantics in either view"),
            ("action", "different navigation contracts"),
            ("decision", "shared presentation owner earned?", "KEEP surfaces separate"),
            ("action", "No production refactor"),
            ("action", "G2-032 KEEP / STOP"),
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
            ("LOAM G2.032 - Attention delivery closure",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.032 Attention Closure")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Attention closure audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing Attention closure source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
