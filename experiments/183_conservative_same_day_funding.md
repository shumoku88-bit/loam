# Observation 183 — conservative same-day funding without time-of-day

Status: Lean observation following the practical Scheduled balance-effect projection in PR #379.

## Pressure

LOAM can now answer the signed current-open Scheduled effect on each coordinate selected by `balance-view.tsv` before an end-exclusive horizon.

That is enough for questions such as:

```text
what is the aggregate Scheduled effect on this selected balance coordinate?
```

It is not obviously enough for the stronger household question:

```text
how much additional opening quantity is required so this balance cannot go
negative while the Scheduled effects occur?
```

The difficult case is not a later date. It is two effects on the **same** ScheduledDate when their intra-day order is unknown.

## Question

Can LOAM derive a conservative same-day funding requirement without inventing hour/minute timestamps or an artificial within-day sequence?

For one fixed `Locus × Measure × ScheduledDate`, retain only two observation-local magnitudes:

```text
same-day inflow subtotal
same-day outflow subtotal
```

and an opening quantity already known before that day.

## Candidate

If within-day order is unknown, the safe extreme must allow:

```text
all same-day outflow
-> before any same-day inflow
```

So the candidate additional opening quantity is:

```text
max(0, same-day outflow - opening)
```

Same-day inflow does not reduce this requirement because there is no evidence that it arrives first.

## Lean result

`Loam/Observations/Observation183.lean` models within-day uncertainty without time-of-day. A progress state records only how much of the already-known daily inflow and outflow may have happened so far.

The quantified state space includes the extreme:

```text
received = 0
paid     = all same-day outflow
```

Lean proves, for nonnegative directional subtotals:

```text
SafeForUnknownOrder opening additional day
iff
requiredAdditionalOpening opening day <= additional
```

Therefore the candidate is both sufficient and minimal for this conservative boundary.

## Net-only counterexample

A signed daily net is insufficient.

Two days can both have net zero:

```text
A: inflow 0   / outflow 0
B: inflow 10  / outflow 10
```

with opening zero.

But the conservative additional opening requirements differ:

```text
A -> 0
B -> 10
```

So:

```text
daily net
-/->
conservative same-day funding requirement
```

This matters directly to PR #379. Its aggregate signed Scheduled effect is intentionally a weaker projection. It should not be reused as though it already contained enough information for conservative funding pressure.

## Earned boundary

Observation 183 supports this narrow statement:

```text
one fixed selected balance coordinate
+ one ScheduledDate
+ directional inflow/outflow subtotals
+ unknown within-day order
-> exact conservative additional opening requirement
```

It does **not** earn:

- time-of-day or a hidden intra-day sequence;
- a canonical `Balance` entity;
- a canonical `Funding` or `TopUp` event kind;
- Backing topology;
- safe-to-spend authority;
- a claim that Scheduled will equal later Actual;
- a multi-day production projection yet.

A later multi-day projection may carry each day's signed net forward to the next existing ScheduledDate while using the directional outflow subtotal for that day's conservative floor. That is a separate composition boundary and should not be smuggled into this observation.
