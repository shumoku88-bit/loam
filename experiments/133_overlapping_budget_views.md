# Observation 133 — Can overlapping budget windows coexist without earning canonical budget roles?

## Question

Observations 131–132 left a small application candidate:

```text
friendly selector
    -> DateRange [start,end)
    -> Capacity formula definition
    -> generated base Capacity
    + retained Capacity movements
    -> final Capacity projection
```

A household may still want several views at once. For example:

```text
pension period
monthly view
six-month view
```

These windows can overlap heavily and reuse the same Actual / Scheduled evidence.

The next question is therefore:

> Does simultaneous multi-window budgeting require canonical `OperatingBudget`, `ForecastBudget`, or budget-role objects, or can all windows remain ordinary projections while one selected DateRange+Capacity context is supplied only when a scalar operating answer is requested?

There is a second risk. Even if every view is individually meaningful, overlapping views are not automatically additive. Summing their Consumption or Commitment may count the same retained facts more than once.

## Bounded specimen

One set of retained temporal evidence is projected through three views:

```text
PensionView  [0,4)  Capacity 20
MonthView    [1,3)  Capacity 10
HalfView     [0,6)  Capacity 30
```

A definition-equivalent `PensionViewCopy` has the same endpoints and Capacity under another experiment identity.

The fixed evidence is:

```text
ActualShared     day 2  quantity 3
ActualLater      day 4  quantity 2
ScheduledShared  day 2  quantity 4
ScheduledLater   day 4  quantity 5
```

`ActualShared` and `ScheduledShared` therefore belong simultaneously to the pension, month, and half-year views without being copied.

## Application selection scaffold

The model gives a dashboard a set of visible views and one selected view for a scalar question such as:

```text
"what is headroom in the budget I am currently using?"
```

This `selected` field is experiment-local query/config scaffolding. It is deliberately not placed on household facts and does not propose a canonical role.

The fixed selections include:

```text
UsePension:
  visible = Pension + Month + Half
  selected = Pension

UseMonth:
  visible = Pension + Month + Half
  selected = Month

UsePensionMinimal:
  visible = Pension only
  selected = Pension
```

Thus the same visible set can answer a different operating question when selection changes, while adding unselected views need not change the selected answer.

## Qualification targets

Expected witnesses:

```text
overlappingViewsReuseSameEvidence                         SAT
sameVisibleViewsDifferentSelectionDifferentOperatingAnswer SAT
extraUnselectedViewsDoNotChangeSelectedAnswer             SAT
equalSelectedDefinitionDifferentIdentitySameAnswer        SAT
```

Expected counterexamples to deliberately too-strong assumptions:

```text
SummingOverlappingViewConsumptionEqualsUnion              SAT counterexample
SummingOverlappingViewCommitmentEqualsUnion               SAT counterexample
VisibleViewSetDeterminesOperatingHeadroom                  SAT counterexample
```

Expected no counterexample for the smaller candidate:

```text
SelectedViewDefinitionDeterminesOperatingHeadroom         UNSAT counterexample
```

## Interpretation if qualified

The useful candidate would be:

```text
same household evidence
  -> pension projection
  -> monthly projection
  -> six-month projection

views may coexist
views are not an additive partition when ranges overlap

when one operating answer is requested:
  selected DateRange + Capacity definition
      -> selected answer
```

This would not mean only one view is "real" or that longer views must be forecasts. Each view can be a valid answer to its own temporal question. It would mean only that the set of visible projections does not itself create one larger pool of Capacity.

If the selected query context is sufficient, canonical role families such as:

```text
OperatingBudget
ForecastBudget
PlanningBudget
```

would remain unearned for this question. Friendly labels may stay application configuration.

## What would count as failure?

The small candidate should be rejected if fixing the selected view's information-equivalent DateRange and Capacity still leaves different selected Consumption / Commitment / Headroom answers.

Likewise, if merely adding an unselected view changes the selected answer, then projections are not independent enough for this design.

## Boundaries

Observation 133 does not establish:

- a production Dashboard or selected-budget type;
- that every household must have exactly one operating window;
- that a six-month view is necessarily forecast-only;
- a formula language or formula persistence;
- cross-window Capacity composition laws;
- historical selector provenance;
- Backing interaction across overlapping windows;
- UI layout, persistence, or canonical household-data changes.

In particular, this observation asks whether multiple projections can coexist safely. It does not assert that Capacity values from arbitrary formulas are additive across disjoint or overlapping ranges.
