# Observation 196: Budget-window selection pressure

Status: production-facing Lean observation after the first production Capacity TUI workspace.

## Question

The production TUI now has one selected day, and production already has an explicit Budget Window report over `[start, end)`.

Can Home derive the household budget window from its selected day without adding new semantics?

## Existing results

Observation 158 already showed that a retained `BudgetPeriod` / `EnvelopeCycle` identity is not needed merely to exclude older facts when Capacity and Actual have independent time coordinates. A half-open query window is sufficient for that membership question.

Observation 181 already showed that once windowed Entitlement and Consumption resolve, Remaining is a derived observation:

```text
Remaining = Entitlement - Consumption
```

So the missing pressure is no longer arithmetic or Period identity. It is window selection.

## Witness

Use one selected day:

```text
selected = 15
```

and two valid half-open windows that both contain it:

```text
narrow = [10, 20)
wide   = [ 0, 20)
```

Retain the same facts in both cases:

```text
day 5  -> 20
day 12 -> 30
```

Then:

```text
project(narrow) = 30
project(wide)   = 50
```

The selected day and household facts are identical. Only the query boundaries differ.

Therefore selected day alone cannot determine the budget answer.

## Lean qualification

`Loam.Observations.Observation196` proves:

- both candidate windows satisfy production `validCapacityWindow`;
- the same selected day belongs to both;
- the two windows yield different additive answers over the same facts;
- different Cycle/Period names with equal coordinates cannot change a coordinate-derived answer.

## Finding

The current pressure earns, at most, a **window-selection policy**:

```text
selected context
      +
shared policy / explicit input
      -> [start, end)
      -> existing CapacityWindowInspection
```

It does not earn a retained Cycle identity.

This means a future Home Budget / Remaining summary must not silently use:

- the visible calendar month;
- the selected day as a start or end;
- the first retained Capacity effective date;
- host-local month boundaries;
- any guessed income/payment cadence.

Any automatic choice needs a shared Application-level policy with an explicit source of justification. Until then, a Reports surface may safely ask for an explicit `[start, end)` and reuse the existing production Budget Window projection.

## Stop condition for retained Period identity

Observation 158 remains the stop condition: add stable Period identity only if two worlds can agree on all time coordinates and household facts yet still require different membership, for example parallel overlapping budget regimes.

## Next practical gate

The smallest production experiment after this observation is not a Home summary. It is an explicit-window Reports workspace:

```text
Reports
  -> Budget Window
  -> enter/select START
  -> enter/select END
  -> existing shared projection
```

If that works without semantic duplication, it provides a real report while leaving automatic "current cycle" selection unclaimed.
