# Observation 112: What evidence does a practical Capacity writer need?

## Question

Practical Capacity is now writable in `main`, but the first entrance deliberately records only a balanced Capacity movement. That is enough to derive current Entitlement totals, yet it leaves a sharper writer question:

> When the source is a named Purpose, what evidence is required to justify calling a request a Capacity movement rather than merely accepting another balanced vector?

The concrete pressure appeared immediately after the first practical entrance. A writer can currently accept a request whose named source has less derived Entitlement than the requested transfer amount.

## Reality pressure

HRA's canonical Household contract provides a useful comparison without becoming LOAM's ontology.

HRA's native Entitlement source distinguishes:

```text
unallocated -> Envelope
Envelope -> Envelope
Envelope -> unallocated
```

and retains an explicit valid date for each movement plus a stock origin per Commodity. Its admission law rejects cumulative negative spendable Envelope stock, while `unallocated` is a balancing boundary rather than a finite spendable stock. Same-day effects are combined before the cumulative non-negative check so textual source order within one day does not invent a transient negative balance.

The private canonical household source was also inspected as reality pressure. Only non-identifying shape observations are recorded here:

- the source contains an explicit stock origin;
- the observed Capacity-like history uses two-endpoint transfers;
- it contains initial grants, a later return to the outside boundary, and a later reallocation between named purposes;
- the inspected named-source transfers do not exceed their previously admitted Entitlement stock.

No private dates, quantities, names, paths, or source text are copied into this repository.

## Candidate model

The model deliberately keeps the quantity vocabulary tiny: every movement carries one abstract unit. That is enough to distinguish historical stock validity from final totals.

```text
Movement
  source -> target

World
  Movement -> effective Day
```

Purpose stock at a day is:

```text
units received through day
- units sent through day
```

A historically valid Purpose stock never becomes negative at a day boundary.

`Unallocated` is intentionally excluded from that non-negative law.

## Probes

### 1. HRA-shaped two-endpoint history is reachable

A grant from `Unallocated` followed by a transfer between two Purposes can satisfy the Purpose stock law.

Observed: **SAT**.

### 2. The same movements can be valid or invalid when only effective days change

The endpoint graph is held fixed. One world dates a movement history so named Purpose stock remains valid; another dates the same movement set so a named Purpose becomes negative at an earlier day.

Observed: **SAT**.

Untimed Capacity movement memory is therefore too small to reconstruct this historical admission question.

### 3. Final non-negative totals can hide an earlier invalid state

A later incoming movement can repair the final total even though an earlier named-source movement drove a Purpose below zero.

Observed: **SAT**.

Final Entitlement alone is therefore too small for historical stock admission.

### 4. Same-day grant and transfer can be valid without line ordering

When both effects share the same effective day, the day-level aggregate can remain non-negative. No extra within-day sequence is required for this bounded law.

Observed: **SAT**.

### 5. `Unallocated` can be negative while all named Purpose stock remains valid

The outside balancing boundary can become negative while every named Purpose satisfies the non-negative stock law.

Observed: **SAT**.

## Executed result

Alloy 6.2.0 + Sat4j, exactly 2 Days / 2 Movements / 2 Purposes / 2 Worlds:

```text
representativeHraShapedCapacity                         SAT
sameMovementSetDifferentTimeDifferentValidity           SAT
finalNonnegativeHidesEarlierInvalidity                   SAT
sameDayGrantAndTransferCanNet                            SAT
unallocatedBoundaryCanBeNegative                        SAT
UntimedMovementsDetermineHistoricalStockValidity        SAT counterexample
TimedMovementsDetermineHistoricalStockValidity          UNSAT counterexample
FinalPurposeTotalsDetermineHistoricalStockValidity      SAT counterexample
PurposeAndUnallocatedShareOneNonnegativeStockLaw        SAT counterexample
```

The first execution used relational `-` where integer subtraction was intended in the bounded stock helper. Alloy executed that model correctly, but the malformed arithmetic collapsed several probes. Replacing it with explicit integer `sub[...]` changed no intended observation question; the corrected exact-head result above passed the expected-result checker.

## Finding

Within this bounded question:

```text
balanced Capacity movements alone
    too small for historical named-Purpose stock validity

final Purpose totals
    too small for historical named-Purpose stock validity

movement endpoints + effective day
    sufficient for the selected historical stock-validity answer

same-day textual order
    not required

Purpose non-negative stock law
    does not imply the same law for Unallocated
```

Effective time is therefore independently observable **if LOAM wants retained Capacity history itself to determine whether named-source movements were historically admissible**.

That does not by itself require a built-in `date` field on `CapacityMovement`. The information could be retained as separate typed evidence or another information-equivalent temporal mechanic. The observation earns the information distinction, not one representation.

The result also sharpens the meaning of the first practical entrance. A named Purpose behaves like spendable Capacity stock for this bounded admission question; `unallocated` does not. Consequently, blindly allowing a named-source movement to exceed available Entitlement is not equivalent to merely allowing `unallocated` to become negative.

## Deliberate boundaries

Observation 112 does **not** decide yet:

- whether `CapacityMovement` in Core must be restricted to exactly two endpoints;
- whether multi-endpoint Capacity occurrences should exist at all;
- whether a current-only writer guard is sufficient even if historical validity cannot later be reconstructed;
- whether Capacity requires its own production time evidence or can reuse a generic temporal mechanic without semantic collapse;
- whether an explicit stock origin is required for LOAM's own local stream;
- Capacity correction semantics;
- Backing or physical holdings;
- Consumption / Remaining negativity.

In particular, negative `Remaining` is not the same thing as negative Entitlement stock. A household may overspend relative to Entitlement while the retained Capacity allocation history itself remains valid.

## Decision pressure

The next implementation decision is now explicit:

1. **writer-only current guard**: reject a named-source movement when current Entitlement is insufficient, while accepting that persisted untimed history does not independently prove historical admission; or
2. **retained temporal evidence**: add enough effective-time evidence that Capacity history can itself determine the stock-admission question.

HRA and the canonical household source justify asking this question, but do not choose LOAM's representation. The smallest production step should be chosen from LOAM's own practical needs rather than by copying HRA's source format.
