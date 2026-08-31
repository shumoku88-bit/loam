# LOAM Observation Map

This document is a compressed checkpoint after Observations 001–071.

It is not a final ontology, schema, or roadmap. Detailed evidence remains in the individual observation and experiment records. This map records only the current terrain: what the observations have earned, what remains derived or overlay-like, what the Practical Lean Core currently carries, and what LOAM has deliberately not promoted into domain meaning.

The Practical Core audit for the latest sub-arc is recorded separately in [`experiments/066_071_practical_core_audit.md`](experiments/066_071_practical_core_audit.md).

## 1. Arc so far

### 001–017 — before household nouns

LOAM begins without assuming Account, Transaction, Budget, Envelope, Month, or Report.

The early observations ask which structures survive when finite resources are distributed through time and purpose.

Earned lessons include:

- availability can be derived in the bounded consumptive world;
- envelope-like live holdings can be projections rather than primary stored objects;
- commitment requires information beyond live holdings;
- the vocabulary of future questions determines which distinctions history must retain.

### 018–029 — memory, provenance, correction, and resolution

The second arc separates occurrence from later interpretation:

```text
what happened
    !=
how the current view interprets it
```

Explicit identity, append-only parentage, provenance, Correction, Resolution, conflict, and vocabulary-relative compression appear here.

Earlier facts need not be erased merely because a later relation changes which facts a current view treats as effective.

### 030–039 — generic Events, coordinates, and time

A bounded generic Event can retain the selected physical distinctions without restoring a nominal household EventKind hierarchy.

When the questions require them, two coordinates become independently observable:

```text
Locus
Measure
```

and time itself separates:

```text
valid time
    !=
learned time
```

Retrospective questions can therefore require a two-dimensional view:

```text
view(valid time, knowledge time)
```

### 040–051 — revision structure and overlays

This arc pressures explanation, conflict recurrence, revision frontiers, selection, backing eligibility, AccountingRole, asynchronous settlement, and reconciliation evidence.

A recurring result is that many useful classifications are not properties of physical quantity placement itself.

For example:

```text
where quantity is
    !=
what accounting role that locus plays
```

Selection policy, backing eligibility, and AccountingRole remain overlays unless richer retained facts later earn a derivation.

### 052–061 — from observation to practical protocol

Observation 052 earns stable Effect identity before coordinate collapse:

```text
Effect identity
    !=
Locus × Measure coordinate
```

The following observations separate storage order from history, compare unified and split fact topologies, observe publication boundaries, relation collection identity, derived referential admission, and raw relation-memory append admission.

Protocol-specific tools then earn bounded ordering results.

For Correction publication:

```text
writer: Correction -> Event
reader: Event -> Correction
```

For a Resolution over an already-visible stable conflict frontier:

```text
writer: Resolution -> Event
reader: Event -> Resolution
```

These results do not solve moving-frontier concurrency, autonomous recovery, concurrent writers, fsync durability, or a general multi-stream transaction protocol.

### 062–065 — real household pressure outside the physical core

Anonymized household-record structure tests whether familiar application nouns must return to the neutral core.

Observation 062 finds that representative bookkeeping shapes still fit:

```text
Event
+ Effect
+ Locus
+ signed Quantity
+ AccountingRole
```

without forcing a conventional Account object or nominal EventKind hierarchy into the physical core.

Observation 063 finds:

```text
Plan record + Actual Event record
    does not determine
which Event realizes which Plan
```

Observation 064 finds:

```text
Plan content
    !=
recurrence kind
    !=
Series membership
```

Observation 065 finds:

```text
Event records + net quantity
    does not determine
refund provenance
```

and:

```text
refund / reimbursement
    !=
Correction
```

These observations make several application relations observable without yet earning practical Plan, Series, or Refund types.

### 066–071 — external accounting pressure without importing product ontology

This sub-arc uses mature accounting features only as pressure. It does not copy their nouns into the Practical Core.

Observation 066 separates:

```text
historical valuation
    !=
acquisition basis
    !=
current valuation
```

Observation 067 separates:

```text
aggregate holding
    !=
quantity-bearing disposal provenance
```

and:

```text
source identity set
    !=
quantity consumed from each source
```

Observation 068 separates three meanings:

```text
valid allocation
    !=
policy-selected attribution
    !=
explicitly retained attribution
```

Observation 069 moves that distinction through time:

```text
current policy
    !=
retained historical attribution
```

Observation 070 finds:

```text
retained attribution
    !=
policy provenance
```

Observation 071 finally holds policy identity fixed while its behavior changes and finds:

```text
stable policy identity
    !=
historical policy definition
```

More strongly, in the bounded model:

```text
stable policy identity
+ current definition
+ retained attribution

    does not determine

historical policy definition
```

The sub-arc is closed at Observation 071. It earns no `CostBasis`, `Lot`, disposal-policy, `PolicyId`, or `PolicyVersion` primitive. It instead constrains how those ideas must be treated if a future practical question actually requires them.

## 2. Earned structure

### Stable identity

Current evidence supports stable identity for:

- Event
- Effect
- Locus
- Measure
- Correction within its semantic kind
- Resolution within its semantic kind

Experimental vocabularies also show why Plan identity and source Event identity matter when planning, realization, Series, or refund questions are retained.

Identity is not inferred from:

- list position;
- physical file order;
- display name;
- aggregate coordinate;
- equal amount/time/shape;
- opposite-signed quantity;
- recurrence kind;
- current policy output.

The practical `EffectKey` is especially important: later overlays can refer to one Effect without turning `(Locus, Measure)` or list position into identity.

### Exact physical quantity shape

The Practical Core physical shape remains:

```text
Event
  -> Effect identity
       -> Locus
       -> Measure
       -> Quantity
```

Quantity is exact. Coordinate totals are projections over Effects, not Effect identity.

Observations 062–071 add application/provenance questions around this shape but do not add another physical coordinate.

### Explicit revision relations

Correction and Resolution remain explicit relations rather than destructive edits.

Raw relation memory may retain references whose Event endpoints are not currently visible. Derived referential admission fails closed until the needed endpoints exist.

### Explicit correspondence when provenance is observable

Several experiments share one general lesson:

> Endpoint content or aggregate summaries need not determine correspondence.

Examples include:

- Plan -> Actual realization;
- Plan -> Series membership;
- Return -> earlier expense refund provenance;
- acquisition -> basis information;
- disposal -> acquisition-specific quantity provenance;
- retained attribution -> historical policy provenance.

This does **not** imply one universal practical Relation type. Different relation kinds still carry different semantic and operational laws.

### More than one time coordinate when the question requires it

Validity time and knowledge time remain independently observable in retrospective questions.

Later temporal observations also show a different principle: a mutable current configuration must not be substituted for retained historical meaning merely because the current and historical values share one representation shape.

## 3. Derived views

The following have appeared as derivable views rather than automatically deserving primary stored identity:

- envelope-like live holdings;
- availability in the bounded consumptive model;
- total balance;
- balance by Locus / Measure;
- transfer-like shape;
- role-aware bookkeeping readings over physical facts plus AccountingRole;
- completed Plan membership from explicit realization linkage;
- realized Actual membership from explicit realization linkage;
- expected/Actual mismatch views;
- same-Series peer sets from explicit Series membership;
- refund-linked source/return sets from explicit refund linkage;
- historical/current valuation answers from retained valuation observations;
- aggregate post-disposal holding from acquisition quantities and disposal provenance;
- participating acquisition source set from positive provenance quantities;
- implicated acquisition-basis set from participating acquisition identities;
- policy-generated current attribution from physical candidates plus current policy;
- current revision tips;
- correction-aware effective quantity views;
- referentially admitted relation views;
- report-like readings over physical facts plus overlays.

A stored cache or publication representation may later support a derived view operationally. That alone would not make the cache canonical domain meaning.

A particularly important boundary from Observation 069 is:

```text
current-policy attribution view
    !=
retained historical attribution
```

when the application has chosen to retain the latter as historical meaning.

## 4. Overlays

The following relations are semantically independent from the neutral physical core in the bounded observations, or remain intentionally outside it pending stronger pressure:

- Purpose / intentional assignment;
- AccountingRole;
- Plan realization linkage;
- Series membership;
- refund / reimbursement source linkage;
- valuation / Rate relations;
- acquisition-basis relation;
- quantity-bearing disposal-to-acquisition provenance;
- disposal selection policy;
- explicit policy/conformance statement when an application intentionally defines retained attribution as policy-generated;
- policy provenance when a future query asks which selector produced a retained attribution;
- historical policy-definition information when mutable policy identity must remain historically explainable;
- backing eligibility;
- recipient assignment;
- other application-facing classifications.

An overlay is not "less real." It means its meaning is not determined by the underlying physical placement and quantity relations currently retained.

## 5. Practical Lean Core

The current entry point imports:

- `Quantity`
- `Measure`
- `Effect`
- `Event`
- `EventMemory`
- `EventCorrection`
- `EventCorrectionMemory`
- `EventResolution`
- `EventResolutionMemory`
- `RelationAdmission`
- `CorrectionQuantity`
- `Rate`
- `Allocation`
- `RecipientAssignment`

The core remains deliberately concrete.

Correction and Resolution have separate modules rather than one premature generic relation abstraction.

`Rate` remains a neutral exact Measure-to-Measure relation. Observation 066 strengthens the reason not to treat it as acquisition provenance.

`EffectKey` already provides a stable endpoint for the bounded provenance question in Observation 067. That result does not earn a separate Lot identity.

`Allocation` and `RecipientAssignment` remain exact numeric infrastructure. Similar arithmetic shape does not make them disposal-provenance or accounting-policy semantics.

Observations 062–071 therefore add **no new Practical Core primitive**.

The implementation rule remains:

```text
observation
  -> identify one earned distinction or law
  -> add only the minimum practical representation needed by a real operation or retained query
```

Experimental vocabulary does not automatically become production vocabulary.

## 6. Persistence boundary

Current practical persistence keeps:

- exact Amount representation;
- Event identity and every detailed Effect, including `EffectKey`;
- EventMemory without giving block order historical meaning;
- raw Correction memory as an independent stream.

Physical storage topology remains separate from logical canonical meaning:

```text
logical canonical facts
    !=
physical storage topology
    !=
derived projections
```

Publication by separate atomic file replacement does not create a cross-stream transaction, concurrent-writer lock, or power-loss durability guarantee.

Observation 061 earns only the bounded stable-frontier Resolution protocol. Practical Resolution persistence is not added merely by analogy.

Observations 062–071 add **no persistence stream or wire-format change**.

In particular, observability alone does not earn:

- Plan store;
- realization stream;
- Series store;
- refund stream;
- acquisition-basis stream;
- disposal-provenance stream;
- policy stream;
- policy-version stream;
- Lot store.

A new stream should appear only when a practical operation must publish, reload, coordinate, correct, or query that information.

## 7. Deliberately unearned concepts

LOAM should not silently promote these into domain law without concrete pressure that requires them:

- one global FactId shared by all semantic kinds;
- one globally ordered canonical history;
- chronology from list or file position;
- priority or authority from arrival order;
- a conventional Account object as the physical primitive;
- a stored nominal EventKind hierarchy for bookkeeping roles;
- stored Envelope balance as the canonical live-holdings source of truth;
- eager referential rejection as a raw relation-memory rule;
- autonomous recovery metadata;
- concurrent-writer locking semantics;
- fsync or power-loss durability guarantees;
- a manifest or generation selector;
- general moving-frontier Resolution persistence semantics;
- one-to-one ledger-posting-to-LOAM-Effect import semantics;
- Practical Core Plan, Series, or Refund objects merely because their relations are observable;
- many-to-many Plan realization without source pressure;
- recurrence generation or Series lifecycle semantics;
- first-class refund relation identity, lifecycle, correction, or persistence;
- Practical Core `CostBasis` or `Lot` merely because acquisition basis or disposal provenance is observable;
- a production disposal-provenance relation before a practical disposal workflow requires it;
- an additional Lot identity when existing Effect-style identity answers the bounded selected questions;
- FIFO, LIFO, average cost, specific identification, or other selection methods as primitive physical history;
- a Practical Core disposal-selection policy merely because deterministic attribution is observable;
- policy identity, policy version, validity interval, authority, authorship, approval, or governance semantics without a retained practical question that observes them;
- a requirement to persist which policy generated every attribution;
- a requirement to store a complete executable policy snapshot;
- a rule that every explicit source relation conforms to the current policy;
- a rule that policy changes rewrite retained historical attribution;
- realized/unrealized gain semantics merely from valuation, basis, provenance, and policy separation;
- tax-specific basis rules;
- compaction semantics.

These concepts are not rejected forever. They are simply not earned yet.

## 8. Tool roles after seventy-one observations

### Alloy

Use Alloy when the question is primarily structural:

- can two worlds share one retained structure but differ in a selected answer?
- is one relation independent of another?
- does removing a field collapse distinctions?
- can a familiar noun remain a projection?
- can endpoint records reconstruct the relation connecting them?
- can aggregate or set-valued provenance reconstruct quantity-bearing provenance?
- does deterministic policy output determine an independently retained relation?
- does a retained output determine which behaviorally distinct policy produced it?

Observations 062–068 and 070 are representative recent examples.

### J

Use J when array shape, projection, quotienting, or information loss is the clearest form of the question.

J is not a mandatory second implementation of every Alloy observation.

### Lean 4

Use Lean when a discovered law is worth preserving generally or when the Practical Core needs to embody an earned distinction.

Lean remains both proof environment and practical-core language.

### TLA+ / TLC

Use TLA+ when the distinction depends on state transition, operation order, temporal knowledge, or reachable history.

Observation 034 separates historical/current relation viewpoints.

Observation 069 checks:

```text
RecordDisposal
  -> ChangePolicy
```

and shows current policy can diverge from retained attribution.

Observation 071 holds policy identity stable while its definition changes and shows two histories can converge on the same current projection while retaining different historical definitions.

### Apalache

Use selectively with TLA+ when symbolic checking or inductive-invariant obligations add a distinct answer, as in Observation 060.

### SPIN / Promela

Use when explicit process interleavings and protocol order are the pressure point, as in Observations 059 and 061.

### miniKanren

Use when genuinely relational or backwards search adds a distinct answer that the current tools do not express as directly.

The rule remains:

> Using every tool is not a goal. A tool must earn its place in the question.

## 9. Practical Core audit after Observations 066–071

The external-accounting-pressure sub-arc has been audited as a whole.

Result:

```text
Practical Core additions: 0
Persistence additions:     0
CLI additions:             0
wire-format additions:     0
```

This does **not** mean the six observations were redundant.

They progressively close reconstruction shortcuts:

```text
valuation history
    -/-> acquisition basis

aggregate holding
    -/-> disposal provenance

source set
    -/-> per-source quantity allocation

policy
    -/-> independently retained attribution

current policy
    -/-> retained historical attribution

retained attribution + current policy
    -/-> historical policy provenance

stable policy identity + current definition + retained attribution
    -/-> historical policy definition
```

What the audit changes is the next action: none of those bounded distinctions currently has practical publication/query pressure strong enough to justify another primitive or stream.

Existing boundaries were strengthened instead:

- `Rate` remains neutral;
- `EffectKey` remains the stable identity before aggregation;
- numeric allocation remains separate from source/provenance semantics;
- current derived view remains separate from retained historical meaning;
- policy provenance remains conditional on the questions an application chooses to retain.

See [`experiments/066_071_practical_core_audit.md`](experiments/066_071_practical_core_audit.md) for the detailed audit.

The policy/provenance sub-arc is therefore closed at Observation 071. Authority, approval, governance, and further policy metadata are not automatic Observation 072 candidates.

## 10. Current checkpoint

LOAM has now completed several loops of:

```text
question
  -> formal observation
  -> counterexample or law
  -> protocol observation when needed
  -> Practical Lean boundary when earned
  -> persistence when earned
```

The important result after seventy-one observations is not that the core has accumulated seventy-one concepts.

It is almost the opposite.

The neutral physical center remains small:

```text
Event
  -> Effect identity
       -> Locus
       -> Measure
       -> Quantity
```

Revision remains explicit through narrow Correction / Resolution boundaries.

Operational mathematics remains narrow through `Rate`, `Allocation`, and `RecipientAssignment`.

Many application meanings remain overlays until a retained practical question requires them.

The 066–071 audit provides a useful stopping rule:

> Preserve a distinction when a retained practical question can observe it. Do not promote the distinction into the Practical Core merely because a bounded experiment proves that the distinction can exist.

The next work should therefore not be Observation 072 merely to continue numbering.

A new observation should begin only when one of these appears:

- a concrete practical operation the current Core cannot express safely;
- a retained query whose answer the current representation cannot preserve;
- real persistence pressure for an experimentally observed relation;
- protocol/concurrency pressure at an already-earned practical boundary;
- new external evidence that contradicts a current compression.

Until then, the small Practical Core surviving the pressure is itself the checkpoint result.
