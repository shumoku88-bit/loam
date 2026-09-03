# Observation 134 — When may DateRange Capacity formulas compose?

## Question

Observations 131–133 left a small budget-view candidate:

```text
selector -> DateRange [start,end)
DateRange + Capacity formula -> base Capacity
base Capacity + retained Capacity movements -> final Capacity
```

Several overlapping views may coexist over one retained evidence set, but their projected totals are not generally additive.

The next practical question is narrower:

> When two DateRanges are adjacent, may their formula-generated Capacity values be added to recover the Capacity of the combined DateRange?

This matters if a household wants to compare or combine monthly, pension-period, half-year, or custom views without introducing separate budget-cycle object families.

The hypothesis is deliberately not that every policy composes. Instead, composition may be an algebraic property of the selected formula definition itself.

## Bounded formula scaffold

The model reuses Observation 132's small affine specimen:

```text
capacity(purpose, range)
  = base(purpose)
  + perDay(purpose) * duration(range)
```

This is experiment scaffolding, not a universal user formula language.

Two formula shapes are compared.

### Pure rate

```text
Food   = 3 * days
Travel = 1 * days
```

with zero per-window intercept.

### Fixed per selected window

```text
Food   = 10
Travel = 4
```

with no duration term.

An identity-distinct `RateFormulaCopy` has exactly the same definition as `RateFormula`.

## DateRanges

Adjacent partition:

```text
Left   [0,2)
Right  [2,5)
Union  [0,5)
```

Overlapping pair:

```text
OverlapLeft [0,3)
Right       [2,5)
Union       [0,5)
```

The overlap pair intentionally shares `[2,3)`.

## Expected observations

For the pure rate formula:

```text
Left  + Right
  = 2 days + 3 days
  = 5 days
  = Union
```

so adjacent composition should succeed.

For the fixed-per-window formula:

```text
Food Left   = 10
Food Right  = 10
Food Union  = 10
```

so `Left + Right = Union` should fail because splitting the range repeats the per-window intercept.

Even the additive pure-rate formula should not be naively added across overlapping views, because the shared day is counted twice.

## Qualification targets

Expected witnesses:

```text
pureRateAdjacentRangesCompose                           SAT
fixedPerWindowAdjacentRangesDoNotCompose                SAT
overlappingRateViewsAreNotAdditive                      SAT
equalDefinitionDifferentIdentitySameCompositionAnswer   SAT
```

Expected counterexamples to deliberately too-strong assumptions:

```text
SameFormulaAdjacentRangesAlwaysCompose                  SAT counterexample
ZeroInterceptOverlappingRangesComposeByAddition         SAT counterexample
```

Expected no counterexample for the smaller bounded law:

```text
ZeroInterceptAdjacentRangesCompose                      UNSAT counterexample
AdjacentAdditivityCharacterizedByZeroIntercept          UNSAT counterexample
EqualDefinitionDeterminesSelectedCapacity               UNSAT counterexample
```

## Interpretation if qualified

The useful boundary would be:

```text
same formula + adjacent DateRanges
    does not imply
additive Capacity composition

formula definition
+ range relation
    may determine
whether naive addition is valid
```

For this affine scaffold specifically:

```text
base = 0
    -> adjacent partition additivity

base > 0
    -> splitting repeats per-window authority
```

This would mean LOAM need not immediately introduce canonical kinds such as:

```text
ComposableBudgetPolicy
NonComposableBudgetPolicy
MonthlyBudget
PensionBudget
```

The application may instead inspect or know the law of the selected formula definition. Friendly policy names can remain configuration.

It would also preserve Observation 133's warning: even an additive formula cannot be naively summed across overlapping DateRanges.

## What would count as failure?

The small candidate should be rejected if a zero-intercept affine formula over adjacent half-open ranges can produce a bounded counterexample to additivity.

Likewise, if equal formula definitions under equal ranges can produce different Capacity answers, formula identity or additional authority would remain observable.

## Boundaries

Observation 134 does not establish:

- a universal formula language;
- that all useful household policies are affine;
- how user-defined formulas declare or prove algebraic laws;
- composition of retained Capacity adjustments;
- composition across gaps, recurrence boundaries, changing formulas, or changing policy definitions;
- historical policy provenance;
- Backing interaction;
- persistence, CLI, TUI, or canonical household-data changes.

The question is only whether formula composition can remain a property of DateRange relation plus formula definition, rather than earning a new budget-cycle or budget-role object family.
