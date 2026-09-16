#!/usr/bin/env python3
"""Build the Generation-2 HRA Scheduled Unknown-preservation audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-tui-hra-scheduled-unknown-audit.drn"

DIAGRAMS = {
    "G2.029.1 Production Unknown Collapse": {
        "description": "Show the current production path that collapses Scheduled day Unknown into an empty successful row list.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/HraScheduled.lean; Loam/ScheduledReview.lean",
        "audit": "Home p enters HraScheduled. Focus Day calls ScheduledReview.dayEvidence; current adapter maps .unknown to .ok [], and the empty-success view labels that state as none due on this day.",
        "nodes": [
            ("insertion", "Home p -> HraScheduled"),
            ("action", "ScheduledReview.dayEvidence focusDate"),
            ("decision", "Result is Unknown?", "YES"),
            ("action", "current: .ok []"),
            ("action", "current label: none due on this day"),
            ("action", "information distinction lost"),
        ],
    },
    "G2.029.2 Preserve Open-World Result": {
        "description": "Keep Unknown explicit in the presentation adapter while allowing list projection for local mechanics.",
        "sources": "Loam/Tui/HraScheduled.lean; docs/drakon/ARCHITECTURE_LAWS.md",
        "audit": "Use an explicit ScopeEvidence result: records vs unknown, with errors remaining fail-closed. Local cursor mechanics may project records, but presentation completeness must inspect ScopeEvidence.",
        "nodes": [
            ("action", "ScheduledReview day evidence"),
            ("decision", "Due records?", "YES"),
            ("action", "ScopeEvidence.records"),
            ("decision", "Unknown?", "YES"),
            ("action", "ScopeEvidence.unknown"),
            ("action", "render Unknown explicitly"),
        ],
    },
    "G2.029.3 Stop Point": {
        "description": "Fix only the production HRA adapter; do not mix this change with legacy workspace retirement.",
        "sources": "Loam/Tui/HraScheduled.lean; Loam/Tui/Main.lean; Loam/Tests/TuiHraScheduled.lean; Loam/Tests/TuiScheduled.lean",
        "audit": "Preserve all HRA mechanics, shared review semantics, and legacy Main Scheduled path until the production HRA surface independently carries the Unknown guarantee. Compatibility retirement is a later audit.",
        "nodes": [
            ("action", "FIX HraScheduled Unknown preservation"),
            ("action", "KEEP ScheduledReview semantics"),
            ("action", "KEEP HRA browsing/actions"),
            ("action", "KEEP legacy Main Scheduled for this PR"),
            ("action", "qualify production tests"),
        ],
    },
}


def build() -> None:
    if OUTPUT.exists():
        OUTPUT.unlink()
    conn = sqlite3.connect(OUTPUT)
    try:
        base.create_schema(conn)
        for name, spec in DIAGRAMS.items():
            diagram_id = base.insert_diagram(conn, name, spec["description"])
            base.insert_parameter(conn, diagram_id, "sources", spec["sources"])
            base.insert_parameter(conn, diagram_id, "audit", spec["audit"])
            base.insert_linear_nodes(conn, diagram_id, spec["nodes"])
        conn.commit()
        result = conn.execute("PRAGMA integrity_check").fetchone()
        if result != ("ok",):
            raise RuntimeError(f"DRAKON database integrity failed: {result}")
        count = conn.execute("SELECT COUNT(*) FROM diagrams").fetchone()[0]
        if count != len(DIAGRAMS):
            raise RuntimeError(f"expected {len(DIAGRAMS)} diagrams, found {count}")
    finally:
        conn.close()


if __name__ == "__main__":
    build()
    print(OUTPUT)
