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

A household may still want several views at once, such as a pension period, a monthly view, and a six-month view. These windows can overlap heavily and reuse the same Actual / Scheduled evidence.

The question is:

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

`ActualShared` and `ScheduledShared` belong simultaneously to the pension, month, and half-year views without being copied.

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

The selected bounded answers are:

```text
UsePension Food headroom = 13
UseMonth   Food headroom = 3
```

Adding unselected views does not change the Pension-selected answer.

## Executed result

Alloy 6.2.0 + Sat4j:

```text
overlappingViewsReuseSameEvidence                         SAT
sameVisibleViewsDifferentSelectionDifferentOperatingAnswer SAT
extraUnselectedViewsDoNotChangeSelectedAnswer             SAT
equalSelectedDefinitionDifferentIdentitySameAnswer        SAT

SummingOverlappingViewConsumptionEqualsUnion              SAT counterexample
SummingOverlappingViewCommitmentEqualsUnion               SAT counterexample
VisibleViewSetDeterminesOperatingHeadroom                  SAT counterexample
SelectedViewDefinitionDeterminesOperatingHeadroom         UNSAT counterexample
```

The shared day-2 Actual has quantity 3. Both Pension and Month views independently report that quantity. Adding those two projection totals counts 6, while the union of the retained Actual facts still contains only quantity 3. The same issue appears for the shared Scheduled quantity 4.

So:

```text
overlapping projections
    are not
an additive partition of household evidence
```

## Finding

Multiple overlapping views can coexist over one retained evidence set:

```text
same household evidence
  -> pension projection
  -> monthly projection
  -> six-month projection
```

No source fact needs to be copied into a cycle container or view-specific ledger.

But the visible view set does not determine one scalar operating answer. Two dashboards with exactly the same visible Pension / Month / Half views produce different Food headroom solely because one selects Pension and the other selects Month.

Therefore:

```text
visible views alone
    do not determine
selected operating answer
```

The smaller candidate survives the bounded check:

```text
selected DateRange endpoints
+ selected Capacity definition
+ retained Actual / Scheduled evidence
    -> selected Consumption / Commitment / Remaining / Headroom
```

An identity-distinct copy of the selected Pension view with equal endpoints and Capacity gives the same selected answer. Merely adding unselected views also leaves the selected answer unchanged.

So the qualified boundary is:

```text
many overlapping budget views                 allowed
copying canonical evidence per view            unnecessary
adding overlapping projection totals           invalid in general
selected operating context                     independently required for a scalar operating query
canonical OperatingBudget / ForecastBudget     not earned
canonical budget-role identity                  not earned
```

This does not mean only one view is real, and it does not classify longer windows as forecast-only. Each view remains a valid answer to its own temporal question. Selection matters only when the application asks one operating question rather than displaying several answers side by side.

A selected view can therefore remain query/application configuration in this bounded question, analogous to other replaceable views, rather than becoming new household truth.

## Qualification

- executable-model head `6f7dbdfdb07133c6ed3ad6bbeec93754c3f1825b` — Observation 133 SUCCESS on the PR merge ref against current `main` (`093cff1fbb6cb40362c6e7ceb1f622edd4158001`)
- solver execution and expected-result checker both SUCCESS
- this result note is followed by an exact-final-head rerun before qualification is considered complete

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

In particular, this observation does not assert that Capacity values from arbitrary formulas are additive across disjoint or overlapping ranges. That composition law remains a separate question.
