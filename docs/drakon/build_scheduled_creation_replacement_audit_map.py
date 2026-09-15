#!/usr/bin/env python3
"""Build the Generation-2 Scheduled Creation / Replacement audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-scheduled-creation-replacement-audit.drn"

DIAGRAMS = {
    "G2.010.1 Scheduled Creation / Replacement Comparison": {
        "description": "Scheduled Creation and Replacement writers at one semantic scale after removing one derived runtime guard.",
        "sources": "Loam/ScheduledCreationPublisher.lean; Loam/ScheduledReplacementPublisher.lean; Loam/ScheduledOccurrenceConstruction.lean; Loam/ScheduledActualOwnership.lean",
        "audit": "Both writers share fixed Scheduled-to-Actual ownership, practical draft shape, current Locus policy, one admitted lifecycle image and total fresh Scheduled identity. DRAKON exposed a repeated positive-total decision after nonempty/nonzero BalancedMovement admission; Lean proved that decision derivable and G2-010 removed it from both paths. Replacement still owns retained-source, already-replaced, current-open and terminal-relation obligations, so one generic Scheduled publisher is not earned.",
        "nodes": [
            ("action", "CREATION"),
            ("action", "validate date / JPY / nonempty / token+nonzero"),
            ("insertion", "BalancedMovement proof\npositive side derived"),
            ("insertion", "Scheduled -> Actual ownership"),
            ("insertion", "lifecycle + Actual + Locus admission"),
            ("decision", "all movement Loci admitted?"),
            ("action", "lifecycle readable"),
            ("insertion", "freshId\nshared total mechanic"),
            ("action", "append one occurrence"),
            ("action", "publish lifecycle image"),
            ("action", "REPLACEMENT"),
            ("action", "validate date / JPY / nonempty / token+nonzero"),
            ("insertion", "BalancedMovement proof\npositive side derived"),
            ("insertion", "Scheduled -> Actual ownership"),
            ("insertion", "lifecycle + Actual + Locus admission"),
            ("decision", "all movement Loci admitted?"),
            ("decision", "source retained?"),
            ("decision", "already replaced?"),
            ("decision", "source current-open?"),
            ("insertion", "freshId\nshared total mechanic"),
            ("action", "append successor occurrence"),
            ("action", "append source -> successor terminal"),
            ("action", "publish ONE lifecycle image"),
        ],
    },
    "G2.010.2 Derived Positive-Side Obligation": {
        "description": "Replace a duplicated runtime decision with a proved consequence of retained movement evidence.",
        "sources": "Loam/Core/BalancedMovement.lean; Loam/ScheduledOccurrenceConstruction.lean; Loam/ScheduledCreationPublisher.lean; Loam/ScheduledReplacementPublisher.lean",
        "audit": "After #767, both drafts already carry BalancedMovement. Each publisher independently establishes that changes are nonempty and every retained quantity is nonzero. Exact signed balance then implies that at least one retained quantity is positive. positiveTotalQuanta_pos_of_nonempty_nonzero proves this, so the old positiveTotalQuanta <= 0 refusal branch was derived rather than independent and has been removed from both production writers.",
        "nodes": [
            ("insertion", "BalancedMovement\nsigned total = 0"),
            ("decision", "changes nonempty?"),
            ("decision", "every quantity nonzero?"),
            ("action", "Lean theorem\npositive side must exist"),
            ("action", "positiveTotalQuanta > 0"),
            ("action", "DELETE runtime positive-total decision"),
        ],
    },
    "G2.010.3 Already-Earned Shared Seam / Stop Point": {
        "description": "Show what is shared, what was simplified, and why the remaining similarity stays local.",
        "sources": "Loam/ScheduledOccurrenceConstruction.lean; Loam/ScheduledActualOwnership.lean; Loam/Application/ScheduledInspection.lean; docs/research/SEMANTIC_AUDIT_SA008_SCHEDULED.md; commits 0338ed7964a0acbee70eb03c1b7063b95813af72, 718d34ca12107de11845aa6882350a6874b8283c, 3dff2fa0be66e8a6db4f9f2496725d8a8f1ad02c",
        "audit": "#730 promoted shared occurrence construction, #767 made drafts canonical BalancedMovement, and #864 made numbered allocation total. G2-010 removes the one remaining validation branch that is mathematically derivable. The surviving repeated checks carry operation-local diagnostics; occurrence literals own no new law; currentOpen string mapping is adapter policy; Replacement source checks have an independent refusal order. A larger generic validation or Scheduled writer layer would add more conceptual surface than it removes.",
        "nodes": [
            ("action", "#730 shared occurrence construction"),
            ("action", "#767 canonical BalancedMovement drafts"),
            ("action", "#864 total fresh identity"),
            ("action", "G2-010 derive + delete positive guard"),
            ("insertion", "ScheduledActualOwnership.withOwnership"),
            ("insertion", "ScheduledOccurrenceConstruction.freshId"),
            ("insertion", "positiveTotalQuanta\nderived value for display/receipt"),
            ("action", "date / JPY / nonempty / token+nonzero\nKEEP local diagnostics"),
            ("action", "Replacement transition obligations\nKEEP local"),
            ("action", "KEEP current shared seam"),
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
            ("LOAM G2.010 - Scheduled Creation / Replacement write topology",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.010 Scheduled Creation / Replacement")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Scheduled Creation/Replacement audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing Scheduled Creation/Replacement source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
