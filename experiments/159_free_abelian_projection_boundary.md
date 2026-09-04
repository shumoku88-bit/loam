# Observation 159 — free Abelian projection boundary

LOAM already contains more algebra than its vocabulary advertises.

For one fixed `MeasureId` and coordinate type `C`, a finite list of signed
`MovementChange C` values can be interpreted as a finitely supported integer
vector

```text
C ->₀ Z
```

which is the usual free Abelian group on `C`.

The current Core does not store that canonical vector directly. It retains a
finite list presentation and provides coordinate-wise additive projection.
`BalancedMovement` additionally retains proof that the complete signed total is
zero.

This observation asks a deliberately smaller question than "should LOAM be
rewritten using group theory?":

> Does the existing practical movement algebra already factor through a
> free-Abelian-style coordinate-vector equivalence, and where must LOAM refuse
> to quotient retained evidence?

## Existing correspondence

For fixed coordinate type `C`:

```text
MovementChange C list
    -> aggregate equal coordinates
    -> finite vector in Z^(C)
```

The map sending a vector to the sum of all coefficients is the augmentation
map

```text
ε : Z^(C) -> Z
```

Today's `BalancedMovement` admission law is exactly the represented-list form
of

```text
ε(v) = 0
```

so its additive meaning sits in the kernel of augmentation.

This is a **subgroup/kernel** observation first, not a quotient observation.

The quotient candidate appears one layer earlier: different list presentations
may represent the same coordinate vector. Permutation, splitting one coordinate
coefficient into several entries, or merging such entries need not change any
coordinate projection.

## Executable witness

`Loam.Observations.Observation159` constructs two different presentations:

```text
compact
  wallet -100
  food   +100

split
  food   +100
  wallet  -40
  wallet  -60
```

They have different list shape but:

- every coordinate projects to the same exact quantity;
- both totals are exactly zero;
- both are admitted by the existing `BalancedMovement` boundary;
- existing `BalancedMovement.quantityAt` cannot distinguish them.

The observation defines `VectorEquivalent` as equality of every coordinate
projection and proves reflexive, symmetric, and transitive behavior. It then
proves that the practical `quantityAt` projection respects that relation.

This is the candidate quotient relation without committing production code to a
quotient representation or a Mathlib dependency.

## Why canonical Event evidence must not be quotient-collapsed

The same algebraic reading does **not** imply that raw LOAM evidence should be
identified whenever its quantity vector agrees.

`Event` deliberately retains:

```text
EventId
EffectKey
original Effect collection
```

while `Event.quantityAt` is only a read-only aggregate projection. Distinct
Effects may share the same `(LocusId, MeasureId)` coordinate and contribute
additively without becoming the same retained Effect.

Therefore two Events can have the same additive image while still carrying
different identity/provenance evidence. Quotienting canonical Event evidence by
its additive image would erase information that LOAM already treats as
observable.

## Correction is not additive inverse

`EventCorrection` is also outside the proposed additive quotient.

The current application semantics derive an admitted correction frontier from
explicit target/replacement paths and then remove superseded Event identities
before quantity projection.

That is not the same operation as adding `-event` to an Abelian group:

- correction provenance remains explicit;
- branching or merging shapes fail closed rather than algebraically cancelling;
- terminal replacement identity remains observable;
- the quantity image is computed only after relation authority selects the
  effective frontier.

So a useful decomposition is:

```text
canonical evidence / relation authority
    -> select or relabel effective evidence
    -> additive coordinate vector
    -> household projection
```

not:

```text
canonical evidence
    -> quotient everything by equal quantity result
```

## Capacity fits especially cleanly

`CapacityMovement` already reuses `BalancedMovement` under the distinct
`CapacityCoordinate` type. This is almost exactly the algebraic separation one
would want:

```text
physical Actual vector   over LocusId
capacity-authority vector over CapacityCoordinate
```

The arithmetic can share one additive law while the coordinate types prevent
semantic planes from collapsing.

## Budget Remaining reading

The current practical budget-window path computes:

```text
Remaining = Entitlement - Consumption
```

where both sides are exact coordinate sums after their own authority and time
selection.

For a *fixed* correction frontier, routing history, purpose, measure, and
half-open time window, that final arithmetic is group-like and can be viewed as
a homomorphic coordinate calculation.

But correction, routing, and temporal authority are not thereby reduced to
group equations. They determine which evidence enters the additive image.

## Result

Observation 159 supports this narrower algebraic picture:

```text
retained evidence
    richer than
finite additive image
    richer than
one report coordinate
```

and, for one movement plane,

```text
finite presentation
    -- quotient by equal coordinate totals -->
free-Abelian-style vector Z^(C)

BalancedMovement image
    = zero-augmentation part of that vector space-like group
```

The practical lesson is not to introduce `FreeAbelianGroup` into Core now.
The useful result is the boundary:

- additive projections may be reasoned about as free-Abelian images;
- balanced movement corresponds to an augmentation kernel;
- projection-specific quotient reasoning is legitimate;
- canonical identity, relation provenance, semantic plane, and time authority
  must remain outside that quotient unless a separate observation proves they
  are unobservable.

## Stop condition

Do not refactor `Quantity`, `Event`, `BalancedMovement`, `CapacityMovement`, or
persistence merely to make the implementation resemble textbook algebra.

A production algebraic abstraction is earned only if a later practical change
would otherwise duplicate laws, proofs, or projection machinery, and the new
abstraction preserves the existing evidence/projection boundary rather than
compressing provenance away.
