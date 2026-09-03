# Observation 126 — Does Capacity plus eligible holding determine Backing?

## Household question

Observation 048 already established:

```text
what is held
    !=
what may participate in allocation
```

Observation 113 later established that Capacity remains authority evidence rather than a mutable reservation mirror for Scheduled spending.

The remaining seam is sharper:

> If the household has fixed Capacity, fixed physical holdings, and a fixed eligibility overlay, is that already enough to answer which purposes are actually backed?

Or does Backing topology carry independently observable information?

## Why Alloy

This is a static minimum-sufficiency question.

Hold constant:

```text
Capacity claims
physical holding quantities
eligible holdings
```

Vary only:

```text
which eligible holding backs which Purpose
```

Then ask whether funded / under-backed answers can change.

No temporal transition is required, so Alloy is the smallest instrument.

## Bounded specimen

Two purposes have fixed Capacity:

```text
Food   = 6
Travel = 4
```

Two eligible holdings contain the same total quantity:

```text
Bank   = 6
Points = 4

total eligible holding = 10
total Capacity          = 10
```

The two worlds agree on all of those facts.

Only Backing topology changes.

### Left

```text
Bank   -> Food
Points -> Travel
```

So both purposes are fully backed:

```text
Food funded   = 6 / 6
Travel funded = 4 / 4
total funded  = 10
```

### Right

```text
Bank   -> Travel
Points -> Food
```

The household still has exactly the same Capacity and exactly the same eligible total, but the selected answers become:

```text
Food funded   = 4 / 6   -- under-backed
Travel funded = 4 / 4   -- 6 units support a 4-unit claim
total funded  = 8
```

The extra 2 units behind Travel do not repair Food merely because household aggregate eligible quantity equals aggregate Capacity.

## Executed result

Alloy 6.2.0 + Sat4j:

```text
backingTopologyChangesPurposeFunding              SAT
capacityCanRemainUnderbacked                       SAT
backingCanExceedCapacity                           SAT
sameAggregateFundingDifferentPurposeAnswer         SAT
CapacityAndEligibilityDeterminePurposeFunding      SAT counterexample
AggregateEligibleQuantityDeterminesTotalFunded     SAT counterexample
ExplicitBackingDeterminesSelectedFunding           UNSAT counterexample
```

The expected-result checker passed the complete result set.

## Finding

The bounded counterexample keeps identical:

```text
Capacity
physical holding quantities
eligibility
total eligible quantity
```

while changing only the holding-to-Purpose Backing relation. The funded answer changes anyway.

So the selected vocabulary supports this separation:

```text
Capacity authority
    !=
Backing support
```

and, extending Observation 048:

```text
physical holding
    !=
eligible holding
    !=
Backing of a particular Capacity claim
```

The strongest aggregate result is:

```text
total Capacity = 10
total eligible = 10
```

in both worlds, yet:

```text
Left total funded  = 10
Right total funded = 8
```

Therefore aggregate eligible quantity is too small for the selected per-Purpose funded / under-backed answer.

Information equivalent to Backing correspondence remains independently observable once the household asks which Capacity claim is supported by which eligible holding.

Once explicit Backing topology is held fixed, Alloy finds no bounded counterexample to the selected funded projection.

## Important restraint

The model intentionally uses a very small Backing topology:

```text
Holding -> at most one Purpose
```

and each linked holding contributes its whole bounded quantity.

That is **not** proposed as the production representation.

A real household may need:

- one holding to back multiple purposes;
- partial backing quantities;
- priority / reservation semantics;
- debt or liability interaction;
- multi-Measure constraints;
- historical Backing changes;
- liquidity, ownership, legal-access, or institution-specific restrictions.

Those pressures may require quantity-bearing Backing evidence or a different representation. Observation 126 establishes only that aggregate eligible holdings cannot replace topology for the selected funded answer.

## Neighboring boundaries

- Observation 048: physical holding does not determine allocation eligibility.
- Observation 106: Capacity is a semantic plane distinct from Actual.
- Observation 113: Scheduled reservation mirrors are not needed for the selected Headroom composition.
- Observation 126: eligible holdings and Capacity still leave an independent Backing seam.

No generic resource / entitlement / collateral framework is earned by this observation.

## Boundaries

Observation 126 does not establish:

- a production `Backing` type;
- a production `BackingPool` or Envelope object;
- the final direction or cardinality of Backing relations;
- that whole-holding assignment is sufficient;
- multi-purpose apportionment semantics;
- historical or bitemporal Backing;
- liquidity or withdrawal constraints;
- debt netting;
- valuation or exchange-rate policy;
- ownership / Agent semantics;
- Practical Core, persistence, CLI, or canonical household-data changes.
