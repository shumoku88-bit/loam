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
| Initial-character lookup | observed | Earlier review describes typing a leading character and using arrow keys to reuse past values. |
| Input-mode assistance | observed historically | 1999 review notes automatic input-mode switching by cell. |
| Keyword-driven category assignment | observed | Version 5 can associate keywords with categories. |
| Calculator popup | observed | Calculator available from amount cells. |
| Formula entry in amount cells | observed | Version 5 permits formulas directly in income/expense fields. |
| Receipt grouping / receipt total | observed | Multiple item lines can be grouped visually under a receipt total. |
| Insert row at position | observed | 2024 hands-on walkthrough uses a context-menu row insertion. |
| Memo / diary-related context | observed | Daily diary/list appears in version 5 side pane. |
| Automatic save behavior | partially observed | Contemporary descriptions emphasize direct editing; exact persistence timing still needs primary manual evidence. |

## B. Accounts and movement

| Feature | Evidence status | Notes |
| --- | --- | --- |
| Multiple accounts | observed | Present from early concept and reviews. |
| Cash and bank accounts in one ledger | observed | Core household overview behavior. |
| Credit-card account handling | observed | Card can be selected as payment account. |
| Running balance on each row | observed | Right side of row exposes account balance at that point. |
| Account-to-account movement assistance | observed | 2008 review mentions support for withdrawal/movement between accounts. |
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
| Settlement -> underlying purchase detail | observed | Card payment detail can be opened from the ledger. |

## D. Scheduled / recurring activity

| Feature | Evidence status | Notes |
| --- | --- | --- |
| Automatic recurring entry | observed | Monthly, weekly, half-yearly and other patterns are described. |
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
| Report-cell -> detail drill-down | observed | Context action exposes source transactions. |
| Graph region -> detail drill-down | observed | Later hands-on analysis demonstrates this. |

## F. Data interchange and resilience

| Feature | Evidence status | Notes |
| --- | --- | --- |
| Backup / restore | observed | Version 5 review. |
| CSV export | observed | Version 5 review. |
| Bank statement import | observed | Specific banks mentioned in 2008 review. |
| Edy / Suica / PASMO history import | observed | Version 5 era, sometimes through FeliCa reader. |
| Multiple household books | observed | Multiple files/books can be used, and 2008 review says several could be open. |
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

## H. Features not yet completely reconstructed

Still missing or only partially understood:

- exact search/filter UX;
- exact navigation among multiple open household books;
- tag/link semantics seen in sample data;
- detailed import conflict handling;
- exact card installment/revolving algorithms;
- all recurring-entry rule types;
- full diary behavior;
- backup file format and migration behavior;
- accessibility behavior;
- performance on decades of data.
