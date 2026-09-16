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
    "MGA.012.1 Actual Date Anti-Symmetry Verdict": {
        "description": "Record the negative control: keep the tiny ActualDateCorrection terminal loop inline instead of copying the Session naming pattern.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/ActualDateCorrection.lean; Loam/HouseholdCommand.lean; PR #519; docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md",
        "audit": "ActualDateCorrection already owns state, validation, transitions, publication intent and view, while HouseholdCommand.correctActualDate remains authoritative. The local terminal loop has one selected-day caller and no reusable world/catalog context. Extracting it would not remove the surrounding selected-record lookup, initial editor construction, canonical reload, SelectedDay refresh, or destination redraw from Tui.Cli. File history shows the editor and terminal wiring were introduced together in PR #519 and have not shown an independent change history. MGA-012 therefore keeps the shell inline: logical separability alone does not justify another physical module.",
        "nodes": [
            ("action", "ActualDateCorrection.State / Step / view"),
            ("action", "tiny terminal/effect loop stays in Tui.Cli"),
            ("insertion", "HouseholdCommand.correctActualDate"),
            ("action", "caller reloads canonical evidence + refreshes SelectedDay"),
            ("decision", "Would Session extraction remove workflow coupling?", "NO"),
            ("decision", "Independent history / reuse / ownership pressure?", "NO EVIDENCE YET"),
            ("decision", "Split only for Record/Correction symmetry?", "REJECT"),
            ("action", "KEEP_INLINE / SPLIT_REJECTED"),
        ],
    },
    "MGA.012.2 Physical Boundary Stop Rule": {
        "description": "Calibrate physical module creation with two positive session splits and one deliberate negative control.",
        "sources": "docs/research/MODULE_GRANULARITY_AUDIT.md; docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md; Loam/Tui/Cli.lean; Loam/Tui/RecordSession.lean; Loam/Tui/CorrectionSession.lean; Loam/Tui/ActualDateCorrection.lean",
        "audit": "MGA-010 and MGA-011 show that justified effect/session boundaries can increase raw module counts while reducing responsibility coupling. MGA-012 supplies the necessary negative control: a logically distinct tiny effect shell can still remain inline when extraction does not materially improve navigation, reuse, ownership, or change independence. The next audit compares the three remaining Scheduled loops by their actual continuation topology rather than by naming symmetry.",
        "nodes": [
            ("action", "Observe semantic ownership + effect topology + history"),
            ("decision", "Logical responsibility is distinct?", "CANDIDATE ONLY"),
            ("decision", "Physical split materially improves navigation / reuse / change independence?", "REQUIRED"),
            ("action", "Record + Correction: split qualified"),
            ("action", "ActualDateCorrection: keep inline"),
            ("decision", "Naming symmetry alone?", "NEVER A SPLIT REASON"),
            ("action", "Next: compare Completion / Cancellation / Replacement topology"),
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
            ("LOAM MGA.009-013 - TUI CLI module granularity",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "MGA.009-013 TUI CLI module granularity")
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
