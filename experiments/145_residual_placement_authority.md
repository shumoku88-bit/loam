# Observation 145 — Residual placement authority

Status: **qualified experiment**

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

## Qualified result

Alloy 6.2.0 + Sat4j confirms the intended boundary.

The positive witnesses are SAT:

```text
sameExactResidualSeveralPlacements
sameEvidenceDifferentPlacementAuthority
noPlacementAuthorityLeavesCarrierUnselected
equalPlacementMeaningDifferentIdentitySameCarrier
```

So the same symmetric exact evidence admits A, B, and C as possible visible carriers. Keeping the retained evidence identical while changing only the experiment-local placement definition selects different carriers. With no placement definition, the candidate set remains visible and no carrier is silently invented.

Both deliberately too-strong claims have counterexamples:

```text
ExactResidualEvidenceAloneDeterminesOneCarrier
SameRetainedEvidenceForcesSameCarrier
```

Therefore:

```text
exact arithmetic
    !=
visible carry placement
```

The bounded sufficiency checks have no counterexample:

```text
EqualPlacementMeaningDeterminesCarrier
SelectedCarrierComesFromCandidatesAndIsScalar
```

Inside this specimen, equal placement meaning determines the same carrier, and a selected carrier remains one scalar member of the retained candidate set.

Identity-distinct placement definitions with the same carrier meaning also produce the same selected carrier. Durable placement-policy identity is therefore not earned by this observation.

## Qualified candidate

The smaller candidate is:

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

Placement authority becomes observable only when a caller demands one per-piece integral presentation. Aggregate exact queries can remain authority-free.

## Relationship to `Loam.Core.Allocation`

`Loam.Core.Allocation` already exposes `RemainderPlacement.front` / `.back` rather than pretending quotient/remainder arithmetic determines placement. Its documentation explicitly says that remainder placement is an explicit choice relative to caller order and does not determine recipient identity or priority.

Observation 145 treats that as a useful precedent, not as evidence that conversion residuals should reuse the same production type.

The common mathematical pressure is now supported as:

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

Observation 145 does not establish canonical:

- `RoundingPolicy`;
- persistent `Residual`;
- `ResidualOwner`;
- `CarryPlacement`;
- `ConversionReceipt`;
- `ExchangeRate` or `Currency` types;
- any Practical Core change.

The experiment-local `PlacementDefinition` is only evidence that one selected per-piece integral answer requires information equivalent to placement authority in this symmetric specimen. It does not establish durable policy identity.

## Qualification

- pre-qualification scaffold head `e1b6578ae53672188c36c180f00b6224a829ac94` stopped before solver execution because a Lean-style block comment was invalid Alloy syntax;
- corrected executable head `29898310515c0a95be0b180eceba9a9b572be204` — Observation 145 SUCCESS;
- run `33780610802`, job `100733060219` — Alloy execution + expected-result checker SUCCESS.

The syntax-only scaffold failure is not semantic evidence; qualification starts at the corrected executable head.

## Tool choice

**Alloy.**

Observation 144 already used Lean for the universal arithmetic law. The remaining question is static distinguishability:

```text
same exact arithmetic evidence
same candidate pieces
vary only visible placement authority
```

Alloy is therefore the smaller tool for this boundary. Lean can return later if a concrete carry algorithm is actually chosen and needs a general conservation proof.
