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

Qualified result:

```text
different selector/context identity
+ same DateRange
+ same Capacity authority
    -> same selected projection
```

So the selected answer does not need a canonical Cycle identity in this specimen.

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

The half-open adjacency check found no counterexample, so adjacent ranges do not double count the selected boundary facts in this bounded specimen.

## Pressure 4: DateRange is not Capacity authority

`Monthly` and `SameRangeOtherCapacity` have exactly the same `[1,4)` endpoints and therefore select exactly the same Actual / Scheduled evidence.

But Capacity differs:

```text
10 versus 12
```

so Remaining and Headroom differ.

Alloy found the expected counterexample to:

```text
DateRange alone
    -> full budget answer
```

This does not restore a Cycle object. It establishes the smaller separation:

```text
DateRange selection
    !=
Capacity authority
```

## Qualified Alloy result

Alloy 6.2.0 + Sat4j:

```text
differentLabelsCollapseToSameRangeProjection          SAT
selectedScheduledChangesWithRange                      SAT
boundaryBelongsToNextNotMonthly                        SAT
sameFactAppearsInOverlappingWindowsWithoutCopy         SAT
sameRangeDifferentCapacityChangesBudgetAnswer          SAT

DateRangeDeterminesTemporalSelection                   UNSAT counterexample
HalfOpenAdjacentWindowsDoNotDoubleCount                UNSAT counterexample
DateRangeAloneDeterminesFullBudgetProjection           SAT counterexample
DateRangePlusCapacityDeterminesBudgetProjection        UNSAT counterexample
```

The first executable head also exposed one model-only redundant inequality between two disjoint singleton signatures. That assertion was removed before final qualification; it carried no semantic information.

## Finding

The useful compression survives:

```text
Monthly / pension / half-year / custom selector
    -> resolves to [start,end)

[start,end)
+ canonical temporal evidence
    -> temporal inclusion
```

No canonical Cycle identity was needed for the selected Actual / Scheduled membership, overlapping views, or adjacent half-open boundary behavior.

For the selected budget projection, one more independent authority remains:

```text
[start,end)
+ Capacity authority
+ included Actual / Scheduled
    -> Consumption / Commitment / Remaining / Headroom
```

So the qualified boundary is:

```text
Cycle identity                  not earned
selector label                  not needed after range resolution
DateRange endpoints             sufficient for temporal membership
Capacity authority              independently required for budget answer
```

A household may therefore have several simultaneous views without canonical facts being copied into several cycle containers.

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
