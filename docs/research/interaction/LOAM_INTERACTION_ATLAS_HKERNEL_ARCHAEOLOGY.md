# LOAM Interaction Atlas — h-kernel TUI Archaeology

Date: 2026-09-06  
Status: **comparative usability specimen; not a LOAM UI selection**  
Parent: `LOAM_INTERACTION_ATLAS.md`  
Companion: `LOAM_INTERACTION_ATLAS_HRA_ARCHAEOLOGY.md`

---

## 0. Why compare h-kernel with HRA

The user reports that HRA has been the easiest household system they have used so far.

h-kernel is a particularly valuable comparison because it is not an unrelated product. It grew from much of the same household domain, canonical-data pressure, and TUI experimentation, but its Brick TUI evolved a different interaction shell.

That makes the comparison unusually useful:

> If HRA felt easier, which interaction differences may explain that, despite h-kernel having more sophisticated widgets, mouse support, responsive layout, and richer workspace structure?

Reference h-kernel revision inspected here:

`722b8460b056bf2d68d1cc837de403ee59f29c0c`

This document distinguishes direct code observations from usability hypotheses.

---

# 1. Shared ancestry: h-kernel is also calendar-first

h-kernel did **not** abandon the HRA idea of temporal orientation.

Its Home module explicitly describes itself as a quiet calendar-first observation surface. It preserves:

- a selected calendar day,
- current observation day,
- Plan / Issue / Cycle markers,
- explicit unavailable calendar marker state,
- selected-day details,
- direct `r` recording from Home,
- arrow/hjkl day and week movement,
- `t` to return to the current observation day.

The calendar therefore remains an important shared strength.

Source trail:

- `editor-tui-app/HKernel/Editor/TUI/Home.hs`
- `editor-tui-app/Main.hs`

### Comparative observation HK-HRA-01

The difference between HRA and h-kernel is **not** simply “HRA had a calendar and h-kernel did not”. Both are time-oriented.

The more interesting difference is what happens *after* temporal orientation.

---

# 2. h-kernel adds a persistent three-focus shell

h-kernel's application shell introduces three explicit focus modes:

1. `CalendarFocus`
2. `SectionFocus`
3. `SurfaceFocus`

The shell visually contains:

- calendar rail,
- section rail,
- selected section surface.

On wide terminals the rail and surface sit side by side. On narrow terminals they stack.

Tab and Shift-Tab rotate focus among the three regions. From Section focus:

- Up/Down or j/k changes section,
- Right/Enter enters the section surface,
- Left returns toward calendar.

Sections are:

- Actual
- Plans
- Envelopes
- Accounts
- Issues
- Reports
- Settings

Source trail:

- `editor-tui-app/HKernel/Editor/TUI/Shell.hs`
- `editor-tui-app/HKernel/Editor/TUI/Model.hs`
- `editor-tui-app/Main.hs`

### Usability hypothesis HK-U01 — explicit shell focus adds a second navigation dimension

HRA mostly asks:

> which day / which object / which action?

h-kernel additionally asks:

> which region currently has interaction focus?

The focus system is powerful and keyboard/mouse friendly, but it may impose an extra piece of working memory.

### Candidate metric

Count **focus-state decisions** separately from semantic decisions.

A UI may have few keystrokes while still demanding repeated awareness of focus mode.

---

# 3. HRA direct mnemonic jump vs h-kernel section rail

HRA Home exposes mnemonic one-key jumps:

- `a` Actual
- `p` Plan
- `i` Issue
- `e` Entitlement
- `v` Reports

h-kernel generally reaches those surfaces through the section rail:

```text
Home/Calendar
   -> Tab to Sections
   -> move section selection
   -> Right/Enter to Surface
```

Mouse users can click section tabs directly, which is a real advantage. But keyboard users no longer have the same one-keystroke domain jump from Home.

### Usability hypothesis HK-U02 — generalized navigation may cost more than mnemonic navigation for a tiny stable section set

A section rail scales elegantly when sections grow or reorder.

But for a personal system with a small stable set of daily domains, HRA's one-key mnemonic mapping may have been faster to internalize and may produce less navigation overhead.

### LOAM experiment candidate

Compare three keyboard strategies using identical synthetic tasks:

A. direct mnemonics from Home

B. section rail + focus

C. command palette

Measure:

- keystrokes,
- wrong-section entries,
- time after one week of familiarity,
- discoverability for a cold start,
- need to look at help text.

---

# 4. h-kernel makes shell focus continuously visible

This is an important counterpoint: h-kernel does not hide its focus complexity.

The shell labels the active region and changes help text based on focus:

- Calendar help
- Section help
- Surface help

The selected section has an active-tab treatment, and section rows show compact status such as:

- number of Actual records,
- number of open Plans,
- open Issue count,
- report readiness.

### Positive observation HK-P01 — focus complexity is honestly represented

If a multi-focus shell is required, h-kernel does a good job exposing it.

The research question is not whether this implementation is poor. It is whether LOAM needs this much shell state in the first place.

---

# 5. h-kernel Home adds range-observation interaction

h-kernel Home supports more than a selected day.

It can also mark a `FROM` day and compare a selected range or selected-to-current observation using:

- Space / click to mark or replace FROM,
- Enter to observe change,
- Esc to clear range.

This is a sophisticated inspection affordance that HRA Home did not expose in the same immediate way.

### Positive observation HK-P02 — richer temporal inquiry is integrated into Home

For investigation, this is powerful. It turns the calendar into both a point selector and range selector.

### Usability hypothesis HK-U03 — inspection power can compete with daily-action clarity

Home now serves at least two strong purposes:

- orient and act on a day,
- construct temporal comparison queries.

For a user primarily trying to record or act, the added range state may increase visual and mental surface area.

### LOAM question

Should range comparison be:

- a Home primitive,
- a report/query mode reached from Home,
- or a secondary gesture that appears only after an explicit compare action?

Do not assume h-kernel or HRA already answered this.

---

# 6. Actual workspace: richer workspace, more nested focus

h-kernel's Actual surface contains two panes:

- Accounts
- Transactions

It tracks an additional `WorkspaceFocus`:

- `AccountsFocus`
- `TransactionsFocus`

Left/Right switches panes; Enter from Accounts moves to Transactions; Enter on a transaction opens reversal.

The surface also exposes multiple entry modes:

- `e`: Expense
- `i`: Income
- `g`: General transaction
- `c`: compare/reconcile selected Account

The selected transaction appears in a detail pane.

Source trail:

- `editor-tui-app/HKernel/Editor/TUI/Actual/Workspace.hs`
- `editor-tui-app/HKernel/Editor/TUI/Actual.hs`

### Positive observation HK-P03 — progressive entry modes reduce ordinary form burden

Expense and Income can have shorter specialized flows while General remains available.

### Usability hypothesis HK-U04 — nested focus depth may be the price

To reverse a transaction, a user may conceptually traverse:

```text
Calendar focus
 -> Section focus
 -> Actual section
 -> Surface focus
 -> Accounts/Transactions pane focus
 -> selected transaction
 -> Reverse flow
```

The structure is coherent, but each level introduces another location that may need to be remembered.

HRA's Actual workspace also had account and transaction selection, but it was entered directly from Home with `a`; there was no separate persistent shell focus layer surrounding it.

### Candidate metric: interaction depth

For each task record:

- semantic target depth,
- presentation focus depth,
- number of nested state machines entered before preview.

---

# 7. h-kernel has more specialized Actual entry paths

h-kernel distinguishes:

- Daily Expense flow
- Income flow
- General Record flow
- Issue realization
- Reversal
- Reconciliation

This can make common cases shorter and friendlier than a raw posting editor.

### Positive observation HK-P04 — surface vocabulary can be closer to household intent

The user can say “Expense” rather than immediately manipulating arbitrary postings.

### Tension HK-T01

HRA's general Actual editor is structurally simple and predictable:

`Description -> Account -> Amount -> ...`

h-kernel gains intent-specific convenience but creates more entry branches.

This produces a key LOAM research question:

> Is it easier to learn one flexible editor with excellent defaults, or several short intent-specific flows with a general escape hatch?

This should be dogfooded rather than decided philosophically.

---

# 8. Plan workspace preserves object-local actions

h-kernel retains one of HRA's strongest interaction properties.

The selected Plan is visible, with details and actions local to it:

- Enter / `c`: Complete & Advance
- `a`: Add
- `e`: Edit
- `x`: Cancel
- `r`: Replace

The Plan list hides mutation targets entirely when open-Plan observation is unavailable rather than treating the unavailable set as empty.

Source trail:

- `editor-tui-app/HKernel/Editor/TUI/Plan/Workspace.hs`
- `editor-tui-app/HKernel/Editor/TUI/Plan.hs`

### Positive observation HK-P05 — object-local actions and fail-closed UI survived

This is likely worth preserving regardless of shell design.

### Comparative observation HK-HRA-02

HRA had `complete / add / cancel / supersede`.
h-kernel evolved this into `complete / add / edit / cancel / replace`.

The vocabulary became more capable, but the core interaction pattern stayed recognizable.

---

# 9. h-kernel's state-machine architecture is more explicit

The top-level TUI `UIState` includes states such as:

- Home
- Workspace
- ActualFlow
- PlanFlow
- MaintenanceFlow
- ReportPicker
- ExpenseRoutingFlow
- ReloadFailure

Actual itself has states such as:

- DailyFlow
- RecordFlow
- ReverseFlow
- ReconcileFlow
- WriteOutcome
- PublishRequested
- ReturnToWorkspace

Plan similarly has Completion and Lifecycle flows plus write outcomes.

This is architecturally clear. It is also evidence that the UI accumulated many nested modes.

### Usability hypothesis HK-U05 — implementation clarity does not automatically mean interaction simplicity

A beautifully typed state machine can still expose too many mode transitions to the human.

LOAM should measure the user's experienced state graph, not infer usability from the elegance of the internal type graph.

---

# 10. Return path is strong in both systems

h-kernel carefully preserves a `selectedDay` when entering and returning from flows.

For example:

- an Actual flow can return to Home on the same selected day,
- an Actual flow entered from the Actual workspace returns to that workspace with the selected day retained,
- Plan and maintenance flows return to their previous surface,
- successful writes reload fresh Household context.

### Positive observation HK-P06 — preserve place, refresh truth also survives

This strongly reinforces HRA-derived candidate law `HRAL-09`.

The difference is that h-kernel often preserves **more place**:

- selected day,
- current section,
- surface focus,
- sometimes pane/list selection.

More preserved context is helpful until the context itself becomes a burden.

---

# 11. Mouse support changes the trade-off

h-kernel's Brick UI supports:

- clickable calendar days,
- clickable section tabs,
- clickable list rows,
- mouse wheel scrolling,
- responsive wide/stacked layout.

HRA's Curses TUI is more strongly keyboard-centered.

### Positive observation HK-P07 — h-kernel is more discoverable for pointer users

A section rail that feels slower on keyboard can be excellent with mouse selection.

### LOAM implication

Do **not** score one navigation topology globally.

The same structure may have different value on:

- keyboard TUI,
- mouse GUI,
- touch mobile.

HRA's direct mnemonic topology may be the right TUI inspiration without being the right GUI navigation model.

---

# 12. Preliminary explanation for the user's HRA preference

The evidence currently supports a plausible, but not yet proven, explanation.

## HRA interaction graph

```text
          selected day
              |
    +---------+---------+---------+---------+
    |         |         |         |         |
    r         a         p         i         e / v
 Record    Actual     Plan      Issue     Entitlement/Reports
              |         |         |
         select obj select obj select obj
              |         |         |
         local action local action local action
```

## h-kernel interaction graph

```text
selected day / calendar
          |
       focus mode
  Calendar / Sections / Surface
          |
       section rail
          |
       section surface
          |
   optional inner pane focus
          |
      selected object
          |
       action flow
          |
    typed flow state(s)
```

Both are coherent.

But HRA's human-visible graph is **flatter**.

### Hypothesis HK-U06 — HRA may have felt easier because it minimized presentation-state navigation

It did not necessarily have fewer domain concepts.

It may simply have made the user navigate fewer *UI states* before reaching the same domain action.

This distinction is important for LOAM.

---

# 13. Interaction complexity dimensions to measure

Future synthetic dogfood should distinguish at least five kinds of complexity.

| Dimension | Question |
|---|---|
| Semantic decisions | How many real-world distinctions must the human decide? |
| Target selection | How much work identifies the object being acted on? |
| Presentation focus | How many UI focus/mode states must be tracked? |
| Data entry | How many fields/defaults/keystrokes are needed? |
| Publication/recovery | How many steps are needed to preview, commit, cancel, or recover? |

A good UI should not hide required **semantic decisions**.

But it should be aggressive about removing accidental **presentation-focus decisions**.

This may become one of the most useful evaluation principles in the Atlas.

---

# 14. Candidate comparison scorecard

Use this for the same scenario in HRA, h-kernel, current LOAM CLI, and later LOAM TUI candidates.

| Measure | HRA | h-kernel | LOAM CLI | Candidate TUI |
|---|---:|---:|---:|---:|
| semantic decisions | | | | |
| target-selection steps | | | | |
| presentation-focus changes | | | | |
| typed characters | | | | |
| default acceptances | | | | |
| internal identifiers recalled | | | | |
| preview transitions | | | | |
| cancel distance | | | | |
| selected-day preservation | | | | |
| selected-object preservation | | | | |
| fail-closed state visible | | | | |

---

# 15. What h-kernel contributes that HRA should not erase

The user's HRA preference should not cause a simplistic rollback.

h-kernel contributes valuable interaction experiments:

1. mouse/click/wheel support,
2. responsive wide vs stacked layout,
3. visible section status summaries,
4. explicit focus rendering,
5. specialized Expense / Income / General entry,
6. integrated account reconciliation,
7. calendar range comparison,
8. richer Plan lifecycle actions,
9. typed top-level and sub-flow state machines,
10. fail-closed hiding of unavailable mutation targets.

Some of these may belong in LOAM even if the outer TUI shell becomes much flatter.

---

# 16. Strongest current synthesis

A promising LOAM TUI experiment is now more specific than “copy HRA”.

Try a shell with:

- HRA-like **stable selected-day Home**,
- HRA-like **direct mnemonic jumps** for frequent workspaces,
- HRA-like **ambient local help**,
- HRA-like **object-local actions**,
- h-kernel-like **mouse support** where available,
- h-kernel-like **responsive layout**,
- h-kernel-like **fail-closed target visibility**,
- h-kernel's better specialized entry flows only where synthetic dogfood proves they beat one general editor,
- LOAM-native semantics underneath rather than either predecessor's domain model.

The experiment should initially avoid a mandatory Calendar/Section/Surface focus cycle.

That is not a rejection of Brick or h-kernel. It is a test of whether the focus shell is necessary.

---

# 17. Next research experiment

Before implementation, create paper/synthetic interaction traces for these tasks:

1. record ordinary purchase on today,
2. record purchase on three days ago,
3. inspect and reverse a mistaken Actual,
4. complete a scheduled/Plan item as Actual,
5. reschedule/replace an upcoming item,
6. move capacity/allocation,
7. inspect why a balance differs from an external account,
8. inspect an overdue nonfinancial attention item.

For each candidate topology, record every human-visible state transition.

The next question is now crisp:

> Can LOAM preserve h-kernel's richer capabilities while keeping HRA's flatter, date-and-object-centered interaction graph?
