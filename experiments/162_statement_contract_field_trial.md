# Observation 162: Does the statement contract help on a real existing LOAM proof?

Status: field trial of Observation 161 against existing Observation 159.

## Question

Observation 161 showed that a reviewed Lean proposition can serve as a machine-checkable statement-alignment boundary. That isolated witness was intentionally tiny.

Observation 162 asks the practical follow-up:

> Does the same pattern add useful review protection when applied to an already-existing LOAM observation, without rewriting or duplicating its mathematics?

## Subject under trial

Observation 159 is a suitable target because its prose and Lean statements are already careful and it contains a small cluster of claims that jointly carry the center of the observation:

1. `compactPresentation` and `splitPresentation` are `VectorEquivalent`;
2. the two representations have different list shape;
3. both satisfy the exact zero-augmentation boundary.

Observation 162 records those three points as one explicit `ExpectedClaim` and requires the existing Observation 159 theorems to inhabit that claim.

## Why this is a field trial rather than a retrofit

Observation 159 is left unchanged. Observation 162 imports it and checks the already-produced proof artifacts against a separately named reviewed claim.

This has two useful properties:

- the mathematical proof is not duplicated;
- if one of the existing theorem statements drifts incompatibly while the reviewed claim stays fixed, Observation 162 stops compiling.

The field trial therefore measures whether statement alignment can be added around existing proof-bearing work with little ceremony.

## Trust boundary

This does not prove that English prose and `ExpectedClaim` mean the same thing. Human review still owns that edge.

It also does not freeze the definitions imported from Observation 159. A coordinated change to the underlying definitions and the reviewed contract can still move meaning together.

The machine-checked gain is narrower and explicit:

```text
reviewed ExpectedClaim
    -> existing Observation 159 theorem types
    -> Lean type checking
```

## Evaluation criterion

The pattern earns further use only if this extra artifact makes statement drift easier to detect or review at low cost.

Do not generalize it to every observation merely because the field trial compiles.

## Stop condition

Do not introduce a generic contract framework, natural-language comparator, code generator, or project-wide mandatory policy here.

A successful result means only that the pattern works cheaply on one real existing observation. Repeated practical pressure is still required before broader adoption.
