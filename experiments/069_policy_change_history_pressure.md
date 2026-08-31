# Observation 069 — Does a later policy change rewrite retained disposal attribution?

## Question

Observation 068 separated three layers:

```text
valid disposal allocation
    !=
policy-selected attribution
    !=
explicitly retained source relation
```

It deliberately left policy change through time unasked.

Observation 069 asks the temporal question:

> If a disposal attribution is retained while one policy is current, then the current policy changes later, may the old attribution be reconstructed from the new current policy?

The narrow pressure is historical meaning. The observation does not yet ask which tax or inventory policy should be used, nor whether policy identity or version must itself be persisted.

## Why TLA+ / TLC

Alloy already answered the structural independence question in Observation 068. The new distinction depends on an operation order:

```text
record attribution
    ->
change current policy
    ->
query old attribution
```

TLA+ therefore adds a distinct answer: it can explore reachable states across the policy change and show whether a retained historical statement is rewritten.

TLC is sufficient for this bounded transition system. Apalache would not add a distinct result here, so it is not introduced.

## Minimal state

The model keeps only two mutable values:

```text
currentPolicy
recordedAttribution
```

Two experiment-local policies are retained from Observation 068:

```text
preferEarlier -> earlier3_later1
preferLater   -> earlier1_later3
```

`RecordDisposal` snapshots the attribution produced by the current policy exactly once.

`ChangePolicy` changes only `currentPolicy`.

No `recordedUnderPolicy`, policy version, policy identity object, disposal object, Lot object, gain calculation, or persistence record is introduced.

## Positive safety property

Once a disposal attribution has been retained, it never rewrites:

```text
RecordedAttributionNeverRewrites
```

TLC result:

```text
Model checking completed. No error has been found.
9 states generated
6 distinct states found
state graph depth 4
```

So the bounded transition system preserves the retained attribution across every reachable current-policy change.

## Boundary hypothesis

The tempting reconstruction rule is:

```text
recorded attribution
    =
output of current policy
```

encoded as:

```text
CurrentPolicyReconstructsRecordedAttribution
```

TLC finds the required counterexample:

```text
State 1
currentPolicy       = preferEarlier
recordedAttribution = none

State 2  RecordDisposal
currentPolicy       = preferEarlier
recordedAttribution = earlier3_later1

State 3  ChangePolicy
currentPolicy       = preferLater
recordedAttribution = earlier3_later1
```

At State 3 the current-policy view is `earlier1_later3`, while the retained historical attribution remains `earlier3_later1`.

Therefore the boundary invariant is violated exactly after the later policy change.

## Finding

The bounded temporal separation is:

```text
retained historical attribution
    !=
current-policy attribution view
```

More operationally:

```text
policy change
    may change current-policy answers
    but does not thereby rewrite
    an already-retained attribution
```

This extends Observation 068. There, policy output and an independent explicit relation were structurally separable. Observation 069 shows why that distinction matters over time: if an old explicit relation is semantically retained, silently recomputing it from today's policy changes the historical answer.

## Relation to Observation 034

Observation 034 already established a general time-indexed relation lesson: the latest relation does not answer every past relation query.

Observation 069 does not re-earn that general result. It applies temporal pressure to a new distinction first exposed in Observations 067–068:

```text
quantity-bearing disposal attribution
    +
configurable selection policy
```

The new domain-specific risk is treating a current selector as though it were the retained source attribution of an already-recorded disposal.

## What is not earned

Observation 069 does **not** establish:

- FIFO, LIFO, average-cost, specific-identification, tax, or inventory law;
- that every disposal attribution must be stored rather than derived;
- that `recordedUnderPolicy` must be stored;
- policy identity, versioning, validity time, authority, provenance, or correction;
- that a policy change affects future disposals only in every application;
- a practical policy type;
- a production disposal-provenance relation;
- a Practical Core `Lot` or `CostBasis` type;
- gain/loss semantics;
- policy or attribution persistence;
- concurrent policy changes or publication protocols.

The strongest earned statement is narrower:

> Once an application chooses to retain a disposal attribution as historical meaning, the current policy alone is not a valid reconstruction source after policy changes.

## Practical Core boundary

No Practical Lean Core, Persistence, CLI, or wire-format change is earned by this bounded temporal observation.

A future observation may ask whether a retained attribution also needs policy provenance or version metadata. Observation 069 deliberately stops before that question.
