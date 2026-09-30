# Let's Kakeibo — open research questions

This file prevents the current synthesis from pretending to be complete.

## UI evidence still needed

- Full-resolution screenshots for each major top-level tab in v5.93.
- Exact toolbar commands and which are global vs context-sensitive.
- Exact status-bar help behavior for each main cell type.
- Search/filter screen and keyboard shortcuts.
- How the left daily-summary/diary pane behaves while scrolling across months.
- Window resizing and column resizing behavior.
- Multi-book window behavior.
- Accessibility / font scaling / high-DPI limitations.

## Input behavior still needed

- Exact persistence/autosave timing.
- Exact rule for receipt grouping and ungrouping.
- How duplicate shop/description history is ranked.
- Whether keyword category rules can conflict and how conflicts are resolved.
- Full calculator/formula grammar.
- Undo support, if any.
- Detailed correction flow after a posted card settlement.
- Exact balance-correction representation in exported data.

## Scheduled/card behavior still needed

- Complete recurring-rule schema.
- Holiday calendar semantics across versions.
- Installment/revolving card calculation details.
- What happens when closing/withdrawal configuration changes after purchases exist.
- How card refunds are represented.
- How debit/prepaid/e-money distinctions are modeled internally.

## Reports still needed

- Full report/graph list in v5.93.
- Exact period controls for every report.
- Export/print behavior.
- Selection model for graph drill-down.
- Whether drill-down preserves current filters.
- How zero/no-data periods are shown.

## Data durability still needed

- Native file format and migration history.
- Whether old-version data files open directly in v5.93.
- Backup archive structure.
- CSV field definitions.
- Import duplicate handling and failure recovery.

## Research method for the next pass

Prefer evidence in this order:

1. official help/manual shipped with v5.93;
2. direct hands-on inspection of v5.93 in an isolated environment;
3. author documentation;
4. contemporary Vector / 窓の杜 reviews;
5. later specialist hands-on reviews;
6. screenshots without accompanying text;
7. inference.

Every newly discovered behavior should be marked as observed or inferred and linked in SOURCES.md.
