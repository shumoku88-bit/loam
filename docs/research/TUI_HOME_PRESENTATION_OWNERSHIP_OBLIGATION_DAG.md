# G2-028 — TUI Home presentation ownership obligation DAG

Status: **Generation-2 audit evidence — SIMPLIFY QUALIFIED**

Primary instruments: **DRAKONview + production reachability + reference DAG**.

## Question

After the HRA-shaped production-shell cutover, did the older
`Loam.Tui.Main.homeView` still own an independent product surface, or had it
become migration residue?

This question was deliberately narrower than `Surface.home`. Home remains a
real interaction state and navigation destination. G2-028 audited
**presentation ownership**, not the existence of Home in the state machine.

## Qualified production root

Production rendering now has one explicit surface dispatcher:

```text
Cli.compiledFrameFor
  -> HraHome.view bounds snapshot state
       |
       +-- Surface.home
       |     -> HraHome.homeView
       |
       +-- Surface.actual browse
       |     -> Main.actualBrowseView
       |
       +-- Surface.actual detail
       |     -> Main.actualDetailView
       |
       `-- Surface.scheduled
             -> Main.scheduledView
```

`Main.view` is no longer present. Home presentation ownership is singular:
`HraHome.homeView` is the production Home renderer.

## Qualified reference DAG

The audit separated helpers that remain shared from a presentation island that
had no production entrance.

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
   +-- Actual -> Main.actualBrowseView / actualDetailView
   |
   `-- Scheduled -> Main.scheduledView

retired legacy-only island
   |
   +-- dayText -> calendarSpans
   +-- recentActualPreview -> homeActualPreview
   +-- homeScheduledRecords -> homeScheduledPreview
   +-- listAt? -> actualPreviewSpans / scheduledPreviewSpans
   +-- scheduledHeader
   +-- homeEvidenceSpans -> homeEvidenceRow
   +-- Main.homeView
   +-- Main.view
   `-- screenBounds / screenFor
```

The old Home-only preview/calendar composition had no independent production,
authority, proof, or interaction reason to change. Shared read and navigation
helpers remained because the HRA Home still consumes them.

## Historical evidence

The HRA-shaped Home entered production in PR #512,
`feat(tui): establish HRA-shaped production shell`.

That change rewired `Cli.compiledFrameFor` from the old `Main.view` route to
`HraHome.view` while intentionally retaining existing workspace views. The
later double-Home shape was therefore a migration bridge: Home changed owner
first while Actual/Scheduled rendering stayed in `Main`.

G2-028 qualified that the bridge no longer needed the old Home renderer.

## Implemented simplification

PR #960, `refactor(tui): retire G2-028 legacy Home renderer`, implemented the
ownership collapse.

The change:

- made `HraHome.view` explicitly dispatch Home, Actual browse/detail, and
  Scheduled surfaces;
- retired `Main.homeView` and its Home-only preview/calendar chain;
- retired `Main.view`, `screenFor`, and `screenBounds`;
- retained `Surface.home`, Home navigation, cached-review state, and all
  workspace transitions;
- retained `selectedMonth`, `calendarSlot`, `homeActualRecords`, and
  `homeScheduledEvidence` because HRA Home still consumes them;
- changed Scheduled TUI regression rendering to use the production
  `HraHome.view` dispatcher;
- moved the superseded-undated semantic regression to `RecordReview`;
- retired the TUI-only `ActualSnapshot.undatedCount` projection after its last
  presentation consumer disappeared.

The implementation head was
`4ce3fb5ecc3d65ebf3ac4bc23406688f087d85c5` and PR #960 merged as
`ae013f36a2c2761aaf7831e2b8a94e9216aaec25`.

## KEEP boundaries

G2-028 preserved:

- `Surface.home` and cached-review navigation state;
- Home date navigation and Home-to-workspace transitions in `Main.update`;
- `selectedMonth` and `calendarSlot`, consumed by `HraHome`;
- `homeActualRecords`, consumed by HRA Home Actual presentation;
- `homeScheduledEvidence`, consumed by HRA Home Scheduled/status presentation;
- all Actual browse/detail behavior;
- all Scheduled browse/detail/refusal behavior;
- `.undated` query semantics in `ActualReview` and the line CLI;
- HRA Home Today/focus/Pending presentation and dynamic viewport behavior;
- household authority and read semantics outside presentation.

## Qualification result

The implementation head was qualified after the final patch correction.

- Compression Audit run #918: **SUCCESS**.
- Selected Lean Observations run #1156: **SUCCESS**.
- Production TUI run #780: **SUCCESS, all 62 verification steps passed**.
- Production executable build: **SUCCESS**.
- Shared Actual review checks, including the moved `.undated` semantic
  regression: **SUCCESS**.
- Full-day Actual local-window navigation: **SUCCESS**.
- Scheduled browse/detail/open-world Unknown: **SUCCESS**.
- HRA Scheduled workspace mechanics, including HRA Home Pending/Today/focus
  presentation exercised by that test surface: **SUCCESS**.
- Selected-day Actual and Scheduled composition: **SUCCESS**.
- Remaining Reports, Capacity, Budget, routing, footer geometry, and PTY
  interaction gates completed without regression.

The qualification therefore establishes both halves of the obligation: the old
presentation island is gone, while the independently meaningful Home state,
read helpers, and Actual/Scheduled workspace behavior remain live.

## Generation-2 verdict

**SIMPLIFY QUALIFIED.**

The old Home renderer was migration residue rather than an independent product
surface. LOAM now has one production Home presentation owner and one production
surface dispatcher, while preserving the semantic and interaction boundaries
that actually carry independent meaning.
