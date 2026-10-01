# LOAM Desk TUI v0 hypothesis

Date: 2026-10-01  
Status: **experiment concluded; implementation retired after real-use comparison with the production TUI**

## 1. Question

Can a separate terminal "household desk" make LOAM easier to inhabit day to day by keeping chronological Actual evidence at the center?

The experiment is successful only if it improves orientation and navigation without duplicating LOAM semantics.

## 1.1 Outcome

The merged v0 was used alongside the existing production TUI.

The result was useful but negative: the calendar + chronological Actual + selected-detail arrangement did **not** create enough practical difference from the production TUI to justify a second terminal shell.

That result triggers the experiment's own kill criterion:

```text
same terminal interaction medium
        +
similar keyboard navigation
        +
same underlying household reads
        ->
insufficiently distinct daily experience
```

The `Loam/Desk/` implementation and `loamDesk` executable are therefore retired from the product tree. Git history preserves the implementation. This document preserves the hypothesis and result.

The next experiment moves the same information-topology question to a GUI, where direct manipulation, pointer selection, resizable panes, rich tables, and graph-to-evidence navigation can create a genuinely different interaction surface.

## 2. Non-goals

v0 does **not** attempt to:

- replace the production TUI;
- replace named CLI commands;
- redesign Actual/Scheduled semantics;
- add a generic UI framework;
- implement every Let's家計簿 feature;
- provide full editing;
- reproduce smooth GUI graphs;
- become a GUI precursor that forces a specific later toolkit.

## 3. Minimal screen

Wide-terminal hypothesis:

```text
 LOAM Desk                     2026-10        cycle: current
+----------------+-----------------------------------------------+
| calendar       | Actual                                        |
|                |                                               |
|     October    | 10/01  PayPay -> Food               680 JPY  |
| Mo Tu ...      | 10/01  SMBC   -> PayPay           3,000 JPY  |
|                | 10/02  Cash   -> Coffee              140 JPY  |
+----------------+-----------------------------------------------+
| day / cycle    | selected                                      |
| local summary  | movement detail / balance effect / provenance |
+----------------+-----------------------------------------------+
| keys: move  date  detail  evidence  future  search  quit       |
+----------------------------------------------------------------+
```

The Actual table receives the largest area.

The left pane is navigation/context, not a dashboard competing for attention.

## 4. v0 scope

Implement only read/navigation behavior.

### Required

1. current-month calendar;
2. chronological Actual rows for the visible interval;
3. row selection;
4. previous/next row;
5. previous/next day;
6. previous/next month;
7. jump to date;
8. selected-row detail/context;
9. persistent help/status line;
10. one route from selected row to deeper evidence/provenance if an existing presentation/application entrance already supports it.

### Optional only if already cheap

- tiny day/cycle totals;
- related Scheduled marker;
- derived balance after selected row;
- a compact text sparkline.

## 5. Explicitly defer writing

Do not add Record/Edit/Correct in the first implementation.

Reasons:

- reading/navigation is enough to test the desk topology;
- write support would immediately duplicate production TUI flows;
- correction and admission semantics deserve deliberate routing through existing Application entrances;
- failure of the desk experiment should remain cheap to delete.

The first write action, if v0 succeeds, should be chosen from observed real use rather than copied from Let's家計簿.

## 6. Keyboard model

Do not reproduce historical shortcuts mechanically.

Start with a small LOAM-native vocabulary:

```text
j / k        previous / next row
h / l        previous / next day
H / L        previous / next month
g            jump to date
Enter        selected detail
e            evidence / provenance
s            related Scheduled / future context
/            search
?            key help
q            quit
```

This is only a hypothesis. Existing LOAM conventions should win where they conflict.

The important property is that the user can navigate rows/days/months without mode-switching.

## 7. Focus model

v0 should have one primary focus:

```text
Actual row selection
```

Calendar selection and context panes follow that focus rather than becoming independent miniature applications.

Avoid multiple nested focus modes unless real use proves they are necessary.

## 8. Data boundary

Desk must consume existing LOAM read/application surfaces.

Preferred dependency direction:

```text
Authority/Core
     |
Application / Presentation
     |
Desk model
     |
terminal rendering
```

Forbidden direction:

```text
Desk parser / renderer
     ->
direct read/write of actual.loam
```

No second accounting implementation belongs in Desk.

## 9. Module boundary hypothesis

Do not create these modules until implementation proves they are useful, but a small starting shape could be:

```text
Loam/Desk/
  Model.lean
  Layout.lean
  CalendarPane.lean
  ActualPane.lean
  ContextPane.lean
  Session.lean
  Executable.lean
```

Prefer fewer files if the first implementation is small.

Do not build a reusable pane/widget framework in advance.

## 10. Terminal-width behavior

Only three coarse layouts are needed initially.

### Wide

Calendar + Actual + context visible together.

### Medium

Calendar becomes a compact header/side strip; Actual remains primary.

### Narrow

Actual only, with date/context exposed through a compact status line or temporary view.

The desk should degrade by removing secondary context, never by making the Actual table unreadable.

## 11. Interaction invariants

The experiment should preserve these rules:

1. selection never mutates household authority;
2. changing month/day only changes view/focus;
3. displayed balances/totals are derived through existing LOAM logic;
4. every visible aggregate states or implies a clear period;
5. navigation from aggregate/context to evidence is reversible;
6. no silent fallback when underlying read state fails;
7. failure/refusal state remains visible in the desk.

## 12. Acceptance test

The v0 experiment is worth keeping if normal use can answer these questions more naturally than the current menu-first route:

- What happened around this date?
- What did I spend from this locus/account?
- What does this selected movement mean?
- What changed the balance?
- Is this related to a scheduled obligation?
- Can I move a week/month backward without losing context?
- Can I return from a detail/observation to the originating row?

The goal is not fewer keystrokes at any cost. The goal is stronger orientation.

## 13. Kill criteria

Delete or stop the experiment if:

- it requires duplicating application/business logic;
- it creates a second canonical read path;
- focus/mode complexity exceeds the production TUI;
- the user consistently leaves the desk to understand basic rows;
- calendar/context panes consume more attention than the Actual table;
- maintaining two TUIs becomes costly before the desk proves a distinct benefit.

## 14. Next experiment after v0

Only after sustained read-only use:

```text
v0 read/navigation
       |
       v
choose one high-frequency write action
       |
       v
route it through existing Application semantics
       |
       v
observe real use before adding another
```

Potential first write actions include "record another item with inherited context" or "correct selected movement", but neither is selected by this document.
