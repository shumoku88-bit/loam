#!/usr/bin/env python3
"""Build the Generation-2 G2-033 Scheduled terminal asymmetry audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-scheduled-terminal-asymmetry-audit.drn"

DIAGRAMS = {
    "G2.033.1 Shared Terminal Boundary": {
        "description": "The mechanics completion and cancellation genuinely share before their operation-specific admission diverges.",
        "sources": "Loam/ScheduledTerminalPublisher.lean; Loam/Application/ScheduledInspection.lean; Loam/ScheduledActualOwnership.lean; PR #696; PR #706; PR #848",
        "audit": "Earlier compression already shared the selected terminal relation, lifecycle projection, target lookup, and Scheduled-to-Actual ownership order. Generation 2 therefore does not search for another physical common tail merely because completion and cancellation live in one publisher.",
        "nodes": [
            ("action", "terminal operation request"),
            ("action", "ScheduledActualOwnership"),
            ("action", "load Scheduled lifecycle"),
            ("action", "load current Actual evidence"),
            ("action", "Application.currentOpenScheduled"),
            ("action", "findOpen? when operation permits"),
            ("action", "shared terminal meaning already compressed"),
            ("action", "KEEP shared boundary"),
        ],
    },
    "G2.033.2 Interrupted Completion Counterexample": {
        "description": "Why current-open projection cannot by itself authorize cancellation.",
        "sources": "Loam/ScheduledTerminalPublisher.lean; experiments/116_ui_action_admission.md; experiments/116_ui_action_admission.als; experiments/118_ui_stale_admission.md",
        "audit": "An interrupted completion retains a Scheduled-to-Actual claim while the Actual Event is absent. Readers deliberately keep that occurrence visible as open, but cancellation must refuse because publishing retirement would compete with the retained completion claim. Observation 116 supplies the static counterexample and Observation 118 supplies the stale-activation interleaving counterexample.",
        "nodes": [
            ("action", "completion claim retained"),
            ("decision", "Actual Event exists?", "Interrupted completion"),
            ("action", "effective completion"),
            ("action", "read projection: not open"),
            ("action", "read projection: still open"),
            ("decision", "Cancel from open projection?", "REFUSE raw completion claim"),
            ("action", "naive open => Cancel is unsound"),
            ("action", "KEEP admission asymmetry"),
        ],
    },
    "G2.033.3 Completion vs Cancellation": {
        "description": "Same-scale operation obligations for completion/retry and cancellation.",
        "sources": "Loam/ScheduledTerminalPublisher.lean; Loam/Tests/ScheduledTerminalPublisher.lean; Loam/LocusAdmissionAuthority.lean; Loam/ActualAuthority.lean",
        "audit": "Completion owns Actual construction, current Locus admission, deterministic/recoverable endpoint ownership, relation-first publication and Actual publication. Cancellation writes no Actual Event but must exclude every retained completion claim before appending retirement. Those are distinct reasons to change, not duplicated implementations of one condition.",
        "nodes": [
            ("decision", "terminal command"),
            ("action", "COMPLETION / RETRY"),
            ("action", "current-open + Locus + Actual draft admission"),
            ("action", "reuse or allocate completion endpoint"),
            ("action", "completion claim FIRST; Actual SECOND"),
            ("action", "CANCELLATION"),
            ("decision", "any completion claim?", "refuse completed/interrupted"),
            ("action", "require current-open"),
            ("action", "append retirement only"),
            ("action", "KEEP LOCAL obligations"),
        ],
    },
    "G2.033.4 Stop Verdict": {
        "description": "Generation-2 stop decision for the Scheduled terminal family.",
        "sources": "docs/research/SCHEDULED_TERMINAL_ASYMMETRY_OBLIGATION_DAG.md; docs/research/AUDIT_GENERATION_2_CHECKPOINT_031.md; docs/research/ATTENTION_DELIVERY_CLOSURE_OBLIGATION_DAG.md",
        "audit": "No production change follows. The apparent asymmetry is required by retained recovery evidence and is backed by Alloy, SPIN, runtime regression and the current ownership boundary. G2-033 is the second targeted KEEP/no-new-pressure result after the G2-031 checkpoint, so one final broad falsification pass is more informative than another local refactor hunt.",
        "nodes": [
            ("action", "G2-031 coverage checkpoint"),
            ("action", "G2-032 Attention\nKEEP / closed"),
            ("action", "G2-033 Scheduled terminal\nKEEP / earned asymmetry"),
            ("decision", "new structural pressure?", "No production refactor"),
            ("action", "second consecutive stop result"),
            ("action", "next: final broad falsification pass"),
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
            ("LOAM G2.033 - Scheduled terminal asymmetry",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.033 Scheduled Terminal")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Scheduled terminal asymmetry audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing Scheduled terminal source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
