#!/usr/bin/env python3
"""Build the Generation-2 TUI undated-count derivation audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-tui-undated-count-derivation-audit.drn"

DIAGRAMS = {
    "G2.027.1 Undated Count Dependency": {
        "description": "Show that ActualSnapshot.undatedCount is an exact consequence of retained Actual review records.",
        "sources": "Loam/Tui/Main.lean; Loam/Tui/Cli.lean; Loam/ActualReview.lean",
        "audit": "The production loader retains allRecords and independently stores the length of ActualReview.select allRecords .undated. The count has no authority or admission meaning beyond those records.",
        "nodes": [
            ("action", "Load admitted Actual review records"),
            ("action", "retain allRecords"),
            ("action", "select .undated"),
            ("action", "mergeSort selected records"),
            ("action", "retain undatedCount := length"),
            ("decision", "Can count differ from allRecords consequence?", "YES - structure permits contradiction"),
        ],
    },
    "G2.027.2 Production Reachability": {
        "description": "Separate the production HRA Home route from the legacy Main Home route that consumes the count.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/HraHome.lean; Loam/Tui/Main.lean",
        "audit": "compiledFrameFor renders through HraHome.view. HraHome intercepts the Home surface and does not read undatedCount; it delegates only non-Home surfaces to Main.view. The count is therefore not consumed by the production Home path.",
        "nodes": [
            ("insertion", "compiledFrameFor"),
            ("insertion", "HraHome.view"),
            ("decision", "Surface is Home?", "YES"),
            ("action", "HraHome.homeView\nno undatedCount read"),
            ("decision", "Surface is non-Home?", "YES"),
            ("insertion", "Main.view"),
            ("action", "legacy Main.homeView is not reached through production Home"),
        ],
    },
    "G2.027.3 Keep Semantic Query": {
        "description": "Remove only redundant snapshot retention while preserving the real undated read question.",
        "sources": "Loam/ActualReview.lean; Loam/Cli/ReviewCli.lean",
        "audit": "ActualReview.Query.undated remains a real read-side operation used by the CLI. G2-027 targets only the independent TUI snapshot count, not undated semantics or correction/validity admission.",
        "nodes": [
            ("action", "KEEP Query.undated"),
            ("action", "KEEP predicate\ncurrent && date none"),
            ("action", "KEEP CLI undated review"),
            ("action", "SIMPLIFY snapshot field"),
            ("action", "derive only where a presentation actually consumes the count"),
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
            ("LOAM G2.027 - TUI undated count derivation",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.027 TUI undated count derivation")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("TUI undated-count audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing TUI undated-count source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
