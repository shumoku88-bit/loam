#!/usr/bin/env python3
"""Build the Generation-2 Home update Snapshot-dependency audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-tui-home-update-snapshot-audit.drn"

DIAGRAMS = {
    "G2.031.1 Home Transition Dependency": {
        "description": "Show the inputs that can change the root Home transition after G2-030 retired object workspace state.",
        "sources": "Loam/Tui/Main.lean",
        "audit": "Main.update branches only on Event and mutates only State.selectedDate / State.notice or Step.quit. Household Snapshot evidence is not consulted by left/right/up/down/quit/other transitions, so retaining Snapshot in the transition signature states a dependency that does not exist.",
        "nodes": [
            ("action", "State\nselectedDate + notice"),
            ("action", "Event\nleft/right/up/down/quit/other"),
            ("insertion", "Main.update"),
            ("decision", "date movement?", "YES -> moveDate from State only"),
            ("decision", "quit?", "YES -> Step.quit"),
            ("action", "Step\nstate + quit"),
            ("action", "Snapshot has no transition edge"),
        ],
    },
    "G2.031.2 Production Dependency Split": {
        "description": "Separate Home interaction state transition from household-evidence presentation and the explicit known-date jump.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/HraHome.lean; Loam/Tui/Main.lean",
        "audit": "Cli.loop sends ordinary Home navigation through Main.update state event, then renders the resulting state with compiledFrameFor bounds snapshot. HraHome consumes Snapshot for Today, Actual, Scheduled, and Pending evidence. The g/known command is intentionally handled outside Main.update because it needs snapshot.actual.today.",
        "nodes": [
            ("insertion", "Home key"),
            ("decision", "g / known?", "YES"),
            ("action", "selectedDate := snapshot.actual.today"),
            ("decision", "ordinary Home navigation?", "YES"),
            ("insertion", "Main.update state event\nno Snapshot"),
            ("insertion", "compiledFrameFor bounds snapshot state"),
            ("insertion", "HraHome.view\nSnapshot presentation evidence"),
            ("action", "transition and read dependencies stay distinct"),
        ],
    },
    "G2.031.3 Refactor Boundary": {
        "description": "Remove only the false transition dependency while keeping real read-side Snapshot dependencies.",
        "sources": "Loam/Tui/Main.lean; Loam/Tui/Cli.lean; Loam/Tui/HraHome.lean; Loam/Tests/TuiScheduled.lean",
        "audit": "G2-031 changes Main.update from Snapshot -> State -> Event -> Step to State -> Event -> Step. It preserves Snapshot, HraHome presentation, homeActualRecords, homeScheduledEvidence, g/known Today navigation, and snapshot-dependent object workspaces. Existing Home focus/presentation regression tests now exercise the snapshot-free transition directly.",
        "nodes": [
            ("action", "SIMPLIFY Main.update signature"),
            ("action", "KEEP Snapshot read model"),
            ("action", "KEEP HraHome evidence rendering"),
            ("action", "KEEP g / known Snapshot dependency"),
            ("action", "KEEP snapshot-dependent object workspaces"),
            ("action", "qualify production TUI + audit workflows"),
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
            ("LOAM G2-031 - Home update Snapshot dependency",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2-031 Home update Snapshot dependency")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Home update Snapshot audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing Home update Snapshot source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
