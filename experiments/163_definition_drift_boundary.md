# Observation 163 — definition drift boundary

## Question

Observation 162 checks whether an implementation theorem inhabits a separately
named reviewed proposition. Does that layer also detect a semantic change when
the reviewed proposition and implementation both depend on the same changed
definition?

## Field trial

Keep Observation 159 and Observation 162 unchanged. Add a separate finite
witness with two candidate equivalence meanings:

- **StrictMeaning** uses Observation 159 `VectorEquivalent`, so every coordinate
  aggregate must agree.
- **DriftedMeaning** keeps only equality of total augmentation.

The witness has zero total augmentation on both sides but different wallet and
food quantities. Lean proves both facts:

1. `DriftedMeaning` accepts the witness.
2. `StrictMeaning` rejects the same witness.

Then model a hypothetical coupled edit by letting both a reviewed contract and
its implementation use `DriftedMeaning`. Their statement-alignment theorem still
builds.

## Result

The Observation 161/162 contract pattern protects the edge between a reviewed
`Prop` and an implementation theorem. It does **not** independently pin the
meaning of declarations shared by both sides.

This is a real definition-drift boundary, not a failure of Lean proof checking.
The proof is correct for the proposition it receives; the weakness is that the
trusted and untrusted sides still share semantic dependencies.

## Why this matters

A future independent statement surface can address this pressure by separating
the reviewed specification from implementation declarations and comparing the
transitive statement dependencies, as tools such as Lean Comparator do.

This observation does not introduce Comparator, Nanoda, a generic contract
framework, or a new production abstraction. It only establishes the concrete
failure mode that could justify such machinery later.

## Stop condition

Do not add another verification tool merely because this observation succeeds.
The next experiment should first test the smallest independent statement surface
that prevents this exact coupled-drift witness from remaining green.
