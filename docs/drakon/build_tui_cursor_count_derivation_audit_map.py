#!/usr/bin/env python3
"""Build the Generation-2 TUI cursor count-derivation audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-tui-cursor-count-derivation-audit.drn"

DIAGRAMS = {
    "G2.026.1 Cursor Count Dependency": {
        "description": "Show that both browse totals are exact consequences of retained full-day arrays.",
        "sources": "Loam/Tui/Main.lean; Loam/Tests/TuiActual.lean",
        "audit": "ReviewCursor and ScheduledCursor retain the complete selected-day Array. The ten-row viewport is derived later, so totalCount has no independent pagination or authority meaning.",
        "nodes": [
            ("action", "Selected-day records"),
            ("action", "displayed := records.toArray"),
            ("decision", "Is displayed only a viewport slice?", "NO - full selected-day Array"),
            ("action", "selected : Fin displayed.size"),
            ("action", "derive totalCount := displayed.size"),
            ("action", "visible*Rows derives ten-row window later"),
        ],
    },
    "G2.026.2 Remove Contradictory State": {
        "description": "Compare the retained-state graph before and after G2-026.",
        "sources": "Loam/Tui/Main.lean",
        "audit": "Before G2-026 a cursor could retain displayed rows and an unrelated totalCount. After G2-026 there is one cardinality source and the existing cursor.totalCount surface is a derived function.",
        "nodes": [
            ("action", "BEFORE\ndisplayed Array + totalCount Nat"),
            ("decision", "Can fields disagree?", "YES - structure permits contradiction"),
            ("action", "AFTER\ndisplayed Array only"),
            ("action", "cursor.totalCount := displayed.size"),
            ("action", "Browse text remains unchanged"),
        ],
    },
    "G2.026.3 Stop Point": {
        "description": "Keep independent cursor state and separate the neighboring undated-count question.",
        "sources": "Loam/Tui/Main.lean; Loam/ActualReview.lean",
        "audit": "Selection and retained rows remain independent interaction state. ActualSnapshot.undatedCount is another derived-summary candidate, but its full-record traversal cost is a separate question and is not mechanically removed by this audit.",
        "nodes": [
            ("action", "KEEP displayed rows"),
            ("action", "KEEP selected cursor position"),
            ("action", "KEEP viewport derivation"),
            ("decision", "Also remove ActualSnapshot.undatedCount now?", "NO - separate cost/ownership audit"),
            ("action", "Close G2-026 at exact cursor cardinality"),
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
            ("LOAM G2.026 - TUI cursor count derivation",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.026 TUI cursor count derivation")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("TUI cursor count-derivation audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing TUI cursor count-derivation source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
