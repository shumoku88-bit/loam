# Let's Kakeibo — open research questions

This file prevents the current synthesis from pretending to be complete.

The exact v5.93 package and its bundled HTML Help are now available as primary evidence. Key page bodies have been safely decoded without executing the application, so several earlier questions are closed.

## Resolved by the v5.93 bundled help

- keyboard shortcut map and core month/date/shop navigation;
- four-region v5 main layout and direct-cell interaction;
- Undo support;
- search/filter interaction and batch actions;
- tag semantics;
- exit-time autosave semantics;
- broad recurring-rule schema;
- holiday-shift policy;
- core card settlement navigation and postponement;
- future-list composition;
- transfer-assistant representation;
- balance-adjustment workflow;
- report-cell and graph-to-detail drill-down;
- account/currency presentation;
- backup/restore and configurable data locations;
- custom CSV field shape and broad import surfaces;
- multi-book startup/navigation concepts.

See the `FINAL_HELP_*.md` notes.

## UI evidence still needed

- full visual reconstruction of each major top-level tab from the bundled screenshots;
- exact toolbar icon-to-command mapping;
- status-bar text for every cell state;
- precise resize behavior at narrow/minimum window sizes;
- direct observation of multiple simultaneously open book windows;
- accessibility/high-DPI behavior beyond configurable grid font size;
- identification of stale historical help pages still bundled in v5.93.

## Input behavior still needed

- exact ordering/ranking algorithm for shop/content history candidates;
- conflict resolution when several classification keywords match;
- full calculator expression grammar and error behavior;
- exact receipt-group formation/breaking rules;
- detailed correction semantics after complex installment/revolving settlement;
- exported representation of balance adjustments.

## Scheduled/card behavior still needed

- exact installment/revolving math at edge cases;
- refund behavior across already-generated settlements;
- exact effect of changing card configuration across every boundary date;
- debit/prepaid distinctions beyond tag/account conventions.

## Reports still needed

- exhaustive report/graph catalog and every period control;
- exact filter preservation when drilling to details;
- no-data/zero-period rendering;
- print/export behavior for each report family.

## Data durability still needed

- native household-file format;
- migration compatibility across historical versions;
- binary `.LBK` backup structure;
- crash/partial-write behavior;
- exact import-cancel mutation bug mechanism and whether it affects every import path.

## Research method

Prefer evidence in this order:

1. bundled v5.93 help/readme and safely extracted package metadata;
2. direct hands-on inspection of v5.93 in an isolated environment;
3. author documentation/interviews;
4. contemporary Vector / 窓の杜 reviews;
5. later specialist hands-on reviews;
6. screenshots without accompanying text;
7. inference.

When bundled help pages conflict, use version-history chronology and explicit v5-era pages to distinguish final behavior from retained historical documentation.
