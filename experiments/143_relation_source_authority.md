# Observation 143 — Relation source provenance and scalar authority

Status: **qualified bounded experiment**

## Question

Observation 033 established that a Measure-to-Measure relation can remain an overlay over physical Event history.

Observation 142 then qualified a temporal-applicability boundary: occurrence-time, settlement-time, and current valuation questions may select different retained relation observations at different effective coordinates.

The next pressure is intentionally narrower than a full exchange-rate policy:

> If several relation observations for the same Measure pair exist at the same effective coordinate but come from different sources and carry different values, does the effective coordinate alone determine a scalar valuation input? If not, what additional information is independently observable?

This observation keeps the vocabulary neutral. `Source`, `RelationObservation`, and `SelectionDefinition` are experiment-local names, not proposed Practical Core types.

## Minimal specimen

One Measure pair and one effective coordinate are fixed:

```text
ForeignMeasure -> BaseMeasure
C2
```

Three retained relation observations coexist at C2:

```text
BankObservation      source BankSource      value V5
ProviderObservation  source ProviderSource  value V6
UserObservation      source UserSource      value V7
```

All three have exactly the same:

```text
source Measure
target Measure
effective coordinate
```

They differ only in source provenance and value.

The model then exposes two different kinds of question.

### Candidate-set question

```text
what relation observations exist for this Measure pair at C2?
```

This question needs no scalar-selection authority. The answer can remain the full source-distinguished candidate set.

### Scalar-selection question

```text
which one relation value should this valuation query use at C2?
```

Three experiment-local selection definitions choose BankSource, ProviderSource, or UserSource respectively.

The retained observations remain identical across those worlds. Only the selection definition changes.

## Qualified result

Alloy 6.2.0 + Sat4j confirms the expected boundary.

The positive witnesses are SAT:

```text
sameCoordinateExposesSeveralSourceDistinguishedCandidates
sameEvidenceDifferentAuthorityDifferentScalar
provenanceWithoutAuthorityLeavesCandidateSetUncollapsed
equalAuthorityDefinitionDifferentIdentitySameSelection
```

So one effective coordinate can expose several source-distinguished candidates, and the same retained evidence can yield V5, V6, or V7 when the scalar-selection authority differs.

Complete source provenance without a selection definition leaves the candidate set uncollapsed. Provenance preserves where observations came from; it does not itself authorize one scalar answer.

Identity-distinct selection definitions accepting the same source produce the same selected projection in this bounded specimen, so a durable policy identity is not earned merely by this result.

## Deliberately too-strong boundaries

### Effective coordinate alone determines one relation value

```text
EffectiveCoordinateDeterminesOneRelationValue
```

Observed: **SAT counterexample**.

At C2 the candidate values are V5, V6, and V7.

Therefore:

```text
effective coordinate
    -> candidate relation set
```

may be possible, while:

```text
effective coordinate
    -> one authoritative scalar relation value
```

is too strong in this specimen.

### Source provenance automatically selects one scalar

```text
ProvenanceAloneAlwaysSelectsScalar
```

Observed: **SAT counterexample**.

`CandidateWorld` retains all three observations with complete source provenance but has no selection definition. The source information says where each observation came from. It does not itself say which source should govern a scalar valuation query.

This separates two kinds of information:

```text
provenance
    who / what supplied an observation

authority definition
    which candidate is admitted for this scalar question
```

## Bounded sufficiency checks

### Equal authority definition determines the scalar selection

```text
EqualAuthorityDefinitionDeterminesScalar
```

Observed: **UNSAT counterexample**.

Within the exact specimen, two worlds with the same retained observations and selection definitions accepting the same source cannot produce different selected values.

### Selected value remains one of the retained candidates

```text
SelectedValueComesFromCandidateSetAndIsScalar
```

Observed: **UNSAT counterexample**.

The selection layer may choose among retained observations; it may not manufacture a value outside the candidate set in this bounded model.

## Interpretation

The qualified smaller candidate is:

```text
retained Measure-to-Measure relation observations
+ effective coordinate
+ source provenance
    -> source-distinguished candidate set

candidate set
+ scalar-selection authority definition
    -> selected relation input
```

rather than assuming:

```text
Measure pair
+ effective time
    -> one universally authoritative relation value
```

Source provenance and scalar-selection authority answer different questions.

A multi-valued inspection API could expose all retained observations without needing an authority policy at all. Authority becomes necessary only when a caller demands one selected scalar.

## What is deliberately not modeled

Observation 143 does not yet decide:

- priority ordering among several acceptable sources;
- context-dependent source authority;
- user override semantics beyond the neutral source specimen;
- source trust, confidence, freshness, or quality;
- fallback when the selected source has no observation;
- multiple observations from the same source at one coordinate;
- knowledge-time correction of a relation observation;
- publication / as-known valuation;
- nearest-prior or interpolation rules;
- arithmetic conversion;
- rounding or residual allocation;
- realised/unrealised gain accounting roles;
- persistence.

Those are separate pressure points.

## Not earned by this observation

Observation 143 does not establish:

- canonical `ExchangeRate`;
- canonical `RateSource`;
- canonical `ExchangeRatePolicy`;
- canonical `Override` object;
- a global source-priority order;
- stored `FXGainLoss` facts;
- persistence or CLI/TUI changes;
- any Practical Core change.

In particular, the experiment-local `SelectionDefinition` is evidence that a scalar answer needs information equivalent to selection authority in this specimen. It does not establish that this authority requires its own durable identity or production type.

## Qualification

Initial executable head:

```text
efebf34b8ecb14ab99726b1c53e284c437784920
```

GitHub Actions Observation 143 run `33778533605`, job `100726205821`:

```text
Alloy execution                 SUCCESS
expected-result checker         SUCCESS
```

The result note is then requalified at its exact final head before the observation is considered complete.

## Tool choice

**Alloy.**

The present question is static distinguishability and sufficiency:

```text
same Measure pair
same effective coordinate
same retained observations
vary scalar-selection authority
```

No transition ordering is needed yet. TLA+ becomes appropriate if source observations arrive or are corrected concurrently, or if historical as-known source authority becomes the question.
