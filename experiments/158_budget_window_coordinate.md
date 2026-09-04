# Observation 158: Does envelope budgeting need BudgetPeriod identity, or only time coordinates?

Status: bounded Alloy observation prompted by private-household Capacity migration pressure after Observation 156 and Practical ActualRouting persistence.

## Question

The private household source exposes a clean Capacity epoch beginning on a real date, while LOAM retains older canonical Actual history.

If current Consumption simply folds all historical Actuals, a newly admitted current Capacity allocation would be compared against pre-epoch spending and Remaining would be wrong.

The immediate temptation is to introduce a retained `BudgetPeriod` / `EnvelopeCycle` entity.

This observation asks a smaller question first:

> If Capacity authority and Actual occurrence already have effective/valid time coordinates, can envelope-style Remaining for the current household be selected by a half-open time window alone? When would stable period identity add information that coordinates cannot reconstruct?

## Existing pressure

Observation 112 already found that Capacity movement timing is independently observable for historical named-Purpose stock validity. It earned effective-time information but deliberately did not choose a representation.

Observation 113 then found no need to retain Envelope, reservation, Remaining, Commitment, or Headroom state when Capacity, Actual, Scheduled, routing, and lifecycle evidence can be projected.

Observation 156 separately showed that an `initial` routing coordinate must not be collapsed into a fabricated first date.

The remaining question is therefore not whether time matters. It is whether a new **period identity** matters.

## Candidate A: coordinate window

The coordinate-only candidate keeps facts independent and asks a query over:

```text
Purpose
+ Measure        (abstracted away in this unit-count model)
+ [start, end)
```

For the bounded model:

```text
Entitlement(window)
  = Capacity facts whose effective day is inside [start, end)

Consumption(window)
  = Actual facts whose valid day is inside [start, end)

Remaining(window)
  = Entitlement(window) - Consumption(window)
```

This is intentionally a one-unit abstraction of the exact quantity algebra. The observation is about membership information, not arithmetic representation.

## Candidate B: explicit period membership

A stronger candidate gives retained Period identity and separately assigns Capacity / Actual facts to a Period.

If period membership is *only* the date-containment relation and periods do not overlap, that membership should be reconstructible from coordinates.

If two independent budget regimes occupy the same or overlapping coordinates, explicit period membership can distinguish facts that time alone cannot.

That is the proposed stop condition for earning Period identity.

## Probes

### 1. A clean epoch window excludes older Actuals

A Capacity fact and one Actual occur at the window start, while another Actual is earlier than the start.

The coordinate-window answer is zero, while the all-history answer is negative one.

This directly represents the current migration pressure: old canonical Actual history must not be silently charged against a later Capacity epoch.

Expected: **SAT**.

### 2. The same facts with different dates can produce different Remaining

Two worlds retain the same Capacity and Actual identities. Only the Actual valid coordinate differs: inside the queried window in one world, before the window in the other.

The coordinate-window Remaining differs.

This re-confirms for this specific projection that time information is independently observable; untimed Capacity/Actual sets are too small.

Expected: **SAT**.

### 3. Parallel same-window budget regimes create identity pressure

Two Period identities have exactly the same `[start, end)` coordinates. One Capacity fact is assigned explicitly to the first Period and one Actual fact to the second.

The coordinate-only answer is identical for both Period coordinate pairs, but explicit Period membership yields different Remaining answers.

This is the bounded witness that would earn period identity: two independent budget programs can coexist over the same coordinates and facts must belong to one rather than the other.

Expected: **SAT**.

### 4. Disjoint periods with coordinate-derived membership add no answer

When Period windows are pairwise disjoint and explicit membership is constrained to be exactly date containment, explicit Period Remaining must equal coordinate-window Remaining.

Expected check: **UNSAT counterexample**.

### 5. Equal coordinates imply equal coordinate-only answers

Two Period identities with the same start/end coordinates cannot produce different coordinate-only Remaining merely by being different atoms.

Expected check: **UNSAT counterexample**.

## Candidate finding

If the expected matrix holds, the current household pressure does **not** earn a `BudgetPeriod` entity merely to exclude pre-epoch Actual history.

The smaller vocabulary is:

```text
Capacity evidence + effective coordinate
Actual evidence   + valid coordinate
Purpose
[start, end) query window
```

and familiar envelope values remain projections.

Stable Period identity becomes independently observable only when the household wants something coordinates cannot decide, such as parallel/overlapping budget regimes with explicit membership.

## Important limits

This observation does not yet decide:

- the production representation of Capacity effective time;
- whether the current clean epoch end should be retained evidence or supplied by a query/cycle boundary;
- rollover semantics when Capacity from before the window should carry forward;
- overlapping Purpose hierarchies or multiple simultaneous budgeting systems;
- multi-Measure arithmetic;
- Backing;
- Scheduled period filtering beyond the already-qualified half-open horizon behavior;
- whether a later real household case will earn stable Period identity.

In particular, a coordinate window that excludes pre-start Capacity does not itself define rollover. If rollover is required, LOAM must represent that meaning explicitly rather than accidentally inheriting old Capacity merely because it exists in history.

## Stop condition

Do not add `BudgetPeriod` because budgeting software conventionally has one.

Add period identity only if two worlds can agree on all retained time coordinates and household facts yet still require different budget answers.

The parallel same-window witness is the deliberate example of such pressure; the current single clean household epoch is not assumed to have it.
