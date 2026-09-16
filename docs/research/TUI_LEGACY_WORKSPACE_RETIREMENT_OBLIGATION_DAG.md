# G2-030 — legacy Main workspace retirement obligation DAG

Status: **Generation-2 audit evidence — SIMPLIFY IDENTIFIED / MIGRATION REQUIRED**

Primary instruments: **production reachability + DRAKONview + interaction-regression DAG**.

## Question

After production cut over to `SelectedDay`, `HraActual`, and `HraScheduled`, does
`Loam.Tui.Main` still need to own its older Actual/Scheduled browse-detail state
machine, or is that machinery now a compatibility island?

The audit distinguishes two questions:

1. whether the legacy state machine still has a documented production entrance;
2. whether its tests still carry behavior guarantees that have not yet been moved
   to the production workspaces.

Retirement is allowed only after both are answered.

## Current production entrance DAG

The documented Home grammar is:

```text
Enter -> SelectedDay
a     -> HraActual
p     -> HraScheduled
```

`Cli.loop` intercepts those keys before its fallback into `Main.update`.
Therefore the normal production paths are:

```text
Home
  +-- Enter --> SelectedDay session
  +-- a -----> HraActual session
  `-- p -----> HraScheduled session
```

The older Main state machine still contains:

```text
Surface.home (cached Actual cursor)
Surface.actual ReviewCursor ActualMode
Surface.scheduled cached ReviewCursor ScheduledCursor ScheduledMode
```

and transitions:

```text
Main.update .enter -> legacy Surface.actual
Main.update .tab   -> legacy Surface.scheduled
```

but production Home `Enter` is intercepted before `Main.update`, while `a` and `p`
launch the modern sessions directly.

## Hidden compatibility entrance

`eventOfKey` still maps physical Tab to `Main.Event.tab`. `homeEventOfKey` falls
through to `eventOfKey`, and Tab is not part of the documented Home grammar.
Consequently one undocumented route remains:

```text
Home physical Tab
  -> homeEventOfKey fallback
  -> Event.tab
  -> Main.update
  -> openScheduled
  -> legacy Surface.scheduled
```

This is compatibility reachability, not a documented product entrance.

No corresponding normal production entrance to legacy `Surface.actual` remains:
Home Enter is intercepted by SelectedDay and Home `a` enters HraActual.

## Legacy island inventory

Candidate retirement surface in `Main`:

- `ReviewCursor` and `ScheduledCursor`;
- derived cursor totals;
- `ActualMode` and `ScheduledMode`;
- `Surface.actual`, `Surface.scheduled`, and the cached `lastReview` payload;
- cursor construction and movement helpers;
- `openActual` / `openScheduled`;
- legacy Actual/Scheduled branches in `Main.update`;
- state-machine theorems whose statements mention those branches;
- legacy Actual browse/detail renderers;
- legacy Scheduled browse/detail/refusal renderers;
- the hidden Tab compatibility entrance and Actual-browse return special case in
  `Cli.loop`;
- `HraHome.view` compatibility dispatch branches for those legacy surfaces.

Likely retained Home/shared surface:

- `Snapshot` and `ActualSnapshot`;
- selected date and notice interaction state;
- date movement and Home calendar helpers;
- `recordsForDay`, `homeActualRecords`, and `homeScheduledEvidence` where still
  consumed by production HRA surfaces;
- production Home, SelectedDay, HraActual, and HraScheduled sessions.

The audit does **not** authorize this entire deletion yet.

## Migration obligation discovered

Legacy tests still contain one behavioral guarantee that the production HRA tests
have not independently pinned: navigation beyond the first local viewport.

`TuiActual` creates 12 legacy Actual rows and verifies that selection can reach the
11th row while the local window follows it.

`TuiScheduled` creates 12 legacy Scheduled occurrences and verifies the same class
of behavior.

The modern workspaces implement their own independent 8-row windows:

```text
HraActual      -> txWindowStart
HraScheduled   -> occWindowStart
```

Therefore old cursor tests do not validate production window mechanics. Before
retiring the legacy island, equivalent long-list tests must be moved to
`HraActual` and `HraScheduled` themselves.

## Required bridge

```text
legacy long-list regression
          |
          v
migrate guarantee to production HRA tests
          |
          +-- HraActual reaches row 11 and window follows
          `-- HraScheduled reaches row 11 and window follows
          |
          v
qualify production TUI
          |
          v
retire compatibility state machine
```

The migration must test the production state/update/view path, not reproduce the
old `ReviewCursor` or `ScheduledCursor` abstraction under a new name.

## KEEP boundaries

G2-030 must preserve:

- Home day/week navigation and notice behavior;
- production Home key grammar from `docs/TUI.md`;
- SelectedDay composition;
- HraActual Focus Day / All Current, locus filtering, ordering, and actions;
- HraScheduled Focus Day / All Current, Unknown preservation from G2-029, locus
  filtering, and actions;
- canonical reload after writes;
- read semantics and household authority outside presentation.

## Qualification obligations

Before retirement:

- HraActual must independently prove navigation beyond its first 8-row viewport;
- HraScheduled must independently prove the same;
- selected record/occurrence and rendered window must follow the global local-state
  cursor;
- end-of-list refusal must keep selection stable;
- G2-029 Unknown behavior must remain explicit.

After retirement:

- no undocumented Tab route may open a second Scheduled workspace;
- no production branch may construct legacy Actual/Scheduled surfaces;
- Home navigation must remain intact;
- production HRA tests and the full Production TUI suite must remain green;
- Compression Audit and Selected Lean Observations must remain green.

## Generation-2 verdict

**SIMPLIFY IDENTIFIED / MIGRATION REQUIRED.**

The older Main Actual/Scheduled state machine no longer owns the documented
production workspaces and has only a hidden Tab compatibility entrance. Its removal
is strongly indicated, but two useful long-list regressions still live only on the
legacy abstractions. Move those guarantees to the production HRA workspaces first;
then retire the compatibility island rather than deleting the tests with it.
