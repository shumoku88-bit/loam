# Let's Kakeibo — source catalog

Accessed for this research pass: 2026-10-01.

## Source A — official author site, 2024 support closure

URL: https://www.letsware.com/

Use:

- freeware transition on 2024-07-06;
- final downloadable version v5.93;
- support ended;
- source/toolchain modernization described as difficult after more than a decade without development;
- author states the existing binary still appears to work on Windows 10/11 with possible minor issues.

Authority: **high for product/support history**.

## Source B — 窓の杜, 2024 freeware announcement

URL: https://forest.watch.impress.co.jp/docs/news/1607059.html

Use:

- independent report of freeware transition;
- confirms spreadsheet-style direct cell entry;
- reports Windows 11 operation checked by the publication;
- provides a large screenshot of the v5-era main screen.

Authority: **high for 2024 availability and visible layout**.

### Screenshot inventory

The article screenshot visibly shows:

- left monthly calendar;
- left simple daily aggregation/diary list;
- large right monthly ledger;
- colored transaction rows/amounts;
- toolbar and tabs;
- lower help/context area.

Do not copy the image into this repository without a separate licensing decision. Link to the source page instead.

## Source C — 窓の杜, 2008 v5.00 release

URL: https://forest.watch.impress.co.jp/article/2008/10/10/letskakeibo5.html

Use:

- addition of calendar pane;
- addition of simple daily aggregation/diary list;
- calendar date -> ledger row navigation;
- formula entry directly in amount cells;
- stronger input assistance in v5.

Authority: **high for v5 delta**.

## Source D — Vector, 1999 v1.79 review

URL: https://www.vector.co.jp/magazine/softnews/991120/n9911202.html

Use:

- early eight-column monthly ledger;
- color-coded direct cell entry;
- multiple-account management;
- input-history assistance;
- recurring entry and holiday shifting;
- early graph/budget support;
- author account of the PC-8801 origin and stable concept.

Authority: **high for early interaction history; author quotes are primary testimony embedded in a review**.

## Source E — Vector, 2005 review

URL: https://www.vector.co.jp/magazine/softnews/050518/n0505183.html

Use:

- continued spreadsheet-like main interface;
- keyboard/mouse parity;
- seven-panel/tab organization;
- recurring entries;
- budget and graph maturity.

Authority: **high for mid-life product behavior**.

## Source F — Vector, 2008 v5.03 review

URL: https://www.vector.co.jp/magazine/softnews/081030/n0810301.html

Use:

- eight-tab v5 structure;
- direct input/history/keyword assistance;
- calculator;
- receipt total/grouping;
- account movement assistance;
- balance correction;
- recurring entries;
- credit-card configuration and settlement;
- backup/restore;
- CSV;
- inactivity reminder;
- password protection;
- bank/e-money imports;
- contextual guide/help;
- author statement about long-term continuity vs perfect bookkeeping.

Authority: **high for v5 feature inventory**.

## Source G — たこぶつの家計簿アプリ研究所, 2024 introductory series

Index:
https://takobutsu.blogspot.com/2024/

Specific part 3:
https://takobutsu.blogspot.com/2024/07/letskakeibo004.html

Use:

- hands-on reconstruction on a modern system;
- sample-data/tutorial behavior;
- input-screen complexity warning;
- receipt grouping and card markers;
- graph/report access;
- configurable fiscal-year start;
- graph -> detail drill-down;
- report cell -> detail drill-down;
- category vs account/asset report target;
- account month-end balance reporting.

Authority: **valuable specialist secondary source; distinguish its interpretation from author documentation**.


## Source H — 窓の杜 current library entry

URL: https://forest.watch.impress.co.jp/library/software/letskakeibo/

Use:

- v5.93 final release date;
- direct-cell entry description;
- cell/status guidance;
- statement that household data is saved automatically whenever a change is made;
- summary of graph families and period selection.

Authority: **high for currently published product description**.

## Source I — long-term-user Dropbox/data-location article

URL: https://kurashi-note00.com/archives/53508

Use:

- documents the `自動バックアップ` folder;
- identifies `.LBK` backup files in actual use;
- demonstrates restore onto another PC;
- demonstrates changing Let's家計簿's data storage location;
- illustrates an unofficial Dropbox-synced local-data workflow.

Authority: **secondary user report; useful for observed final-release data-location behavior, not for guarantees about safety or supported synchronization**.

## Source J — exact official v5.93 package and bundled HTML Help

Artifact identity:

```text
lets593.zip
MD5 875b05ddc22e5992d06f4d0ca672a7d4
```

The hash exactly matches the author's published MD5.

The Inno Setup payload was parsed/decompressed without executing Windows code. Six recovered files were verified against installer-internal SHA-1 values. The bundled `lets.chm` directory and key LZX-compressed page bodies were then decoded in a temporary local research workspace.

Primary-help pages inspected include the main grid, key list, menus, entry fields, automatic entries, cards, accounts, classifications, holidays, future list, transfer, reconciliation, search, tags, reports, backup/restore, data folders, imports, options, FAQ, startup, reminder, and version history.

No extracted binary, help HTML, screenshot, or other bundled copyrighted asset is committed or redistributed.

Authority: **highest available for final-release behavior**, with one caveat: the final CHM visibly retains some older historical pages, so conflicting pages require version-history chronology.

## Source-quality notes

The bundled v5.93 help is now the primary reference for final-release interaction. Contemporary reviews remain valuable for historical context and for identifying behavior that may have changed over time.

Where the final help conflicts with a secondary product description, prefer the bundled help for precise v5.93 semantics.
