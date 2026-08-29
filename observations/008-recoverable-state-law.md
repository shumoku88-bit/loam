# Observation 008: Recoverable State Law

## Question

Observation 007 found several different retained-state coordinate systems that preserve the same future-visible distinctions:

```text
u0 + u1
u0 + count
u1 + count
```

Can that finite observation be lifted into a small general law rather than left as three successful examples?

## Lean boundary

`Sufficient History Summary Visible observe` means that a retained `Summary` can always decode the chosen future-visible observation:

```text
decode (encode history) = observe history
```

This deliberately says nothing about how a summary is stored, whether it is minimal, or whether it resembles the vocabulary it preserves.

## Proved laws

### 1. Summary collision is future-invisible

`Sufficient.equalSummaryInvisible` proves:

> If two histories encode to the same sufficient summary, then the chosen future-visible observation is equal for those histories.

So a sufficient state representation is allowed to forget history only along distinctions that the chosen future vocabulary cannot see.

### 2. Sufficiency transfers through recovery

`Sufficient.reencode` proves:

> If representation `B` can recover an already-sufficient representation `A` on every encoded history, then `B` is sufficient for the same future-visible observation.

This law is intentionally asymmetric. `B` does not need to be identical to `A`, minimal, or recoverable from `A`.

### 3. Mutual recovery preserves collision classes

`Sufficient.sameCollisionClasses` proves:

> If two encodings recover each other on the image of histories, they identify exactly the same pairs of histories.

This gives a precise limited meaning to calling two retained-state coordinate systems observationally equivalent at the history-collision level.

## Concrete bridge to Observation 007

The four history classes remain Boolean pairs `(u0Stayed, u1Stayed)`.

A finite `Count` has values:

```text
zero
one
two
```

Lean proves by exhaustive construction that:

```text
(u0Stayed, count) -> (u0Stayed, u1Stayed)
(u1Stayed, count) -> (u0Stayed, u1Stayed)
```

on every encoded history.

Therefore both `u0 + count` and `u1 + count` are obtained with the general `reencode` law from the direct pair representation. Lean also proves that each induces the same history-collision classes as the direct pair in this universe.

## Executed result

CI used:

- Lean 4 `v4.33.1`
- Lake 5.0.0 from that toolchain
- Lean core only, no Mathlib
- `leanprover/lean-action@v1`

The executed checks were:

```text
lake build        SUCCESS
leanchecker       SUCCESS
axiom-audit       SUCCESS
```

`axiom-audit` audited 68 declarations under `Loam`; every dependency was inside its standard allowlist (`propext`, `Classical.choice`, `Quot.sound`). The Observation 008 declarations introduce no admitted theorem or home-grown axiom.

## Finding

Observation 007 suggested that a future vocabulary does not determine one unique set of state fields.

Observation 008 sharpens that:

> Sufficiency belongs to a decoding relationship, not to a particular representation.

A state shape earns its role when it retains enough information to recover what the future vocabulary needs. Its field names and coordinates are secondary.

For two mutually recoverable encodings, even their history-collision partition is the same. They are different coordinates over the same retained distinctions.

## Boundary

This observation does **not** prove that:

- every sufficient representation is minimal,
- every pair of sufficient representations is mutually recoverable,
- one canonical state representation exists,
- the Boolean continuity vocabulary is appropriate for household finance,
- finite search in Observation 007 becomes arbitrary synthesis.

The general Lean theorem is about recovery and decoding. The concrete `u0 + count` / `u1 + count` examples remain the small bridge back to the finite loam experiment.

## Next question

If several different representations are sufficient, what chooses among them?

Possible criteria now include representation cost, update cost, locality, compositionality, and the number of future vocabularies preserved. This may be a place where J can return, not to prove sufficiency, but to compare the geometry and cost of equivalent coordinate systems.
