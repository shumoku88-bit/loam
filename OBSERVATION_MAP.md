# LOAM Observation Map

This document is a compressed checkpoint after Observations 001–084, the operational private real-data quantity shadow, and the current private Plan-realization summary dogfood.

It is not a final ontology, schema, or roadmap. Detailed evidence remains in the individual observation and experiment records. This map records the current terrain: what the observations have earned, what remains derived or overlay-like, what the Practical Lean Core carries, what real-data dogfood has actually exercised, and what LOAM has deliberately not promoted into domain meaning.

Two focused audits close important sub-arcs:

- [`experiments/066_071_practical_core_audit.md`](experiments/066_071_practical_core_audit.md) closes the external-accounting-pressure audit;
- [`experiments/079_084_context_relative_sufficiency_audit.md`](experiments/079_084_context_relative_sufficiency_audit.md) records the return of vocabulary-relative sufficiency in formal-result and privacy-safe observation work.

## 1. Arc so far

### 001–017 — before household nouns

LOAM begins without assuming Account, Transaction, Budget, Envelope, Month, or Report.

The early observations ask which structures survive when finite resources are distributed through time and purpose. Availability and envelope-like holdings can appear as projections; commitment and retained historical questions require more information than a current aggregate alone.

Observations 004–005 already expose a recurring law: the state worth retaining is shaped by the distinctions a future operation vocabulary can observe, not by a context-free notion of smallest summary.

### 018–029 — memory, provenance, correction, resolution, and vocabulary-relative sufficiency

Occurrence is separated from later interpretation:

```text
what happened
    !=
how the current view interprets it
```

Stable identity, append-only parentage, provenance, Correction, Resolution, conflict, and vocabulary-relative compression appear here. Later relations can change an effective view without erasing earlier facts.

Observation 029 proves general vocabulary-inclusion laws in Lean. In particular, a summary sufficient for a richer vocabulary remains sufficient for a sub-vocabulary, while a newly admitted question may require more retained information only when it exposes a distinction the current summary collapses.

### 030–039 — generic Events, coordinates, and time

The neutral physical shape settles around:

```text
Event
  -> Effect
       -> Locus
       -> Measure
       -> exact Quantity
```

Time also becomes question-dependent. In retrospective questions:

```text
valid time
    !=
learned time
```

### 040–051 — revision structure and overlays

Revision frontiers, explanation, selection, backing eligibility, AccountingRole, asynchronous settlement, and reconciliation pressure show that useful application classifications need not be physical properties of quantity placement.

A recurring boundary is:

```text
where quantity is
    !=
what an application says that quantity means
```

### 052–061 — practical identity and bounded publication protocol

Observation 052 earns stable Effect identity before coordinate collapse:

```text
Effect identity
    !=
Locus × Measure coordinate
```

The following observations separate storage order from history, logical facts from physical topology, raw relation memory from referential admission, and bounded writer/reader ordering for Correction and Resolution publication.

These protocol results do not claim a general transaction protocol, moving-frontier concurrency solution, concurrent-writer locking, autonomous recovery, fsync semantics, or power-loss durability.

### 062–065 — anonymized household pressure

Representative bookkeeping shape still fits the neutral core without restoring a conventional Account object or nominal EventKind hierarchy.

The pressure instead exposes explicit relations that endpoint content cannot reconstruct:

```text
Plan + Actual records
    -/-> realization correspondence

Plan content + recurrence kind
    -/-> Series membership

Event records + net quantity
    -/-> refund provenance
```

Refund / reimbursement also remains distinct from Correction-style supersession because the original expense remains an occurrence.

### 066–071 — external accounting pressure and checkpoint audit

This sub-arc uses mature accounting questions only as pressure. It separates:

- historical valuation from acquisition basis and current valuation;
- aggregate holding from quantity-bearing disposal provenance;
- source identity sets from quantities consumed from each source;
- valid allocation from policy-selected attribution and explicitly retained attribution;
- current policy from retained historical attribution;
- retained attribution from policy provenance;
- stable policy identity from historical policy definition.

The closing audit records:

```text
Practical Core additions: 0
Persistence additions:     0
CLI additions:             0
wire-format additions:     0
```

The sub-arc therefore constrains future semantics without importing `CostBasis`, `Lot`, disposal-policy, policy-version, or similar product ontology into the Practical Core.

### 072–073 — descriptive context pressure

Practical dogfood exposes a distinction between the physical quantity fact and what made an Event recognizable to a person:

```text
quantity placement
    !=
human descriptive context
```

Observation 072 refuses to overload `Locus` or `EventId` with description and does not earn Merchant, Place, Purpose, Category, Counterparty, Description, or Note primitives.

Observation 073 then shows that Event-level and Effect-level descriptive attachment are independently observable. A uniform-context law can compress some worlds, but split-context Events prevent one attachment scope from being declared universal.

No generic Practical Core `Context` is earned.

### 074–075 — private shadow pressure and imported identity

A read-only adapter is introduced to inspect only anonymous structural coverage from a private canonical journal. It does not publish Events, retain converted files, or copy private values into public artifacts.

The private source pressure shows that quantity shape alone does not provide stable LOAM occurrence identity. In particular:

```text
source quantity shape
    does not earn
stable Event / Effect identity
```

Observation 075 closes the tempting shortcuts:

```text
mutable content
    -/-> stable occurrence identity

presentation position
    -/-> stable occurrence identity
```

Imported continuity must be retained continuity information, not identity recomputed from a later mutable snapshot.

### 076–077 — no permanent sidecar by default

Observation 076 asks what happens when an external identity aid is retired.

The project direction becomes:

```text
prefer no sidecar
```

If an external aid is ever introduced, it must have an exit condition from the beginning. Deleting an aid without transferring or otherwise resolving continuity does not make the identity problem disappear.

Possible exits include source-owned stable identity, an explicit authority transfer, or fail-closed re-observation with explicit reconciliation when ambiguity appears.

Observation 077 keeps reconciliation deliberately one-shot:

```text
0 candidates   -> reject
1 candidate    -> this operation may proceed
2+ candidates  -> no automatic choice
                  -> explicit reconciliation
```

A reconciliation decision for one operation is not automatically a durable cross-run mapping.

### 078 — stateless run-local identity

The private source still lacks enough stable occurrence identity for lossless continuity-sensitive import across the whole source. Observation 078 therefore asks a narrower question:

> May a read-only query use fresh run-local identities when its retained answer is proved invariant under identity renaming?

Lean proves the positive boundary for `Event.quantityAt` and representative `EventMemory.quantityAtRecorded` projections, and simultaneously proves the negative boundary by showing that `EventMemory.findById?` observes identity.

The earned rule is:

```text
identity-renaming-invariant query
+ fresh run-local unique identity
+ no persistence
+ no cross-run relation
=> stateless shadow observation may proceed
```

Run-local identity is only a temporary representation witness. It is not imported identity.

It must not carry:

- correction attachment;
- reconciliation continuity;
- relation targets across runs;
- persistent source mapping;
- a claim that a later source occurrence is the same historical occurrence.

### 079–084 — formal-result context and context-relative sufficiency

This sub-arc moves the old vocabulary-relative sufficiency question to a new surface: formal-tool results, later implementation reuse, and privacy-safe observation.

Observation 079 shows that a bare checker token is not self-interpreting:

```text
workflow SUCCESS
    !=
raw result
    !=
semantic interpretation
```

Observation 080 adds the checking regime itself. A bounded Alloy result, its finite scope, and a Lean theorem under explicit premises cannot be collapsed into one context-free `SUCCESS` fact:

```text
bounded no-counterexample
    !=
unbounded theorem
```

Observation 081 then moves from interpretation to reuse:

```text
retained formal result alone
    -/->
later applicability
```

Applicability depends on the later question being asked. The existing correction boundary gives concrete pressure: the same retained body of knowledge can justify recorded quantity, a single-correction projection, or a fail-closed result depending on the later correction shape.

Observation 082 returns to the private Plan-realization observer. Its sanitized joint aggregate preserves useful structural pressure while deliberately losing identity provenance:

```text
privacy-safe structural summary
    !=
realization provenance
```

Observation 083 projects one step further. Separate marginals do not preserve their joint correlation:

```text
summary(A × B)
    -> summary(A) + summary(B)

summary(A) + summary(B)
    -/-> summary(A × B)
```

Observation 084 asks whether one extra joint anchor repairs that loss. The answer is shape-dependent:

```text
2 × 2:
  marginals + one joint anchor
      -> whole joint table

3 × 3:
  marginals + one joint anchor
      -/-> whole joint table
```

Lean proves the positive 2 × 2 integer law; Alloy and J expose the 3 × 3 negative boundary.

The important checkpoint is that this is not a separate universal Summary theory. It is the earlier 004/005/029 law returning at another layer:

```text
004 / 005 / 029:
future vocabulary
    -> observable distinctions
    -> sufficient retained state

079–084:
later question
    -> distinctions that must survive
    -> sufficient retained evidence
```

No generic `Summary`, `CheckReceipt`, `Applicability`, `Correlation`, `Anchor`, or proof/evidence kernel is earned.

## 2. Current Practical Core

The practical Lean boundary remains deliberately concrete. It carries the neutral exact structures needed by real operations and proved queries, including:

- Quantity;
- Measure;
- Effect and stable `EffectKey`;
- Event and EventMemory;
- EventCorrection and EventCorrectionMemory;
- EventResolution and EventResolutionMemory;
- RelationAdmission;
- correction-aware quantity projection;
- Rate;
- Allocation;
- RecipientAssignment.

Correction and Resolution remain separate semantic kinds rather than being collapsed into a premature universal relation abstraction.

The implementation rule remains:

```text
observation
  -> identify one observable distinction or law
  -> add only the minimum representation required by a real operation or retained query
```

Experimental vocabulary does not automatically become production vocabulary.

Observations 079–084 add no Practical Core type. Their diagnostic tools operate outside canonical household state.

## 3. Derived views and overlays

Coordinate totals are projections over Effects, not Effect identity.

Other useful views that have appeared without automatically earning canonical stored identity include:

- live holdings and availability in bounded models;
- total quantity by Locus / Measure;
- transfer-like shape;
- role-aware accounting readings over physical facts plus AccountingRole;
- current correction-aware effective quantity;
- referentially admitted relation views;
- Plan completion / Series / refund readings when explicit relations are supplied;
- historical/current valuation answers when the relevant observations are retained;
- disposal and attribution views when their provenance relations are retained;
- report-like readings over physical facts plus overlays;
- sanitized Plan-realization structural summaries;
- query-local sufficiency readings over sanitized joint aggregates.

Important overlays remain independent from the neutral physical core unless stronger practical pressure earns otherwise. These include AccountingRole, descriptive context, Plan realization, Series membership, refund provenance, valuation/basis relations, backing eligibility, policy attribution/provenance, and other application classifications.

An overlay is not less real. It means its meaning is not determined by the physical placement and quantity relations currently retained.

A summary is also not automatically canonical state. It may be deliberately sufficient for one later question while collapsing distinctions needed by another.

## 4. Persistence boundary

Current practical persistence retains exact Event / Effect facts and the independent relation streams already earned by practical operations.

The architectural distinction remains:

```text
logical canonical facts
    !=
physical storage topology
    !=
derived projections
```

Observations 062–084 do not earn a Plan store, Series store, refund stream, disposal-provenance stream, policy-version stream, imported-identity sidecar, generic metadata stream, formal-result database, or generic summary/evidence store.

A new persistent structure should appear only when a practical operation must publish, reload, coordinate, correct, or query information that cannot otherwise be retained correctly.

The 079–084 result sharpens that rule: persistence should be justified by a later distinction that observes the retained information, not by the mere availability of a compact schema.

## 5. Operational real-data shadow checkpoint

### Quantity shadow

`shadow-quantity` is the first operational entrance that runs a private canonical journal through the existing Practical Core without claiming imported continuity:

```text
private journal snapshot
    -> parse quantity-bearing Events / Effects
    -> assign fresh run-local EventId / EffectKey
    -> EventMemory.quantityAtRecorded
    -> print current-run quantity projection
    -> discard every generated identity
```

Properties of this entrance:

- source is read-only;
- LOAM persistence is not created;
- no sidecar is created;
- unsupported source lines fail closed;
- unsupported raw private source text is not echoed by the failure path;
- header context, metadata, and include directives are counted as explicitly unprojected rather than silently given Core meaning.

A whole-file private run succeeded. For the same canonical snapshot, every non-zero Locus × Measure quantity aggregate produced by LOAM matched the corresponding native h-kernel accounting projection.

That result establishes a real-data quantity-projection checkpoint. It does **not** establish parity for descriptive context, metadata meaning, Plan semantics, correction/relation continuity, imported stable identity, temporal report semantics, or every future source construct.

The observed zero-only coordinate difference is currently a presentation/view distinction rather than evidence of a quantity mismatch: LOAM can retain a represented coordinate whose aggregate is exactly zero while the native report may omit zero rows.

### Explicit Plan-realization shadow

A second private observer follows explicit Plan references without promoting Plan into Practical Core.

Its privacy-safe output asks structural questions such as:

- whether explicit references resolve;
- whether the current snapshot pressures one-to-many realization;
- how linked pairs distribute over a joint time × physical-delta shape;
- whether quantity-different pairs have query-local unique or ambiguous Effect correspondence by existing coordinates.

The observer keeps source mutation checks and withholds private identities/content. Its joint aggregate is deliberately diagnostic rather than canonical semantic state.

Observation 082 proves why that distinction matters: the sanitized joint aggregate does not reconstruct the underlying realization provenance.

### Summary-sufficiency dogfood

After Observation 084, `private-plan-realization-summary-sufficiency.py` adds one more read-only diagnostic layer:

```text
private canonical source
    -> private-plan-realization-shadow
    -> sanitized joint aggregate
    -> summary-sufficiency checker
    -> structural sufficiency result
```

The outer checker consumes only the already-sanitized matrix and privacy/read-only confirmations. It does not reinterpret raw private canonical records.

For the current private snapshot:

- the separate marginals do not uniquely determine the observed joint aggregate;
- no single observed joint-cell anchor is sufficient to make that aggregate unique.

This is snapshot-specific reality pressure, not a universal minimum-evidence theorem.

The public synthetic qualification includes both a fully active 3 × 3 ambiguous case and an effective 2 × 2 case where a single anchor is sufficient. The executable dogfood therefore preserves the shape distinction found in Observation 084 rather than hard-coding one answer.

No private canonical values are part of these public checkpoints.

## 6. Deliberately unearned concepts

LOAM should not silently promote these into domain law without concrete pressure that requires them:

- one global FactId shared by all semantic kinds;
- one globally ordered canonical history;
- chronology, identity, priority, or authority from file/list position;
- imported identity derived from mutable content or presentation position;
- a permanent source-to-LOAM identity sidecar by default;
- a conventional Account object as the physical primitive;
- a stored nominal EventKind hierarchy for accounting roles;
- a generic Context / Merchant / Place / Purpose / Category primitive merely because descriptive information exists;
- a generic Metadata primitive merely because private source metadata is observable;
- eager referential rejection as a raw relation-memory rule;
- autonomous recovery metadata;
- concurrent-writer locking semantics;
- fsync or power-loss durability guarantees;
- a general moving-frontier Resolution persistence protocol;
- Practical Core Plan, Series, Refund, CostBasis, Lot, or disposal-policy objects merely because bounded experiments can observe those distinctions;
- policy identity/version/governance semantics without a retained practical question that observes them;
- a complete executable historical policy snapshot by default;
- tax-specific basis rules;
- compaction semantics;
- a generic `CheckReceipt`, `ReuseReceipt`, `Applicability`, `ProofDatabase`, or cross-tool `Evidence` object;
- a universal `Summary`, `Anchor`, or `Correlation` primitive;
- a universal observer algebra or fixed minimal-summary formula;
- a general privacy framework merely because sanitized observations are useful;
- a semantic-OS proof/evidence kernel inferred from the 079–084 sub-arc.

These are not rejected forever. They are simply not earned yet.

## 7. Tool roles

### Alloy

Use Alloy when the question is primarily structural: whether two worlds can share retained facts but differ in an answer, whether one relation is independent of another, whether a field is necessary, or whether a familiar noun can remain a projection.

Observations 079, 081–084 use this role directly by asking whether projected-away coordinates permit two worlds to collide while differing in a later answer.

### J

Use J when array shape, quotienting, projection, or information loss is the clearest form of the question. J is not a mandatory second implementation of every structural experiment.

Observation 083 makes correlation loss visible as independent marginal reductions; Observation 084 exposes reconstruction in 2 × 2 and residual ambiguity in 3 × 3.

### Lean 4

Use Lean when a discovered law deserves a general proof or when the Practical Core must embody an earned distinction.

Observation 029 proves the general vocabulary-inclusion laws behind context-relative sufficiency. Observation 078 proves the safe stateless-shadow boundary. Observation 084 uses Lean only for the positive 2 × 2 arithmetic law, rather than treating a bounded search result as an unbounded theorem.

### TLA+ / TLC

Use TLA+ when the answer depends on state transition, operation order, temporal knowledge, or reachable history.

### Apalache

Use selectively with TLA+ when symbolic checking or inductive-invariant obligations add a distinct answer.

### SPIN / Promela

Use when explicit process interleavings and protocol order are the actual pressure point.

### miniKanren

Use when genuinely relational or backwards search adds a distinct answer that the current tools do not express as directly.

The rule remains:

> Using every tool is not a goal. A tool must earn its place in the question.

Observation 080 adds one more caution: tool receipts must keep their checking contracts distinct. Agreement in CI status is not evidence that two tools established claims with the same epistemic strength.

## 8. Current checkpoint and next pressure

The repository is now at another natural stopping point:

```text
formal structural observations
    -> small Practical Core
    -> practical CLI dogfood
    -> private whole-file stateless quantity shadow
    -> native non-zero quantity parity
    -> private explicit-relation structural shadow
    -> privacy-safe joint summary
    -> query-relative summary sufficiency dogfood
```

No new Core or persistence primitive is required by this checkpoint.

The 079–084 sub-arc also closes a loop with early LOAM:

```text
004 / 005 / 029
  future vocabulary shapes sufficient retained state

079–084
  later question shapes sufficient retained evidence
```

The next useful pressure is therefore **not automatically Observation 085** and not a generic summary framework.

A new Observation should begin when an actual later operation, human/AI reuse decision, or private shadow query exposes a distinction that current retained evidence collapses. At that point LOAM can ask exactly which information must survive for that concrete question.

Until such pressure appears, the current context-relative sufficiency checkpoint is enough.