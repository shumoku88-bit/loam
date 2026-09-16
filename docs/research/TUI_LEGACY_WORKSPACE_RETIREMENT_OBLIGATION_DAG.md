# G2-030 — legacy Main workspace retirement obligation DAG

Status: **Generation-2 implementation — RETIRED CANDIDATE / QUALIFICATION PENDING**

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

Before retirement, the older Main state machine still contained:

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

Production Home `Enter` was intercepted before `Main.update`, while `a` and `p`
launched the modern sessions directly.

## Hidden compatibility entrance

Before retirement, `eventOfKey` still mapped physical Tab to `Main.Event.tab`.
`homeEventOfKey` fell through to `eventOfKey`, and Tab was not part of the documented
Home grammar. Consequently one undocumented route remained:

```text
Home physical Tab
  -> homeEventOfKey fallback
  -> Event.tab
  -> Main.update
  -> openScheduled
  -> legacy Surface.scheduled
```

This was compatibility reachability, not a documented product entrance.

No corresponding normal production entrance to legacy `Surface.actual` remained:
Home Enter was intercepted by SelectedDay and Home `a` entered HraActual.

## Legacy island inventory

Retired surface in `Main`:

- `ReviewCursor` and `ScheduledCursor`;
- derived cursor totals;
- `ActualMode` and `ScheduledMode`;
- `Surface.actual`, `Surface.scheduled`, and the cached `lastReview` payload;
- cursor construction and movement helpers;
- `openActual` / `openScheduled`;
- legacy Actual/Scheduled branches in `Main.update`;
- state-machine theorems whose statements mentioned those branches;
- legacy Actual browse/detail renderers;
- legacy Scheduled browse/detail/refusal renderers;
- the hidden Tab compatibility entrance and Actual-browse return special case in
  `Cli.loop`;
- `HraHome.view` compatibility dispatch branches for those legacy surfaces.

Retained Home/shared surface:

- `Snapshot` and `ActualSnapshot`;
- selected date and notice interaction state;
- date movement and Home calendar helpers;
- `recordsForDay`, `homeActualRecords`, and `homeScheduledEvidence` where still
  consumed by production HRA surfaces;
- production Home, SelectedDay, HraActual, and HraScheduled sessions.

## Migration obligation discovered

Legacy tests contained one behavioral guarantee that the production HRA tests had
not independently pinned: navigation beyond the first local viewport.

`TuiActual` created 12 legacy Actual rows and verified that selection could reach the
11th row while the local window followed it.

`TuiScheduled` created 12 legacy Scheduled occurrences and verified the same class
of behavior.

The modern workspaces implement their own independent 8-row windows:

```text
HraActual      -> txWindowStart
HraScheduled   -> occWindowStart
```

Therefore old cursor tests did not validate production window mechanics.

## Completed bridge

The guarantee was migrated before retirement:

```text
legacy long-list regression
          |
          v
production HRA regression
          |
          +-- HraActual reaches row 11 and window follows
          `-- HraScheduled reaches row 11 and window follows
          |
          v
legacy compatibility island retired
```

The migrated tests exercise the production state/update/view path directly rather
than reproducing the old `ReviewCursor` or `ScheduledCursor` abstraction.

## KEEP boundaries

G2-030 preserves:

- Home day/week navigation and notice behavior;
- production Home key grammar from `docs/TUI.md`;
- SelectedDay composition;
- HraActual Focus Day / All Current, locus filtering, ordering, and actions;
- HraScheduled Focus Day / All Current, Unknown preservation from G2-029, locus
  filtering, and actions;
- canonical reload after writes;
- read semantics and household authority outside presentation.

## Qualification obligations

The retired topology must show that:

- HraActual independently navigates beyond its first 8-row viewport;
- HraScheduled independently does the same;
- selected record/occurrence and rendered window follow the local workspace cursor;
- end-of-list refusal keeps selection stable;
- G2-029 Unknown behavior remains explicit;
- no undocumented Tab route opens a second Scheduled workspace;
- no production branch constructs legacy Actual/Scheduled surfaces;
- Home navigation remains intact;
- production HRA tests and the full Production TUI suite remain green;
- Compression Audit and Selected Lean Observations remain green.

## Retirement implementation

The production HRA long-list bridge was staged before removal. The branch now
removes `ReviewCursor`, `ScheduledCursor`, browse/detail modes, legacy `Surface`
variants, legacy renderers, the hidden Tab entrance, and the Actual-browse return
special case. `Main.State` is reduced to selected Home date plus notice, while
SelectedDay, HraActual, and HraScheduled remain the object-workspace owners.

## Generation-2 verdict

**SIMPLIFY CANDIDATE / QUALIFICATION PENDING.**

The compatibility island has been retired only after its unique long-list guarantee
was moved to the production HRA workspaces. Promote this result to
`SIMPLIFY QUALIFIED` only after the retired topology passes Production TUI,
Compression Audit, and Selected Lean Observations.
