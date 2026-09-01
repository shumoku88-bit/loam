# Observation 085 — Is starting basis a property of a coordinate, or of the query?

## Question

Real daily-use dogfood exposed a new pressure immediately after the first corrected two-locus spending record.

A payment-shaped event can now retain two neutral quantity effects such as:

```text
payment locus   -q
use locus       +q
```

The existing anchored-current projection currently ranges over every represented Event coordinate plus every basis coordinate. It therefore asks for a starting basis at both coordinates before showing any current answer.

For a use-shaped coordinate this produced a strange but formally legal setup step:

```text
starting basis = 0
```

The question is not whether explicit zero differs from missing. Application 008 already made that distinction deliberately.

The new question is narrower:

> Must every query over a represented `Locus × Measure` coordinate require the same starting-basis premise, or can basis applicability depend on what projection is being asked?

## Model boundary

The Alloy model deliberately does **not** introduce `HoldingRole`, `UseRole`, Account, Expense Category, or AccountingRole.

Instead, it keeps:

```text
Coordinate = Locus × Measure
Event-derived effective quantity at Coordinate
optional starting basis at Coordinate
```

and introduces only two experiment-local query modes:

```text
AnchoredCurrent
  = basis + effective Event quantity

ActivityTotal
  = effective Event quantity only
```

The mode belongs to the query, not to the coordinate.

This matters because the same coordinate may support both readings when the relevant premises exist. The experiment is therefore not trying to prove that a `coffee`-like locus is intrinsically a use locus or that a `paypay`-like locus is intrinsically a holding locus.

## Dogfood pressure

The first bounded witness asks for two coordinates with equal-and-opposite Event quantity:

```text
source  -q
use     +q
```

The source has a starting basis. The use coordinate does not.

The model asks whether all of the following can hold simultaneously:

- an `AnchoredCurrent` query selects both coordinates;
- the source coordinate is answerable;
- the use coordinate is not answerable because its basis is missing;
- therefore the whole anchored-current query fails;
- an `ActivityTotal` query selecting the same use coordinate is still answerable.

Observed:

```text
dogfoodCurrentCanFailWhileActivityIsDefined  SAT
```

So missing basis can block one query vocabulary without making the Event-derived quantity itself unknowable.

## Same coordinate, two readings

The second witness asks whether one coordinate with a non-zero basis and non-zero Event quantity can support both query modes while producing different answers.

Observed:

```text
sameCoordinateSupportsBothReadings  SAT
```

This rejects a tempting shortcut:

```text
coordinate identity
    -> one intrinsic projection meaning
```

The coordinate alone does not choose whether a caller wants anchored current quantity or activity quantity.

## Explicit zero

The third witness compares two fact sets with identical Event-derived quantity:

```text
Missing: no basis at c
Zeroed:  explicit basis 0 at c
```

For an `ActivityTotal` query, both produce the same quantity because the basis is irrelevant to that query.

For an `AnchoredCurrent` query, the explicit zero changes answerability from unavailable to available while leaving the numeric result equal to the activity total.

Observed:

```text
explicitZeroEnablesCurrentWithoutChangingActivity  SAT
```

This is the exact shape of the dogfood discomfort: adding `0` may be a truthful explicit basis fact, but its main effect can be to satisfy a premise of one projection rather than to add new Event activity.

## Observed Alloy result

Alloy 6.2.0 + Sat4j produced the exact expected boundary:

```text
dogfoodCurrentCanFailWhileActivityIsDefined       SAT
sameCoordinateSupportsBothReadings                 SAT
explicitZeroEnablesCurrentWithoutChangingActivity SAT
AnchoredCurrentRequiresExplicitBasis               UNSAT counterexample
ActivityValueIgnoresBasis                          UNSAT counterexample
CoordinateDeterminesProjectionMode                 SAT counterexample
```

The first three commands provide witnesses. The next two checks find no counterexample to the model's definition-preservation laws. The final check intentionally finds a counterexample: two queries may select the same coordinate while asking different projection modes.

## Finding

The qualified boundary is:

```text
missing basis
    -> anchored-current unavailable

missing basis
    -/-> activity unavailable
```

and:

```text
basis fact
    !=
coordinate role
    !=
query mode
```

The current dogfood friction therefore should not be repaired by silently treating missing basis as zero.

It also should not be repaired by treating basis presence itself as a hidden classification of coordinates. A basis remains evidence for an anchored quantity; it does not automatically make a coordinate a holding, account, expense category, or any other domain noun.

The real-data `coffee = 0` step is therefore best understood as satisfying an `AnchoredCurrent` premise. It does **not** establish that the `coffee` coordinate intrinsically has holding semantics.

## What this observation does not yet decide

The result does not yet tell production exactly how to enumerate a future current view.

Possible later designs include:

- an explicit query selection surface;
- a separate activity view;
- an anchored-coordinate enrollment relation;
- a warning surface for Event coordinates not selected by an anchored view;
- another relation earned by further dogfood.

Those are deliberately not collapsed into this observation.

In particular, simply changing `current` to enumerate only coordinates that already have basis facts could hide a newly observed holding coordinate. That may be worse than the present fail-closed behavior.

## Tool choice

Alloy is sufficient here because the missing question is bounded relational independence and coexistence:

- can the same coordinate support two projection modes;
- can one mode be answerable while another is not;
- can explicit zero affect one query without affecting another.

No temporal transition order is involved, so TLA+ is unnecessary. No reusable unbounded arithmetic law is being claimed yet, so Lean would be premature.

## Practical Core impact

None at this checkpoint.

- no Core change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no `HoldingRole` / `UseRole` type;
- no Account or Expense Category primitive;
- no private household values committed.
