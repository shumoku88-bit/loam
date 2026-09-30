# Let's Kakeibo interaction study

Date: 2026-10-01  
Status: **Evidence collection in progress, not a LOAM UI specification**  
Subject: Let's家計簿 / Let's Kakeibo, with emphasis on long-lived desktop household interaction.

## Purpose

This directory collects the observable interaction design of Let's家計簿 before LOAM decides whether to build a separate ledger-desk TUI or a later GUI.

The study intentionally separates:

1. **observed behavior** — supported by screenshots, contemporary reviews, author statements, or later hands-on analysis;
2. **reconstruction** — a compact model inferred from several observations;
3. **LOAM translation** — a possible mapping onto LOAM concepts;
4. **implementation choice** — deliberately not decided here.

The aim is not to clone Let's家計簿. The aim is to understand why a spreadsheet-like household program could remain understandable and usable across decades.

## File map

- [UI_LAYOUT.md](UI_LAYOUT.md) — screen geometry, tabs, panes, table structure, visual hierarchy, and layout evolution.
- [FEATURE_INVENTORY.md](FEATURE_INVENTORY.md) — feature census with evidence notes.
- [INTERACTION_MODEL.md](INTERACTION_MODEL.md) — direct manipulation, keyboard/mouse use, input assistance, correction, and guidance.
- [INPUT_MECHANICS_DEEP_DIVE.md](INPUT_MECHANICS_DEEP_DIVE.md) — cell-level entry mechanics, history reuse, formulas, receipt grouping, cards, autosave, and contextual help.
- [REPORTS_AND_DRILLDOWN.md](REPORTS_AND_DRILLDOWN.md) — graphs, reports, budget views, account-balance views, and detail drill-down.
- [LONGEVITY.md](LONGEVITY.md) — product history, durable interaction ideas, and technology-aging lessons.
- [EVOLUTION_AND_REWRITE.md](EVOLUTION_AND_REWRITE.md) — the multi-year Ver.3 internal rewrite that intentionally preserved visible behavior, plus architectural lessons.
- [DATA_PORTABILITY_AND_RECOVERY.md](DATA_PORTABILITY_AND_RECOVERY.md) — backup, restore, CSV, data location, import behavior, and multiple household books.
- [PACKAGE_INSPECTION_5_93.md](PACKAGE_INSPECTION_5_93.md) — byte-identity verification and non-executing extraction of the official v5.93 ZIP/installer.
- [IMPLEMENTATION_LINEAGE.md](IMPLEMENTATION_LINEAGE.md) — primary-package evidence for Delphi 2007 and the earlier Delphi toolchain lineage.
- [HELP_CONTENT_INDEX.md](HELP_CONTENT_INDEX.md) — final-release CHM topic and UI-asset inventory without redistributing bundled help contents.
- [LOAM_TRANSLATION_NOTES.md](LOAM_TRANSLATION_NOTES.md) — tentative correspondences to LOAM; not a design decision.
- [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) — missing evidence and next research passes.
- [SOURCES.md](SOURCES.md) — source catalog and screenshot inventory.

## Current high-confidence findings

The strongest recurring pattern is that the main working surface remained a **monthly chronological table** rather than a dashboard. The table placed transaction facts, account choice, and running balance in one workspace.

Later versions added surrounding context without replacing that center:

```text
calendar / daily summary
        |
        v
monthly chronological table
        |
        +--> card detail
        +--> reports / graphs
        +--> account balance
        +--> budget
        +--> original detail rows
```

Input assistance was unusually deep for a desktop household program: history reuse, keyword-driven category selection, calculator/formula entry, receipt grouping, recurring entries, card settlement support, context hints, and tutorial guidance.

The reporting surface also supported a particularly valuable pattern: **summary -> originating detail**. Graph regions and report cells could lead back to the transactions that produced the number.

A second-pass finding is especially relevant to longevity: the author reports that the Ver.3 line came from an almost complete internal rewrite after years of feature accretion, while deliberately keeping the visible appearance and behavior the same. The rewrite took more than three and a half years. This is direct historical evidence for treating interaction habits and implementation machinery as separate replacement boundaries.

## Research rule

Do not convert an observation here into a production requirement merely because it appears durable or elegant.

A LOAM Desk experiment should only borrow an idea after checking:

- whether the same human goal exists in current LOAM use;
- whether LOAM already has a stronger semantic model;
- whether the interaction fits a terminal surface;
- whether the feature preserves provenance and correction semantics;
- whether the interaction remains simple after months of real use.

## Scope boundary

This directory studies the external product. It does not redefine LOAM's authority model, Actual evidence, Scheduled semantics, movement model, or correction rules.
