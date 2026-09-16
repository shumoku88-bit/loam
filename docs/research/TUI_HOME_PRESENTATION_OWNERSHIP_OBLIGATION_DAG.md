# G2-028 — TUI Home presentation ownership obligation DAG

Status: **Generation-2 audit evidence — SIMPLIFY IDENTIFIED**

Primary instruments: **DRAKONview + production reachability + reference DAG**.

## Question

LOAM currently contains two Home renderers:

- `Loam.Tui.HraHome.homeView`, which is the production Home presentation;
- `Loam.Tui.Main.homeView`, the earlier selected-day preview Home.

G2-028 asks whether the older renderer and its private presentation chain still
own an independent product surface, or whether they are migration residue from
the HRA-shaped production-shell cutover.

The question is deliberately narrower than `Surface.home`. Home remains a real
interaction state and navigation destination. This audit concerns **presentation
ownership**, not removal of Home from the state machine.

## Production root

The production renderer is explicit:

```text
Cli.compiledFrameFor
  -> HraHome.view bounds snapshot state
       |
       +-- Surface.home
       |     -> HraHome.homeView
       |
       +-- non-Home
             -> legacy Main workspace rendering
```

`compiledFrameFor` does not call `Main.view` directly. `HraHome.view` intercepts
Home before any delegation.

## Reference DAG

Current repository references establish three different classes.

```text
production root
   |
   v
HraHome.view
   |
   +-- Home -> HraHome.homeView
   |            |
   |            +-- KEEP selectedMonth / calendarSlot
   |            +-- KEEP homeActualRecords
   |            +-- KEEP homeScheduledEvidence
   |            +-- KEEP plainLine / mutedLine / blankLine
   |
   +-- Actual/Scheduled -> Main workspace views

legacy-only island in Main
   |
   +-- dayText -> calendarSpans --------------------------+
   +-- recentActualPreview -> homeActualPreview ----------|
   +-- homeScheduledRecords -> homeScheduledPreview ------|
   +-- listAt? -> actualPreviewSpans / scheduledPreviewSpans
   +-- scheduledHeader -----------------------------------|
   +-- homeEvidenceSpans -> homeEvidenceRow --------------|
   +-------------------------------------------------------+
                                                           v
                                                    Main.homeView
                                                           |
                                         direct consumer: TuiActual regression
```

`Main.view` itself has only two current external roles:

1. `HraHome.view` delegates non-Home surfaces to it;
2. `TuiScheduled` uses it to render Scheduled test states.

That means Home ownership can be made singular without losing workspace
rendering: `HraHome.view` can dispatch Actual/Scheduled directly to the existing
workspace view functions, and the tests can exercise that same production
dispatcher.

## Historical evidence

The HRA-shaped Home entered production in PR #512,
`feat(tui): establish HRA-shaped production shell`.

That change rewired `Cli.compiledFrameFor` from the old `Main.view` route to
`HraHome.view` while deliberately retaining existing workspace views. The
current double-Home shape is therefore consistent with a migration bridge:
Home changed owner first, while Actual/Scheduled rendering stayed in `Main`.

G2-028 asks whether that bridge still needs the old Home renderer. Current
reachability says no.

## Test ownership

The old Home is not protected by a production contract. Its only direct current
consumer is a legacy assertion in `Loam/Tests/TuiActual.lean`.

The semantic behavior that assertion indirectly exercised is independently
covered elsewhere:

- `ActualReview.select ... .undated` is a real read-side query;
- `Loam/Tests/RecordReview.lean` already checks undated evidence discovery;
- G2-027 established that an undated count is derived, not snapshot authority.

A test that exists only to keep an unreachable renderer alive is not an
independent product reason to retain that renderer.

## Intended simplification

The candidate target is:

```text
Surface.home                   KEEP
Main.update Home transitions   KEEP
selectedMonth / calendarSlot   KEEP
homeActualRecords              KEEP
homeScheduledEvidence          KEEP
Actual/Scheduled views         KEEP

HraHome.view
  |-- Home       -> HraHome.homeView
  |-- Actual     -> Main.actualBrowseView / actualDetailView
  `-- Scheduled  -> Main.scheduledView

RETIRE
  Main.homeView
  Main.view dispatcher
  Main.screenFor / screenBounds
  legacy Home-only preview/calendar helpers
  TUI-only ActualSnapshot.undatedCount projection if it has no remaining consumer
```

This is an ownership simplification, not merely dead-code deletion. After the
change there is one production Home renderer and one dispatcher that chooses it.

## KEEP boundaries

G2-028 must preserve:

- `Surface.home` and cached-review navigation state;
- Home date navigation and Home-to-workspace transitions in `Main.update`;
- `selectedMonth` and `calendarSlot`, consumed by `HraHome`;
- `homeActualRecords`, consumed by `HraHome.actualLines`;
- `homeScheduledEvidence`, consumed by HRA Home Scheduled/status presentation;
- all Actual browse/detail and Scheduled browse/detail/refusal behavior;
- `.undated` query semantics in `ActualReview` and the line CLI;
- HRA Home Today/focus/Pending presentation and dynamic viewport behavior.

## Qualification obligations

An implementation PR should establish that:

- production has exactly one Home renderer entry, `HraHome.homeView`;
- `HraHome.view` explicitly dispatches Home, Actual, and Scheduled surfaces;
- no `Main.homeView`, `Main.view`, `screenFor`, or `screenBounds` production/test
  consumer remains;
- Home navigation state still enters/exits Actual and Scheduled correctly;
- Scheduled browse/detail/Unknown tests render through `HraHome.view` and remain
  unchanged semantically;
- HRA Home calendar, Pending, Today/focus, footer, and viewport tests remain green;
- Actual browse local-window and HRA Actual mechanics remain green;
- RecordReview keeps `.undated` semantics independently green;
- Compression Audit and Selected Lean Observations remain green.

## Generation-2 verdict

**SIMPLIFY IDENTIFIED.**

The old Home renderer no longer owns a production entrance. The right boundary
is not to delete Home state, but to retire the obsolete presentation island and
make the HRA production dispatcher the single owner of Home presentation.