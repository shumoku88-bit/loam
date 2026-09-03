# Observation 135 — How do timed Capacity adjustments interact with DateRange views?

## Question

Observations 131–134 left a small budget candidate:

```text
selector -> DateRange
DateRange + Capacity formula -> base Capacity
base Capacity + retained Capacity movements -> final Capacity
```

Observation 112 already established a separate historical pressure: untimed Capacity movements are too small for selected historical stock-validity questions, while movement endpoints plus effective day are sufficient for that bounded law.

The next practical question is different:

> If a Capacity reallocation becomes effective inside a longer operating budget period, can arbitrary subrange views be computed by looking only at adjustments whose effective day lies inside the visible DateRange, or does the application also need the DateRange that owns the Capacity authority?

This matters for a household that operates on a pension period but also wants monthly or half-year views.

## Bounded specimen

One fixed Capacity formula gives the selected authority range:

```text
Food   = 10
Travel = 4
```

The pension authority range is:

```text
Pension [0,4)
```

Two retained, balanced Capacity reallocations have effective days:

```text
day 1:
  Food   -2
  Travel +2

day 3:
  Food   +1
  Travel -1
```

The visible ranges are:

```text
First  [0,2)
Month  [2,3)
Second [2,4)
Whole  [0,4)
```

The important month specimen is evaluated in two different query contexts.

### Month as a view into the pension authority

```text
authority = Pension [0,4)
view      = Month   [2,3)
```

The day-1 reallocation occurred before the visible month, but it still changes the Capacity state that is in force during that month.

At the month end:

```text
Food   = 8
Travel = 6
```

The day-3 reallocation is excluded because the view is half-open and ends at day 3.

### Month as a freshly reset authority

```text
authority = Month [2,3)
view      = Month [2,3)
```

With the same formula definition and same retained adjustment evidence, the day-1 reallocation is outside this authority range and does not carry in:

```text
Food   = 10
Travel = 4
```

The two contexts therefore share the same visible DateRange while answering different authority questions.

## Candidate projection

For a selected query context, the bounded model computes Capacity at the view end as:

```text
generated Capacity over authority DateRange
+ adjustments with
    effectiveDay >= authority.start
    effectiveDay <  view.end
```

This treats Capacity allocation as state that persists after an effective reallocation, rather than as a flow that belongs only to the visible subrange.

A deliberately too-small alternative keeps only adjustments local to the visible range:

```text
generated Capacity over authority DateRange
+ adjustments with
    effectiveDay >= view.start
    effectiveDay <  view.end
```

The month specimen distinguishes the two.

## Executed result

Alloy 6.2.0 + Sat4j:

```text
preViewAdjustmentCarriesIntoSubview                      SAT
sameViewDifferentAuthorityDifferentAnswer                SAT
adjustmentAtViewEndIsExcluded                            SAT
laterSubviewIncludesBoundaryAdjustment                   SAT
equalDefinitionCopySameAnswer                            SAT

ViewRangeFormulaAndTimedAdjustmentsDetermineCapacityAtEnd SAT counterexample
OnlyViewLocalAdjustmentsDetermineCapacityAtEnd            SAT counterexample
AuthorityViewFormulaAndTimedAdjustmentsDetermineCapacityAtEnd UNSAT counterexample
AdjacentSubviewCapacitySnapshotsComposeByAddition         SAT counterexample
```

The PR merge-ref qualification used current `main` after PR #296 (`1672e83786b01c71f80d06bb56e03ffa29efe9c1`) and completed successfully with both Alloy execution and the expected-result checker passing.

## Finding

The visible range is not enough to identify the selected Capacity state.

The bounded month witness gives:

```text
same visible range [2,3)
same formula definition
same timed Capacity adjustments

authority = pension [0,4)
  -> Food 8 / Travel 6

authority = month [2,3)
  -> Food 10 / Travel 4
```

So the stronger compression is false:

```text
view DateRange
+ formula definition
+ timed Capacity adjustments
    do not determine
Capacity-at-view-end
```

Filtering only movements whose effective day lies inside the visible range is also too small. The day-1 `Food -2 / Travel +2` decision remains in force during `[2,3)` even though it is not local to that visible range.

The smaller bounded candidate survives:

```text
authority DateRange
+ view DateRange
+ formula definition
+ timed Capacity adjustments
    -> Capacity-at-view-end
```

No counterexample was found once the information-equivalent authority endpoints, view endpoints, formula definition, and timed adjustments were fixed.

The half-open boundary also behaves coherently: the day-3 adjustment is excluded from `[2,3)` and included in the later `[2,4)` view.

A second compression fails as well:

```text
Capacity snapshot over first subview
+ Capacity snapshot over second subview
    != in general
Capacity snapshot over whole range
```

Capacity reallocations are state changes that carry forward. The same earlier decision may therefore be visible in multiple later snapshots; those snapshots are not independent flow quantities to add.

## Product interpretation

This does not restore a canonical `Cycle` object.

Both roles can remain ordinary half-open DateRanges supplied by application/query context:

```text
ordinary pension operation:
  authority = current pension period
  view      = current pension period

monthly lens on the same pension budget:
  authority = current pension period
  view      = this month intersected with that period

independent monthly budget:
  authority = this month
  view      = this month
```

The distinction is therefore not necessarily a new household noun. It is a distinction between two questions asked with the same DateRange mechanics:

```text
which interval owns the Capacity authority?
which interval am I currently looking at?
```

Observation 112 already established that effective time is independently observable for selected Capacity-history questions. Observation 135 adds practical budget-view pressure for that same information distinction without choosing a production representation.

## Boundaries

Observation 135 does not establish:

- a production time field on `CapacityMovement`;
- a production temporal-evidence representation;
- a canonical AuthorityRange or ViewRange type;
- that every Capacity policy resets at an authority start;
- formula persistence or a formula language;
- recurrence or automatic pension-period generation;
- composition of separate authority periods;
- correction semantics for Capacity movements;
- Backing interaction;
- UI, CLI, persistence, or canonical household-data changes.

As in Observation 112, effective time is modeled as information-equivalent evidence. The experiment asks what information is required, not where that information must physically live in production.
