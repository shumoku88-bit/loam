#!/usr/bin/env python3
"""Build the post-MGA-014 Scheduled TUI session/continuation audit map."""

from pathlib import Path
import sqlite3
import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-tui-scheduled-session-audit.drn"

DIAGRAMS = {
    "MGA.014.1 Qualified Scheduled Replacement Session Seam": {
        "description": "Record the post-#968 Scheduled Replacement split that graduated after production and inventory qualification.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/ScheduledReplacement.lean; Loam/Tui/ScheduledReplacementSession.lean; Loam/HouseholdCommand.lean; docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md; PR #971",
        "audit": "ScheduledReplacement owns editor state, validation, preview, transitions and view. ScheduledReplacementSession owns key reads, dirty redraws, HouseholdCommand.replaceScheduled delegation and retry after refusal. HraScheduled and SelectedDay share the Session while retaining selection, vocabulary loading, canonical reload and destination refresh. PR #971 passed Production TUI 62/62, Compression Audit, module inventory, Selected Lean Observations and Purpose Catalog Boundary; production-like unreachable remained zero.",
        "nodes": [
            ("action", "ScheduledReplacement.State / validation / preview / view"),
            ("insertion", "ScheduledReplacementSession.run"),
            ("action", "read terminal key + update + dirty redraw"),
            ("decision", "Step publishes draft?", "YES"),
            ("insertion", "HouseholdCommand.replaceScheduled"),
            ("decision", "publication refused?", "YES -> same editor retry"),
            ("action", "HraScheduled + SelectedDay share Session"),
            ("action", "callers retain selection + vocabulary + canonical reload + destination refresh"),
            ("decision", "Independent effect/change boundary qualified?", "YES - KEEP_BOUNDARY / SPLIT_QUALIFIED"),
        ],
    },
    "MGA.015.1 Scheduled Completion Continuation Seam": {
        "description": "Re-observe Completion after MGA-014 without copying Replacement's module shape blindly.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/ScheduledCompletion.lean; Loam/Tui/ScheduledCreation.lean; Loam/Tui/ScheduledCreationSession.lean; Loam/HouseholdCommand.lean; PR #642; PR #646; PR #971",
        "audit": "ScheduledCompletion still has a reusable terminal/effect shell shared by HraScheduled and SelectedDay: key reads, dirty redraws, HouseholdCommand.completeScheduled delegation and refusal retry. That shell returns only Bool. Successful completion then crosses a separate continuation seam owned by callers: seed an optional next Scheduled editor, run ScheduledCreationSession, optionally inherit routing, then reload canonical evidence and refresh the destination workspace. The Bool boundary means continuation semantics do not need to move with the terminal shell. MGA-015 therefore keeps Completion as a narrow SPLIT_CANDIDATE; any continuation deduplication must be audited separately rather than smuggled into the Session extraction.",
        "nodes": [
            ("action", "ScheduledCompletion.State wraps Record-shaped Actual editor"),
            ("action", "shared local completion terminal/effect shell"),
            ("action", "read key + update + dirty redraw"),
            ("decision", "completion draft published?", "NO -> continue editor / cancel"),
            ("insertion", "HouseholdCommand.completeScheduled"),
            ("decision", "publication refused?", "YES -> same editor retry"),
            ("action", "shell returns Bool only"),
            ("decision", "completed successfully?", "NO -> completion cancelled notice"),
            ("action", "caller seeds optional next Scheduled from completed record"),
            ("insertion", "ScheduledCreationSession.runWithScheduledId"),
            ("decision", "next Scheduled created?", "NO -> preserve completed result / no continuation"),
            ("insertion", "HouseholdCommand.inheritScheduledRouting"),
            ("action", "caller reloads canonical snapshot + refreshes workspace"),
            ("decision", "Must continuation move with terminal shell?", "NO - Bool seam already separates it"),
            ("action", "MGA-015: narrow CompletionSession experiment justified; continuation remains caller-owned"),
        ],
    },
    "MGA.015.2 Qualified Scheduled Completion Session Seam": {
        "description": "Record the narrow Completion terminal/effect split after production, inventory, and continuation-boundary qualification.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/ScheduledCompletion.lean; Loam/Tui/ScheduledCompletionSession.lean; Loam/Tui/ScheduledCreationSession.lean; Loam/HouseholdCommand.lean; docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md; PR #974",
        "audit": "PR #974 extracted only the reusable Completion terminal/effect shell. ScheduledCompletion still owns editor semantics; ScheduledCompletionSession owns key reads, dirty redraws, HouseholdCommand.completeScheduled delegation and refusal retry, and returns Bool only. HraScheduled and SelectedDay retain optional next-Scheduled creation, routing inheritance, canonical reload and destination refresh. Production TUI #812, Compression Audit #950, module inventory #20, Selected Lean Observations #1194 and Purpose Catalog Boundary #331 all succeeded. Inventory reports the new Session at 50 lines / one declaration / fan-in 1 / fan-out 5 / reachable, with zero production-like unreachable modules. The boundary therefore graduates to KEEP_BOUNDARY / SPLIT_QUALIFIED without absorbing continuation semantics.",
        "nodes": [
            ("action", "ScheduledCompletion.State / validation / preview / view"),
            ("insertion", "ScheduledCompletionSession.run"),
            ("action", "read terminal key + update + dirty redraw"),
            ("decision", "Step publishes completion draft?", "YES"),
            ("insertion", "HouseholdCommand.completeScheduled"),
            ("decision", "publication refused?", "YES -> same editor retry"),
            ("action", "Session returns Bool only"),
            ("decision", "completion published?", "NO -> cancellation notice"),
            ("action", "caller retains optional creation + routing inheritance + reload + workspace refresh"),
            ("action", "inventory: 50 lines / fan-in 1 / fan-out 5 / reachable"),
            ("decision", "Independent effect/change boundary qualified?", "YES - KEEP_BOUNDARY / SPLIT_QUALIFIED"),
        ],
    },
    "MGA.016.1 Qualified Scheduled Continuation Coordinator": {
        "description": "Record the shared post-completion continuation coordinator after two-caller, history, DAG, production, and reachability evidence converge.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/ScheduledContinuationSession.lean; Loam/Tui/ScheduledCreation.lean; Loam/Tui/ScheduledCreationSession.lean; Loam/HouseholdCommand.lean; Loam/ScheduledContinuationRouting.lean; docs/research/SCHEDULED_CONTINUATION_SESSION_OBLIGATION_DAG.md; docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md; PR #712; PR #796; PR #974; PR #977",
        "audit": "MGA-016 starts beyond MGA-015's Boolean completion stop line. HraScheduled and SelectedDay duplicated the same next-editor -> creation-session -> optional routing-inheritance -> notice corridor, and PR #712 provides historical parallel co-change evidence. The old none branch also re-tested a cancellation string even though runWithScheduledId returns none only on cancellation. ScheduledContinuationSession now owns only that common TUI composition; completion publication, catalog policy, routing semantics, canonical reload and workspace refresh remain outside it. Initial PR #977 qualification passed Production TUI #820 62/62, Compression Audit #958, Selected Lean Observations #1204 and Purpose Catalog Boundary #341. Inventory reports 72 lines / fan-in 1 / fan-out 8 / reachable=True; Tui.Cli is 1067 lines / 30 declarations / fan-out 58; production-like unreachable=0.",
        "nodes": [
            ("action", "ScheduledCompletionSession returns Bool stop line"),
            ("decision", "completion published?", "NO -> caller cancellation notice"),
            ("insertion", "ScheduledContinuationSession.runAfterCompletion"),
            ("decision", "next editor seed representable?", "NO -> completion + unavailable notice"),
            ("action", "execute caller-owned lazy Locus catalog action"),
            ("insertion", "ScheduledCreationSession.runWithScheduledId"),
            ("decision", "continuation created?", "NO -> completion + no-next notice"),
            ("insertion", "HouseholdCommand.inheritScheduledRouting"),
            ("action", "format creation + routing outcomes"),
            ("action", "return final notice to caller"),
            ("action", "caller retains canonical reload + workspace-specific refresh"),
            ("decision", "Independent coordinator boundary qualified?", "YES - KEEP_BOUNDARY / SPLIT_QUALIFIED"),
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
        db.execute("insert into state values (1,1,?)", ("LOAM MGA.014-016 - Scheduled session and continuation seams",))
        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)
        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "MGA.014-016 Scheduled session seams")
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
