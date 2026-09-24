# G2-031 — Home update Snapshot dependency obligation DAG

Status: **Generation-2 audit evidence — SIMPLIFY QUALIFIED**

Primary instruments: **DRAKONview + semantic dependency DAG + caller inspection**.

## Question

After G2-030 retired the legacy Main Actual/Scheduled workspace state machine,
`Loam.Tui.Main.update` had the shape:

```lean
def update (_snapshot : Snapshot) (state : State) (event : Event) : Step
```

Does the root Home transition still have an independent reason to depend on one
household `Snapshot`, or is that parameter residue from the older state machine?

The audit deliberately separates:

1. evidence needed to **change Home interaction state**;
2. evidence needed to **render Home household answers**;
3. commands such as `g` / known-date navigation that really do use household
   read evidence.

Removing a parameter is justified only if those boundaries remain explicit.

## Transition dependency DAG

Current `Main.State` after G2-030 contains only:

```text
selectedDate
notice
```

The root transition is:

```text
State + Event
     |
     v
 Main.update
     |
     +-- quit  -> Step.quit
     +-- left  -> moveDate -1
     +-- right -> moveDate +1
     +-- up    -> moveDate -7
     +-- down  -> moveDate +7
     `-- other -> unchanged State
```

`moveDate` reads `state.selectedDate` and changes only the selected date / notice.
No branch reads Actual records, Scheduled evidence, Today, Pending evidence, or any
other field reachable from `Snapshot`.

Before this change the type therefore permitted this apparent dependency:

```text
Snapshot -----> Main.update
```

while the implementation had no corresponding semantic edge.

G2-031 removes that false edge:

```lean
def update (state : State) (event : Event) : Step
```

The absence of a `Snapshot` argument now makes snapshot-independence structural
rather than an informal property of an underscore-prefixed unused parameter.

## Production caller inspection

The production root caller is the fallback Home navigation branch in `Cli.loop`:

```text
key
 |
 v
homeEventOfKey
 |
 v
Main.update state event
 |
 v
Step.state
 |
 v
compiledFrameFor bounds snapshot state
 |
 v
HraHome.view bounds snapshot state
```

The same lexical scope owns both `state` and `snapshot`, but they serve different
reasons to change:

- `state` + `event` determine the local Home transition;
- `snapshot` + resulting `state` determine the household answer presentation.

Passing the same `snapshot` through both calls previously made those independent
dependencies look like one transition dependency.

## Real Snapshot dependency retained

Home is not globally snapshot-free.

`HraHome.view` intentionally consumes `Snapshot` for:

- `snapshot.actual.today`;
- selected-day Actual records;
- selected-day Scheduled evidence;
- past-date current-open Scheduled / Pending evidence;
- Today styling and Known Through presentation.

Those are real read-side dependencies and remain unchanged.

The `g` / known-date command is the strongest transition-shaped counterexample:

```text
physical g
   |
   v
Cli.loop explicit branch
   |
   v
selectedDate := snapshot.actual.today
```

This command genuinely needs read evidence. It is already handled outside
`Main.update` and is not represented by `Main.Event`. G2-031 therefore does not
pretend that all Home actions are snapshot-independent; it narrows only the
ordinary `Main.update` transition to its actual inputs.

If this command is ever moved into a shared transition helper, the earned input
would currently be the known date itself, not necessarily the entire household
`Snapshot`.

## Caller / test migration

Caller inspection found the production root call in `Loam/Tui/Cli.lean` and two
Home-focus regression calls in `Loam/Tests/TuiScheduled.lean`.

They now call:

```lean
Main.update state event
```

The Scheduled regression still renders the resulting states with the same
`pendingSnapshot`, so it continues to verify the important separation:

- Home focus moves with the local transition;
- Today remains tied to `snapshot.actual.today`;
- Pending / Scheduled household evidence remains tied to the snapshot.

No compatibility wrapper or overloaded transition API was introduced.

## KEEP boundaries

G2-031 preserves:

- `Snapshot` and `ActualSnapshot` as the admitted process-local Home read image;
- `recordsForDay`, `homeActualRecords`, and `homeScheduledEvidence`;
- `HraHome.view` and all Snapshot-backed Home presentation;
- explicit Scheduled Unknown / refusal distinctions;
- the `g` / known-date branch using `snapshot.actual.today`;
- `SelectedDay`, `HraActual`, and `HraScheduled` Snapshot dependencies where their
  browsing / selection mechanics actually read household evidence;
- canonical reload behavior after writes;
- all authority, persistence, and semantic review boundaries.

The change does **not** claim that `Snapshot` is redundant. It claims only that
`Main.update` was not one of its consumers.

## Qualification

PR #972 qualified the current boundary against current `main`, including the
independent MGA-014 Scheduled replacement-session change merged as #971.

The affected-boundary checks all succeeded:

- **Compression Audit #944 — SUCCESS**;
- **Selected Lean Observations #1188 — SUCCESS**;
- **Purpose Catalog Boundary #325 — SUCCESS**;
- **Production TUI #806 — SUCCESS**.

Production TUI completed its full integration sequence through step 62, including
Home/Scheduled presentation regression coverage. The merge result remained clean
against #971; the PR diff changes only the Home transition caller in `Cli.lean`,
not the Scheduled replacement-session seam.

The G2-031 DRAKON map was a campaign-local qualification artifact. After Generation 2 closed, its builder graduated from the working tree; Git history retains the exact renderer and generated-map contract.

## Generation-2 verdict

**SIMPLIFY QUALIFIED.**

The old `Snapshot` argument was a signature remnant of a broader Main state
machine, not an independent input to the remaining Home transition. G2-031 makes
the transition boundary state its actual dependency set while retaining every
real Snapshot-backed read and presentation dependency around it.
