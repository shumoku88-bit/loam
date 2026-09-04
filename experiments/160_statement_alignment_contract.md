# Observation 160 — statement alignment contract

LOAM already checks many Lean observations in CI, but a successful build proves
only that Lean accepted the proposition written next to a proof. It does not by
itself establish that the proposition is the one a human reviewer intended to
ask.

Observation 160 asks a smaller practical question:

> Can LOAM add a mechanical statement-alignment boundary without introducing a
> new verifier, natural-language parser, or framework?

## Minimal boundary

The observation separates two roles:

```text
Observation160Contract.lean
    reviewed expected proposition

Observation160.lean
    proof-bearing implementation
```

The implementation theorem is required to inhabit the independently named
`ExpectedClaim` proposition. Lean therefore checks both proof validity and the
compatibility between the proof-bearing theorem and the reviewed contract.

If the implementation theorem drifts to an incompatible proposition while the
contract remains unchanged, the alignment theorem stops type-checking and CI
fails.

## What this earns

This is stronger than:

```text
workflow SUCCESS
=> intended statement proved
```

because workflow success alone does not identify which proposition was proved.
The new boundary is instead:

```text
review expected proposition
    -> implementation theorem
    -> theorem inhabits ExpectedClaim
    -> Lean kernel accepts
```

The contract can also be unfolded at a use site, so downstream review does not
have to infer its meaning from a workflow name or success token.

## What this does not earn

This observation does **not** mechanically understand English prose.

A reviewer can still write the wrong `ExpectedClaim`, or change the contract and
proof together. Therefore the remaining trust boundary is explicit:

```text
human intent
    -> reviewed Lean contract        still human review
reviewed Lean contract
    -> proof theorem compatibility   mechanical
proof theorem
    -> kernel acceptance             mechanical
```

That is intentional. Natural-language semantic equivalence is not smuggled in
as a solved problem.

The practical gain is that LOAM can make the machine-checkable portion larger
without pretending to eliminate the human specification boundary.

## Relation to earlier observations

Observation 079 distinguished workflow success from semantic interpretation.
Observation 080 distinguished bounded formal results from unbounded theorem
claims. Observation 160 applies the same discipline to theorem statements
themselves: the statement under review should be an explicit artifact rather
than something reconstructed from a green CI token.

Observation 159 is a useful motivating example because its prose and Lean
statement are already carefully aligned by convention. Observation 160 does not
retrofit 159 or change its result. It tests a reusable pattern that a later
observation may adopt when statement drift becomes practically important.

## Stop condition

Do not build a generic specification DSL, natural-language theorem comparator,
hash registry, or mandatory contract layer for every Lean file.

Keep this as an observation until repeated statement-drift pressure shows that
production or project-wide machinery would remove real review risk rather than
add ceremony.
