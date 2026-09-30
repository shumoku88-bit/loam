# Let's Kakeibo — UI layout reconstruction

Status: evidence-backed reconstruction, not pixel specification.

## 1. Stable center: the household table

A 1999 Vector review describes the main ledger as a one-month chronological table with eight fields:

```text
date | shop | description | income | expense | category | account | balance
```

The user writes directly into cells. Categories are color-coded. Cash, financial accounts, and card-related activity are shown in the same household workspace.

This basic shape persists in the 2005 and 2008 reviews.

### Reconstructed main geometry

```text
+-------------------------------------------------------------------+
| tabs / commands                                                    |
+----------------------+--------------------------------------------+
| optional context     | monthly household table                    |
|                      |                                            |
| calendar             | date | shop | description | in | out ...  |
| daily summary        | ...                                        |
| diary summary        |                                            |
|                      |                                            |
+----------------------+--------------------------------------------+
| status/help: what can be done in the selected cell                |
+-------------------------------------------------------------------+
```

The exact controls changed by version, but the table remained the visual and interaction center.

## 2. 1999 structure

The 1999 review describes seven top-level windows/panels switched through tabs, including:

- 家計簿を付ける / record household entries
- 予算と実績 / budget and actual
- 口座の設定 / account settings
- other setup surfaces, including recurring-entry/card-related setup

The important layout decision is not the precise tab count. It is that **ordinary recording stays in a single monthly table**, while less frequent configuration is moved to separate tabs.

The main table uses color to distinguish categories and make the month readable without opening transaction detail.

## 3. 2005 structure

By 2005, the product still uses a tabbed main window and the same eight-column recording table.

Contemporary review material explicitly highlights:

- spreadsheet-like entry;
- keyboard and mouse access to equivalent functions;
- direct account assignment on the row;
- color-coded content;
- automatic recurring entries;
- budget/actual and graph surfaces.

This suggests evolution around the table rather than replacement of the table.

## 4. Version 5 / 2008 structure

Version 5 adds the most relevant layout change for LOAM research.

The left side of the recording screen gains:

- a monthly calendar;
- a simple daily aggregation / diary list pane.

Clicking a calendar date moves the main ledger to the corresponding row. The side pane therefore acts as **temporal navigation into the ledger**, not as an independent dashboard.

The 2008 screenshot also shows:

- a dense toolbar above the table;
- the calendar and daily list stacked on the left;
- the transaction table occupying most of the width;
- contextual help/status information below.

### Why this matters

The side pane does not compete with the ledger for primary attention. It gives the ledger another entrance.

That is different from a modern card dashboard where each card is a separate destination.

## 5. Main table visual grammar

Observed or described cues include:

- chronological rows;
- category colors;
- income and expense amount columns with visually distinct treatment;
- account and running balance visible on the same row;
- credit-card payment method markers;
- receipt-group visual grouping;
- reduced borders / background differences for grouped receipt lines;
- contextual hints at the bottom of the window.

The table is therefore not merely a database grid. It encodes state and grouping directly into row appearance.

## 6. Calendar behavior

Version 5 documentation states that selecting a date in the calendar moves the ledger to the corresponding row.

The calendar's role is therefore:

```text
month overview -> date selection -> exact ledger position
```

This is a strong candidate for terminal translation because it does not require drag/drop or free-form graphics.

## 7. Layout principle reconstructed from the evidence

A compact statement of the durable layout is:

```text
persistent chronological evidence
+ local temporal navigator
+ local summary
+ contextual actions/help
+ separate infrequent setup/report surfaces
```

This reconstruction is stronger than saying "old Windows GUI with tabs." The durable part is the information topology.

## 8. Evidence limits

The available public screenshots are not sufficient to reconstruct:

- exact column sizing rules;
- minimum window dimensions;
- keyboard focus traversal in every cell;
- all toolbar icons and their semantics;
- behavior at very large data volumes;
- whether every subpanel persisted across minor versions.

Those remain open research items.
