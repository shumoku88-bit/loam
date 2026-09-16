#!/usr/bin/env python3
"""Build the Generation-2 TUI Home presentation ownership audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-tui-home-presentation-ownership-audit.drn"

DIAGRAMS = {
    "G2.028.1 Production Home Ownership": {
        "description": "Show that the production root enters HraHome.view and HraHome owns the Home surface.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/HraHome.lean; Loam/Tui/Main.lean",
        "audit": "Cli.compiledFrameFor renders HraHome.view. HraHome handles Surface.home itself and delegates only non-Home surfaces. Main.homeView has no production entrance.",
        "nodes": [
            ("insertion", "Cli.compiledFrameFor"),
            ("insertion", "HraHome.view"),
            ("decision", "Surface is Home?", "YES"),
            ("action", "HraHome.homeView\nproduction Home owner"),
            ("decision", "Surface is Actual/Scheduled?", "YES"),
            ("action", "existing workspace renderer"),
        ],
    },
    "G2.028.2 Shared Helpers vs Legacy Island": {
        "description": "Separate Main helpers reused by HraHome from helpers reachable only through the legacy Home renderer.",
        "sources": "Loam/Tui/Main.lean; Loam/Tui/HraHome.lean",
        "audit": "selectedMonth, calendarSlot, homeActualRecords, homeScheduledEvidence, and basic line helpers remain live. Preview/calendar composition below those helpers is reachable only from Main.homeView.",
        "nodes": [
            ("decision", "Consumed by HraHome?", "YES"),
            ("action", "KEEP shared read/presentation helper"),
            ("decision", "Reachable only from Main.homeView?", "YES"),
            ("action", "RETIRE legacy presentation chain"),
            ("action", "Do not remove Surface.home or update transitions"),
        ],
    },
    "G2.028.3 Dispatcher Collapse": {
        "description": "Make the HRA production dispatcher the only surface renderer dispatcher.",
        "sources": "Loam/Tui/HraHome.lean; Loam/Tui/Main.lean; Loam/Tests/TuiScheduled.lean",
        "audit": "Main.view is externally used only by HraHome non-Home delegation and Scheduled tests. HraHome can dispatch Actual/Scheduled directly to the existing view functions; tests can follow the production dispatcher.",
        "nodes": [
            ("action", "HraHome.view matches all Surface constructors"),
            ("action", "Home -> HraHome.homeView"),
            ("action", "Actual -> Main Actual views"),
            ("action", "Scheduled -> Main.scheduledView"),
            ("action", "retire Main.view / screenFor / screenBounds"),
            ("action", "tests render through production dispatcher"),
        ],
    },
    "G2.028.4 Semantic Stop Point": {
        "description": "Preserve Home state and read semantics while retiring only duplicate presentation ownership.",
        "sources": "Loam/Tui/Main.lean; Loam/ActualReview.lean; Loam/Tests/RecordReview.lean",
        "audit": "Surface.home, navigation transitions, Actual/Scheduled read helpers, and ActualReview.Query.undated remain meaningful. Presentation duplication is the target, not those semantics.",
        "nodes": [
            ("action", "KEEP Surface.home"),
            ("action", "KEEP Home navigation transitions"),
            ("action", "KEEP ActualReview.Query.undated"),
            ("action", "KEEP shared HraHome evidence helpers"),
            ("action", "STOP after duplicate renderer ownership is gone"),
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
            ("LOAM G2.028 - TUI Home presentation ownership",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.028 TUI Home presentation ownership")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("TUI Home ownership audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing TUI Home ownership source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
