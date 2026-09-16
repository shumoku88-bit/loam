#!/usr/bin/env python3
"""Build the module-granularity audit map for the large production TUI CLI."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-tui-cli-granularity-audit.drn"

DIAGRAMS = {
    "MGA.009.1 TUI CLI Responsibility Fanout": {
        "description": "Expose the distinct responsibilities still meeting in Loam.Tui.Cli after the first focused session extraction.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/Main.lean; Loam/Tui/Reports.lean; Loam/Tui/RecordSession.lean; Loam/Tui/CorrectionSession.lean",
        "audit": "Tui.Cli remains the production terminal composition root. PRs #961 and #964 removed the Record and Correction terminal/effect loops, but key grammars, snapshot/config loading, four local editor loops, Home/Actual/Scheduled/SelectedDay orchestration, report query execution, and administration entrances still meet here. The Record result proves that raw module count is only candidate evidence; responsibility ownership decides the boundary.",
        "nodes": [
            ("insertion", "loamTui main / terminal entrance"),
            ("action", "resolve data directory + current authority roots"),
            ("action", "load shared snapshot / catalogs / presets"),
            ("action", "map terminal keys to Home / Actual / Scheduled / SelectedDay events"),
            ("action", "delegate extracted terminal sessions\nRecord / Correction / creation / routing / capacity / admission / reversal"),
            ("action", "run remaining local editor loops\nDate / Completion / Cancellation / Replacement"),
            ("action", "orchestrate HRA Home / Actual / Scheduled / SelectedDay"),
            ("action", "dispatch Reports queries + redraw"),
            ("action", "reload canonical evidence after successful writes"),
            ("decision", "One independent reason to change?", "NO - several families remain"),
        ],
    },
    "MGA.010.1 Qualified Record Session Seam": {
        "description": "Record the first focused split that graduated from candidate pressure to a qualified ownership boundary.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/Record.lean; Loam/Tui/RecordSession.lean; Loam/HouseholdCommand.lean; PR #961",
        "audit": "Record owns editor state, validation, transitions and view. RecordSession owns one terminal/effect shell: key reads, dirty redraws and publication delegation. HouseholdCommand.record remains the authoritative write entrance, while Tui.Cli still loads the selected world, reloads canonical evidence and chooses the destination surface. PR #961 passed Production TUI, Compression Audit, Module granularity inventory and Selected Lean Observations. The split is therefore qualified even though it adds one small one-consumer module.",
        "nodes": [
            ("action", "Record.State / Step / view"),
            ("insertion", "RecordSession.run"),
            ("action", "read terminal key"),
            ("action", "Record.update + dirty redraw"),
            ("decision", "Step publishes draft?", "YES"),
            ("insertion", "HouseholdCommand.record"),
            ("action", "return human-facing completion notice"),
            ("action", "caller reloads canonical evidence + chooses destination"),
            ("decision", "Independent effect/change boundary qualified?", "YES - KEEP_BOUNDARY / SPLIT QUALIFIED"),
        ],
    },
    "MGA.011.1 Qualified Correction Session Seam": {
        "description": "Record the second focused split and use it to calibrate the next anti-symmetry control.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/Correction.lean; Loam/Tui/CorrectionSession.lean; Loam/HouseholdCommand.lean; PR #964",
        "audit": "Correction owns replacement-editor state, validation, transitions and view. CorrectionSession owns key reads, dirty redraws, publication delegation and retry-on-publication-error. HouseholdCommand.correctActual remains authoritative, while Tui.Cli keeps canonical reload and workspace destination. PR #964 passed Production TUI, Compression Audit, Module granularity inventory, Selected Lean Observations and Purpose Catalog Boundary. The boundary therefore qualifies even though it adds another small one-consumer module.",
        "nodes": [
            ("action", "Correction.State / Step / view"),
            ("insertion", "CorrectionSession.run"),
            ("action", "read terminal key"),
            ("action", "Correction.update + dirty redraw"),
            ("decision", "Step publishes draft?", "YES"),
            ("insertion", "HouseholdCommand.correctActual"),
            ("action", "publication refusal returns to same editor"),
            ("action", "caller reloads canonical evidence + chooses destination"),
            ("decision", "Independent effect/change boundary qualified?", "YES - KEEP_BOUNDARY / SPLIT QUALIFIED"),
        ],
    },
    "MGA.012.1 Actual Date Anti-Symmetry Control": {
        "description": "Compare keeping the tiny ActualDateCorrection loop in Tui.Cli against extracting another Session module before making a symmetry-driven change.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/ActualDateCorrection.lean; Loam/HouseholdCommand.lean; docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md",
        "audit": "ActualDateCorrection already owns date-editor state, validation, transitions and view. Its local Tui.Cli loop owns key reads, dirty redraws, HouseholdCommand.correctActualDate delegation and retry on refusal. That resembles the two qualified session seams, but the shell is especially small. MGA-012 is therefore an anti-symmetry control: compare INLINE versus SESSION and extract only if ownership and navigation improve for an independent reason, not merely because RecordSession and CorrectionSession exist.",
        "nodes": [
            ("action", "ActualDateCorrection.State / Step / view"),
            ("action", "current local loop in Tui.Cli"),
            ("decision", "Effect shell has independent change reason?", "TO TEST"),
            ("action", "Shape A: keep loop inline"),
            ("action", "Shape B: extract ActualDateCorrectionSession"),
            ("decision", "Only argument is naming symmetry?", "YES -> KEEP INLINE"),
            ("decision", "Ownership/navigation materially clearer?", "YES -> narrow extraction experiment"),
        ],
    },
    "MGA.010.3 Stop Rule": {
        "description": "Calibrate the coarse-file audit with the Record result and constrain the next experiment.",
        "sources": "docs/research/MODULE_GRANULARITY_AUDIT.md; docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md; Loam/Tui/Cli.lean; Loam/Tui/RecordSession.lean",
        "audit": "MGA-010 demonstrates that a justified split may increase file count, small-module count, one-consumer count and composition-root fan-out. Those metrics remain useful detectors but are not verdicts. A split graduates only when it isolates a real ownership/effect/change boundary, preserves semantic and authority ownership, and passes focused qualification. Record and Correction are qualified; the next test is whether the much smaller ActualDateCorrection shell deserves a boundary at all.",
        "nodes": [
            ("action", "Observe raw granularity metrics"),
            ("decision", "Metrics worsen after a split?", "NOT A VETO"),
            ("decision", "Independent ownership/effect boundary?", "YES"),
            ("action", "try one narrow extraction"),
            ("action", "qualify Production TUI + Compression + inventory"),
            ("decision", "Boundary stays coherent and navigation improves?", "YES -> graduate"),
            ("action", "Next test: compare INLINE vs SESSION for ActualDateCorrection"),
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
            ("LOAM MGA.009-012 - TUI CLI module granularity",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "MGA.009-012 TUI CLI module granularity")
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
