# Canonical basis re-minimization

Status: **working audit; no production or loam-data migration authorized**

Baseline production main: `9d11b5413bc353d1e596aa7e839ee281cd28e613`

Tracking: #693 / draft PR #694

## Question

Re-run the early LOAM minimization discipline against the current product:

> What is the smallest independently retained household information from which
> every currently admitted operation can produce the same observable result?

Then, only after that semantic basis is known:

> What is the smallest physical authority topology that preserves those results
> and the independently required publication / crash / recovery laws?

The audit therefore keeps three layers separate:

```text
retained meaning
    -> authority state
    -> physical topology
```

File count, type count, and module count are not semantic evidence.

## Q: observable operation vocabulary

`Q` includes current reads **and** writes/administration.

For household worlds `h1` and `h2`:

```text
h1 ~Q h2
iff
for every admitted current operation q and input x,
observableResult(q, x, h1) = observableResult(q, x, h2)
```

Preserve topology-neutral differences such as:

```text
value
known / unknown
available / unavailable
admitted / refused
publication success / refusal
```

Do not freeze physical facts into Q merely because current code exposes them.
For example:

```text
Reversal authority unavailable
```

may be semantic, while:

```text
file actual-reversals.loam does not exist
```

is a current representation fact.

This distinction is necessary or the current filesystem layout would prove its
own necessity by definition.

## Current retained semantic families

The working census contains roughly these independently retained meanings:

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

Current configuration / presentation metadata is not promoted into historical
household fact merely because it affects today's interface.

Likewise these useful household nouns remain derived results, not retained state:

```text
Consumption
Remaining
Commitment
Headroom
current-open views
report sections
```

## Global witness rule

For each retained family seek one of:

```text
WITNESS
  erase the family, find two otherwise-equal worlds, and show Q differs

DERIVABLE
  reconstruct every Q-visible contribution from the remaining basis

QUERY-IRRELEVANT
  Q cannot observe the distinction

UNRESOLVED
  current evidence is insufficient
```

Existing files, codecs, modules, workflows, and current real-data emptiness do not
count as indispensability witnesses.

## Current closed semantic witnesses

### ZeroOriginCoverage

Observation 242 uses production types.

Keep EventMemory and EventCorrectionMemory identical and empty. Vary only whether
`cash / jpy` has zero-origin coverage:

```text
covered   -> current 0
uncovered -> coverageMissing
```

Result:

```text
ZeroOriginCoverage = KEEP MEANING
```

This does not imply a dedicated `zero-origin-coverage.loam` file.

### CapacityEffective

Observation 243 keeps one Capacity movement fixed and changes only its effective
coordinate. A selected window then yields different Entitlement answers.

Result:

```text
CapacityEffective = KEEP MEANING
```

This does not imply a `.effective` companion file.

### Reversal authority availability

Observation 241 factors one current Correction pressure into semantic authority
state and physical container topology:

```text
explicit known-empty Reversal authority -> Correction-like admission may proceed
Reversal authority unavailable          -> refuse
```

Changing only representative container shape while preserving decoded authority
state does not change that selected result.

Result:

```text
known-empty != unavailable     KEEP DISTINCTION
separate file vs bundled       NOT EARNED BY THIS DISTINCTION
```

## Important rediscovery: Observation 054 already separated semantic and physical topology

Observation 054 compared one unordered tagged fact set with several typed fact
sets.

For its modeled questions, both retain the same semantic information when typed
membership and explicit identity relations are preserved.

It also showed the actual danger of a naïve "one history" representation: a
physical global serialization order may accidentally become chronology,
priority, or authority even though the domain never earned such an order.

Therefore:

```text
one file != one semantic family
one file != one ordered log
co-location != semantic conflation
```

Semantic typing must survive; physical separation is not forced by that fact.

## Important rediscovery: Observation 055 already separated publication law and file topology

Observation 055 compared:

```text
atomic bundle
uncoordinated independent streams
dependency-ordered independent streams
fail-closed admitted view over torn raw storage
```

Its result was explicit:

- atomic bundle is sufficient for closure but not necessary;
- uncoordinated stream publication can tear;
- dependency ordering can preserve closure while streams remain separate;
- fail-closed admission can keep semantic truth closed over temporarily torn raw
  storage.

So the logical canonical basis and atomic publication boundary do not have to
share one topology.

A duplicate current Observation 244 was briefly created during this audit and
immediately removed when 055 was rediscovered. The historical result should be
reused rather than re-proved.

## Current production evidence that topology leaked upward

### Correction -> Reversal sibling discovery

`CorrectionPublisher` receives a Correction path and derives another semantic
dependency from physical placement:

```lean
let reversalFile := correctionFile.withFileName "actual-reversals.loam"
```

The semantic dependency is earned: Correction must exclude retained Reversal
participation under the current qualified rules.

The sibling filename is not the semantic rule.

### Capacity companion derivation

Capacity effective evidence is found by:

```text
capacity.loam
    -> append ".effective"
    -> capacity.loam.effective
```

This convention is visible in persistence, publisher, CLI, review, TUI, and tests.

Yet Capacity publication already uses one writer-ownership domain for both files,
checks their completeness together, allocates one identity across both, and writes
Effective evidence before the activating Capacity movement.

The deeper law is therefore:

```text
one ownership domain
+ dependent evidence before activation
```

not:

```text
two semantic facts -> two files
```

### Correction path fanout

Current production/report wiring repeatedly constructs `dataDir / corrections.loam`
in Balance, Actual, Stock-Flow, Transactions-Flow, Budget Window, Current Coverage,
Operational Continuity, and TUI paths.

Therefore changing Correction persistence currently fans out above Persistence.
Physical placement has become application wiring.

## Missing-storage semantics are inconsistent by family and sometimes by operation

Current code contains all of these policies:

```text
missing -> empty
missing -> unavailable
missing -> refusal/error
```

Examples:

- Correction readers/writers often interpret missing correction storage as an
  empty EventCorrectionMemory.
- CorrectionIntegrity prints the same `No corrections recorded.` result for a
  missing file and an explicit empty correction memory.
- Effective quantity inspection also maps missing correction storage to empty.
- Reversal authority is required explicitly by Correction/Reversal mutation;
  missing Reversal authority refuses.
- Scheduled lifecycle is required and missing storage is unavailable.
- Attention missing storage is represented as unavailable.
- plain Capacity review treats missing movement storage as empty, while richer
  Current Coverage requires Capacity and CapacityEffective evidence explicitly.

This proves that `file missing` is not one semantic bottom value in LOAM.

It also gives one concrete compression result:

```text
missing Correction storage
and
explicit empty Correction memory
```

are intentionally Q-equivalent for current Effective / CorrectionIntegrity
surfaces. Physical absence itself is not earned historical meaning there.

## Current selected authority graph

The roughly eighteen semantic families do not map one-to-one to files today.
A working authority grouping closer to current update/failure laws is:

```text
1 Movement generation authority
  Event
  ActualValidity
  EventDescription
  RelationUnit
  RelationDischarge
  LocusAdmission

2 Scheduled lifecycle authority
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

This is **not an eight-file target**.

Movement currently demonstrates why selected authority handles and backing files
must remain separate concepts: one `CURRENT` selects six typed semantic families
stored in several immutable content-addressed objects plus recovery generations.

Scheduled demonstrates the opposite physical shape: four semantic lifecycle
families already share one typed file.

Therefore:

```text
semantic-family count != authority-handle count != physical-file count
```

## Tension in current MovementManifestAuthority rationale

The Movement manifest is a useful production success:

```text
many typed backing objects
    -> one selected CURRENT authority
    -> callers do not choose family object files
```

However its current prose says a monolithic single-file snapshot would
necessarily "conflate distinct semantic authorities".

Observation 054 does not support that implication as stated.

A typed atomic image can preserve distinct semantic families provided it does not
erase family tags/identities or invent global semantic order.

The real reasons to prefer the current Movement object topology are operational:

```text
content-addressed reuse / deduplication
write amplification
recovery generations
corruption localization
human recovery / inspection
```

Those may fully justify keeping the current backing topology. The audit only
removes semantic conflation as an automatic argument for separate files.

No production comment is changed by this research PR yet.

## Strong physical compression candidate: Capacity

Current:

```text
capacity.loam
capacity.loam.effective
```

Both are loaded and validated under the same writer-owned Capacity operation.
Every new Capacity movement receives matching Effective evidence.

Compare later:

```text
A current companion files
B one typed atomic Capacity image
C one opaque Capacity authority handle backed by two files
```

B could remove the intermediate incomplete crash state but may increase write and
corruption blast radius.

C keeps current physical behavior while removing companion-path knowledge from
callers.

File count alone cannot choose between them.

## Strong physical compression candidate: Actual revision

Correction and Reversal remain semantically different operations:

```text
Correction -> replace current interpretation frontier
Reversal   -> retain a real inverse occurrence
```

Do not merge those meanings.

But their current physical relationship is unusually tight:

- Correction mutation reads Reversal evidence;
- Reversal mutation reads Correction evidence;
- both serialize through Movement `CURRENT` ownership;
- Reversal persistence is directly consumed in production essentially by the two
  mutation publishers;
- Correction derives the Reversal sibling filename;
- current household Reversal authority is explicitly empty;
- current household has no Correction file, and production treats that as known
  empty for ordinary Correction reads.

This makes a topology-neutral **Actual revision authority** a strong candidate.
It could expose typed sections:

```text
Corrections : EventCorrectionMemory
Reversals   : ActualReversalMemory
```

while hiding whether those sections live in one file, two files, or selected
objects.

The main counterpressure to one file is corruption blast radius: today damaged
Reversal storage need not necessarily destroy ordinary Correction-only reads.
That must be measured before choosing a bundled physical image.

## Next production move

Do **not** choose the final file count yet.

First make the strongest leaking topology exchangeable behind local authority
boundaries.

Best first candidates:

```text
Capacity authority
Actual revision authority
```

The immediate goal is:

```text
application / TUI
    -> semantic authority handle
    -> persistence topology hidden below
```

After that boundary exists, compare one-file vs multi-file backing forms without
rewiring every report and UI caller.

This is the clean experiment that the current code cannot perform cheaply because
physical filenames have leaked upward.

## Merge discipline for new formal abstractions

A new generic theorem should not be merged merely because it is elegant.

For example open PR #692 / Observation 240 extracts a representation-free
`required evidence before activation anchor` law. It is not a direct duplicate of
055 or 129, but under this compression audit it should pay a replacement dividend:

```text
new generic live theorem
+ no retired/simplified older obligation
= repository growth

new generic live theorem
+ retired/simplified specialized obligation(s)
= candidate compression
```

This gate has been recorded on #692 before merge.

## Stop rule

Optimize:

```text
independent retained distinctions
+ independent publication/failure laws
+ unavoidable operational boundaries
```

Do not optimize raw file count directly.

The audit has nevertheless reached the requested physical conclusion:

> Current LOAM's retained meanings do not determine its file topology, and some
> filename / companion-file conventions have leaked upward far enough to shape
> application architecture.

The next step is to push those conventions back below explicit local authority
boundaries, then let the final physical file count be chosen by measured crash,
recovery, corruption, write-amplification, and inspectability properties.
