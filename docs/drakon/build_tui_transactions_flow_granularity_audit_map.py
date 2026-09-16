#!/usr/bin/env python3
"""Build MGA-019 Transactions Flow module-granularity audit map."""

from pathlib import Path
import sqlite3
import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-tui-transactions-flow-granularity-audit.drn"

DIAGRAMS = {
    "MGA.019.1 Current Transactions Flow Ownership": {
        "description": "Expose the result-local Transactions Flow state/presentation cluster that remains inside Reports after MGA-018.",
        "sources": "Loam/Tui/Reports.lean; Loam/Tests/TuiTransactionsFlow.lean; PR #630; PR #633; docs/research/MODULE_GRANULARITY_TRANSACTIONS_FLOW_019.md",
        "audit": "After ReportWindow became a separate canonical owner, Reports still retains TransactionsFlowReview.Snapshot, selected coordinate index, summary/detail flag, active-row filtering and gross-salience ordering, focused contribution projection, responsive table layout, and summary/detail body presentation. PR #630 explicitly introduced index/detail as Transactions-local state while reusing shared window and scrolling; PR #633 later changed only the responsive Transactions presentation. The candidate is therefore a result-local interaction/presentation owner, not a one-file-per-report split.",
        "nodes": [
            ("action", "Reports.State\ntransactionsSnapshot + transactionsIndex + transactionsDetail"),
            ("action", "TransactionsFlowReview.Snapshot"),
            ("action", "derive active rows\nfilter zero activity + order by gross salience"),
            ("action", "selected coordinate index"),
            ("decision", "detail open?", "YES -> focused contributors; NO -> responsive summary table"),
            ("action", "derive nonzero Event contributions"),
            ("action", "responsive TableLayout from content width"),
            ("action", "summary/detail presentation"),
            ("decision", "independent change axis in history?", "YES - #630 behavior / #633 layout"),
        ],
    },
    "MGA.019.2 Candidate TransactionsFlowPane Seam": {
        "description": "Separate the proposed result-local pane owner from Reports-owned window, query, invalidation, and workspace paging policy.",
        "sources": "Loam/Tui/Reports.lean; Loam/Tui/ReportWindow.lean; Loam/TransactionsFlowReview.lean; docs/research/MODULE_GRANULARITY_TRANSACTIONS_FLOW_019.md; docs/research/TRANSACTIONS_FLOW_PANE_OBLIGATION_DAG.md",
        "audit": "The strongest experiment nests snapshot/index/detail in one TransactionsFlowPane.State. The pane may own snapshot adoption/reset, row/contribution derivation, selection, summary/detail local transitions, and responsive body rendering. Reports must retain ReportWindow, explicit Query.transactionsFlow emission, stale-result invalidation policy, Mode/menu/notice composition, scroll, body/footer paging and bounds clamping. Pane must not import Reports or ReportWindow and must not create a second movement semantic engine.",
        "nodes": [
            ("action", "Reports.State"),
            ("action", "window : ReportWindow.State\nKEEP Reports-owned"),
            ("action", "transactions : TransactionsFlowPane.State\nCANDIDATE nested owner"),
            ("action", "pane State = Snapshot + selectedIndex + detail"),
            ("action", "pane derives rows / selected row / contributions / responsive body"),
            ("decision", "pane owns Query or ReportWindow?", "NO - reject if YES"),
            ("decision", "pane owns scroll / paging / bounds clamp?", "NO - reject if YES"),
            ("decision", "Reports mirrors snapshot/index/detail?", "NO - reject if YES"),
            ("action", "dependency: Reports -> Pane -> Review/Layout/Kernel"),
            ("decision", "Pane -> Reports or ReportWindow dependency?", "NO - reject if YES"),
        ],
    },
    "MGA.019.3 Qualification Obligation DAG": {
        "description": "Record the all-or-nothing obligations that MGA-020 must satisfy before a Transactions Flow physical split can graduate.",
        "sources": "docs/research/TRANSACTIONS_FLOW_PANE_OBLIGATION_DAG.md; Loam/Tests/TuiTransactionsFlow.lean; Loam/Tui/Reports.lean",
        "audit": "MGA-020 may qualify only if result-local state becomes singular, all exact projections stay derived, shared window/query/invalidation/paging ownership stays in Reports, movement semantics stay in TransactionsFlowReview, focused behavior remains unchanged, and production reachability is preserved. Any compatibility mirror, report-specific window adapter, second scroll owner, cached derived rows/contributions/layout, or presentation-owned semantic result is a split-rejection signal.",
        "nodes": [
            ("action", "O: semantic source = TransactionsFlowReview.Snapshot"),
            ("decision", "one pane state owns snapshot/index/detail?", "MUST BE YES"),
            ("decision", "rows/contributions/layout retained as state?", "MUST BE NO"),
            ("action", "R: ReportWindow + query + invalidation remain Reports"),
            ("decision", "window/query adapter duplicated?", "MUST BE NO"),
            ("action", "W: scroll + paging + bounds clamp remain Reports"),
            ("decision", "second workspace owner introduced?", "MUST BE NO"),
            ("action", "T: dedicated Transactions tests preserve sparse summary/detail behavior"),
            ("decision", "production reachability and behavior preserved?", "MUST BE YES"),
            ("decision", "all obligations satisfied?", "YES -> MGA-020 SPLIT_QUALIFIED; NO -> SPLIT_REJECTED"),
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
        db.execute("insert into state values (1,1,?)", ("LOAM MGA.019 - Transactions Flow module granularity",))
        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)
        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "MGA.019 Transactions Flow granularity")
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
