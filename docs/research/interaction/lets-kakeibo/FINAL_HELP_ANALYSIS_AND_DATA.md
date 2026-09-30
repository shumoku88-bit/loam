# Let's Kakeibo v5.93 — analysis, search, backup, and import

Date: 2026-10-01  
Status: **primary-help reconstruction from the bundled v5.93 CHM**

## 1. Reports are queryable evidence surfaces

The final help describes a flexible "Budget and Actual" analysis area with both table and graph forms.

The report can aggregate by:

- day;
- week;
- month;
- year;
- category/purpose-like classification;
- account balance.

A selected report cell can preview contributing detail, and right-click can open the complete underlying list.

This upgrades the earlier secondary-source observation into bundled-help evidence:

```text
aggregate -> contributing rows
```

## 2. Budgets are edited directly in the report table

Budget cells are editable in place and support formulas.

Budgets are monthly and can be propagated using several mechanisms:

- common/shared budget from a reference month;
- inherit previous month;
- copy/paste a month's budget;
- inherit previous year's budget;
- clear local month overrides.

This is another example of direct manipulation rather than a separate budget wizard.

## 3. Standard graph families

The help describes a configurable report/graph system and several standard views.

Examples include:

- current-month expense composition;
- current-year monthly income/expense;
- account-balance trend;
- multi-year annual comparison;
- selected-category monthly trend;
- stacked monthly expense composition.

Graph regions can expose or open the underlying details.

The important LOAM lesson is the drill-down path, not graph-type abundance.

## 4. Search is an editing surface, not only a finder

Search supports combinations of:

- keyword;
- period;
- account;
- category;
- imported-source state;
- tags.

Text search supports AND/OR/NOT-like composition and normalizes several Japanese width/case/script differences.

Results can be grouped by receipt-like date/shop/account context.

If only period and account are selected, the result behaves like a passbook with running balances.

## 5. Search-result batch actions

Multiple search result rows can be selected and then acted upon.

Documented actions include:

- jump back to ledger date;
- copy;
- delete;
- bulk change shop;
- bulk change content;
- bulk change category;
- bulk change account;
- bulk edit tags;
- postpone card withdrawal;
- restore original card withdrawal timing.

These result-level changes have Undo support.

This is a striking design pattern:

```text
query -> inspect subset -> edit subset -> undo if needed
```

A future LOAM analytical surface could adopt the navigation idea while routing all mutation through typed Application actions.

## 6. Tags

Tags are intentionally distinct from report categories.

They are lightweight cross-cutting labels for things such as:

- waste/attention;
- ToDo;
- restaurant preference;
- debit-card identification.

A row can hold multiple tags. Tags can be created freely, searched, removed, and batch-applied through search results.

Automatic-entry definitions can also assign tags.

This is closer to an annotation/attention dimension than an accounting classification.

## 7. Accounts as derived state

The account-configuration screen shows month-start/month-end balances but does not permit direct balance editing.

Money is entered through the ledger, and balances are derived.

Used accounts cannot simply be deleted; they can be disabled.

There is also a setting controlling whether future entries participate in displayed balance calculations.

This is another useful evidence-vs-derived-state distinction.

## 8. Autosave semantics corrected by primary help

The final bundled help resolves an ambiguity in secondary descriptions.

Default behavior is **automatic save when the application/household book closes**, not guaranteed persistence after every individual cell edit.

The option can be disabled. When disabled:

- an explicit Save operation is available;
- closing can prompt about unsaved changes;
- "close without saving" is supported.

This primary evidence supersedes the earlier interpretation of the current 窓の杜 product description.

## 9. Backup and restore

Automatic backup:

- normally created on application exit;
- one automatic backup per day;
- same-day backup is overwritten;
- default retention is ten days;
- contains the whole household book.

Manual backup:

- produces an `.LBK` backup;
- filename includes date/time/book name;
- intended for removable/off-machine storage.

Restore fully replaces a same-named household book or creates it if absent.

## 10. Data location

The household-data folder and automatic-backup folder are independently configurable.

The help explicitly encourages separation onto another drive/device as a resilience measure, while warning that custom paths are an advanced operation.

The FAQ also describes using removable storage so the same local household data can be pointed to from different PCs.

This is local-first portability, not cloud-account ownership.

## 11. Multiple household books

The startup screen supports:

- create;
- rename;
- delete;
- reorder;
- open;
- restore;
- data-location change.

Multiple books can exist, and later releases can open multiple books.

Each book owns its own account/card/automatic-entry/category configuration.

A password can restrict startup access, but the help explicitly warns that it is not encryption.

## 12. Import ecosystem

The final help covers imports from:

- bank/card histories;
- OFX;
- CSV/TXT;
- FeliCa/e-money sources;
- iPhone-era household apps over local networking.

A custom CSV interchange layout is documented around:

```text
date, shop, content, income, expense, category, account
```

Previously imported records can be excluded as duplicates.

Unknown categories/accounts may be created as part of import, which helps explain why later hands-on research found cancellation/partial-configuration failure cases. For LOAM, preview and commit should therefore remain transactionally separated.

## 13. Reminder and sustained use

A separate reminder utility can notify after a configurable period without recording, from roughly a day to a month.

The help suggests disabling it once recording becomes habitual.

This is a small but notable design choice: the reminder is scaffolding for continuity, not a permanent engagement mechanism.

## 14. Historical/stale help inside the final CHM

The final CHM is not a perfectly uniform snapshot.

For example:

- the v5 `MainGrid` page describes the calendar/simple-summary pane integrated into the left side of the main window;
- a `Calendar` page still describes a separate/floating calendar interaction associated with earlier releases.

The version history shows that calendar behavior evolved across major versions.

Therefore:

```text
bundled in v5.93 help
!=
guaranteed simultaneously current v5.93 behavior
```

Where pages conflict, prefer explicitly v5-era pages plus version-history chronology, and mark older-looking pages as archaeology rather than current specification.
