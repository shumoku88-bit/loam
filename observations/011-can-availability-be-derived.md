# Observation 011: Can Availability Be Derived?

## Question

After Observation 010 exposed repeated use under a purpose boundary, the next missing concept was availability.

This observation asks whether availability must be independent stored state, or whether it can be derived from an initial resource observation and consumptive use history.

## Deliberate isolation

`Purpose` is absent here.

Observation 010 already isolated the purpose boundary. Observation 011 studies only the lifetime of a finite resource unit:

- `Origin.initial`: units available at the beginning;
- `Use`: a unit used at a time;
- `Stored.available`: a deliberately redundant stored observation;
- `derivedAvailable[t]`: initial units minus units used before `t`.

No later arrival, creation, refund, or restoration exists in this model.

## Alloy result

Alloy 6.2.0 + Sat4j produced the expected four results:

```text
phantomLossUnderWeakRules                 SAT
ExactStoredEqualsDerived                  UNSAT
derivedConsumptiveWorld                   SAT
DerivedAvailabilityForbidsRepeatedUse     UNSAT
```

### Weak stored state can invent loss

The SAT witness begins with:

```text
Origin.initial = {Unit1, Unit2}
```

`Unit2` is stored as available at `Time1`, then absent at `Time2`, even though no `Use` of `Unit2` explains that transition.

So monotonic stored availability plus a use guard is not enough. It admits **phantom depletion**: state can change without a corresponding observation in the history.

### Exact evolution collapses the extra freedom

The stronger law is:

```text
available(next t) = available(t) - usedAt(t)
```

Within the checked scope, Alloy found no counterexample to:

```text
Stored.available[t] = derivedAvailable[t]
```

where `derivedAvailable[t]` is computed only from `Origin.initial` and earlier `Use`s.

### Derived availability closes Observation 010's repeated-use hole

A nontrivial consumptive world exists using only the derived observation.

At the same time, Alloy found no counterexample in the checked scope to the claim that a unit cannot be used at two different times when every `Use` must see the unit as derived-available beforehand.

## Lean 4 law

The bounded Alloy finding produced a general law worth keeping.

`Loam.Observation011` defines availability as a predicate over arbitrary resource-unit types and defines one-step consumption plus finite-history evolution.

Lean proves:

1. `exactEvolutionUnique`: any stored trace with the same initial observation and exact one-use evolution law equals the derived trace for every finite history;
2. `exactStoresAgree`: two separately stored traces obeying that law cannot disagree;
3. `consumedUnitUnavailable`: immediately after a unit enters the use history, it is unavailable in the derived observation.

CI uses Lean 4.33.1, builds the project, runs the bundled `leanchecker`, and runs `axiom-audit`. The executed run audited 78 declarations under `Loam` with no axioms outside the configured allowlist.

## Finding

For this closed consumptive world:

```text
availability
  = projection(initial resources, use history)
```

An independently stored availability relation is either:

- too weak, in which case it can invent state changes such as phantom depletion; or
- constrained by exact evolution, in which case Lean shows it is uniquely determined by the same history and therefore adds no semantic freedom.

This suggests that **availability is a projection here, not a new source of truth**.

## Boundary

This is not yet a household-wide law.

The model deliberately excludes later resource arrival, creation, refund, restoration, expiration, partial consumption, and quantities greater than one unit. Once any of those enter the vocabulary, the derivation must include the corresponding observations.

It also does not yet establish that `Envelope` has emerged. What has emerged so far is:

```text
Purpose boundary
+ derived resource lifetime
```

Whether that combination is sufficient for envelope-like behavior remains open.
