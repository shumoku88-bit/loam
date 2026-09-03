# Observation 127 — Does quantity-free Backing topology determine funded Capacity?

Status: qualified bounded Alloy observation

## Household question

Observation 126 asks whether Capacity plus eligible holdings are enough to answer which purposes are backed. Its bounded scaffold assigns each whole Holding to at most one Purpose.

That is intentionally too small for an ordinary household budget shape such as:

```text
Bank = 10

Food Capacity   = 6
Travel Capacity = 4

Bank backs:
  Food   6
  Travel 4
```

One physical holding may support several envelope-like purposes at once.

The next question is therefore:

> If we know that one Holding backs both Food and Travel, is that quantity-free topology enough to recover how much of each Capacity claim is actually backed?

Or does the apportionment itself carry independently observable information?

## Why this matters for practical budgeting

A future LOAM budget surface may need to distinguish at least:

```text
Capacity authority
Backed amount
Under-backed amount
```

For example, a household may choose Food Capacity of 6 while only 4 units of eligible physical quantity currently support it.

If Backing is reduced to a yes/no relation such as:

```text
Bank -> Food
Bank -> Travel
```

then the UI still needs some way to answer whether Food is backed by 6, 4, or another quantity.

Observation 127 asks for the minimum information required for that selected answer before any production Envelope or Backing type is introduced.

## Bounded specimen

The physical and Capacity evidence is fixed:

```text
Bank holding = 10

Food Capacity   = 6
Travel Capacity = 4
```

Eligibility is also fixed.

Three worlds are used.

### Full

```text
Bank -> Food   share 6
Bank -> Travel share 4
```

Both Capacity claims are fully backed.

### Skew

```text
Bank -> Food   share 4
Bank -> Travel share 6
```

The quantity-free topology is identical:

```text
Bank -> Food
Bank -> Travel
```

and the same total 10 units of Bank holding are assigned.

But Food is now backed only 4/6 while Travel has more support than its 4-unit Capacity claim needs.

### Copy

`Copy` repeats the `Full` quantity shares. It exists so the final sufficiency check has an inhabited same-share pair rather than passing only because no two worlds share the same quantity evidence.

## Candidate projection

For the bounded single-Measure model:

```text
backed(purpose)
  = sum of Backing shares supporting that purpose

funded(purpose)
  = min(Capacity entitlement, backed amount)
```

Each Holding's total Backing shares may not exceed its physical quantity.

This is only bounded scaffolding. It is not a proposed production representation.

## Executed result

Alloy 6.2.0 + Sat4j:

```text
oneHoldingCanFullyBackTwoPurposes                   SAT
sameTopologyDifferentApportionment                  SAT
sameTopologySameTotalDifferentFunding               SAT
partialBackingAppearsWithoutCapacityChange          SAT
identicalSharesRecoverSameAnswer                    SAT
TopologyDeterminesPurposeFunding                    SAT counterexample
TopologyAndUsedQuantityDeterminePurposeFunding      SAT counterexample
QuantitySharesDetermineSelectedFunding              UNSAT counterexample
```

The complete expected result set passed in CI on the PR merge ref against current `main`.

## Finding

The selected bounded answer requires more than quantity-free Backing topology.

`Full` and `Skew` agree on:

```text
Capacity
Holding quantity
Eligibility
Bank -> Food topology
Bank -> Travel topology
total quantity used from Bank = 10
```

but differ on funded Capacity:

```text
Full:
  Food   6 / 6 funded
  Travel 4 / 4 funded
  total funded = 10

Skew:
  Food   4 / 6 funded
  Travel 4 / 4 funded
  total funded = 8
```

The extra 2 units directed toward Travel in `Skew` cannot fund more than Travel's 4-unit Capacity claim, while Food remains under-backed.

So the compression boundary is:

```text
Backing topology
    !=
Backing apportionment
```

and more concretely:

```text
Capacity
+ Holding quantity
+ Eligibility
+ quantity-free Holding <-> Purpose topology
+ total quantity used from the Holding

    do not determine

per-Purpose backed / funded amount
```

Information equivalent to quantity-bearing Backing apportionment is independently observable for the selected household answer.

`QuantitySharesDetermineSelectedFunding` has no bounded counterexample, and the explicit `Full` / `Copy` witness demonstrates an inhabited same-share pair with the same selected funded answer.

## Relationship to Observation 120

Observation 120 found a parallel pressure in Scheduled realization:

```text
relation topology says which things correspond
quantity evidence says how much passes through that correspondence
```

Observation 127 finds the same structural pressure independently in Capacity Backing.

That repetition is interesting, but it does **not** earn a generic relation framework. Scheduled realization and Capacity Backing retain different household authority and different downstream questions.

## Product interpretation

The practical consequence is not "store envelope balances".

A smaller candidate remains:

```text
Capacity evidence
+ physical holdings
+ eligibility
+ quantity-bearing Backing evidence
    -> backed / funded / under-backed projection
```

So a future envelope-like UI could potentially show:

```text
Food
  Capacity: 6
  Backed:   4
  Gap:      2
```

without turning `funded`, `gap`, or an Envelope balance into independently retained truth.

This matters for daily use because Capacity may express what the household intends to permit while Backing answers whether that permission is physically supported by the selected holdings. Those meanings should not be collapsed merely because both eventually appear as numbers in one budget screen.

Observation 127 changes no practical surface yet.

## Boundaries

Observation 127 does not establish:

- a production `BackingShare` type;
- that Backing quantities should be persisted directly rather than reconstructed from finer evidence;
- an Envelope object;
- how Capacity is initially funded;
- automatic rebalancing between purposes;
- priority rules when Backing is insufficient;
- whether one unit of physical quantity may support multiple purposes under credit or contingent rules;
- multi-Measure / currency valuation;
- liabilities, credit limits, debt netting, or settlement timing;
- historical Backing changes or valid-time / knowledge-time semantics;
- ownership, Agent, legal-access, or institution semantics;
- Practical Core, persistence, CLI, or canonical household-data changes.

The qualified result is only that quantity-free Backing topology does not preserve enough information for per-Purpose funded Capacity in this bounded specimen.
