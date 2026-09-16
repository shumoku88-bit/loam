#!/usr/bin/env python3
"""Build the Generation-2 G2-034 closure audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-generation-2-closure-audit.drn"

DIAGRAMS = {
    "G2.034.1 Campaign Waves": {
        "description": "Generation-2 coverage from read topology through final frontier falsification.",
        "sources": "docs/research/AUDIT_GENERATION_2_CHECKPOINT_031.md; docs/research/ATTENTION_DELIVERY_CLOSURE_OBLIGATION_DAG.md; docs/research/SCHEDULED_TERMINAL_ASYMMETRY_OBLIGATION_DAG.md; docs/research/AUDIT_GENERATION_2_CLOSURE_034.md",
        "audit": "The campaign crossed read/report, write/admission, derived-state, and TUI/root ownership surfaces before entering a closing sequence. G2-032 and G2-033 produced targeted KEEP results; G2-034 rechecks the remaining thin families rather than opening another local refactor search.",
        "nodes": [
            ("action", "G2-001..009\nread / report topology"),
            ("action", "G2-010..021\nwrite / admission topology"),
            ("action", "G2-022..031\nderived state + TUI/root"),
            ("action", "G2-032\nAttention closure"),
            ("action", "G2-033\nScheduled terminal KEEP"),
            ("action", "G2-034\nfinal broad falsification"),
            ("action", "Generation 2 COMPLETE"),
        ],
    },
    "G2.034.2 Final Thin Families": {
        "description": "Final falsification of the thin production families left by the G2-031 checkpoint.",
        "sources": "Loam/RoleFlowReview.lean; Loam/Tui/Cli.lean; Loam/CapacityPublisher.lean; docs/research/CAPACITY_ENTRY_OBLIGATION_DAG.md; docs/research/ATTENTION_DELIVERY_CLOSURE_OBLIGATION_DAG.md; docs/research/RELATION_PUBLICATION_OBLIGATION_DAG.md; docs/research/SCHEDULED_TERMINAL_ASYMMETRY_OBLIGATION_DAG.md",
        "audit": "RoleFlow is a thin overlay on one admitted TransactionsFlow snapshot; Capacity already shares the earned publication tail while retaining distinct admission; Attention, relation publication, and Scheduled terminal recovery have explicit closure evidence. No unexplained major family remains.",
        "nodes": [
            ("decision", "remaining thin family"),
            ("action", "RoleFlow\nexisting flow + role overlay"),
            ("action", "Capacity\nshared tail + local admission"),
            ("action", "Attention\nG2-032 closed"),
            ("action", "Relation\nG2-011 sufficient"),
            ("action", "Scheduled terminal\nG2-033 earned asymmetry"),
            ("decision", "new semantic pressure?", "No"),
            ("action", "No production refactor"),
            ("action", "STOP mining"),
        ],
    },
    "G2.034.3 Closure Criteria": {
        "description": "Apply the explicit stop criteria declared at the G2-031 coverage checkpoint.",
        "sources": "docs/research/AUDIT_GENERATION_2_CHECKPOINT_031.md; docs/research/AUDIT_GENERATION_2_CLOSURE_034.md",
        "audit": "All five closure conditions are satisfied: major read families are mapped or explicitly stopped; major write families have cross-path evidence or KEEP boundaries; TUI/root ownership has no known duplicate semantic owner; module granularity remains a separate calibrated track; and consecutive frontier audits no longer produce high-value structural pressure.",
        "nodes": [
            ("decision", "major reads explained?", "Yes"),
            ("decision", "major writes explained?", "Yes"),
            ("decision", "duplicate TUI/root owner known?", "No"),
            ("decision", "MGA is separate calibrated track?", "Yes"),
            ("decision", "frontier still yields pressure?", "No"),
            ("action", "Closure criteria satisfied"),
            ("action", "Generation 2 COMPLETE"),
        ],
    },
    "G2.034.4 Reopen Gate": {
        "description": "Conditions that justify a later audit campaign after Generation 2 is closed.",
        "sources": "docs/research/AUDIT_GENERATION_2_CLOSURE_034.md",
        "audit": "Generation 2 should not silently continue. A later campaign is earned only by new evidence such as duplicate semantic engines, repeated authority admission, derivable canonical fields, multi-generation report reads, unreachable compatibility surface, unexplained recovery order, or real data that forces duplicated side state.",
        "nodes": [
            ("action", "Generation 2 closed"),
            ("decision", "new concrete pressure?", "No: stay closed"),
            ("action", "duplicate semantic engine?"),
            ("action", "repeated admission / publication?"),
            ("action", "derivable canonical state?"),
            ("action", "same-answer multi-generation read?"),
            ("action", "ownerless legacy / recovery gap?"),
            ("action", "real data exposes missing distinction?"),
            ("action", "Open a NEW scoped campaign"),
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
            ("LOAM G2.034 - Generation 2 closure",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.034 Generation 2 Closure")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Generation-2 closure audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing Generation-2 closure source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
