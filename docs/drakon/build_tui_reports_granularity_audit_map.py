#!/usr/bin/env python3
"""Build MGA-017/018 Reports module-granularity audit map."""

from pathlib import Path
import sqlite3
import build_map as base

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-tui-reports-granularity-audit.drn"

DIAGRAMS = {
    "MGA.017.1 Reports Responsibility Fanout": {
        "description": "Expose the independent presentation responsibilities currently co-located in Loam.Tui.Reports.",
        "sources": "Loam/Tui/Reports.lean; Loam/Tui/Cli.lean; Loam/Tests/TuiReports.lean; Loam/Tests/TuiTransactionsFlow.lean; docs/research/MODULE_GRANULARITY_FRONTIER_017.md",
        "audit": "Reports is a 1214-line / 103-declaration production presentation module with fan-out 13. It owns menu/query state, shared report-window editing, Transactions Flow interaction and responsive table presentation, Income & Expense projection, Balances delegation, conditional Liquidity interaction, Budget Window presentation, and cross-mode bounds paging. The question is not whether it is large, but whether these responsibilities have independent change reasons and reusable ownership seams.",
        "nodes": [
            ("action", "Loam.Tui.Reports\n1214 lines / 103 decls / fan-out 13"),
            ("action", "menu + Mode / Query / top-level State"),
            ("action", "shared report-window coordinates\nmonth / preset / custom"),
            ("action", "Transactions Flow\nselection + detail + responsive table"),
            ("action", "Income & Expense\nrole-flow presentation"),
            ("action", "Balances\nRoleBalances delegation"),
            ("action", "conditional Liquidity\nassumption editor + presentation"),
            ("action", "Budget Window\npresentation"),
            ("action", "bounds-aware paging\nbody/footer/viewport policy"),
            ("decision", "one physical reason to change?", "NO - history selects subregions independently"),
        ],
    },
    "MGA.017.2 Independent Change Axes": {
        "description": "Use repository history to distinguish genuine Reports change axes from mere source regions.",
        "sources": "PR #488; PR #548; PR #550; PR #555; PR #630; PR #633; PR #813; PR #814; PR #815; PR #820; PR #821; PR #952; Loam/Tui/Reports.lean",
        "audit": "Reports accumulated multiple separately motivated presentation changes: calendar window convenience and presets, conditional Liquidity, terminal paging, sparse Transactions Flow and its responsive table, Income & Expense, and RoleBalance presentation. #633 changed Transactions Flow layout, #815 changed Income & Expense detail, #952 simplified conditional-Liquidity result state while the Reports consumer interface remained stable, and #555 changed cross-mode paging. This is positive change-independence evidence rather than a line-count heuristic.",
        "nodes": [
            ("action", "#488 / #550\nreport-window coordinate UX"),
            ("action", "#548 / #952\nconditional Liquidity"),
            ("action", "#555\nworkspace paging"),
            ("action", "#630 / #633\nTransactions Flow"),
            ("action", "#813-815\nIncome & Expense"),
            ("action", "#820-821\nBalances"),
            ("decision", "same requirement repeatedly changes all regions?", "NO"),
            ("action", "Physical split may be earned where ownership stays singular"),
        ],
    },
    "MGA.017.3 Candidate Seams": {
        "description": "Classify Reports subregions without assuming one file per report menu item.",
        "sources": "Loam/Tui/Reports.lean; docs/research/MODULE_GRANULARITY_FRONTIER_017.md",
        "audit": "The shared report-window state is the strongest first split candidate because four report modes reuse one coordinate/preset/calendar responsibility with independent history. Transactions Flow is also a split candidate because it owns dedicated interaction state, responsive layout, detail navigation and a dedicated test surface, but its extraction should wait until shared window ownership is settled. Income & Expense, Balances, Liquidity/Budget rendering, and bounds paging remain inline for now because splitting them today would mostly move one-consumer presentation code or hide workspace-local policy.",
        "nodes": [
            ("action", "Shared ReportWindow\n4 internal consumers / #488 #550"),
            ("decision", "independent reusable presentation owner?", "YES -> SPLIT_CANDIDATE"),
            ("action", "Transactions Flow\ndedicated state + test + #630 #633"),
            ("decision", "split before window ownership settles?", "NO -> defer implementation"),
            ("action", "Income & Expense renderer"),
            ("decision", "new file removes independent burden now?", "NO -> KEEP_INLINE"),
            ("action", "Balances / Liquidity / Budget render slices"),
            ("decision", "one-file-per-menu-item justified?", "NO -> KEEP_INLINE"),
            ("action", "bounds paging"),
            ("decision", "second workspace consumer?", "NO -> KEEP_INLINE"),
        ],
    },
    "MGA.017.4 First Experiment Stop Rule": {
        "description": "Define the narrow acceptance test for a future ReportWindow extraction.",
        "sources": "Loam/Tui/Reports.lean; Loam/BoundaryPresetConfig.lean; Loam/Tui/Calendar.lean; docs/research/MODULE_GRANULARITY_FRONTIER_017.md",
        "audit": "A ReportWindow extraction qualifies only if it creates exactly one owner for start/end coordinates, calendar anchor, presets, source label and focus/edit transitions. Liquidity's assumption horizon must remain distinct. The split must not duplicate window state, introduce report-specific policy parameters, move report semantics, or require a compatibility mirror in Reports.State. If those costs appear, reject the split despite the size reduction.",
        "nodes": [
            ("action", "Candidate nested ReportWindow state"),
            ("decision", "one canonical coordinate state?", "MUST BE YES"),
            ("decision", "Stock / Transactions / Income / Budget reuse it?", "MUST BE YES"),
            ("decision", "Liquidity assumption kept separate?", "MUST BE YES"),
            ("decision", "report semantics / authority moved?", "MUST BE NO"),
            ("decision", "adapter mirror / duplicated fields required?", "MUST BE NO"),
            ("action", "If all pass -> MGA-018 implementation experiment"),
            ("action", "Otherwise -> KEEP Reports window state inline"),
        ],
    },
    "MGA.018.1 Qualified ReportWindow State Owner": {
        "description": "Record the MGA-018 extraction after state-singularity, behavior, reachability, and inventory qualification.",
        "sources": "Loam/Tui/ReportWindow.lean; Loam/Tui/Reports.lean; Loam/Tests/TuiReports.lean; Loam/Tests/TuiTransactionsFlow.lean; docs/research/MODULE_GRANULARITY_REPORT_WINDOW_018.md; docs/research/MODULE_GRANULARITY_FRONTIER_017.md",
        "audit": "MGA-018 replaces Reports' flat Form/calendarAnchor/windowPresets/windowSource fields with exactly one nested ReportWindow.State. ReportWindow owns only calendar/preset/custom coordinate presentation transitions; Reports retains report snapshots, invalidation policy, query selection, rendering, and Liquidity's independent assumption horizon. Reports falls from 1214/103 to 1104/97 lines/declarations; ReportWindow is 176 lines / 14 declarations / fan-in 1 / fan-out 2 / reachable, with production-like unreachable still zero. A refused month shift preserves the current snapshot, while a successful coordinate change invalidates it; success is derived from old/new canonical window-state equality rather than stored separately. KEEP_BOUNDARY / SPLIT_QUALIFIED.",
        "nodes": [
            ("action", "Before: Reports flat window fields\nForm + anchor + presets + source"),
            ("action", "After: Reports.window : ReportWindow.State\none canonical owner"),
            ("action", "ReportWindow owns\nseed / reset / shift / preset cycle / custom edit / focus"),
            ("decision", "mirrored coordinate state remains?", "NO"),
            ("action", "Stock / Transactions / Income / Budget\nreuse same nested state"),
            ("decision", "Liquidity completeness horizon moved?", "NO - stays Reports-owned"),
            ("decision", "report semantics / snapshots moved?", "NO - stay Reports-owned"),
            ("decision", "month shift refused?", "YES -> notice only; preserve snapshot"),
            ("action", "successful coordinate change\nclear stale report results"),
            ("action", "derive changed/not-changed from canonical state equality"),
            ("action", "inventory: Reports 1104/97; ReportWindow 176/14; reachable; unreachable=0"),
            ("decision", "independent physical owner qualified?", "YES - KEEP_BOUNDARY / SPLIT_QUALIFIED"),
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
        db.execute("insert into state values (1,1,?)", ("LOAM MGA.017-018 - Reports module granularity",))
        item_id = 1
        for name, spec in DIAGRAMS.items():
            item_id = base.add_flow_diagram(db, item_id, diagram_ids[name], name, spec)
        node_id = 1
        root = node_id
        node_id = base.add_tree_node(db, node_id, 0, "folder", "MGA.017-018 Reports granularity")
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
