#!/usr/bin/env python3
"""Build the Generation-2 legacy Main workspace retirement audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-tui-legacy-workspace-retirement-audit.drn"

DIAGRAMS = {
    "G2.030.1 Production Workspace Reachability": {
        "description": "Separate documented production workspace entrances from the legacy Main compatibility state machine.",
        "sources": "docs/TUI.md; Loam/Tui/Cli.lean; Loam/Tui/Main.lean",
        "audit": "Home Enter is intercepted by SelectedDay, a by HraActual, and p by HraScheduled. Legacy Main Actual has no normal entrance; physical Tab still falls through to Main.update and opens legacy Scheduled.",
        "nodes": [
            ("insertion", "Production Home"),
            ("decision", "Enter / a / p?", "YES"),
            ("action", "SelectedDay / HraActual / HraScheduled"),
            ("decision", "Physical Tab?", "YES"),
            ("action", "hidden compatibility -> Main.update .tab"),
            ("action", "legacy Surface.scheduled"),
        ],
    },
    "G2.030.2 Compatibility Island": {
        "description": "Inventory state and render machinery retained only for the older Main workspaces.",
        "sources": "Loam/Tui/Main.lean; Loam/Tui/HraHome.lean; Loam/Tui/Cli.lean",
        "audit": "ReviewCursor, ScheduledCursor, browse/detail modes, Surface Actual/Scheduled variants, old renderers, and compatibility dispatch form one connected island. Shared snapshots, Home date state, calendar helpers, and read helpers remain outside it.",
        "nodes": [
            ("action", "ReviewCursor / ScheduledCursor"),
            ("action", "legacy Surface variants + transitions"),
            ("action", "legacy browse/detail renderers"),
            ("action", "HraHome compatibility dispatch"),
            ("action", "Cli hidden Tab / legacy return handling"),
            ("action", "RETIRE candidate after migration"),
        ],
    },
    "G2.030.3 Regression Bridge": {
        "description": "Move the only unique long-list guarantees to production HRA workspaces before retiring legacy state.",
        "sources": "Loam/Tests/TuiActual.lean; Loam/Tests/TuiScheduled.lean; Loam/Tui/HraActual.lean; Loam/Tui/HraScheduled.lean",
        "audit": "Only legacy tests currently reach the 11th row and verify a moving local window. Modern HRA workspaces have independent eight-row windows, so those guarantees must be tested directly before old cursor tests are deleted.",
        "nodes": [
            ("action", "legacy 12-row tests"),
            ("action", "migrate to HraActual / HraScheduled"),
            ("decision", "production long-list tests green?", "YES"),
            ("action", "retire legacy island"),
            ("action", "full Production TUI qualification"),
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
            ("LOAM G2-030 - legacy TUI workspace retirement",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2-030 legacy workspace retirement")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("legacy workspace retirement diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing legacy workspace retirement source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
