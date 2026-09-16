# Module Granularity Audit Ledger

Checkpoint base: `098c84557d8e911e732f1ed0d73e15eaa7720286`

Status: **SECOND INVENTORY RUN COMPLETE — MGA-001 graduated; root pass calibrated**

## Refreshed inventory

After PR #959 retired the unreachable SHA-256 utility, PR #957 was rebased onto
current `main` and the inventory was rerun successfully.

```text
Lean modules: 330
Modules <= 80 lines: 87
Modules with exactly one local consumer: 50
Declared Lake roots: 17
Production-like modules unreachable from declared roots: 0
```

The disappearance of the only unreachable production-like module is the first
end-to-end calibration result for this audit. The detector found stale physical
surface, source/history inspection justified retirement, a separate PR removed it,
and the next inventory closed the reachability finding.

## MGA-001 — `Loam.Sha256`

Classification: **RETIRED — CLOSED by PR #959**

Evidence before retirement:

- `fan_in = 0`, `fan_out = 0`;
- unreachable from all declared Lake roots;
- no current source imported `Loam.Sha256`;
- its own contract tied it to the historical-admission prepare/verify boundary;
- repository history showed the former production caller had already retired.

PR #959 deleted only `Loam/Sha256.lean`. Compression Audit and Selected Lean
Observations both passed before merge. The refreshed inventory now reports zero
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

The first two passes do not support a general diagnosis that LOAM is fragmented
into too many tiny Lean modules.

The useful distinction so far is:

```text
small + shared/independent responsibility      -> KEEP_BOUNDARY
one consumer + independent change history      -> KEEP_BOUNDARY
unreachable + retired historical responsibility -> RETIRE_CANDIDATE
```

## Next pass

Audit the CLI layer next. Separate three cases explicitly:

1. declared executable roots, where `fan_in = 0` is expected;
2. command modules consumed only by `Loam.Cli`, where a dedicated command contract
   may still justify a file;
3. nested helper command modules, especially one-consumer chains such as
   `ScheduledDayEvidenceCli -> OpenScheduledCli`.

Then audit TUI `Foo` / `FooSession` pairs using pure state-machine versus effectful
terminal-session ownership as a KEEP criterion, followed by the opposite question:
large modules that may be too coarse.

Audit vocabulary:

```text
KEEP_BOUNDARY
COLLAPSE_CANDIDATE
RETIRE_CANDIDATE
MOVE_LAYER_CANDIDATE
SPLIT_CANDIDATE
NEEDS_DRAKON
NEEDS_HISTORY
```


## MGA-010 — `Loam.Tui.RecordSession` focused extraction

Classification: **SPLIT_CANDIDATE — IMPLEMENTATION EXPERIMENT**

MGA-009 found that `Loam.Tui.Cli` mixes root navigation/orchestration with
several object-local terminal editor loops. `Record` is the first narrow
experiment because neighboring TUI features already demonstrate a stable
presentation-module / terminal-session seam.

This slice moves only the Record key-read/redraw/publication loop into
`Loam.Tui.RecordSession`. `Loam.Tui.Record` continues to own editor state,
validation, transitions, and view; `HouseholdCommand.record` continues to own
the production write entrance; `Tui.Cli` continues to load/reload canonical
evidence and choose the destination surface.

The experiment earns a KEEP/SPLIT verdict only if focused Production TUI and
compression qualification pass and the resulting dependency direction remains
`Cli -> RecordSession -> Record + HouseholdCommand`, without introducing a
second semantic or authority boundary.
