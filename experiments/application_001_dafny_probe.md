# Application 001 Dafny probe

## Purpose

Application 001 already has an Alloy query-shape boundary:

```text
0 Corrections
    -> recorded quantity

1 Correction + closed endpoints
    -> single-correction effective quantity

1 Correction + missing endpoint
    -> explicit refusal

2+ Corrections
    -> frontier required
```

This experiment asks a narrower implementation question:

> Can that already-earned application boundary become a small verified executable operation in Dafny without moving accounting semantics out of Lean or creating a new household domain model?

This is a host-language probe, not a decision that Dafny belongs permanently in LOAM.

## Boundary under test

The Dafny program receives only evidence already shaped for this query:

- number of Corrections;
- recorded quantity candidate;
- optional single-correction effective quantity candidate.

It deliberately does **not** compute the recorded or effective quantity itself. Those meanings remain owned by the existing Lean Core laws.

The Dafny operation decides which answer is permitted:

```text
QuantityInspectionEvidence
    ->
RecordedQuantity(value)
| SingleCorrectionEffectiveQuantity(value)
| MissingCorrectionEndpoint
| FrontierRequired
```

The two refusal cases are ordinary typed answers, not exceptions and not generic error strings.

## Why optional effective evidence is useful here

The existing Lean single-correction projection is partial: it returns no effective quantity when Correction endpoints cannot be projected from EventMemory.

The Dafny probe preserves that shape rather than reconstructing endpoint semantics independently.

```text
Lean-derived effective candidate absent
    + exactly one Correction
    -> MissingCorrectionEndpoint
```

For multiple Corrections, even a supplied candidate cannot authorize an answer:

```text
2+ Corrections
    -> FrontierRequired
```

The probe therefore cannot smuggle a guessed frontier through a numeric value.

## Verification questions

The Dafny verifier is required to establish that:

1. the executable `InspectQuantity` result is exactly the specification function `ExpectedAnswer`;
2. with zero Corrections, changing single-correction evidence cannot change the recorded answer;
3. with multiple Corrections, changing recorded/effective numeric candidates cannot escape `FrontierRequired`;
4. the four synthetic witnesses execute as the four expected typed modes.

These are deliberately application-boundary properties. They are not new accounting laws.

## Toolchain containment

The workflow pins Dafny `4.11.0` and uses it only for this experiment and its dedicated CI path.

```text
production Lean build dependency:  no
Practical Core dependency:         no
Persistence dependency:            no
CLI dependency:                    no
private canonical data dependency: no
```

If the probe teaches nothing beyond what Lean already expresses, the Dafny source and workflow can be removed without losing Core semantics.

If it proves unusually natural, a later checkpoint can ask whether verified application operations deserve a persistent Dafny role.

## Non-goals

This experiment does not:

- make Dafny the LOAM application language;
- replace Lean proofs;
- parse canonical household source;
- write canonical data;
- introduce a TUI;
- introduce Plan, Series, Budget, Account, or other household vocabulary;
- introduce Observation 085.

## Reading the result

A successful probe would establish only this implementation result:

```text
Alloy-shaped application distinction
    + Lean-owned quantity semantics
    ->
small Dafny specification + verified executable gate
```

The next decision would then be whether that gate provides enough additional clarity to justify keeping Dafny at all.
