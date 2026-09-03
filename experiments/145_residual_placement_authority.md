# Observation 145 — Residual placement authority

Status: **experiment under qualification**

## Question

Observation 144 proved a general arithmetic boundary for exact relation conversion over indivisible quanta:

```text
whole target quanta alone
    !=
compositional exact conversion

whole target quanta + residual
    -> exact scaled conservation under splitting
```

The next question is no longer whether the arithmetic can retain the missing information. It can.

The next pressure is:

> Once accumulated residual is large enough to expose one additional whole target quantum, does the exact arithmetic determine which split piece receives that visible quantum?

This observation deliberately separates arithmetic conservation from placement authority.

## Minimal specimen

Reuse the concrete shape exposed by Observation 144, but split the source into three equal pieces under an exact `1 / 3` relation:

```text
A: whole = 0, residual = 1
B: whole = 0, residual = 1
C: whole = 0, residual = 1

residual total = 3
```

The normalized aggregate contains one additional target quantum.

All three pieces are deliberately symmetric with respect to the retained arithmetic evidence.

Three placement worlds keep that evidence identical and vary only where the one visible carry quantum is attached:

```text
World A: +1 on A
World B: +1 on B
World C: +1 on C
```

Each world represents the same aggregate exact quantity. The difference is only visible placement among the split pieces.

The model also includes a world with all candidate pieces retained but no placement definition.

## Positive witnesses

Expected SAT:

```text
sameExactResidualSeveralPlacements
sameEvidenceDifferentPlacementAuthority
noPlacementAuthorityLeavesCarrierUnselected
equalPlacementMeaningDifferentIdentitySameCarrier
```

These witnesses ask whether:

- the same symmetric exact residual evidence admits several carrier candidates;
- identical retained arithmetic evidence can coexist with different visible placements when placement authority differs;
- without placement authority, the candidate set can remain uncollapsed rather than silently choosing one piece;
- identity-distinct placement definitions with the same carrier meaning produce the same selected carrier.

## Deliberately too-strong boundaries

### Exact residual evidence alone determines one carrier

```text
ExactResidualEvidenceAloneDeterminesOneCarrier
```

Expected: **SAT counterexample**.

The candidate world retains A, B, and C with equal whole/residual evidence but has no placement authority. Arithmetic conservation tells us that one target quantum exists at aggregate scale; it does not name a recipient.

### Equal retained evidence forces equal placement

```text
SameRetainedEvidenceForcesSameCarrier
```

Expected: **SAT counterexample**.

AWorld, BWorld, and CWorld retain the same arithmetic evidence while selecting different carriers under different placement definitions.

Therefore:

```text
exact arithmetic
    !=
visible carry placement
```

## Bounded sufficiency checks

### Equal placement meaning determines the carrier

```text
EqualPlacementMeaningDeterminesCarrier
```

Expected: **UNSAT counterexample**.

Inside the exact specimen, two worlds with the same retained evidence and the same carrier meaning cannot produce different selected carriers.

### Selected carrier comes from the candidate set and remains scalar

```text
SelectedCarrierComesFromCandidatesAndIsScalar
```

Expected: **UNSAT counterexample**.

The placement layer may select one retained candidate. It may not manufacture an unrelated recipient or select several recipients for the single carry quantum.

## Interpretation gate

If these results qualify, the smaller candidate becomes:

```text
exact conversion arithmetic
    -> aggregate whole + residual information

normalized residual
+ candidate split pieces
    -> possible visible placements

possible placements
+ placement authority
    -> one selected visible placement
```

rather than assuming:

```text
exact conversion arithmetic
    -> one uniquely determined split placement
```

This would make placement authority observable only when a caller demands a per-piece integral presentation. Aggregate exact queries can remain authority-free.

## Relationship to `Loam.Core.Allocation`

`Loam.Core.Allocation` already exposes `RemainderPlacement.front` / `.back` rather than pretending quotient/remainder arithmetic determines placement. Its documentation explicitly says that remainder placement is an explicit choice relative to caller order and does not determine recipient identity or priority.

Observation 145 treats that as a useful precedent, not as evidence that conversion residuals should reuse the same production type.

The common mathematical pressure may be:

```text
conservation determines quantity
placement determines location
```

while the domain meaning of the placement authority remains separate.

## What is deliberately not modeled

Observation 145 does not decide:

- front/back or any specific ordering rule;
- largest-remainder allocation;
- round-half-up, half-even, floor, ceiling, or nearest rounding;
- whether a specific Event or Effect owns residual placement;
- whether placement authority is global, per relation, per query, or per publication;
- multiple carry quanta;
- unequal residuals;
- signed quantities;
- negative conversion results;
- persistence of residual or placement decisions;
- historical correction of a placement decision;
- accounting presentation of rounding differences.

Those are separate pressure points.

## Not earned by this observation

Even if qualified, Observation 145 does not establish canonical:

- `RoundingPolicy`;
- persistent `Residual`;
- `ResidualOwner`;
- `CarryPlacement`;
- `ConversionReceipt`;
- `ExchangeRate` or `Currency` types;
- any Practical Core change.

The experiment-local `PlacementDefinition` is only evidence that one selected per-piece integral answer requires information equivalent to placement authority in this symmetric specimen. It does not establish durable policy identity.

## Tool choice

**Alloy.**

Observation 144 already used Lean for the universal arithmetic law. The remaining question is static distinguishability:

```text
same exact arithmetic evidence
same candidate pieces
vary only visible placement authority
```

Alloy is therefore the smaller tool for this boundary. Lean can return later if a concrete carry algorithm is actually chosen and needs a general conservation proof.
