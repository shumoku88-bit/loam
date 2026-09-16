# Module Granularity Audit Ledger

Checkpoint base: `448fffdbe0b161151f8f21811bc1cde177d2b1f4`

Status: **MGA-012 CLOSED — ActualDateCorrection terminal loop stays inline; physical Session symmetry rejected**

## Refreshed inventory

The module-granularity inventory was rerun on the PR #964 merge candidate after extracting
`Loam.Tui.CorrectionSession`.

```text
Lean modules: 332
Modules <= 80 lines: 89
Modules with exactly one local consumer: 52
Declared Lake roots: 17
Production-like modules unreachable from declared roots: 0
```

The raw counts again increased by one module, one small module, and one
one-consumer module. MGA-011 deliberately tests whether that apparent metric
regression can still represent a cleaner ownership boundary. No production-like
surface became unreachable. The two qualified dependency seams are now explicit:

```text
Tui.Cli -> RecordSession     -> Record + HouseholdCommand
Tui.Cli -> CorrectionSession -> Correction + HouseholdCommand
```

Current focused metrics:

```text
Loam.Tui.Cli              1179 lines / 32 declarations / fan-out 55
Loam.Tui.RecordSession      48 lines /  1 declaration  / fan-in 1 / fan-out 5
Loam.Tui.CorrectionSession  49 lines /  1 declaration  / fan-in 1 / fan-out 5
```

This is an important calibration result for the audit: file count, small-module
count, one-consumer count, and composition-root fan-out are candidate detectors,
not verdicts. A justified ownership boundary can make all four raw metrics look
worse while reducing change coupling.

## MGA-001 — `Loam.Sha256`

Classification: **RETIRED — CLOSED by PR #959**

Evidence before retirement:

- `fan_in = 0`, `fan_out = 0`;
- unreachable from all declared Lake roots;
- no current source imported `Loam.Sha256`;
- its own contract tied it to the historical-admission prepare/verify boundary;
- repository history showed the former production caller had already retired.

PR #959 deleted only `Loam/Sha256.lean`. Compression Audit and Selected Lean
Observations both passed before merge. The refreshed inventory reports zero
production-like unreachable modules.

This was not a size-based merge. It was stale-surface retirement.

## MGA-002 — `Loam.Persistence.ScheduledPersistence`

Classification: **KEEP_BOUNDARY**

Candidate signal:

- exactly one local consumer:
  `Loam.Persistence.ScheduledLifecyclePersistence`;
- compact child codec.

Why the boundary remains justified:

- it owns pure encode/decode of `ScheduledMemory String`;
- the lifecycle module separately owns the complete envelope, terminal projection,
  staging/rename, and authority-file I/O;
- the child codec has had an independent dependency-narrowing reason to change
  after the old standalone Scheduled authority retired.

One consumer is therefore not evidence of sameness.

## MGA-003 — `Loam.CycleFundingConfig`

Classification: **KEEP_BOUNDARY**

Candidate signal:

- 29 lines;
- exactly one local consumer: `Loam.CycleBudgetReview`.

Why the boundary remains justified:

- it owns replaceable configuration grammar/load policy;
- `CycleBudgetReview` owns query orchestration and canonical evidence loading;
- review behavior has changed independently without requiring config changes.

## MGA-004 — small shared controls

Classification: **KEEP_BOUNDARY**

False-positive controls retained deliberately:

- `Loam.Core.Purpose`;
- `Loam.FreshNumberedToken`;
- `Loam.ScheduledActualOwnership`;
- `Loam.SparseEffectIdentity`.

Each is small but has multiple independent consumers or owns a shared law/order
that would otherwise be duplicated or hidden.

## MGA-005 — `Loam.Tui.CompletionPrompt`

Classification: **KEEP_BOUNDARY (for now)**

Candidate signal:

- 25 lines;
- exactly one local consumer: `Loam.Tui.Cli`.

Counter-evidence:

- PR #622 deliberately moved recognition ownership under `Tui/`;
- it is one coherent pure recognition projection;
- folding it into the already-large `Tui.Cli` would reduce file count while
  increasing navigation density.

Revisit only if broader TUI decomposition changes the consumer topology.

## MGA-006 — root production one-consumer pass

Classification: **NO COLLAPSE / MOVE CANDIDATE FOUND**

After MGA-001, the root layer has only two substantive one-consumer cases beyond
aggregation barrels:

1. `CycleFundingConfig`, already classified KEEP in MGA-003;
2. `AccountingRoleReview`, consumed today only by
   `Tui.LocusAdmissionAdministrationSession`.

`AccountingRoleReview` is also **KEEP_BOUNDARY**:

- PR #762 deliberately extracted it as a presentation-neutral canonical evidence
  loading boundary rather than leaving authority reads inside the TUI session;
- the module reuses `AccountingRolePublisher.eligibleInitialLoci`, so read
  presentation cannot invent a second eligibility rule;
- PR #945 later changed the review independently to include current-anchor evidence
  when Generation-2 found a virginity gap.

That history is positive evidence of an independent reason to change. Its current
single consumer does not justify folding authority reads back into the TUI.

`Loam.Core`, `Loam.Application`, and `Loam.Observations` are aggregation modules,
not semantic micro-modules, and are excluded from collapse ranking.

## Current verdict

The audit still does not support a general diagnosis that LOAM is fragmented into
too many tiny Lean modules. MGA-010 adds a stronger distinction:

```text
small + shared/independent responsibility       -> KEEP_BOUNDARY
one consumer + independent ownership/effect seam -> KEEP_BOUNDARY can be valid
unreachable + retired historical responsibility  -> RETIRE_CANDIDATE
large root + object-local effect loops             -> SPLIT_CANDIDATE, one slice at a time
```

A raw increase in module count is not a failure if the new file owns one durable
reason to change and no semantic or authority ownership is duplicated.

Audit vocabulary:

```text
KEEP_BOUNDARY
KEEP_INLINE
COLLAPSE_CANDIDATE
RETIRE_CANDIDATE
MOVE_LAYER_CANDIDATE
SPLIT_CANDIDATE
SPLIT_QUALIFIED
NEEDS_DRAKON
NEEDS_HISTORY
```

## MGA-010 — `Loam.Tui.RecordSession` focused extraction

Classification: **KEEP_BOUNDARY / SPLIT_QUALIFIED — CLOSED by PR #961**

MGA-009 found that `Loam.Tui.Cli` mixed root navigation/orchestration with
object-local terminal editor loops. Record was chosen as the first narrow
experiment because neighboring TUI features already demonstrated a stable
presentation-module / terminal-session seam.

PR #961 moved only the Record key-read/redraw/publication loop into
`Loam.Tui.RecordSession`:

- `Loam.Tui.Record` still owns editor state, validation, transitions, and view;
- `RecordSession` owns terminal reads, dirty redraws, publication delegation, and
  retry-on-publication-error for one editor session;
- `HouseholdCommand.record` still owns the authoritative production write entrance;
- `Tui.Cli` still loads the selected world, reloads canonical evidence after the
  session, and chooses the destination surface.

The PR head passed:

- Production TUI;
- Compression Audit;
- Module granularity inventory;
- Selected Lean Observations;
- Purpose Catalog Boundary.

No second semantic engine, authority boundary, or canonical state owner was
introduced. The experiment therefore graduates despite adding one 48-line,
one-consumer module.

Historical independence remains naturally young because the boundary was just
created. Future co-change history may strengthen or challenge the verdict, but
there is enough present ownership/effect evidence to keep the boundary.

## MGA-011 — `Loam.Tui.CorrectionSession` focused extraction

Classification: **KEEP_BOUNDARY / SPLIT_QUALIFIED — CLOSED by PR #964**

PR #964 moved only the Correction terminal key-read/redraw/publication loop into
`Loam.Tui.CorrectionSession`:

- `Loam.Tui.Correction` still owns replacement-editor state, validation,
  transitions, publication-intent construction, and view;
- `CorrectionSession` owns terminal reads, dirty redraws, delegation to
  `HouseholdCommand.correctActual`, and retry-on-publication-error;
- `HouseholdCommand.correctActual` remains the authoritative production write
  entrance;
- `Tui.Cli` still owns selected-world loading, canonical reload, and destination
  workspace orchestration.

The PR head passed all focused qualification gates:

- Production TUI;
- Compression Audit;
- Module granularity inventory;
- Selected Lean Observations;
- Purpose Catalog Boundary.

The refreshed inventory reported 332 Lean modules, 89 modules at or below 80
lines, 52 one-consumer modules, and zero production-like modules unreachable from
Lake roots. Those first three counts rose by one again, but the semantic result is
positive: the change isolates one effect/change reason without creating another
state owner or authority boundary.

MGA-010 and MGA-011 together establish that a small one-consumer `*Session`
module can be justified when it owns an effect shell that changes for different
reasons from the pure editor/presentation module.

## MGA-012 — `Loam.Tui.ActualDateCorrection` anti-symmetry control

Classification: **KEEP_INLINE / SPLIT_REJECTED**

MGA-012 deliberately tested the opposite conclusion from MGA-010 and MGA-011.
`ActualDateCorrection` already has a clean semantic boundary: the module owns
editor state, date validation, transition, publication intent, and view, while
`HouseholdCommand.correctActualDate` remains the authoritative write entrance.
The only question was whether the tiny terminal/effect loop still living in
`Tui.Cli` deserved another physical `*Session` module.

The comparison rejects that split for now:

- the loop has one caller and only one selected-day entrance;
- the caller must still own selected-record lookup, `initial?`, first editor
  redraw, canonical reload, `SelectedDay.refreshed`, and destination redraw, so
  extracting the inner loop removes little workflow-navigation burden;
- the effect shell carries no reusable world/catalog context and returns only a
  short notice;
- `Loam/Tui/ActualDateCorrection.lean` has only one repository-history commit,
  PR #519, where the editor, selected-day delegation, publication wiring, tests,
  and terminal loop were introduced together; there is no historical evidence
  yet that the shell changes independently;
- semantic ownership is already non-duplicated and authority remains outside the
  TUI, so leaving the shell inline does not create a second model or writer.

This differs from Record and Correction in an important way. Their extraction
removed a substantial object-local terminal session from the composition root and
made an independently useful call boundary. For ActualDateCorrection, creating a
new file would mostly turn a logically separable but tiny implementation detail
into another one-consumer module. Logical separability is therefore not enough by
itself to justify physical module ownership.

The anti-symmetry control is successful because it produces a negative result:

```text
same editor/session shape
!=
automatically same file split
```

The current dependency shape remains:

```text
Tui.Cli
  -> ActualDateCorrection   (state / validation / transition / view)
  -> HouseholdCommand.correctActualDate  (authoritative write entrance)
```

No production code changes are required for MGA-012.

## MGA-013 — remaining Scheduled local-loop topology

Classification: **NEEDS_DRAKON / NEEDS_HISTORY — NO BATCH EXTRACTION**

Three local Scheduled editor/effect loops remain in `Tui.Cli`:

1. `scheduledCompletionLoop`;
2. `scheduledCancellationLoop`;
3. `scheduledReplacementLoop`.

They must not be treated as a naming family. Their continuation semantics differ:
completion returns a Boolean into next-Scheduled creation and routing inheritance;
cancellation is a compact confirmation/publication path; replacement owns an
editor retry path closer to Correction. MGA-013 should compare those three
control-flow shapes before considering any further physical split.

The next audit therefore asks which, if any, of those loops has a durable
independent change/effect boundary that materially improves navigation when
extracted. A shared `Scheduled*Session` pattern is not an objective.
