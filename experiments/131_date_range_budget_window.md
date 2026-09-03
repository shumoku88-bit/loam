# Observation 131 — Can budget cycles collapse into DateRange query windows?

## Question

The practical budget discussion has reached a pressure that is directly visible to different households:

- one person budgets by calendar month;
- another budgets between pension / salary boundaries;
- another wants a six-month view;
- the same person may want several overlapping views at once;
- Scheduled evidence may extend far beyond the currently selected budget horizon.

A tempting compact design is:

```text
Cycle object
    -> remove

selected budget focus
    -> ordinary half-open DateRange [start, end)
```

Then the same canonical Actual / Scheduled evidence can be projected through any selected range without being copied or assigned to one privileged cycle identity.

Observation 131 asks how far that compression actually goes.

## Existing pressure

`HOUSEHOLD_MINIMUM_VOCABULARY.md` already keeps `Cycle`, reports, monthly views, and other presentation surfaces out of canonical state by default. Its temporal mechanics list includes selected day / interval separately from cycle or report focus.

The current practical `CapacityMovement` also has no built-in date or Cycle field. Capacity is independent allocation authority.

That suggests two different questions must not be collapsed:

```text
Which Actual / Scheduled facts are inside this time window?
    -> DateRange selection

How much authority exists for this selected budget view?
    -> Capacity authority
```

So this observation deliberately tests both a useful compression and a deliberately too-strong version of it.

## Bounded specimen

The model retains one set of time-stamped household facts:

```text
Actual
  day 1: quantity 2
  day 4: quantity 1

Scheduled
  day 2: quantity 3
  day 4: quantity 5
  day 5: quantity 7
```

Query contexts use only half-open endpoints plus independent Capacity authority:

```text
Monthly                 [1,4)  Capacity 10
CustomSame              [1,4)  Capacity 10
SameRangeOtherCapacity  [1,4)  Capacity 12
Pension                 [0,5)  Capacity 20
HalfYear                [0,6)  Capacity 30
Next                    [4,6)  Capacity 15
```

The names are experiment labels only. No recurrence kind, `CycleId`, `MonthlyCycle`, `PensionCycle`, or `HalfYearCycle` relation participates in projection semantics.

## Projection

For a selected range:

```text
Consumption = Actual quantity with day in [start,end)
Commitment  = Scheduled quantity with day in [start,end)
Remaining   = Capacity - Consumption
Headroom    = Remaining - Commitment
```

This is intentionally small. It does not claim that every future budget view has exactly these fields.

## Pressure 1: selector identity versus resolved DateRange

`Monthly` and `CustomSame` are distinct query-context identities but resolve to the same endpoints and the same Capacity authority.

Expected result:

```text
different selector/context identity
+ same DateRange
+ same Capacity authority
    -> same selected projection
```

If that holds, the selected answer does not need a canonical Cycle identity in this specimen.

## Pressure 2: overlapping views without copying facts

`ScheduledEarly` at day 2 lies simultaneously in:

```text
Monthly   [1,4)
Pension   [0,5)
HalfYear  [0,6)
```

It remains one Scheduled fact. Membership is a query result, not retained ownership by one cycle.

This directly supports a user viewing the same household evidence through multiple concurrent horizons.

## Pressure 3: half-open boundary

The day-4 Actual and Scheduled facts are excluded from:

```text
Monthly [1,4)
```

and included in:

```text
Next [4,6)
```

so adjacent ranges should not double count the boundary.

## Pressure 4: DateRange is not Capacity authority

`Monthly` and `SameRangeOtherCapacity` have exactly the same `[1,4)` endpoints and therefore select exactly the same Actual / Scheduled evidence.

But Capacity differs:

```text
10 versus 12
```

so Remaining and Headroom differ.

The deliberately too-strong claim is therefore:

```text
DateRange alone
    -> full budget answer
```

Observation 131 expects Alloy to reject that claim.

This would not restore a Cycle object. It would establish a smaller separation:

```text
DateRange selection
    !=
Capacity authority
```

## Qualification targets

Expected witnesses:

```text
differentLabelsCollapseToSameRangeProjection          SAT
selectedScheduledChangesWithRange                      SAT
boundaryBelongsToNextNotMonthly                        SAT
sameFactAppearsInOverlappingWindowsWithoutCopy         SAT
sameRangeDifferentCapacityChangesBudgetAnswer          SAT
```

Expected no counterexample:

```text
DateRangeDeterminesTemporalSelection                    UNSAT counterexample
HalfOpenAdjacentWindowsDoNotDoubleCount                 UNSAT counterexample
DateRangePlusCapacityDeterminesBudgetProjection         UNSAT counterexample
```

Expected counterexample to the aggressive compression:

```text
DateRangeAloneDeterminesFullBudgetProjection            SAT counterexample
```

## Interpretation if qualified

The useful compression would be:

```text
Monthly / pension / half-year / custom selector
    -> resolves to [start,end)

[start,end)
+ canonical temporal evidence
    -> temporal inclusion

[start,end)
+ independent Capacity authority
+ included Actual / Scheduled
    -> selected budget projection
```

So a household may have several simultaneous views without canonical facts being copied into several cycle containers.

A future UI may still expose friendly selector names such as `month`, `pension period`, or `six months`. Those names can remain range-generating application policy rather than canonical budget objects if later observations do not find missing information.

## Boundaries

Observation 131 does not establish:

- a production DateRange type;
- a production window-selector policy;
- how recurring pension / salary dates are generated;
- time-varying Capacity semantics;
- how Capacity authority is attached to or selected for arbitrary ranges;
- daily pace arithmetic;
- Backing policy over multiple windows;
- historical policy provenance;
- recurrence generation;
- persistence, CLI, TUI, or canonical household-data changes.

The question is only whether selected temporal membership and the bounded budget projection need a canonical Cycle identity once range endpoints and independent Capacity authority are explicit.
