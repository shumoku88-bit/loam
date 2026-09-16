#!/usr/bin/env python3
"""Build the Generation-2 current Actual target comparison audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-current-actual-target-audit.drn"

DIAGRAMS = {
    "G2.012.1 Current Actual Target Comparison": {
        "description": "Compare Correction, Reversal, and ActualValidity target selection at one semantic scale.",
        "sources": "Loam/CorrectionPublisher.lean; Loam/ActualReversalPublisher.lean; Loam/ActualValidityPublisher.lean; Loam/Persistence/NormalizedActualPersistence.lean; Loam/Application/CorrectionFrontier.lean",
        "audit": "All three writers start from the same retained-and-not-correction-target semantic fact after canonical Actual loading has already admitted the whole correction frontier. Correction and Reversal need the retained Event payload and diverge into different provenance refusals; Date correction needs only Event identity plus the validity frontier. The shared semantic law already belongs to CorrectionFrontier, but the runtime consumer shape and diagnostics do not align enough to justify another helper.",
        "nodes": [
            ("insertion", "canonical ActualEvidence loaded\nwhole Correction frontier admitted"),
            ("decision", "requested EventId retained?"),
            ("decision", "absent from Correction targets?"),
            ("action", "shared semantic fact:\nretained + correction-current"),
            ("action", "CORRECTION"),
            ("insertion", "consume retained Event payload"),
            ("decision", "practical Movement + no Relation/Reversal refs?"),
            ("insertion", "carry current validity date"),
            ("action", "REVERSAL"),
            ("insertion", "consume retained Event payload"),
            ("decision", "no reversal / relation / Scheduled-completion conflict?"),
            ("insertion", "derive exact anonymous inverse"),
            ("action", "DATE CORRECTION"),
            ("insertion", "identity only; Event payload unused"),
            ("insertion", "resolve current validity fact"),
            ("decision", "same date?"),
            ("action", "no-op or append validity revision"),
        ],
    },
    "G2.012.2 Authority Precondition / Existing Law": {
        "description": "Show that writer-local target checks execute only after the canonical whole-world correction obligation has already succeeded.",
        "sources": "Loam/ActualAuthority.lean; Loam/Persistence/NormalizedActualPersistence.lean; Loam/Application/CorrectionFrontier.lean",
        "audit": "Normalized Actual admission runs correctionFrontierMemory? before publishers receive ActualEvidence. correctionFrontierMemory?_mem_iff already proves that, under successful frontier admission, current membership is exactly retained Event membership plus absence from Correction targets. Writer-local target checks therefore select within an admitted world; they do not replace or bypass global correction topology validation.",
        "nodes": [
            ("action", "actual.loam"),
            ("insertion", "decodeNormalizedActual? / admitActualEvidence?"),
            ("decision", "correctionFrontierMemory? succeeds?"),
            ("action", "closed + source-unique + successor-unique + acyclic world"),
            ("insertion", "CorrectionFrontier theorem"),
            ("action", "frontier membership"),
            ("action", "IFF"),
            ("action", "retained Event AND not Correction target"),
            ("action", "writers may use cheap local membership test"),
        ],
    },
    "G2.012.3 Sharing Pressure / Stop Point": {
        "description": "Test the obvious abstraction candidates and record why the two repeated boxes remain local.",
        "sources": "Loam/CorrectionPublisher.lean; Loam/ActualReversalPublisher.lean; Loam/ActualValidityPublisher.lean; Loam/Core/EventCorrectionMemory.lean; commit c6e385564d1c6fcf87ecbfc8fd09c70e1ea64758",
        "audit": "Option Event loses missing-vs-stale diagnostics and gives Date correction an unused payload. Bool makes Correction/Reversal repeat Event lookup. A shared error algebra adds a new type and adapters. Reusing correctionFrontierMemory? restores global work deliberately removed by #776. Moving cross-memory currentness into EventCorrectionMemory blurs the raw-Core/Application split. The smallest justified design is the existing local checks plus the already-shared semantic theorem.",
        "nodes": [
            ("action", "Option Event helper"),
            ("action", "diagnostic collapse + unused Date payload"),
            ("action", "REJECT"),
            ("action", "Bool helper"),
            ("action", "second Event lookup or no reduction"),
            ("action", "REJECT"),
            ("action", "shared CurrentTargetError algebra"),
            ("action", "new type + operation adapters"),
            ("action", "REJECT"),
            ("action", "reuse full CorrectionFrontier per writer"),
            ("action", "duplicate global work; reverses #776"),
            ("action", "REJECT"),
            ("action", "KEEP local target checks"),
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
            ("LOAM G2.012 - Current Actual target comparison",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.012 Current Actual target")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Current Actual target audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing Current Actual target source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
