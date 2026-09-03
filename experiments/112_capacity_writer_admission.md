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

Expected: **SAT**.

### 2. The same movements can be valid or invalid when only effective days change

The endpoint graph is held fixed. One world dates the grant before the transfer; another dates the transfer before the grant.

If historical validity differs, untimed Capacity movement memory is too small to reconstruct this admission question.

Expected: **SAT**.

### 3. Final non-negative totals can hide an earlier invalid state

A later grant can repair the final total even though an earlier named-source transfer temporarily drove a Purpose below zero.

Expected: **SAT**.

### 4. Same-day grant and transfer can be valid without line ordering

When both effects share the same effective day, the day-level aggregate can remain non-negative. No extra within-day sequence is required for this bounded law.

Expected: **SAT**.

### 5. `Unallocated` can be negative while all named Purpose stock remains valid

This probes whether the outside balancing boundary should obey the same stock law as a spendable Purpose.

Expected: **SAT**.

## Assertions

The model checks four stronger claims:

```text
untimed movement set -> historical stock validity
final Purpose totals -> historical stock validity
same effective days -> same historical stock validity
Unallocated obeys the same non-negative stock law as Purpose
```

Expected results:

```text
UntimedMovementsDetermineHistoricalStockValidity       SAT counterexample
TimedMovementsDetermineHistoricalStockValidity         UNSAT counterexample
FinalPurposeTotalsDetermineHistoricalStockValidity     SAT counterexample
PurposeAndUnallocatedShareOneNonnegativeStockLaw       SAT counterexample
```

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

If the expected model results hold, the next design choice becomes explicit:

1. **writer-only current guard**: reject a named-source movement when current Entitlement is insufficient, while accepting that persisted history does not independently prove historical admission; or
2. **retained temporal evidence**: add enough effective-time evidence that Capacity history can itself determine the stock-admission question.

The observation should choose between these only after the solver result is known. It should not import HRA's exact source format merely because HRA supplies the reality pressure.
