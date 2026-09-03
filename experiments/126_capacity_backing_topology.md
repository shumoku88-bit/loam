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

So both purposes are fully backed.

### Right

```text
Bank   -> Travel
Points -> Food
```

The household still has exactly the same Capacity and exactly the same eligible total, but Food has only 4 units backing a 6-unit Capacity claim.

Travel has 6 units behind a 4-unit claim.

## Qualification target

Expected witnesses:

```text
backingTopologyChangesPurposeFunding             SAT
capacityCanRemainUnderbacked                      SAT
backingCanExceedCapacity                          SAT
sameAggregateFundingDifferentPurposeAnswer        SAT
```

Expected counterexamples:

```text
CapacityAndEligibilityDeterminePurposeFunding     SAT counterexample
AggregateEligibleQuantityDeterminesTotalFunded    SAT counterexample
```

And once explicit Backing topology itself is fixed:

```text
ExplicitBackingDeterminesSelectedFunding          UNSAT counterexample
```

## Expected compression boundary

If qualified:

```text
Capacity authority
    !=
Backing support
```

and:

```text
Capacity
+ physical holdings
+ eligibility

    do not determine

per-Purpose funded / under-backed answers
```

The selected answer additionally needs information equivalent to Backing correspondence.

This would extend Observation 048 without replacing it:

```text
physical holding
    !=
eligible holding
    !=
Backing of a particular Capacity claim
```

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

Those pressures may require quantity-bearing Backing evidence or a different representation. Observation 126 asks only whether aggregate eligible holdings can replace topology for the selected funded answer.

## Neighboring boundaries

- Observation 048: physical holding does not determine allocation eligibility.
- Observation 106: Capacity is a semantic plane distinct from Actual.
- Observation 113: Scheduled reservation mirrors are not needed for the selected Headroom composition.
- Observation 126: asks whether eligible holdings and Capacity still leave an independent Backing seam.

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
