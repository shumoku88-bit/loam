# Let's Kakeibo v5.93 — bundled help content index

Date: 2026-10-01  
Status: **CHM directory parsed and key page bodies safely decompressed/read**

The safely recovered `lets.chm` is a Microsoft HTML Help archive.

Without executing the application, the CHM directory and LZX-compressed page bodies were safely decoded. The topic map below is now supplemented by primary-help reconstructions in the `FINAL_HELP_*` companion notes.

No CHM file, HTML page body, image, or other copyrighted asset is committed to LOAM.

## 1. Core ledger and entry topics

Observed topic names include:

- `MainGrid.html`;
- `InputDate.html`;
- `InputShop.html`;
- `InputComment.html`;
- `InputMoney.html`;
- `InputClassification.html`;
- `InputAccount.html`;
- `InputMemo.html`;
- `Calendar.html`;
- `KeyList.html`.

This supports treating the monthly grid, its cells, and keyboard operation as first-class documented interaction concepts rather than incidental implementation details.

## 2. Menu-level help map

Dedicated help pages exist for:

- `Menu_File.html`;
- `Menu_Edit.html`;
- `Menu_Function.html`;
- `Menu_Mode.html`;
- `Menu_Setting.html`;
- `Menu_Help.html`.

This creates a clear next research route once page bodies can be safely decompressed: reconstruct the complete command taxonomy without launching the program.

## 3. Household configuration

Observed configuration topics include:

- `ConfigAccounts.html`;
- `ConfigAutowrite.html`;
- `ConfigClassification.html`;
- `ConfigCreditcard.html`;
- `ConfigHoliday.html`;
- `Options.html`.

Screenshot asset names further indicate dedicated settings screens for accounts, automatic filling, classification, credit cards, holidays, and general options.

## 4. Budget, analysis, and reports

Observed topics/assets include:

- `BudgetScreen.html`;
- `ExpenseAnalysis.html`;
- `GraphTop.html`;
- monthly stacked graph imagery;
- bar, yearly bar, depth, pie, and stack chart imagery;
- report chart and report-term controls;
- account-balance screenshots.

The final release therefore documents analysis as a substantial product surface, not a thin afterthought.

## 5. Drill-down and detail

Asset names expose dedicated detail interactions such as:

- `DetailsList075.png`;
- `DetailsListOptions.png`;
- `PieChartShowDetails075.png`;
- `CreditTransactionDetailsDialog075.png`.

This reinforces the earlier secondary-source finding that aggregates and card settlements can lead to their contributing detail.

## 6. Scheduled / future household events

Observed help and asset names include:

- `Future.html`;
- future-list and future-item screenshots;
- automatic-entry configuration;
- holiday configuration;
- credit-card settlement/revolving-payment screenshots.

This suggests that the final help system treats future obligations and recurring activity as a coherent user-facing area.

## 7. Movement and reconciliation

Observed topics/assets include:

- `moneytransfer.html`;
- `AdjustBalance.html`;
- `AccountsBalances.html`;
- bank-move icon imagery;
- balance-adjustment window/menu imagery.

These should be studied carefully against LOAM's stronger first-class Movement and evidence semantics rather than copied literally.

## 8. Backup, data location, and recovery

Observed topics include:

- `AutoBackup.html`;
- `ManualBackup.html`;
- `ChangingDataFolders.html`.

Asset names include explicit backup/restore controls.

This provides primary-package confirmation that data durability and location were documented user operations.

## 9. Import ecosystem

Observed topics include:

- `import.html`;
- `importfile.html`;
- `importfelica.html`;
- `importiphone.html`.

Asset names mention:

- Edy;
- Suica;
- FeliCa2Money;
- iCompta;
- generic file import.

This confirms that import was a broad interaction surface by the final release.

## 10. UI screenshots embedded in help

The help archive contains many product screenshots, including names corresponding to:

- the main tab;
- account settings;
- automatic-fill settings;
- classification settings;
- credit-card settings;
- credit-card item popup menus;
- credit transaction detail;
- budget and actual;
- calendar sizes;
- input-assistance popups;
- data-folder change dialog;
- import dialog;
- report/chart controls.

These images are not copied into the research repository because the bundled license restricts reuse of documentation/help assets.

## 11. Page-body extraction status

The key bodies have now been decompressed/read in a temporary local research workspace, including:

```text
KeyList / MainGrid / Basics
Menu_* / Input* / Options
ConfigAccounts / ConfigAutowrite / ConfigCreditcard
ConfigClassification / ConfigHoliday
Future / moneytransfer / AdjustBalance
BudgetScreen / SummaryTable / GraphTop / ExpenseAnalysis
Search / tag
AutoBackup / ManualBackup / Restore / ChangingDataFolders
import / importfile / importfelica / importiphone
StartupScreen / reminder / FAQ / NewFeatures
```

Derived findings are kept in:

- `FINAL_HELP_KEYBOARD_AND_ENTRY.md`;
- `FINAL_HELP_SCHEDULED_AND_MOVEMENT.md`;
- `FINAL_HELP_ANALYSIS_AND_DATA.md`.

The extracted HTML/image files remain temporary evidence and are not committed or redistributed.

## 12. Version-layer caution

The final CHM retains some historically older help pages alongside v5-era material. The separate `Calendar.html` behavior, for example, conflicts with the integrated v5 left-pane description in `MainGrid.html`.

When pages conflict, research should prefer explicit v5-era pages plus `NewFeatures.html` chronology, and treat older-looking pages as historical residue rather than simultaneous final behavior.
