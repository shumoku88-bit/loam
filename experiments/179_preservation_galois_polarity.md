# Observation 179 — preservation polarity beyond the free-Abelian image

Observation 159 established a deliberately narrow algebraic boundary:

```text
retained finite MovementChange presentation
    -> coordinate-wise additive image
    -> free-Abelian-style vector
```

with `BalancedMovement` lying in the zero-augmentation part of that image.
It also refused to quotient retained identity/provenance merely because two
presentations share the same additive vector.

This observation asks the next question:

> Do the transformations that preserve LOAM's additive observations naturally
> form a group of symmetries, and does a Galois-style relation appear between
> transformations and observables?

## Concrete normalization witness

For Observation 159's finite coordinate type `{wallet, food}`, define

```text
normalize(presentation)
  = [wallet aggregate, food aggregate]
```

The Lean witness proves that `normalize` preserves every coordinate quantity,
so every presentation is `VectorEquivalent` to its normalized form.

But the two already-qualified Observation 159 representatives

```text
compact: wallet -100, food +100
split:   food +100, wallet -40, wallet -60
```

normalize to the same retained list while remaining different presentations.
Therefore `normalize` is not injective and has no two-sided inverse.

This matters because splitting/merging pressure is one of the most natural
ways the free-Abelian quotient appeared. The corresponding practical
projection-preserving operation is therefore **not automatically a group
symmetry**.

The strongest justified reading is weaker:

```text
projection-preserving endomorphisms
```

may exist without invertibility.

So Observation 159 does not currently earn a classical Galois group acting on
canonical LOAM evidence.

## Observable/preserver boundary

The executable observation distinguishes three observations:

```text
wallet quantity
food quantity
retained presentation length
```

and two transformations:

```text
identity
normalize
```

`normalize` preserves both additive observations but not retained presentation
length.

For this finite witness plane, the Lean proof also shows:

```text
VectorEquivalent(left, right)
iff
wallet quantities agree
and food quantities agree
```

so the additive observation family is exactly the Observation 159 quotient
surface in this model.

Adding representation length as an observable excludes `normalize` from the
preserver set. This gives the concrete reversal:

```text
more observations
    -> fewer admissible preserving transformations
```

## Preservation polarity

Let:

```text
PreserverOf(O, t)
```

mean that transformation `t` preserves every observation selected by `O`, and
let:

```text
InvariantUnder(T, o)
```

mean that observation `o` is preserved by every transformation selected by
`T`.

The Lean observation proves:

```text
T subset Preservers(O)
iff
O subset Invariants(T)
```

This is the standard order-reversing polarity, equivalently an antitone Galois
connection between powersets induced by the binary preservation relation.
It also proves both antitone directions explicitly:

- adding observations cannot add preserving transformations;
- adding transformations cannot add invariant observations.

The abstract polarity theorem itself is structurally generic once a
`Preserves` relation is chosen. The domain-specific content is that LOAM has a
natural nontrivial instance:

- additive quantity observations admit `normalize`;
- retained representation observation excludes it;
- `normalize` is nevertheless non-invertible.

## Result

Observation 179 therefore separates two claims that initially looked similar:

```text
classical Galois-group reading
    not earned

Galois-connection / preservation-polarity reading
    genuinely present at the projection boundary
```

A useful current picture is:

```text
retained evidence
    -> choose observable family
    -> induced indistinguishability

observable family
    <---- preservation polarity ---->
projection-preserving transformations
```

Observation 159's free-Abelian image remains valid inside the additive
projection. Observation 179 adds that changing which observations LOAM regards
as visible changes which transformations are semantically admissible, in an
order-reversing way.

## What this does not claim

This observation does not claim:

- that LOAM canonical evidence is a field or field extension;
- that a classical Galois group exists;
- that every projection-preserving transformation is invertible;
- that `normalize` should become production code;
- that retained Event/Effect identity should be quotient-collapsed;
- that correction, routing, relation authority, or time are additive
  symmetries;
- that Core should gain a generic Galois or algebra framework.

In particular, correction and authority selection remain upstream of the
additive image exactly as Observation 159 recorded.

## Next pressure, if any

A later observation would be justified only if a practical LOAM feature needs
to compare observable families or preservation boundaries across semantic
planes.

Interesting future questions include:

- whether some natural *invertible* subset of projection preservers forms a
  useful group;
- whether correction/routing/time induce their own preservation relations
  rather than sharing the additive one;
- whether closure under `Preservers(Invariants(T))` or
  `Invariants(Preservers(O))` identifies a practical notion of observational
  completion;
- whether two UI/report surfaces can be compared by inclusion of observable
  families instead of duplicated ad-hoc equivalence laws.

## Stop condition

Do not introduce production group theory, order theory, quotient types, or a
Mathlib dependency from this observation alone.

The useful result is the boundary: classical group symmetry is too strong for
natural additive normalization, while an observable/preserver Galois polarity
is already available and accurately describes what information a projection
forgets or retains.
