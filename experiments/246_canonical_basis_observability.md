# Experiment 246: canonical basis observability

Status: **research lab; no production or loam-data deletion authorized**

Tracking: #700
Baseline: `f22c666ab89b25991794d0b8e1de782302dedcf3`

## Question

Current LOAM has already begun reconstructing semantics from desired answers rather than current type boundaries. This experiment extends that discipline to canonical data:

> Which independently retained distinctions are required to determine an intended answer, and which distinctions are merely artifacts of the current representation?

File count is not the target variable. A single file may hold several independent meanings, and several files may implement one retained meaning safely.

The audit therefore keeps three counts separate:

```text
physical artifacts
semantic authorities
independently observable retained distinctions
```

Only the last count is a semantic-minimality question.

## Criterion

For a candidate retained distinction `F`, compare worlds `w1` and `w2` that differ only in `F`.

If every intended answer in the relevant observation set agrees,

```text
Q(w1) = Q(w2)
```

then `F` is not yet earned as independently retained information for that observation set.

If some intended answer differs, preserve the information. This does **not** preserve the current type, file, authority wrapper, or publication topology.

The relevant observation sets remain separate:

```text
Q_read
Q_write
Q_safe
```

A distinction may be invisible to reads while still being required for mutation admission or crash/recovery safety.

## First bounded model

`246_canonical_basis_observability.als` deliberately models only two pressures.

### Zero-origin coverage

Changing whether one coordinate has explicit zero-origin coverage changes the read answer describing which balances are answerable from zero. Therefore zero-origin coverage has direct read-side observability pressure.

This protects the **information distinction**, not the current five-coordinate representation in `loam-data`. A later experiment should test whether those coordinates are independent observations or consequences of one smaller explicit origin/boundary statement.

### Known-empty versus absent mutation evidence

For `RelationUnit`, `RelationDischarge`, and `ActualReversal`, the reconstructed read basis does not consume the distinction between absent state and explicitly known-empty state.

The model therefore requires a witness where changing only this presence state is read-invisible.

However, a separate write-side observation can distinguish the same two states. The model also requires that witness.

The conclusion is intentionally narrower than deletion:

```text
read projection basis
    can omit mutation-only presence state

whole household/write world
    may still need that state
```

This creates pressure to isolate mutation-only evidence from read projection machinery and to challenge whether explicit empty persisted families are the smallest representation of that write-side knowledge.

## Next candidate models

1. **Zero-origin factorization**
   Compare five independent covered-coordinate facts with one explicit origin observation plus a selected coordinate set. Require equivalence for every current balance/coverage answer before considering a representation change.

2. **Known-empty representation**
   Test whether write admission requires a three-state representation such as `unknown / known-empty / nonempty`, or whether some states are derivable from other retained write evidence.

3. **Scheduled terminal basis**
   Reuse Observation 244 to classify `Completion / Retirement / Replacement` as one retained terminal relation with three target shapes, then measure the reduction in independently threaded semantic state rather than file count.

4. **Capacity topology**
   Keep `CapacityMovement` and `CapacityEffective` as independently earned meanings while Experiment 245 separately challenges the two-file publication topology.

## Stop rules

- Do not infer household history to make the basis smaller.
- Do not collapse `unknown`, `absent`, and `known-empty` unless every relevant answer agrees.
- Do not infer AccountingRole or Purpose from names/signs merely to remove retained relations.
- Do not treat a bounded model as sufficient evidence for production deletion.
- When a distinction remains, retain or graduate the smallest durable witness explaining which intended answer requires it.

The target is a minimal semantic basis, not a minimal-looking repository.
