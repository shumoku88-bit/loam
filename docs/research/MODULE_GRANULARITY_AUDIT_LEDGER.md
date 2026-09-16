# Module Granularity Audit Ledger

Checkpoint base: `448fffdbe0b161151f8f21811bc1cde177d2b1f4`

Status: **MGA-015 IN QUALIFICATION — ScheduledCompletionSession narrow effect-shell experiment; PR #974**

## Refreshed inventory

The module-granularity inventory was rerun on the PR #971 merge candidate after extracting
`Loam.Tui.ScheduledReplacementSession`.

```text
Lean modules: 333
Modules <= 80 lines: 90
Modules with exactly one local consumer: 53
Declared Lake roots: 17
Production-like modules unreachable from declared roots: 0
```

The raw module, small-module, and one-consumer counts each increased by one, as expected for
one justified Session extraction. No production-like surface became unreachable. Current
focused metrics are:

```text
Loam.Tui.Cli                         1143 lines / 31 declarations / fan-out 56
Loam.Tui.RecordSession                 48 lines /  1 declaration  / fan-in 1 / fan-out 5
Loam.Tui.CorrectionSession             49 lines /  1 declaration  / fan-in 1 / fan-out 5
Loam.Tui.ScheduledReplacementSession   51 lines /  1 declaration  / fan-in 1 / fan-out 5
Loam.Tui.ScheduledReplacement         264 lines / 23 declarations / fan-in 3 / fan-out 6
```

The post-#968 pre-extraction `Tui.Cli` shape is recoverable from the qualified diff as
1166 lines / 32 declarations / fan-out 55. MGA-014 therefore removes one object-local effect
loop and one declaration from the composition root while adding one explicit dependency edge
to the new Session. That fan-out increase is not treated as a regression: file count, small-module
count, one-consumer count, and composition-root fan-out are candidate detectors, not verdicts.
Responsibility ownership decides the boundary.

The qualified dependency seams are now explicit:

```text
Tui.Cli -> RecordSession                -> Record + HouseholdCommand
Tui.Cli -> CorrectionSession            -> Correction + HouseholdCommand
Tui.Cli -> ScheduledReplacementSession  -> ScheduledReplacement + HouseholdCommand
```

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
too many tiny Lean modules. MGA-014 strengthens the calibrated distinction:

```text
small + shared/independent responsibility        -> KEEP_BOUNDARY
one consumer + independent ownership/effect seam -> KEEP_BOUNDARY can be valid
unreachable + retired historical responsibility -> RETIRE_CANDIDATE
large root + object-local effect loops           -> SPLIT_CANDIDATE, one slice at a time
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

Classification: **MIXED VERDICT — NO BATCH EXTRACTION**

Three local Scheduled editor/effect loops remained in `Tui.Cli` at the MGA-013
checkpoint, but DRAKON and history did not support treating them as one naming
family.

### ScheduledCompletion

Classification: **SPLIT_CANDIDATE — focused experiment justified**

The completion shell is stronger than the rejected ActualDateCorrection split:

- the same local loop is entered from both HRA Scheduled and SelectedDay;
- it carries reusable `world` and `known` catalog context;
- publication refusal returns to the same editor and redraws, matching the
  already-qualified Record/Correction session shape;
- the loop returns only a Boolean completion result, while continuation creation
  and routing inheritance deliberately remain in the caller;
- `ScheduledCompletion.lean` has changed independently after its introduction,
  including shared Record-shaped field rendering (#642) and catalog candidate
  projection cleanup (#646).

A physical session boundary is therefore plausible, but completion has an extra
continuation contract. It was deliberately deferred while Replacement supplied the
simpler positive experiment.

### ScheduledCancellation

Classification: **KEEP_INLINE / SPLIT_REJECTED**

Cancellation is the negative control inside the Scheduled family:

- it is a compact confirmation-only interaction with no editable household
  payload and no world/catalog context;
- publisher refusal exits immediately as a human-facing notice instead of
  returning to an editor retry loop;
- its presentation module has only the original #524 history so far, with no
  observed independent change pressure;
- although both HRA Scheduled and SelectedDay reuse the local loop, moving this
  tiny shell to another file removes little navigation burden from either caller.

Two callers are therefore useful candidate evidence, not an automatic split
reason. Cancellation stays inline.

### ScheduledReplacement

Classification at MGA-013: **SPLIT_CANDIDATE — SELECTED FOR MGA-014 IMPLEMENTATION EXPERIMENT**

Replacement was selected because:

- the same terminal shell is entered from both HRA Scheduled and SelectedDay;
- `ScheduledReplacement` owns a substantial presentation-only editor with date,
  posting rows, validation, preview, and publication-intent construction;
- the local shell owns key reads, dirty redraws, delegation to
  `HouseholdCommand.replaceScheduled`, and retry after publication refusal;
- the caller still owns selected-record lookup, initial editor construction,
  canonical reload, and destination refresh;
- the editor has independent history after introduction, including validity
  dependency narrowing (#710) and canonical `BalancedMovement` draft migration
  (#767).

MGA-014 below records the implementation result.

### MGA-013 stop rule

The Scheduled family produced three different outcomes from superficially similar
local loops:

```text
Completion    -> SPLIT_CANDIDATE, deferred because continuation semantics remain caller-owned
Cancellation  -> KEEP_INLINE / SPLIT_REJECTED
Replacement   -> SPLIT_CANDIDATE, qualified by MGA-014
```

Physical modules follow ownership, reuse, continuation topology, navigation cost,
and observed change reasons. They do not follow suffix symmetry.

## MGA-014 — `Loam.Tui.ScheduledReplacementSession` post-#968 focused extraction

Classification: **KEEP_BOUNDARY / SPLIT_QUALIFIED — PR #971 ready for merge**

MGA-014 did not assume the MGA-013 candidate verdict survived G2-030. The topology
was re-observed after PR #968 retired the legacy Main Actual/Scheduled workspace
state machine. `Main.State` is now only Home date focus plus notice, but the
replacement effect shell remained an object-local responsibility shared by the two
production Scheduled workspaces.

The post-#968 evidence supports a physical boundary:

- `ScheduledReplacement` owns date/posting editor state, validation, preview,
  transitions, publication-intent construction, and view;
- `ScheduledReplacementSession` owns key reads, dirty redraws, delegation to
  `HouseholdCommand.replaceScheduled`, and retry after publication refusal;
- both `HraScheduled` and `SelectedDay` enter that same Session;
- both callers continue to own selected-record lookup, `initial?`, vocabulary
  loading, canonical snapshot reload, `refreshed`, and destination redraw;
- publication authority remains outside TUI in the shared publisher reached via
  `HouseholdCommand.replaceScheduled`.

Change history gives bidirectional independence rather than naming symmetry:

- PR #710 and PR #767 changed `ScheduledReplacement.lean` without changing
  `Tui.Cli`;
- PR #968 changed `Tui.Cli` / `Main` topology without changing
  `ScheduledReplacement.lean`.

PR #971 performs only the narrow effect-shell extraction:

```text
Tui.Cli
  -> ScheduledReplacementSession
       -> ScheduledReplacement
       -> HouseholdCommand.replaceScheduled
```

The implementation adds one 51-line Session module and removes the 27-line local
loop from `Tui.Cli`. The qualified inventory reports:

```text
ScheduledReplacementSession  51 lines / 1 declaration / fan-in 1 / fan-out 5 / reachable
ScheduledReplacement        264 lines / 23 declarations / fan-in 3 / fan-out 6 / reachable
Tui.Cli                     1143 lines / 31 declarations / fan-out 56 / reachable
production-like unreachable = 0
```

The post-#968 pre-extraction `Tui.Cli` was 1166 lines / 32 declarations / fan-out
55, derived from the qualified diff and refreshed inventory. The split therefore
reduces responsibility density even though the raw fan-out rises by one through
the explicit Session edge.

The PR head passed every focused qualification gate:

- Production TUI, including all 62 functional verification steps;
- Compression Audit;
- Module granularity inventory;
- Selected Lean Observations;
- Purpose Catalog Boundary.

No household authority, semantic engine, canonical state owner, selection policy,
reload policy, or workspace transition moved into the Session. The boundary is
therefore qualified on ownership, proof locality, navigation cost, reuse, history,
and reachability evidence. The next Scheduled candidate remains Completion, but it
must be re-observed as a continuation seam rather than copied from Replacement.


## MGA-015 — `Loam.Tui.ScheduledCompletionSession` focused extraction

Classification checkpoint: **SPLIT_CANDIDATE — IMPLEMENTATION UNDER QUALIFICATION (PR #974)**

MGA-015 re-observed completion after MGA-014 and the paired DRAKON continuation map.
The experiment deliberately extracts only the reusable inner terminal/effect shell:

- `ScheduledCompletion` retains editor state, representability checks, Record-shaped
  editing/preview transitions, completion-draft construction, refusal restoration,
  and view;
- `ScheduledCompletionSession` owns terminal key reads, dirty redraws, delegation to
  `HouseholdCommand.completeScheduled`, retry after publication refusal, and one
  Boolean result;
- both HRA Scheduled and SelectedDay enter the same session;
- a successful session returns `true`, while cancellation returns `false`;
- optional next-Scheduled creation, `ScheduledCreationSession.runWithScheduledId`,
  routing inheritance, canonical reload, and destination-workspace refresh remain
  caller-owned continuation semantics.

The Boolean return is therefore treated as an explicit stop line rather than an
invitation to absorb the continuation into the Session. The experiment is qualified
only if production CI remains green, the module remains reachable with a narrow
dependency surface, and the refreshed inventory shows no production-like unreachable
module. Final classification and inventory numbers are intentionally deferred until
those checks complete.
