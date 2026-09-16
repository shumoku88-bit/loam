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
        "audit": "Home Enter is owned by SelectedDay, a by HraActual, and p by HraScheduled. The retired root has no Actual/Scheduled Surface variants and physical Tab now falls through to a no-op Home event rather than opening a second Scheduled workspace.",
        "nodes": [
            ("insertion", "Production Home"),
            ("decision", "Enter / a / p?", "YES"),
            ("action", "SelectedDay / HraActual / HraScheduled"),
            ("decision", "Physical Tab?", "NO DOCUMENTED ACTION"),
            ("action", "Home event -> other / no-op"),
            ("action", "no legacy workspace state exists"),
        ],
    },
    "G2.030.2 Compatibility Island": {
        "description": "Inventory state and render machinery retained only for the older Main workspaces.",
        "sources": "Loam/Tui/Main.lean; Loam/Tui/HraHome.lean; Loam/Tui/Cli.lean",
        "audit": "The compatibility island has been removed. Main now retains shared snapshots, Home date/notice state, date navigation, calendar helpers, and Home read projections only; object workspace state belongs to SelectedDay, HraActual, and HraScheduled.",
        "nodes": [
            ("action", "ReviewCursor / ScheduledCursor retired"),
            ("action", "legacy Surface variants + transitions retired"),
            ("action", "legacy browse/detail renderers retired"),
            ("action", "HraHome renders Home only"),
            ("action", "Cli hidden Tab / legacy return handling retired"),
            ("action", "QUALIFY retired topology"),
        ],
    },
    "G2.030.3 Regression Bridge": {
        "description": "Move the only unique long-list guarantees to production HRA workspaces before retiring legacy state.",
        "sources": "Loam/Tests/TuiActual.lean; Loam/Tests/TuiScheduled.lean; Loam/Tui/HraActual.lean; Loam/Tui/HraScheduled.lean",
        "audit": "The bridge is now explicit in production HRA tests: both HraActual and HraScheduled reach the 11th item, move their own eight-row viewport, keep selected detail synchronized, and refuse movement beyond the final row without moving selection.",
        "nodes": [
            ("action", "legacy 12-row guarantee identified"),
            ("action", "migrated to HraActual / HraScheduled"),
            ("decision", "production long-list tests green?", "YES"),
            ("action", "legacy island retired"),
            ("action", "full Production TUI qualification passed (62/62)"),
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
