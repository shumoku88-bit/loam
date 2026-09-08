# LOAM semantic census — 2026-09-08

Status: production-structure census before further compression

Baseline: `bc95e328f9125afda4bf85cc3d209deeb31414cb`

This census deliberately separates physical source modules, independently meaningful household evidence, shared mechanics, and derived projections. A module count is not a concept count.

## 1. Physical semantic-layer count

At the baseline above:

```text
Loam/Core/*.lean          34 modules
Loam/Application/*.lean   18 modules
-------------------------------------
                         52 modules
```

### Core — 34

```text
AccountingRole
ActualReversal
ActualValidity
ActualValidityHistory
Attention
AttentionMemory
BalancedMovement
Capacity
CapacityEffective
CapacityMemory
CorrectionQuantity
Effect
Event
EventCorrection
EventCorrectionMemory
EventDescription
EventMemory
EventResolution
EventResolutionMemory
HistoricalRouting
LocusAdmission
Measure
OpenRelation
Purpose
Quantity
RelationAdmission
RoutingEffective
Scheduled
ScheduledCompletion
ScheduledMemory
ScheduledReplacement
ScheduledRetirement
ScheduledRouting
ZeroOriginCoverage
```

### Application — 18

```text
ActualRoutingInspection
ActualValidityFrontier
AttentionInspection
CapacityInspection
CapacityWindowInspection
ConsumptionInspection
CorrectionFrontier
CurrentCoverageInspection
OpenRelationFrontier
QuantityInspection
RelationDischargeFrontier
ReplacementFrontier
ScheduledBalanceHypothetical
ScheduledBalanceInspection
ScheduledCommitmentInspection
ScheduledInspection
ScheduledOpenWorldInspection
ZeroOriginQuantity
```

The 52-module number is only a physical boundary. It must not be read as "LOAM has 52 independent concepts".

## 2. Repeated Core collection mechanics

The first compression target is stronger than the earlier rough count suggested.

At least ten current Core structures have the same one-key finite-memory skeleton:

```text
items : List Item
unique : (items.map keyOf).Nodup

admit if key unique
append if key remains unique
find by key
representation order is not semantic order
```

Observed families include:

```text
EventMemory                    key Event.id
CapacityMemory                 key CapacityMovement.id
EventCorrectionMemory          key EventCorrection.id
EventResolutionMemory          key EventResolution.id
EventDescriptionMemory         key EventDescription.event
ActualValidityMemory           key ActualValidity.event
ScheduledMemory                key ScheduledOccurrence.id
ScheduledRetirementMemory      key ScheduledRetirement.scheduled
AttentionMemory                key Attention.id
AttentionClosureMemory         key AttentionClosure.attention
```

These are not ten equal household meanings. They are at least ten uses of one candidate mechanical structure.

A second repeated shape has two independently unique endpoints:

```text
ActualReversalMemory
ScheduledCompletionMemory
ScheduledReplacementMemory
```

Their semantic relations differ, but the finite partial-bijection storage mechanics are close enough to deserve a separate audit after the one-key family.

## 3. Already-qualified compression precedent

Observation 218 already extracted repeated replacement-frontier machinery from multiple semantic families into the small internal `Loam/Application/ReplacementFrontier.lean` helper.

The important precedent is:

```text
share structural mathematics
keep semantic evidence types distinct
```

That extraction reduced production-shaped Application source while preserving family-specific meaning and admission rules. Observation 232 applies the same discipline to finite keyed memories.

## 4. Observation 232 first target

The first probe deliberately uses four uncomplicated representatives:

```text
EventMemory
ScheduledMemory
CapacityMemory
AttentionMemory
```

They span four independent semantic authorities while sharing the same retained-data skeleton.

The probe asks two different questions that must not be conflated.

### Q1 — representation/mechanics

Can all four be represented losslessly by one finite keyed-memory shape and reuse one permutation-invariant lookup law?

Qualification requires:

- bidirectional representation round trips;
- identical fail-closed uniqueness admission answers;
- reusable append and lookup mechanics;
- representation-order-independent keyed lookup.

### Q2 — canonical ontology

Should the public domain memories themselves become one generic `Memory` type?

This is a separate and stricter question. A positive answer to Q1 does **not** imply Q2.

If generic wrappers erase useful semantic field names, blur authority, complicate persistence, or increase adapter code, retain the existing domain structures and extract only the mechanics.

## 5. Promotion gate

Do not promote the experiment merely because the generic theorem is elegant.

A production extraction must satisfy all of the following:

```text
1. no semantic family merged merely because its carrier is isomorphic
2. no persistence wire change required for the first extraction
3. existing public read/write behavior preserved
4. fail-closed duplicate-key behavior preserved
5. representation-order semantics remain explicitly absent
6. production source delta is net negative across the qualified families
7. adapters remain thinner than the duplication they replace
8. existing practical CI remains green
```

If a generic container type fails criterion 6 or 7, prefer a smaller internal keyed-list helper instead.

## 6. Next structural candidates after Observation 232

Only after the one-key result is measured:

```text
A. two-endpoint unique relation memory
   ActualReversal / ScheduledCompletion / ScheduledReplacement

B. temporal/effective evidence selection
   ActualValidity / CapacityEffective / RoutingEffective

C. persistence codec / authority wiring fanout

D. remaining Application projection mechanics
```

Each candidate must separately answer whether sameness is semantic or merely mechanical.

## 7. Compression rule

Use two tests throughout the cleanup.

Before deleting a semantic distinction:

> Can two household worlds agree on the proposed merged representation but require different answers?

If yes, keep the semantic distinction.

Before retaining duplicated implementation:

> Do several semantic families enforce the same structural law with independently copied code?

If yes, attempt a small shared mathematical helper and measure whether it pays rent.

The intended end state is not necessarily the fewest files. It is the fewest independent implementation principles that still preserve all independently observable household distinctions.
