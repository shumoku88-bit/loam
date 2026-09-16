# G2-030 — legacy Main workspace retirement obligation DAG

Status: **Generation-2 audit evidence — SIMPLIFY QUALIFIED**

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

The production root loop owns Home interaction only. Object workspaces run in their
own sessions:

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

Production Home `Enter` was already intercepted before `Main.update`, while `a` and
`p` launched the modern sessions directly.

## Retired hidden compatibility entrance

Before retirement, `eventOfKey` mapped physical Tab to `Main.Event.tab`.
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

This was compatibility reachability, not a documented product entrance. G2-030
removes the Tab event, `openScheduled`, and the legacy Scheduled surface entirely.
There is no second Scheduled workspace left for Tab to open.

No corresponding normal production entrance to legacy `Surface.actual` remained:
Home Enter was already intercepted by SelectedDay and Home `a` entered HraActual.
G2-030 removes that unreachable Actual surface as well.

## Retired compatibility island

Removed from `Main`:

- `ReviewCursor` and `ScheduledCursor`;
- derived cursor totals;
- `ActualMode` and `ScheduledMode`;
- the `Surface` type, including cached `lastReview` state;
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
- `recordsForDay`, `homeActualRecords`, and `homeScheduledEvidence` where consumed
  by production HRA surfaces;
- production Home, SelectedDay, HraActual, and HraScheduled sessions.

`Main.State` is now only Home-root presentation state:

```text
selectedDate
notice
```

This removes the second workspace state machine instead of merely making it harder
to reach.

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

## Completed regression bridge

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

The qualified tests show:

- HraActual retains 12 rows, reaches row 11, moves its 8-row viewport, and refuses
  movement beyond the final row without changing selection;
- HraScheduled does the same for 12 current-open occurrences;
- G2-029 open-world Unknown remains explicit;
- Home still distinguishes Scheduled Due, Unknown, and Pending without relying on
  the retired legacy workspace.

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

## Qualification

Qualified code head: `4fd2a62dee6da5e2a4323b072ef5632a8b71b0e9`.

The retired topology passed:

- **Compression Audit #936 — SUCCESS**;
- **Selected Lean Observations #1178 — SUCCESS**;
- **Purpose Catalog Boundary #313 — SUCCESS**;
- **Production TUI #798 — 62/62 SUCCESS**.

Production TUI qualification includes:

- production executable build;
- HRA Actual long-list navigation at step 21;
- Scheduled open-world Unknown at step 22;
- HRA Scheduled long-list/workspace mechanics at step 23;
- selected-day composition and all remaining production surfaces through step 62.

## Generation-2 verdict

**SIMPLIFY QUALIFIED.**

The old Main Actual/Scheduled browse-detail system was a compatibility island after
the production cutover. Its only remaining unique regression value was migrated to
the actual production HRA workspaces before deletion. The root TUI state now owns
only Home focus/notice state, and object workspaces have one production owner each.
