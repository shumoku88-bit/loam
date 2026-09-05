# Observation 176: relation production promotion checkpoint

Status: bounded composition checkpoint stacked on Observation 175.

Observations 163–175 progressively separated physical movement, burden, open relation, discharge, effect anchoring, authority/absence, completeness, writer qualification, endpoint identity, quantity partition, orientation, and retraction.

This checkpoint asks a different question:

> Do those independently qualified meanings compose into a small enough production boundary, or does their combination reveal another missing primitive?

It deliberately does **not** add production relation types yet.

## Current production fit

Current LOAM already supplies several useful boundaries:

- `EventId` is opaque stable identity.
- `EffectKey` exists specifically so later overlays can refer to one Effect without list position or locus/measure projection.
- `Quantity` is exact signed `Int`; its sign has no built-in accounting meaning and later domain types may impose narrower restrictions.
- raw relation-like streams such as Event corrections retain facts independently of referential closure;
- `RelationAdmission` performs fail-closed reference checks later;
- `CorrectionFrontier` keeps currentness/order authority out of list position;
- persistence already permits independently typed streams rather than one universal fact log.

So the promising relation shape remains additive rather than invasive.

## Composition model

Observation 176 combines only the already-earned dimensions:

```text
Effect
  (EventId, EffectKey)
  source Measure
  signed source orientation
  exact source magnitude
  legacy / completeness-covered status

RelationUnit
  stable identity
  source Effect
  debtor endpoint
  creditor endpoint
  exact raw quantity

RelationRevision
  target RelationUnit
  optional replacement RelationUnit

ExplicitNoneEvidence
  source Effect
```

The observation keeps `Household | ExternalEndpoint` as the relation endpoint boundary. It does not introduce Party, Person, Merchant, Friend, or role taxonomies.

## Why raw quantity is tested

Observation 174 qualified the semantic open-relation amount as a **positive exact magnitude**.

Production `Quantity`, however, intentionally remains signed. There is currently no generic `PositiveQuantity` type.

Two implementation choices are possible:

```text
A. introduce a new constrained positive-quantity Core primitive

B. retain ordinary exact Quantity in raw relation provenance
   + require positive/bounded magnitude at semantic admission
```

Observation 176 tests B before earning another primitive.

The critical safety condition is:

> malformed current raw relation evidence must never be silently filtered into completeness-derived known-none.

Therefore the composed projection has four broad outcomes:

```text
known positive
known none
unknown
unresolved
```

A current relation row with a nonpositive or otherwise invalid semantic shape enters **unresolved**. It is not treated as absence.

This makes raw-retention-before-admission compatible with completeness without requiring invalid raw rows to become semantic facts.

## Expected probes

```text
sharedCostPositiveAdmitted                   SAT
equalShapeDistinctRelationUnits              SAT
invalidMagnitudeBlocksCoveredNone            SAT
orphanRawRelationRetainedButNotAdmitted      SAT
coveredRetractionBecomesKnownNone            SAT
legacyRetractionReturnsToUnknown             SAT
positiveReplacementStaysOnSource             SAT
explicitNoneConflictFailsClosed              SAT
sourceMeasureIsEnough                        SAT
```

The last probe checks that relation measure need not be duplicated in the relation row: after source-reference admission, the source Effect already supplies `MeasureId`.

## Expected checks

```text
KnownPositiveUsesOnlyValidCurrentUnits             UNSAT counterexample
InvalidCurrentEvidenceCannotBecomeKnownNone        UNSAT counterexample
CoveredCleanAbsenceIsKnownNone                     UNSAT counterexample
LegacyCleanAbsenceIsKnownNone                      SAT counterexample
RetractionAlwaysProducesKnownNone                  SAT counterexample
EveryRawRelationIsAlreadyPositive                  SAT counterexample
SourceEndpointsQuantityDetermineRelationUnit       SAT counterexample
ExplicitNoneOverridesCurrentPositive               SAT counterexample
PositiveReplacementPreservesSource                 UNSAT counterexample
```

## Promotion judgment if the matrix holds

### Semantics now earned strongly enough for production vocabulary

The following meanings are no longer speculative:

```text
ExternalEndpointId
  opaque stable identity

RelationEndpoint
  Household
  | external ExternalEndpointId

RelationUnitId
  stable identity independent of source/endpoints/quantity

RelationUnit raw provenance
  source EventId
  source EffectKey
  debtor RelationEndpoint
  creditor RelationEndpoint
  exact Quantity

RelationRevisionId
RelationRevision
  target RelationUnitId
  replacement : Option RelationUnitId
```

For an admitted positive relation unit:

- source `(EventId, EffectKey)` must resolve;
- debtor and creditor must differ and cross the Household/external boundary in the currently observed cases;
- quantity must be positive;
- quantity must not exceed source Effect magnitude;
- measure is derived from the resolved source Effect rather than duplicated.

A `replacement = none` revision is explicit retraction. Retained target history is not deleted.

### What the checkpoint does not yet earn

Even if semantic Core vocabulary is ready, the following remain separate implementation decisions:

- a concrete persistent relation stream format;
- a concrete `RelationHistory` / `RelationMemory` physical topology;
- routine persisted `ExplicitNoneEvidence`;
- a relation completeness cutover date;
- writer qualification changes in Movement, Scheduled completion, Correction, or date correction;
- automatic inheritance across Event correction;
- historical relation backfill;
- CLI/TUI interaction;
- endpoint display-name registry;
- a generic `PositiveQuantity` primitive;
- a duplicated relation `MeasureId` field;
- a generic `EffectRef` identity wrapper;
- universal `Party`, `Fact`, `Revision`, or `ActualAdmission` abstractions.

The distinction is intentional: **semantic vocabulary may be promotion-ready before persistence/writer publication is earned as one practical slice**.

## Likely smallest production sequence after this checkpoint

If composition succeeds, the conservative next slice is:

1. introduce the small Core relation vocabulary only;
2. introduce one Application admission/frontier projection that resolves source Effects, validates positive magnitude, derives measure, applies revisions, and fails closed on malformed/conflicting evidence;
3. prove order-insensitivity / reference safety in Lean;
4. only then choose a practical writer/query that actually requires persistence;
5. let that operation earn the first physical relation stream and relation-completeness writer change.

This avoids both extremes:

```text
premature universal relation framework
```

and

```text
keeping a now-stable semantic boundary trapped forever in Alloy-only experiments
```

## Stack

Observation 176 is stacked on Observation 175 / PR #358 at exact head:

`1afa8f20604a811fef2b83852048da7e8ebe850f`

PR #355–#358 remain unmerged by this checkpoint.
