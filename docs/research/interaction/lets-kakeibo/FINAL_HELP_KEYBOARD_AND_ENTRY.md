# Let's Kakeibo v5.93 — primary-help keyboard and entry model

Date: 2026-10-01  
Status: **reconstructed from the bundled v5.93 HTML Help, extracted without executing the application**

This note summarizes interaction behavior documented inside the exact v5.93 `lets.chm`. It paraphrases the help and does not redistribute the original HTML or screenshots.

## 1. Keyboard map

The final help explicitly presents keyboard operation as a speed path with mouse equivalents.

| Action | Shortcut |
| --- | --- |
| first row of current day | `Ctrl+Up` |
| first row of next date | `Ctrl+Down` |
| first row/date cell of current shop group | `Alt+Up` |
| first row/date cell of next shop group | `Alt+Down` |
| leftmost cell (date) | `Home` |
| rightmost cell (account) | `End` |
| first row of month | `Ctrl+Home` |
| last row of month | `Ctrl+End` |
| next row's content cell | `Shift+Enter` |
| move row up/down inside same date/shop range | `Shift+Up` / `Shift+Down` |
| next month | `Ctrl+Right` or `Ctrl+N` |
| previous month | `Ctrl+Left` or `Ctrl+B` |
| jump to date | `Ctrl+J` |
| search | `Ctrl+F` |
| graph/report | `Ctrl+G` |
| memo | `Ctrl+M` |
| transfer input assistant | `Ctrl+T` |
| future payment/receipt schedule | `Ctrl+L` |
| options | `Ctrl+O` |
| calendar / left-pane command | `Ctrl+K` |
| calendar size | `Ctrl+E` |
| row copy / paste | `Ctrl+C` / `Ctrl+V` |
| edit focused cell | `F2` |
| undo | `Ctrl+Z` |
| import | `Ctrl+Alt+I` |
| close graph/memo etc. | `Esc` |

The help recommends learning the shortcuts gradually rather than memorizing them all at once.

## 2. Four-part main workspace

The final v5 help describes the main screen as four regions:

```text
+--------------------+--------------------------------------+
| calendar           | monthly household ledger            |
|                    |                                      |
+--------------------+--------------------------------------+
| simple daily       | common memo                          |
| summary / diary    |                                      |
+--------------------+--------------------------------------+
```

The left area can be hidden to give the ledger more width.

The ledger remains the dominant workspace. Column widths are draggable, window size/position persist, and the content column expands and contracts with the window subject to a minimum width.

## 3. Direct cell editing

The bundled help explicitly compares the ledger to spreadsheet-style direct editing.

Basic interaction:

```text
focus cell -> Enter -> edit/choose -> commit -> remain in ledger
```

All ordinary input can be completed from the keyboard.

The help treats one real-world purchase or receipt/income fact as one row. The date/shop/content/amount/category/account fields remain visible together while editing.

## 4. Date mechanics

Documented behavior includes:

- changing a date re-sorts the row;
- focusing a date can expose that day's expense total;
- memo dates are visually distinguished;
- if date is omitted in the current month, today is normally used;
- past-month insertion can inherit the row-above date;
- a newly inserted/same-shop row can inherit the previous date;
- changing the first row of a same-shop group can shift following group dates together.

This is optimized for entering a whole receipt quickly after the fact.

## 5. Shop and receipt mechanics

Same-shop neighboring rows are visually grouped.

The help documents:

- history lookup using typed prefixes;
- repeated shop display condensed visually;
- same date/shop subtotal feedback;
- omitting date/shop on the next row to inherit them;
- `Shift+Enter` to move directly to the next row's content cell.

The resulting loop is:

```text
date/shop once
  -> item
  -> Shift+Enter
  -> item
  -> Shift+Enter
  -> item
```

This is a strong terminal-friendly interaction pattern.

## 6. Content-driven assistance

The content field is more than free text.

The final help says prior entries and configured keywords can assist:

- category selection;
- shop;
- account inheritance;
- amount reuse.

The history mechanism prefers contextually similar prior entries, including the same shop where applicable.

A special tax shorthand can calculate consumption tax from preceding contiguous same-day/same-shop items.

## 7. Amount entry

The amount cell supports both direct numeric input and an Enter-opened calculator.

Formula expressions can be typed directly, for example multiplication/addition and parentheses.

The help also documents:

- negative expense for cashback/refund-like cases;
- income and expense cannot both be entered on one row;
- special background cues for automatic-entry and credit-settlement-related amounts.

## 8. Category and account entry

Category:

- chosen from a hierarchical popup rather than arbitrary direct text;
- supports parent/subcategory navigation;
- can use numeric shortcuts;
- can be auto-proposed from content/history/keywords.

Account:

- Enter plus arrows cycles cash/accounts/cards;
- cash is visually represented as blank;
- cards have a distinct marker/background;
- choosing an account immediately recalculates the balance;
- the selected account determines currency.

This keeps derived balance feedback adjacent to the act that changed it.

## 9. Row editing and undo

The Edit menu documents:

- copy;
- paste;
- insert;
- delete;
- undo.

Paste intentionally does not duplicate all semantic metadata. Date is replaced by the destination context, and credit-card/automatic-entry linkage is not blindly copied.

Deleting linked credit/automatic-entry rows produces warnings.

This is a useful example of refusing to let a generic clipboard silently clone hidden lifecycle state.

## 10. Memo and event context

There are two memo concepts:

- date-specific memo;
- common memo not tied to a date.

The final v5 help also describes short "before" and "after" event notes that can be surfaced compactly in the left daily-summary area.

## 11. First LOAM Desk pressure

The primary help strengthens a concrete TUI experiment:

```text
calendar + chronological Actual table
        + selected-row context
        + persistent shortcut/help line
```

The most reusable ideas are not the exact Windows controls. They are:

- stay in the ledger;
- inherit obvious local context;
- make repeated entry one-keystroke cheap;
- keep derived balance feedback nearby;
- provide real undo/correction;
- make mouse discovery and keyboard repetition lead to the same conceptual actions.
