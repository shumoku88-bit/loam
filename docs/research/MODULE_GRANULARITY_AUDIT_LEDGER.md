# Module Granularity Audit Ledger

Checkpoint base: `448fffdbe0b161151f8f21811bc1cde177d2b1f4`

Status: **MGA-011 IMPLEMENTATION EXPERIMENT — Correction terminal session extraction under qualification**

## Refreshed inventory

The module-granularity inventory was rerun on the PR #961 head after extracting
`Loam.Tui.RecordSession`.

```text
Lean modules: 331
Modules <= 80 lines: 88
Modules with exactly one local consumer: 51
Declared Lake roots: 17
Production-like modules unreachable from declared roots: 0
```

The raw counts increased by one module, one small module, and one one-consumer
module. That is expected: MGA-010 intentionally added a physical boundary.
The important result is that no production-like surface became unreachable and
that the new dependency direction is explicit:

```text
Tui.Cli -> RecordSession -> Record + HouseholdCommand
```

Current focused metrics:

```text
Loam.Tui.Cli           1200 lines / 33 declarations / fan-out 54
Loam.Tui.RecordSession   48 lines /  1 declaration  / fan-in 1 / fan-out 5
Loam.Tui.Record          302 lines / 28 declarations / fan-in 7 / fan-out 6
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

## MGA-011 — `Loam.Tui.CorrectionSession` candidate

Classification: **SPLIT_CANDIDATE — IMPLEMENTATION EXPERIMENT**

This branch moves only the Correction terminal key-read/redraw/publication loop
into `Loam.Tui.CorrectionSession`. `Correction` keeps replacement-editor state,
validation, transitions, and view; `HouseholdCommand.correctActual` stays the
authoritative write entrance; `Tui.Cli` keeps selected-world loading, canonical
reload, and workspace destination. Graduation remains conditional on focused CI
and the refreshed module inventory.

Five local editor/effect loops remain in `Tui.Cli` after MGA-010:

1. `correctionLoop`;
2. `actualDateCorrectionLoop`;
3. `scheduledCompletionLoop`;
4. `scheduledCancellationLoop`;
5. `scheduledReplacementLoop`.

Correction is the best next comparison, but this is not yet a split verdict.
Its current shape most closely matches the qualified Record seam:

- `Correction` already owns presentation state, validation, transition, and view;
- the local loop owns terminal reads, dirty redraws, and delegation to
  `HouseholdCommand.correctActual`;
- publication refusal re-enters the same editor through `withPublishError`;
- the loop returns only a human-facing notice;
- the caller remains responsible for canonical reload and destination-surface
  orchestration.

The alternatives are less useful as the immediate control:

- `ActualDateCorrection` is also narrow, but tests a smaller special-purpose editor;
- `ScheduledCompletion` returns `Bool` into a caller that may immediately open
  continuation creation and routing inheritance, so its session boundary is more
  coupled to surrounding workflow;
- Scheduled cancellation and replacement remain legitimate candidates, but doing
  all remaining loops together would turn one successful experiment into a
  naming-symmetry refactor.

Next experiment rule:

```text
extract Correction only
-> keep Correction state/validation/view in Correction
-> keep canonical reload + workspace destination in Tui.Cli
-> keep HouseholdCommand.correctActual authoritative
-> run Production TUI + Compression + module inventory
-> graduate only if the boundary remains coherent
```

Do not create the other `*Session` modules merely for symmetry.
