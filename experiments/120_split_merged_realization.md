# Observation 120 — Can Scheduled realization survive split and merged fulfillment?

## Household question

LOAM already retains explicit Scheduled -> Actual realization evidence because matching date, amount, Locus shape, or description does not determine which Actual occurrence realizes which expectation.

The first practical `ScheduledCompletion` deliberately keeps a one-to-one boundary:

```text
one Scheduled
    -> at most one Actual

one Actual
    -> at most one Scheduled
```

Its source comment explicitly leaves split and merged realization as future pressure rather than widening the first writer speculatively.

That pressure is now worth observing directly.

Real household shapes include:

```text
one expected 10
    -> Actual 6 + Actual 4

expected 3 + expected 2
    -> one Actual 5

one expected 10
    -> Actual 6 so far
```

The question is not merely whether the one-to-one cardinality should be relaxed.

> If Scheduled and Actual endpoint facts are fixed, is a many-to-many endpoint relation sufficient to reconstruct per-Scheduled realized quantity and fulfillment, or does split / merged realization expose independently observable apportionment information?

## Why Alloy

This is a structural distinguishability and sufficiency question.

Two bounded worlds can retain the same Scheduled facts, the same Actual facts, and the same realization endpoint topology while varying only how one shared Actual quantity is attributed across Scheduled expectations.

If the household answer changes, endpoint topology alone is too small.

No operation ordering or concurrent publication behavior is being asked yet, so Alloy is the smallest instrument that gives a distinct answer.

## Competing candidates

### Candidate A — current one-to-one completion relation

The current practical relation is intentionally small:

```text
ScheduledId -> EventId
```

with uniqueness on both endpoints.

This candidate should fail to represent both:

```text
1 Scheduled -> N Actual
N Scheduled -> 1 Actual
```

without manufacturing replacement identities merely to preserve cardinality.

### Candidate B — many-to-many endpoint topology

A natural first relaxation is:

```text
ScheduledId <-> EventId
```

with no allocation quantity.

This can preserve that one expectation relates to several Actual events and that one Actual event relates to several expectations.

But when one Actual is shared, the topology does not by itself say how much of the Actual realizes each expectation.

If every linked Scheduled simply consumes the whole Actual quantity, merged realization double-counts it.

### Candidate C — information-equivalent realization shares

The Alloy model therefore includes observation scaffolding:

```text
Scheduled
+ Actual
+ positive realization share
```

A share says how much of one Actual endpoint contributes to one Scheduled endpoint.

This is **not** a proposed production record shape.

Equivalent information might later be carried by finer-grained independently identified Effect evidence or another representation. The question here is whether information equivalent to apportionment is observable at all.

## Synthetic specimens

The model fixes these endpoint quantities:

```text
Scheduled SplitTen    expected 10
Scheduled MergeThree expected 3
Scheduled MergeTwo   expected 2
Scheduled AmbigTwo   expected 2
Scheduled AmbigFour  expected 4

Actual ActualSix      observed 6
Actual ActualFour     observed 4
Actual ActualFive     observed 5
```

### Split completion

```text
SplitTen 10
    -> ActualSix  6
    -> ActualFour 4
```

The expected realized quantity is 10.

### Merged completion

```text
MergeThree 3 --+
                +-> ActualFive 5
MergeTwo   2 --+
```

The expected attribution is 3 + 2 = 5.

If both Scheduled endpoints consume the whole Actual endpoint merely because they are linked, each reads 5 and the shared Actual is double-counted across expectations.

### Partial realization

```text
SplitTen 10
    -> ActualSix 6
```

The expectation is related to Actual evidence but is not yet fully realized.

So `has realization relation` cannot automatically mean `fulfilled` once partial realization is admitted.

### Same topology, different household answer

The strongest specimen holds the endpoint topology fixed:

```text
AmbigTwo  ---+
             +-> ActualFive 5
AmbigFour ---+
```

but compares two apportionments:

```text
Left:
  AmbigTwo  <- 2
  AmbigFour <- 3

Right:
  AmbigTwo  <- 1
  AmbigFour <- 4
```

Both worlds retain:

- the same Scheduled identities and expected quantities;
- the same Actual identity and observed quantity;
- the same two endpoint links;
- full use of the same Actual quantity 5.

But the household answers differ:

```text
Left:
  AmbigTwo  fulfilled
  AmbigFour partial

Right:
  AmbigTwo  partial
  AmbigFour fulfilled
```

If Alloy admits both worlds, endpoint topology alone cannot determine per-Scheduled realized quantity or fulfillment.

## Qualification target

The workflow checks the following expected result set:

```text
splitWitness                              SAT
mergedWitness                             SAT
partialWitness                            SAT
splitAndMergedCoexistWitness              SAT
oneToOneSplitWitness                      UNSAT
oneToOneMergedWitness                     UNSAT
mergedWholeActualProjectionOvercounts     SAT
sameTopologyDifferentRealizationWitness   SAT

TopologyAloneDeterminesRealizedQuantity   SAT counterexample
TopologyAloneDeterminesFulfillment        SAT counterexample
QuantitySharesDetermineRealizedQuantity   UNSAT counterexample
QuantitySharesDetermineFulfillment        UNSAT counterexample
```

The final interpretation should be accepted only after the exact-head Alloy workflow confirms this result set.

## Expected finding if qualified

If the target results hold, the current one-to-one boundary will have done its job: it stayed small until a concrete household distinction required more.

The expected compression boundary is then:

```text
one-to-one ScheduledCompletion
    too small for split / merged realization

many-to-many endpoint topology
    enough to preserve relation shape
    too small to determine shared-Actual apportionment

endpoint evidence
+ information-equivalent realization apportionment
    -> per-Scheduled realized quantity
    -> fulfilled / partial projection
```

This would **not** earn a mutable completion status.

Instead, fulfillment remains a projection from retained realization evidence:

```text
realized quantity = expected quantity
    -> fulfilled

realized quantity < expected quantity
    -> partial
```

The observation also would not automatically earn a generic `Allocation` family. It would establish only that some representation of the missing apportionment distinction is independently observable when one Actual can realize multiple Scheduled expectations or when an Actual endpoint is only partly attributable to an expectation.

## Neighboring LOAM boundaries

This observation is intentionally adjacent to, rather than a replacement for, earlier results:

- Observation 063 established that realization linkage itself cannot be inferred from matching Scheduled and Actual content.
- Observation 105 established that Scheduled lifecycle provenance cannot be collapsed to a mutable status.
- Observation 108 derives Commitment from Scheduled + routing + lifecycle evidence.
- Observation 113 composes Actual, Scheduled, and Capacity without retained reservation state.
- Observation 114 requires Consumption to use the effective Actual frontier after correction.

If split / merged realization is qualified, a later practical design must still compose with those frontiers rather than reading raw endpoints.

In particular, this observation does not decide whether a realization share should attach to:

```text
raw Actual Event
correction-effective Actual Event
Effect identity
another finer-grained realization coordinate
```

That should be decided only when practical writer / correction pressure reaches it.

## Boundaries

This observation does not establish:

- a production many-to-many `ScheduledCompletion` type;
- a canonical `RealizationShare` fact family;
- how realization apportionment should be edited or corrected;
- whether shares require independent identity;
- how a later Actual correction migrates or supersedes realization attribution;
- recurrence / Series grouping;
- refunds or reversal semantics;
- cross-Measure or foreign-exchange realization;
- bank-import reconciliation;
- whether over-realization should be allowed;
- a new Capacity reservation mechanism;
- a universal fulfillment ontology.

It asks only whether the first one-to-one realization boundary and a quantity-free many-to-many endpoint topology retain enough information for split, merged, and partial Scheduled realization.
