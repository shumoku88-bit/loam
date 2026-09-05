# Observation 191 — observational quotient factorization

Observations 159, 179, and 180 left a conspicuous sequence:

```text
Observation 159
  selected additive observations
    -> candidate quotient / vector equivalence

Observation 179
  observations
    <-> preservation polarity <->
  preserving transforms

Observation 180
  double polarity
    -> observational closure
```

The question here is whether these are only neighboring applications of familiar mathematics, or whether one smaller structure explains why they appeared together.

## Generic observation system

Take only:

```text
Evidence E
Observable O
Value(o) for each o : O
observe(o) : E -> Value(o)
```

A selected observation family `A` induces indistinguishability:

```text
x ~A y
iff
for every o in A,
observe(o, x) = observe(o, y)
```

Lean proves this relation reflexive, symmetric, and transitive without requiring any additive structure.

For an evidence endomap `t : E -> E`, define:

```text
t preserves o
iff
for every x,
observe(o, x) = observe(o, t(x))
```

The usual preservation polarity follows immediately:

```text
T subset Preservers(A)
iff
A subset Invariants(T)
```

This recovers the abstract content of Observation 179 without assuming invertibility or a symmetry group.

## The bridge

Observation 180 defined closure using **all retained-evidence endomaps** that preserve the starting observations.

That all-endomap quantification is enough to prove a stronger characterization:

```text
target in Closure(A)
iff
target is constant on every ~A equivalence class
```

Equivalently:

```text
Closure(A)
=
observations that factor through the observational quotient E / ~A
```

The forward direction uses a deliberately tiny witness endomap. If `x ~A y`, redirect exactly `x` to `y` and fix every other evidence value. This endomap preserves every observation in `A`. Therefore any observation in `Closure(A)` must agree on `x` and `y`.

The reverse direction is direct: any `A`-preserving endomap moves each evidence value only within its `~A` class, so every observation constant on those classes is preserved.

No production quotient type is introduced. “Factors through the quotient” is stated extensionally as constancy on equivalence classes.

## Specialization to LOAM

The Observation-180 additive basis is:

```text
walletQuantity
foodQuantity
```

Observation 191 proves that indistinguishability under exactly those two observations is equivalent to Observation 159's `VectorEquivalent` relation.

Therefore, for every Observation-180 target observation:

```text
Closure(AdditiveBasis, target)
iff
for all left right,
VectorEquivalent(left, right)
  -> observe(target, left) = observe(target, right)
```

This is the missing direct bridge between the earlier quotient and closure observations.

### Derived total

`totalQuantity` respects `VectorEquivalent`, because wallet and food coordinate quantities each agree. Its Observation-180 closure membership is therefore recovered as quotient factorization.

### Retained representation length

Observation 159 already supplied two vector-equivalent retained presentations with different lengths:

```text
compact
  wallet -100
  food   +100

split
  food   +100
  wallet  -40
  wallet  -60
```

So `representationLength` does not factor through the additive quotient and therefore is not in the additive closure.

This recovers Observation 180's negative result directly from Observation 159's witness. The normalization endomap from Observation 179 remains a useful concrete preserver witness, but is no longer required to explain the closure boundary.

## Current structural picture

The smallest common reading now is:

```text
retained evidence E
    -> selected observation family A
    -> observational equivalence E / ~A

A
    <---- preservation polarity ---->
class-preserving evidence endomaps

Closure(A)
    = observations constant on ~A classes
    = observations factoring through E / ~A
```

The free-Abelian structure is not the generic theory. It identifies one especially concrete LOAM quotient: Observation 159's additive image.

## Important qualification

The exact closure/factorization equivalence depends on Observation 180's use of **all** evidence endomaps.

If the admissible transformation family is restricted, the generic preservation polarity still exists, but the exact quotient-factorization characterization need not follow. In particular, this observation does not say that production correction, routing, temporal authority, relation authority, publication, recommendation, or human decision policy are arbitrary endomaps of canonical evidence.

Likewise, equal additive image still does not authorize quotient-collapsing retained Event / Effect identity or provenance.

## Novelty boundary

This observation does **not** claim a new mathematical theorem.

The generic result is a familiar quotient/factorization/invariant closure shape. What LOAM has earned is narrower and currently more interesting as a research clue:

- the additive quotient appeared from practical Movement projection pressure;
- the preservation polarity appeared from asking which retained-evidence changes remain invisible;
- the closure appeared from asking which observations are already forced;
- those three independently motivated observations now reduce to one common structure.

A later publication claim would require careful literature comparison and preferably at least one non-household instance showing that the same evidence/observation boundary is useful beyond this LOAM field trial.

## Boundary

No production Core, Application, Persistence, CLI, TUI, manifest/publication stack, household data, Mathlib dependency, quotient representation, generic production framework, or migration contract changes.
