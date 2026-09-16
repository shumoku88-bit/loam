#!/usr/bin/env python3
"""Build the Generation-2 OpeningSupport / Actual-correction audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-opening-support-correction-audit.drn"

DIAGRAMS = {
    "G2.016.1 Opening Support Before Correction": {
        "description": "Show the narrow current-balance claim represented by OpeningSupport before its named Event is superseded.",
        "sources": "Loam/Core/OpeningSupport.lean; Loam/RoleBalanceReview.lean; experiments/245_opening_support_reuse_seam.md",
        "audit": "OpeningSupport contributes only coordinate -> opening EventId meaning. RoleBalance validates that the named Event survives the ordinary current correction frontier and contains the coordinate; quantity arithmetic remains owned by the existing frontier projection.",
        "nodes": [
            ("action", "OpeningSupport(c -> opening Event)"),
            ("action", "build ordinary correction frontier"),
            ("decision", "opening Event survives frontier?"),
            ("action", "YES"),
            ("decision", "Event contains coordinate c?"),
            ("action", "YES"),
            ("action", "reuse ordinary current quantity projection"),
            ("action", "opening-supported balance answer"),
        ],
    },
    "G2.016.2 Correction Makes Witness Stale": {
        "description": "Compare independent Actual correction with the downstream invalidation of an OpeningSupport witness.",
        "sources": "Loam/CorrectionPublisher.lean; Loam/RoleBalanceReview.lean; Loam/Tests/FourVoiceCompatibilityV6.lean; Loam/Tests/CounterpointFiveWorlds.lean",
        "audit": "CorrectionPublisher has no OpeningSupport admission edge. A valid correction supersedes the named Event on the current frontier; RoleBalance then refuses the stale witness. This is already an executable qualified behavior, not an accidental missing guard.",
        "nodes": [
            ("action", "CorrectionPublisher target current Event"),
            ("insertion", "ordinary correction obligations"),
            ("action", "append replacement Event + EventCorrection"),
            ("action", "old Event leaves current frontier"),
            ("action", "OpeningSupport still names old Event"),
            ("decision", "old opening Event survives frontier?"),
            ("action", "NO"),
            ("action", "RoleBalance fails closed"),
            ("action", "derived balance answer retracted"),
        ],
    },
    "G2.016.3 Explicit Re-support Stop Point": {
        "description": "Record why neither correction blocking nor automatic support migration is earned.",
        "sources": "experiments/245_opening_support_reuse_seam.md; Loam/Tests/FourVoiceCompatibilityV6.lean; Loam/CurrentQuantityAnchor.lean",
        "audit": "EventCorrection does not imply inheritance of opening-witness meaning. Explicitly naming the replacement as a new opening witness restores answerability. CurrentQuantityAnchor is different because its reflected-root cut explicitly absorbs correction changes inside the observed cut; that rule must not be generalized to OpeningSupport.",
        "nodes": [
            ("decision", "block correction because support exists?"),
            ("action", "NO - read claim must not freeze Actual"),
            ("decision", "auto-retarget support to replacement?"),
            ("action", "NO - inheritance meaning not retained"),
            ("action", "explicit OpeningSupport(c -> replacement)"),
            ("action", "replacement survives current frontier"),
            ("action", "balance answer restored"),
            ("insertion", "CurrentQuantityAnchor cut semantics stay separate"),
            ("action", "KEEP / DO NOT COUPLE"),
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
            ("LOAM G2.016 - OpeningSupport / Actual correction",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.016 OpeningSupport / Actual correction")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("OpeningSupport correction audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing OpeningSupport correction source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
