# Observation 137 — Unused Remaining carry boundary

## Question

Observation 136 separated cross-authority treatment of retained Capacity reallocations from ordinary within-authority adjustments.

This observation asks a different boundary question:

> Can unused `Remaining` cross an authority boundary without introducing canonical `EnvelopeBalance` / `RolloverBudget` state, by deriving the prior Remaining from existing Capacity + Actual evidence and letting an explicit boundary policy decide whether that derived amount contributes to the next authority?

The pressure to preserve is:

```text
reallocation carry
    !=
unused Remaining carry
    !=
physical savings / Holdings
    !=
Backing
```

No production representation is proposed.

## Bounded specimen

The temporal scaffold reuses adjacent half-open authorities:

```text
Previous [0,2)
Next     [2,4)
Next view [2,3)
```

Base Capacity is:

```text
Food   10
Travel  4
```

Previous-authority Capacity reallocations are:

```text
day 0: Food -2 / Travel +2
day 1: Food +1 / Travel -1
```

so Previous Capacity at end is:

```text
Food    9
Travel  5
```

Existing Actual evidence consumes:

```text
Food    6
Travel  4
```

Therefore Previous Remaining is derived, not stored:

```text
Food    3
Travel  1
```

A movement exactly at `Next.start` remains local to Next:

```text
day 2: Food +1 / Travel -1
```

The experiment-local boundary policy definition has two independent readings:

```text
carryAdjustment : prior Capacity adjustment -> 0 / 1
carryUnused     : Purpose -> 0 / 1
```

This is deliberately a tiny bounded scaffold, not a proposed policy DSL or canonical policy type.

The same evidence is read through five useful combinations:

```text
Reset both
  prior reallocation carry = no
  unused Remaining carry   = no
  -> Food 11 / Travel 3

Reallocation only
  prior reallocation carry = yes
  unused Remaining carry   = no
  -> Food 10 / Travel 4

Unused only
  prior reallocation carry = no
  unused Remaining carry   = yes
  -> Food 14 / Travel 4

Both
  prior reallocation carry = yes
  unused Remaining carry   = yes
  -> Food 13 / Travel 5

Selective unused
  prior reallocation carry = no
  Food unused carry        = yes
  Travel unused carry      = no
  -> Food 14 / Travel 3
```

A policy copy with equal definition but distinct identity is also included.

## Physical-state separation

All contexts share the same experiment-local physical specimen:

```text
holding quantity = 40
Backing:
  Food   20
  Travel 20
```

Changing unused Remaining carry changes next Capacity while those physical quantities remain unchanged.

The model therefore treats rollover as budget authority over Capacity, not as evidence that money physically moved or that Backing changed.

This does not claim Holdings and Backing are unrelated to later budget safety projections. It claims only that they do not determine whether unused Capacity is authorized to carry across this boundary.

## Expected ambiguity checks

The model deliberately expects counterexamples to stronger compressions:

```text
formula
+ Actual evidence
+ Capacity adjustment evidence
+ reallocation-carry definition
    -> next Capacity
```

is expected to be too small, because two policies can agree completely on reallocation carry while disagreeing on unused Remaining carry.

Likewise, the model expects neither direction of implication to hold:

```text
reallocation carry definition -> unused carry definition
unused carry definition       -> reallocation carry definition
```

and expects physical Holdings / Backing to remain insufficient to recover the missing unused-carry decision.

The total-Capacity preservation result from Observation 136 is also expected not to generalize. Balanced reallocation carry preserves total Capacity, while carrying unused Remaining can increase next-authority Capacity above the new base formula result.

## Smaller candidate under test

The bounded candidate is:

```text
next authority DateRange
+ selected view DateRange
+ formula definition
+ timed Capacity adjustments
+ existing Actual evidence
+ boundary policy definition
    - reallocation carry rule
    - unused Remaining carry rule
    -> selected next Capacity
```

with:

```text
previous Remaining
    = previous Capacity projection
    - previous Actual consumption
```

so no retained `EnvelopeBalance` is needed inside this specimen.

The important distinction is that `Remaining` is a derived prior-period answer, while the decision to reuse that amount in the next authority is independent semantic authority supplied by the boundary policy definition.

## What this observation does not claim

It does not propose or earn:

- canonical `EnvelopeBalance`
- canonical `RolloverBudget`
- canonical `Cycle`
- canonical `CarryCycle` / `ResetCycle`
- retained Remaining state
- production boundary-policy type
- policy identity
- a general policy DSL
- persistence changes
- CLI / TUI changes
- automatic Backing movement
- automatic physical savings movement
- canonical household-data changes

Partial-percentage rollover, caps, expiry, negative Remaining / overspending semantics, new-money funding at the boundary, and historical policy provenance remain outside this bounded specimen.

## Qualification

Pending exact-head Alloy qualification.
