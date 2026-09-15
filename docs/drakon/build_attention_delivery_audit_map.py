#!/usr/bin/env python3
"""Build the Generation-2 Attention delivery audit map."""

from pathlib import Path
import sqlite3

import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-attention-delivery-audit.drn"

DIAGRAMS = {
    "G2.009.1 Attention Read Spine": {
        "description": "Current Attention read semantics from retained evidence to the production read-only TUI.",
        "sources": "Loam/Core/Attention.lean; Loam/Core/AttentionMemory.lean; Loam/Application/AttentionInspection.lean; Loam/Persistence/AttentionPersistence.lean; Loam/AttentionReview.lean; Loam/Tui/Attention.lean; Loam/Tui/Cli.lean",
        "audit": "The existing read spine is semantically coherent. Persistence retains Attention items and explicit closures, Application owns lifecycle/open projection, Review preserves unavailable versus configured-empty, and the TUI only renders the typed answer. G2-009 does not duplicate or compress this chain.",
        "nodes": [
            ("insertion", "attention.loam present?"),
            ("decision", "configured stream?", "Unavailable"),
            ("action", "decode complete Attention image"),
            ("decision", "typed image admitted?", "Refuse malformed evidence"),
            ("decision", "closure references known?", "Refuse dangling closure"),
            ("action", "openAttentions?"),
            ("decision", "open items empty?", "Render current-open rows"),
            ("action", "Render 0 open"),
            ("action", "TUI remains read-only"),
        ],
    },
    "G2.009.2 Delivery Gap": {
        "description": "Why Attention is semantically readable but not yet a usable household capability.",
        "sources": "Loam/Persistence/AttentionPersistence.lean; Loam/Tui/Cli.lean; Loam/Tui/Attention.lean; Loam/HouseholdCommand.lean; shumoku88-bit/loam-data",
        "audit": "The household data repository has no attention.loam, no production AttentionPublisher exists, HouseholdCommand has no Attention command, and the TUI exposes no add/resolve/drop action. The apparent non-functionality is therefore a delivery/write-path gap rather than a broken read projection.",
        "nodes": [
            ("action", "SEMANTIC READ STACK"),
            ("action", "Core + Persistence + Application + Review + TUI"),
            ("action", "DELIVERY GAP"),
            ("insertion", "no household attention.loam"),
            ("insertion", "no Attention authority boundary"),
            ("insertion", "no production Attention publisher"),
            ("insertion", "no HouseholdCommand Attention entrance"),
            ("insertion", "no TUI add / resolve / drop verbs"),
            ("action", "READ KEEP / DELIVERY INCOMPLETE"),
        ],
    },
    "G2.009.3 Smallest Earned Write Spine": {
        "description": "The smallest production maturation path suggested by the existing Attention model.",
        "sources": "Loam/Core/Attention.lean; Loam/Core/AttentionMemory.lean; Loam/Persistence/AttentionPersistence.lean; Loam/Application/AttentionInspection.lean",
        "audit": "The existing Core already distinguishes stable identity, three due meanings, and resolved versus dropped closure. A future write slice should therefore reuse those retained meanings: add one Attention item, close one known-open item as resolved or dropped, persist under one authority/publisher boundary, then expose those verbs through HouseholdCommand and the TUI. Editing, closure correction, sorting, taxonomy, selected-day inference, provenance relations, and priority are not earned by this audit.",
        "nodes": [
            ("insertion", "one Attention authority"),
            ("action", "load current image under ownership"),
            ("decision", "command"),
            ("action", "ADD item\nunique stable identity + explicit due meaning"),
            ("action", "RESOLVE known open item\nexplicit knownOn"),
            ("action", "DROP known open item\nexplicit knownOn"),
            ("action", "save complete image"),
            ("action", "fresh AttentionReview answer"),
            ("action", "TUI shows real household evidence"),
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
            ("LOAM G2.009 - Attention delivery topology",),
        )

        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "G2.009 Attention Delivery")
        for name in names:
            node_id = base.add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")

        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        if db.execute("select count(*) from diagrams").fetchone()[0] != len(names):
            raise SystemExit("Attention delivery audit diagram count mismatch")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(names):
            raise SystemExit("missing Attention delivery source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
