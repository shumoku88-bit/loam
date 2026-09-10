# Canonical basis re-minimization

Status: **working audit; no production or loam-data migration authorized**

Baseline production main: `9d11b5413bc353d1e596aa7e839ee281cd28e613`
Tracking: #693 / draft PR #694

## Question

Find the smallest independently retained household information from which every
currently admitted operation can produce the same observable result. Only then
choose the smallest physical authority topology that preserves those results and
required publication / crash / recovery laws.

Keep three layers separate:

```text
retained meaning
    -> authority state
    -> physical topology
```

File count, type count, and module count are not semantic evidence.

## Observable vocabulary Q

`Q` includes current reads and writes/administration. Preserve topology-neutral
observable differences:

```text
value
known / unknown
available / unavailable
admitted / refused
publication success / refusal
```

Do not freeze current filesystem events into Q. `Reversal authority unavailable`
may matter; `actual-reversals.loam does not exist` is only one representation of
such a state.

For each retained family classify it as:

```text
WITNESS       erasure identifies worlds that Q distinguishes
DERIVABLE     every Q-visible contribution follows from the remaining basis
IRRELEVANT    Q cannot observe the distinction
UNRESOLVED    evidence is insufficient
```

Current files, codecs, workflows, and real-data emptiness are not witnesses.

## Working retained basis

Roughly eighteen meanings remain under audit:

```text
Event + signed Effects
Actual validity / occurrence coordinate
Event description
RelationUnit
RelationDischarge
Locus admission policy
Event correction
Actual reversal
Actual routing
Zero-origin coverage
Capacity movement
Capacity effective coordinate
AccountingRole classification
Scheduled occurrence
Scheduled completion
Scheduled retirement
Scheduled replacement
Scheduled routing
```

Presentation/config metadata is not historical household fact merely because it
selects today's UI. Consumption, Remaining, Commitment, Headroom, current-open
views, and report sections remain derived vocabulary.

## Semantic results already earned

### ZeroOriginCoverage: KEEP MEANING

No new Observation is needed. Current production already owns the executable
law in `ZeroOriginQuantity`:

```text
covered coordinate   -> delegate to correction-aware quantity inspection
uncovered coordinate -> coverageMissing
```

`ZeroOriginCoverage.empty` refuses every current zero-origin question regardless
of Event activity. Therefore Event activity cannot reconstruct the distinction.
This protects the meaning, not a dedicated `zero-origin-coverage.loam` file.

### CapacityEffective: KEEP MEANING

No new Observation is needed. Observation 112 already established that Capacity
effective time can be independently observable while explicitly refusing to
choose its representation. Observation 158 later uses effective coordinates for
windowed household questions.

This protects effective-coordinate information, not a `.effective` sidecar.

### Reversal authority availability: KEEP DISTINCTION

Observation 241 is the only new live Lean observation retained by this PR.
Current Correction pressure distinguishes:

```text
explicit known-empty Reversal authority -> admission may proceed
Reversal authority unavailable          -> refuse
```

The same decoded state can be represented by a separate file or bundled section
without changing that selected result. Therefore known-empty vs unavailable is
earned; the dedicated file is not earned by that distinction alone.

## Early LOAM had already solved the topology question

### Observation 054

For its modeled queries, one unordered tagged fact set and several typed fact
sets preserve the same meaning when typed membership and explicit identities are
kept. Co-location does not itself merge semantics.

The danger is adding an unearned global serialization order and then treating it
as chronology, priority, or authority.

```text
one file != one semantic family
one file != one ordered log
co-location != semantic conflation
```

### Observation 055

Observation 055 compares atomic bundles, uncoordinated typed streams,
dependency-ordered streams, and fail-closed admission over torn raw storage.

It shows:

- atomic bundle is sufficient for referential closure but not necessary;
- uncoordinated publication can tear;
- dependency ordering can preserve closure while storage remains split;
- fail-closed admission can preserve semantic closure over torn raw state.

Therefore logical canonical topology and publication topology need not coincide.
A duplicate Observation 244 created during this audit was immediately removed
when 055 was rediscovered.

## Evidence that current physical topology leaked upward

### Correction -> Reversal

`CorrectionPublisher` derives another semantic dependency from placement:

```lean
let reversalFile := correctionFile.withFileName "actual-reversals.loam"
```

The Reversal dependency is semantic. The sibling filename is not.

### Capacity companion

Capacity effective storage is derived by appending `.effective` to the Capacity
path. That convention is visible across persistence, publisher, CLI, review,
TUI, and tests.

Yet Capacity publication already:

```text
owns one writer boundary
loads both images
checks completeness both ways
allocates one identity across both
writes Effective evidence first
writes activating Capacity movement second
```

So the safety law is closer to:

```text
one ownership domain + evidence before activation
```

than `two meanings -> two files`.

### Correction path fanout

Balance, Actual, Stock-Flow, Transactions-Flow, Budget Window, Current Coverage,
Operational Continuity, and TUI wiring construct `corrections.loam` directly.
Changing its physical representation therefore fans out above Persistence.

This is direct evidence that persistence topology has become application wiring.

## Missing storage is not a semantic bottom

Current code uses all of:

```text
missing -> empty
missing -> unavailable
missing -> refusal/error
```

Correction is especially revealing. Production quantity and integrity surfaces
map missing Correction storage to empty EventCorrection memory; the integrity CLI
prints the same `No corrections recorded.` result for missing and explicit-empty
storage.

So for those admitted operations:

```text
missing Correction storage ~Q explicit empty Correction memory
```

Physical absence itself is not earned household meaning.

Reversal differs: Correction/Reversal mutation currently requires explicit
Reversal availability. Scheduled lifecycle and Attention also preserve
unavailability rather than manufacturing empty evidence. Plain Capacity review,
meanwhile, treats missing Capacity history as empty while richer Current Coverage
requires the relevant evidence explicitly.

Therefore `file missing` must not be promoted into one cross-family ontology.

## Current authority graph

The semantic basis already maps non-uniformly to selected authority handles:

```text
1 Movement generation
  Event
  ActualValidity
  EventDescription
  RelationUnit
  RelationDischarge
  LocusAdmission

2 Scheduled lifecycle
  ScheduledOccurrence
  ScheduledCompletion
  ScheduledRetirement
  ScheduledReplacement

3 Capacity authority candidate
  CapacityMovement
  CapacityEffective

4 Actual revision authority candidate
  EventCorrection
  ActualReversal

5 ActualRouting
6 ScheduledRouting
7 AccountingRole
8 ZeroOriginCoverage
```

Eight is not a target and does not mean eight files.

Movement has one selected `CURRENT` authority but several immutable backing
objects and recovery generations. Scheduled already stores four semantic families
in one typed image. Thus:

```text
semantic-family count != authority-handle count != physical-file count
```

## Movement manifest rationale to re-check

The Movement manifest is a successful example of hiding many backing objects
behind one selected authority. Its current rationale nevertheless says a
monolithic file would necessarily conflate semantic authorities.

Observation 054 does not justify that statement as written. A typed atomic image
can preserve distinct meanings if it retains family tags/identities and does not
invent global semantic order.

The real reasons for Movement's object topology are operational candidates:

```text
content-addressed reuse / deduplication
write amplification
recovery generations
corruption localization
human recovery / inspection
```

Those may fully justify keeping it. This audit only removes semantic conflation as
an automatic argument for physical separation.

## First topology candidates

### Capacity

Compare while holding meaning fixed:

```text
A current companion files
B one typed atomic Capacity image
C one opaque Capacity authority handle backed by two files
```

B may remove the intermediate incomplete crash state but increase rewrite and
corruption blast radius. C preserves current backing behavior while removing
companion-path knowledge from callers.

### Actual revision

Correction and Reversal remain distinct meanings:

```text
Correction -> replace current interpretation frontier
Reversal   -> retain a real inverse occurrence
```

But their physical/update relationship is tight:

- Correction mutation reads Reversal evidence;
- Reversal mutation reads Correction evidence;
- both serialize through Movement `CURRENT` ownership;
- production Reversal persistence is consumed essentially by those mutation
  publishers;
- Correction derives the Reversal sibling filename;
- current household Reversal authority is explicit-empty;
- current household Correction storage is absent and ordinary reads interpret it
  as known-empty.

A topology-neutral Actual revision authority could expose typed
`EventCorrectionMemory` and `ActualReversalMemory` while hiding whether they live
in one file, two files, or selected objects.

The main counterpressure to bundling is corruption blast radius: malformed
Reversal bytes should not accidentally make every Correction-only read
unavailable unless that coupling is deliberately chosen.

## Next production move

Do not choose final file count yet. First make the strongest leaking topology
exchangeable behind **local** authority boundaries:

```text
application / TUI
    -> semantic authority handle
    -> hidden persistence topology
```

Best first candidates are Capacity and Actual revision. Once callers stop knowing
companion/sibling filenames, one-file and multi-file implementations can be
compared without rewiring the product.

## Merge discipline

A generic proof must pay a replacement dividend before joining the live working
set. Open PR #692 / Observation 240 is not a direct duplicate of 055 or 129, but
it currently adds a generic activation-last law. Before merge it should retire or
simplify at least one older live obligation or duplicated production rationale.
That gate is recorded on #692.

## Stop rule

Optimize:

```text
independent retained distinctions
+ independent publication/failure laws
+ unavoidable operational boundaries
```

Do not optimize raw file count directly.

Current conclusion:

> LOAM's retained meanings do not determine its file topology, and current
> filename/companion conventions have leaked upward far enough to shape
> application architecture.

Push those conventions back below local authority boundaries first. Then let
measured crash behavior, recovery, corruption radius, write amplification, and
inspectability determine the physical file count.
