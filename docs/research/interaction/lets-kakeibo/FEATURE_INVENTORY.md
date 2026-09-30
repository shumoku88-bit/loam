# Let's Kakeibo — feature inventory

This is a research census. "Observed" means supported by one or more sources in SOURCES.md.

## A. Daily recording and editing

| Feature | Evidence status | Notes |
| --- | --- | --- |
| Monthly chronological ledger | observed | Core surface across 1999, 2005, 2008 material. |
| Direct cell editing | observed | Spreadsheet-like entry is repeatedly described as a defining trait. |
| Date / shop / description / income / expense / category / account / balance | observed | Eight-field table documented in 1999 and later reviews. |
| Category color coding | observed | Used to make the ledger visually scannable. |
| Previously entered value reuse | observed | History/popup selection for shop and description. |
| Initial-character lookup | observed | 2005 review describes first-character or Enter-driven access to prior values. |
| Mouse double-click equivalent to Enter | observed | 2005 review explicitly describes this beginner-friendly parity. |
| Cross-field assistance from content | observed | 2005 review says entered content can assist/populate shop/category/amount. |
| Consumption-tax calculation/input support | observed historically | 2005 review. |
| Input-mode assistance | observed historically | 1999 review notes automatic input-mode switching by cell. |
| Keyword-driven category assignment | observed | Version 5 can associate keywords with categories. |
| Calculator popup | observed | Calculator available from amount cells. |
| Formula entry in amount cells | observed | Version 5 permits formulas directly in income/expense fields. |
| Receipt grouping / receipt total | observed | Multiple item lines can be grouped visually under a receipt total. |
| Insert row at position | observed | 2024 hands-on walkthrough uses a context-menu row insertion. |
| Memo / diary-related context | observed | Daily diary/list appears in version 5 side pane. |
| Automatic save behavior | observed in bundled v5.93 help | Default automatic persistence occurs when the book/application closes; the option can be disabled, exposing explicit Save/unsaved-close behavior. This corrects the earlier per-change interpretation of a secondary description. |

## B. Accounts and movement

| Feature | Evidence status | Notes |
| --- | --- | --- |
| Multiple accounts | observed | Present from early concept and reviews. |
| Cash and bank accounts in one ledger | observed | Core household overview behavior. |
| Credit-card account handling | observed | Card can be selected as payment account. |
| Running balance on each row | observed | Right side of row exposes account balance at that point. |
| Account-to-account movement assistance | observed in bundled help | One assistant action writes two ledger rows using an income/expense-excluded classification; useful interaction, weaker semantics than LOAM Movement. |
| Balance correction / 帳尻合わせ | observed | Current physical cash can be entered; discrepancy becomes an unknown-use adjustment. |
| No first-class generic transfer in the modern accounting sense | observed by later analysis | Later researchers note transfer representation differs from systems with explicit transfer pairs. Treat this as a semantic limitation, not an interaction pattern to copy. |

## C. Credit cards

| Feature | Evidence status | Notes |
| --- | --- | --- |
| Card configuration | observed | Payment account, closing date, withdrawal date. |
| Credit limit | observed | Version 5 review. |
| Revolving-payment configuration | observed | Version 5 review. |
| Lump-sum / installment payment representation | observed | Payment method shown in ledger and editable. |
| Generated settlement entry | observed | Withdrawal day shows クレジット清算 aggregate. |
| Settlement -> underlying purchase detail | observed in bundled help | Purchase can jump to withdrawal; withdrawal aggregate exposes constituent purchases; selected purchases can be postponed one month/restored. |

## D. Scheduled / recurring activity

| Feature | Evidence status | Notes |
| --- | --- | --- |
| Automatic recurring entry | observed in bundled help | Monthly, every-N-months, every-N-weeks, fixed-date, and nth-weekday patterns; start/end applicability; variable amount; holiday shifting; future preview. |
| Fixed-amount recurring item | observed | Rent, loan, saving examples. |
| Variable-amount recurring skeleton | observed historically | Utility-like items can retain the recurring item while amount varies. |
| Holiday shifting | observed historically | Earlier version can move scheduled day before/after holidays. |

## E. Budget and analysis

| Feature | Evidence status | Notes |
| --- | --- | --- |
| Budget entry | observed | Budget and actual share a dedicated surface. |
| Monthly comparison | observed | Graph/report support. |
| Annual / fiscal-year comparison | observed | Year start month can be configured. |
| Category composition | observed | Pie/bar and category reports. |
| Line / area / bar / pie graphs | observed historically | 1999 review explicitly lists several graph forms. |
| Account balance trend | observed | Graph and tabular views. |
| Budget consumption indicator | observed | Later analysis reports heatmap/bar-like budget status in report table. |
| Report-cell -> detail drill-down | observed in bundled help | Hover preview and right-click full contributing detail from report cells. |
| Graph region -> detail drill-down | observed in bundled help | Graph segments/bars expose contributing detail; earlier secondary observation is now primary-help confirmed. |

## F. Data interchange and resilience

| Feature | Evidence status | Notes |
| --- | --- | --- |
| Backup / restore | observed | Version 5 review; later user report demonstrates restore from .LBK auto-backup. |
| Configurable data storage location | observed in bundled help | Data and automatic-backup folders are independently configurable; FAQ also describes removable-media/multi-PC use. |
| CSV export | observed | Version 5 review. |
| Bank statement import | observed | Specific banks mentioned in 2008 review. |
| Edy / Suica / PASMO history import | observed | Version 5 era, sometimes through FeliCa reader. |
| Multiple household books | observed in bundled help | Unlimited books, startup organizer, create/rename/delete/reorder/restore, and multiple-book operation in later releases. |
| Password protection | observed | Version 5 review. |
| Sample household data | observed | 2024 walkthrough notes 18 months of sample data for testing reports. |

## G. Sustained-use assistance

| Feature | Evidence status | Notes |
| --- | --- | --- |
| Tutorial balloons/dialogs | observed | 2024 hands-on analysis calls out first-use guidance. |
| Status-bar hints | observed | 2008 review notes contextual hints. |
| Online help | observed | Contemporary review. |
| 三日坊主防止 reminder | observed | Reminds the user after several days without recording. |
| Approximate reconciliation rather than demanding perfect memory | author-stated philosophy | Author explicitly describes long-term continuity as more important than perfect precision and recommends later correction if memory returns. |

## H. Additional final-help-confirmed capabilities

| Feature | Evidence status | Notes |
| --- | --- | --- |
| Keyboard navigation map | observed in bundled help | Date/shop-group/month navigation, search, graph, memo, transfer, future list, import, copy/paste, edit, etc. |
| Undo | observed in bundled help | `Ctrl+Z`; later history notes additional credit/installment/revolving-aware Undo work. |
| Search-result batch editing | observed in bundled help | Bulk shop/content/category/account/tag changes, delete, credit postponement/restoration, with Undo. |
| Tags distinct from categories | observed in bundled help | Multiple free-form labels; searchable/batch-editable; can be attached to automatic entries. |
| Combined future list | observed in bundled help | Credit settlements, automatic entries, and manually future-dated rows in one horizon view. |
| Per-book holiday policy | observed in bundled help | Used by recurring/card date shifting; fixed/nth-weekday rules and applicability ranges. |
| Multiple currencies by account | observed in bundled help | Account selects currency; reports aggregate per currency; no universal conversion total documented. |
| Exit-time autosave | observed in bundled help | Default; can be disabled for explicit save workflow. |
| Daily automatic backup | observed in bundled help | Usually at exit, one per day, default ten-day retention. |

## I. Still incomplete

- exact native data-file format and migration compatibility;
- exact binary `.LBK` backup structure;
- full installment/revolving mathematical edge cases;
- exact import-cancel mutation defect mechanism;
- accessibility behavior beyond font-size configuration;
- performance on decades of data;
- which historically retained help pages are stale versus still reachable in v5.93.
