#!/usr/bin/env python3
"""Build the module-granularity audit map for the large production TUI CLI."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-tui-cli-granularity-audit.drn"

DIAGRAMS = {
    "MGA.009.1 TUI CLI Responsibility Fanout": {
        "description": "Expose the distinct responsibilities currently meeting in Loam.Tui.Cli before deciding whether the file is merely a large composition root or owns too many independent reasons to change.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/Main.lean; Loam/Tui/Reports.lean",
        "audit": "Tui.Cli is the production terminal composition root, but it also owns key grammars, snapshot/config loading, several local editor loops, Home/Actual/Scheduled/SelectedDay orchestration, report query execution, and administration entrances. Size alone does not authorize a split; this map separates the reasons to change so they can be tested independently.",
        "nodes": [
            ("insertion", "loamTui main / terminal entrance"),
            ("action", "resolve data directory + current authority roots"),
            ("action", "load shared snapshot / catalogs / presets"),
            ("action", "map terminal keys to Home / Actual / Scheduled / SelectedDay events"),
            ("action", "run local editor loops\nRecord / Correction / Date / Scheduled terminal edits"),
            ("action", "run extracted *Session modules\ncreation / routing / capacity / admission / reversal"),
            ("action", "orchestrate HRA Home / Actual / Scheduled / SelectedDay"),
            ("action", "dispatch Reports queries + redraw"),
            ("action", "reload canonical evidence after successful writes"),
            ("decision", "One independent reason to change?", "NO - several families are visible"),
        ],
    },
    "MGA.009.2 Existing Session Seam": {
        "description": "Use an already-extracted session as a control showing what a real TUI file boundary looks like.",
        "sources": "Loam/Tui/ScheduledCreation.lean; Loam/Tui/ScheduledCreationSession.lean; Loam/HouseholdCommand.lean",
        "audit": "ScheduledCreation owns presentation state, validation and transition logic. ScheduledCreationSession owns terminal reads, dirty redraws and publication delegation. HouseholdCommand owns the production write entrance. The files therefore have different reasons to change even though the session is small and has a narrow consumer surface.",
        "nodes": [
            ("action", "ScheduledCreation.State / Step"),
            ("action", "pure-ish presentation transition\nupdate + draft + view"),
            ("insertion", "ScheduledCreationSession.run"),
            ("action", "read terminal key"),
            ("action", "emit dirty redraw"),
            ("decision", "Step publishes draft?", "YES"),
            ("insertion", "HouseholdCommand.createScheduled"),
            ("action", "authoritative publication elsewhere"),
        ],
    },
    "MGA.009.3 Local Session Cluster": {
        "description": "Identify editor-session loops still physically retained inside Tui.Cli even though neighboring features use dedicated Session modules.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/Record.lean; Loam/Tui/Correction.lean; Loam/Tui/ActualDateCorrection.lean; Loam/Tui/ScheduledCompletion.lean; Loam/Tui/ScheduledCancellation.lean; Loam/Tui/ScheduledReplacement.lean",
        "audit": "Record, Correction, ActualDateCorrection, ScheduledCompletion, ScheduledCancellation and ScheduledReplacement each own presentation modules, while their terminal/effect loops still live in Tui.Cli. This is split pressure, not a split verdict. The next test is whether moving a coherent session cluster reduces Tui.Cli change coupling without creating navigation-only files.",
        "nodes": [
            ("action", "Record presentation module"),
            ("action", "recordLoop retained in Tui.Cli"),
            ("action", "Correction presentation module"),
            ("action", "correctionLoop retained in Tui.Cli"),
            ("action", "ActualDateCorrection presentation module"),
            ("action", "actualDateCorrectionLoop retained in Tui.Cli"),
            ("action", "Scheduled terminal presentation modules"),
            ("action", "completion / cancellation / replacement loops retained in Tui.Cli"),
            ("decision", "Do these loops change independently of root navigation?", "CHECK HISTORY + FOCUSED EXTRACTION"),
        ],
    },
    "MGA.009.4 Stop Rule": {
        "description": "Prevent the coarse-file audit from turning into style-driven decomposition.",
        "sources": "docs/research/MODULE_GRANULARITY_AUDIT.md; Loam/Tui/Cli.lean",
        "audit": "A split graduates only when it isolates a real ownership/effect/change boundary and reduces cross-feature coupling. Creating one file per function or per screen merely for symmetry is explicitly out of scope.",
        "nodes": [
            ("action", "Measure source responsibility + history"),
            ("decision", "Independent change/effect boundary?", "YES"),
            ("action", "try one narrow extraction"),
            ("action", "qualify build + focused TUI tests"),
            ("decision", "Navigation/coupling improves?", "YES -> SPLIT_CANDIDATE earns implementation"),
            ("action", "Otherwise KEEP Tui.Cli as composition root"),
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
            ("LOAM MGA.009 - TUI CLI module granularity",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "MGA.009 TUI CLI module granularity")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("TUI CLI granularity diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing TUI CLI granularity source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
