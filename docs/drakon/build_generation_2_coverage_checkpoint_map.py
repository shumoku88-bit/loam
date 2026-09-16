#!/usr/bin/env python3
"""Build the Generation-2 coverage checkpoint map at G2-031."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-generation-2-coverage-checkpoint.drn"

DIAGRAMS = {
    "G2.CP.1 Campaign Waves": {
        "description": "Show the three broad observation waves that carried Generation 2 from read topology through write/admission topology into retained-state and TUI ownership work.",
        "sources": "docs/research/AUDIT_GENERATION_2_CHECKPOINT_031.md; repository history G2-001..G2-031",
        "audit": "The numbered observations are not one linear refactor. G2-001..009 pressure read/projection/report topology, G2-010..021 pressure write/admission/publication topology, and G2-022..031 pressure retained derivations and TUI/root ownership. The campaign has therefore crossed the major semantic surfaces rather than remaining concentrated in one subsystem.",
        "nodes": [
            ("action", "G2-001 .. G2-009\nread / projection / report topology"),
            ("action", "G2-010 .. G2-021\nwrite / admission / publication topology"),
            ("action", "G2-022 .. G2-031\nderived summaries + TUI/root ownership"),
            ("action", "31 observations\nKEEP + FIX + SIMPLIFY all represented"),
            ("action", "campaign is broad, not exploratory-only"),
        ],
    },
    "G2.CP.2 Coverage Depth": {
        "description": "Classify current audit depth by semantic area without turning the labels into percentage claims.",
        "sources": "docs/research/AUDIT_GENERATION_2_CHECKPOINT_031.md; docs/drakon/READ_PATH_ATLAS.md; docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md",
        "audit": "Read/report and write/admission coverage are broad; TUI/root ownership is deep after G2-026..031; module granularity has calibrated both KEEP and SPLIT outcomes; obligation DAGs are mature enough to guide branchy questions but remain selective by design.",
        "nodes": [
            ("action", "Read / report semantics\nBROAD"),
            ("action", "Write / admission semantics\nBROAD"),
            ("action", "TUI / root ownership\nDEEP"),
            ("action", "Module granularity\nCALIBRATED"),
            ("action", "Obligation DAGs\nSELECTIVE, MATURE"),
            ("action", "Do not continue broad sweeps without new pressure"),
        ],
    },
    "G2.CP.3 Current Frontier": {
        "description": "Identify the highest-information remaining surfaces after G2-031 instead of continuing from the most recently touched TUI code.",
        "sources": "docs/research/AUDIT_GENERATION_2_CHECKPOINT_031.md; Loam/RoleFlowReview.lean; Loam/CapacityPublisher.lean; Loam/AttentionReview.lean",
        "audit": "The current frontier is targeted hole-filling: first compare RoleFlowReview with already-audited role/transaction reads, then compare Capacity transfer/rebalance publication with the audited entry boundary, then close the Attention lifecycle question starting from G2-009. Each may legitimately end in KEEP.",
        "nodes": [
            ("action", "RoleFlowReview\nsame-scale read audit"),
            ("decision", "new structural pressure?", "YES -> focused G2 observation"),
            ("action", "Capacity transfer / rebalance\ncross-publisher comparison"),
            ("decision", "new structural pressure?", "YES -> focused G2 observation"),
            ("action", "Attention lifecycle\nend-to-end closure check"),
            ("action", "KEEP is a successful result"),
        ],
    },
    "G2.CP.4 Stop Rule": {
        "description": "Make Generation-2 completion depend on exhausted structural pressure rather than an arbitrary observation count.",
        "sources": "docs/research/AUDIT_GENERATION_2_CHECKPOINT_031.md",
        "audit": "Generation 2 should close when major read/write families have either same-scale evidence or explicit KEEP reasons, TUI/root has no known duplicate semantic owner, module inventory has no unexplained production-like unreachable surface, and consecutive targeted audits stop finding new pressure.",
        "nodes": [
            ("decision", "major production family still thin?", "YES -> targeted audit"),
            ("decision", "known duplicate state / authority / derived echo?", "YES -> investigate"),
            ("decision", "unexplained unreachable or root ownership pressure?", "YES -> MGA / reachability"),
            ("decision", "2-3 targeted audits produce only KEEP / no-new-pressure?", "YES"),
            ("action", "Generation 2 closure candidate"),
            ("action", "reopen only when new product work creates fresh pressure"),
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
            ("LOAM Generation 2 - Coverage Checkpoint at G2-031",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "Generation-2 Coverage Checkpoint")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Generation-2 coverage checkpoint diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing Generation-2 coverage source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
