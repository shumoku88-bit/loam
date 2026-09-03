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

## Qualified Alloy result

Alloy 6.2.0 + Sat4j:

```text
pureRateAdjacentRangesCompose                           SAT
fixedPerWindowAdjacentRangesDoNotCompose                SAT
overlappingRateViewsAreNotAdditive                      SAT
equalDefinitionDifferentIdentitySameCompositionAnswer   SAT

SameFormulaAdjacentRangesAlwaysCompose                  SAT counterexample
ZeroInterceptAdjacentRangesCompose                      UNSAT counterexample
AdjacentAdditivityCharacterizedByZeroIntercept          UNSAT counterexample
ZeroInterceptOverlappingRangesComposeByAddition         SAT counterexample
EqualDefinitionDeterminesSelectedCapacity               UNSAT counterexample
```

The counterexample to `SameFormulaAdjacentRangesAlwaysCompose` selects `FixedFormula`: the same formula is applied to both adjacent subranges and their union, but the per-window intercept is repeated when the subranges are added.

The overlapping-range counterexample remains even for the pure-rate formula because the shared interval `[2,3)` is counted twice.

## Finding

Adjacency alone is not enough:

```text
same formula
+ adjacent DateRanges
    does not imply
additive Capacity composition
```

But in this bounded non-negative affine scaffold, the composition law is recoverable from the formula definition itself:

```text
base = 0
    <->
adjacent partition additivity
```

For example:

```text
RateFormula Food
  [0,2) = 6
  [2,5) = 9
  [0,5) = 15

6 + 9 = 15
```

while:

```text
FixedFormula Food
  [0,2) = 10
  [2,5) = 10
  [0,5) = 10

10 + 10 != 10
```

So the qualified small boundary is:

```text
DateRange relation
+ formula definition
    -> whether this bounded formula composes by naive addition
```

A separate canonical `ComposableBudgetPolicy` / `NonComposableBudgetPolicy` identity is not earned by this specimen. An identity-distinct formula with the same definition also gives the same selected Capacity answer.

Observation 133's warning remains essential: even a formula that composes over an adjacent partition cannot be naively summed over overlapping DateRanges.

## Practical interpretation

A household can therefore have friendly application policies such as:

```text
monthly
pension period
six months
custom
```

without assuming that the labels determine composition.

Instead, a policy definition may carry or admit a law such as:

```text
additive over adjacent partition
```

when that law is justified by the formula itself.

For the current affine specimen, no extra tag is needed because zero intercept characterizes the law. More expressive future formulas may need proof or metadata if the law cannot be derived mechanically from their definition.

## Qualification

- executable-model head `f12902011b43a5775478bf016719b8a7857780ad` — Observation 134 SUCCESS on the PR merge ref against `main` (`093cff1fbb6cb40362c6e7ceb1f622edd4158001`)
- solver execution and expected-result checker both SUCCESS
- result-note final head is qualified separately after this note update

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
