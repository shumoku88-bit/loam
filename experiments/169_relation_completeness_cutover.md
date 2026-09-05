# Observation 169 — relation completeness cutover

## Question

Observation 168 showed that missing open-relation evidence is not generally the same thing as an explicitly known absence of relation.

That creates an obvious but potentially expensive representation:

```text
one source Effect
+ no relation
-> one explicit known-none fact
```

If most ordinary Effects have no open relation, storing one negative fact per Effect would be mostly repetitive absence bookkeeping.

This observation asks whether a **completeness boundary** can compress ordinary known-none without making historical absence lie.

It also asks what coordinate such a boundary could safely use.

## Existing LOAM pressure

Current LOAM keeps Event structure date-free and represents occurrence-valid time separately as `ActualValidity` evidence. `EventId` is opaque and does not encode chronology.

LOAM also deliberately refuses to derive chronology or authority from file/list position.

Therefore a completeness boundary cannot quietly mean "everything after this line in the file".

## Bounded model

The Alloy model keeps:

- Event / Effect identity;
- valid-time era (`ValidBefore` / `ValidAfter`);
- an observation-local admission regime (`LegacyAdmission` / `CompleteAdmission`);
- positive directional relation facts only;
- latent relation meaning used solely to test what retained evidence determines;
- two alternative completeness bases:
  - `ByValidTime`;
  - `ByAdmission`.

For a covered Effect, the completeness contract is:

```text
semantic directed relation exists
iff
one positive relation fact exists
```

Therefore:

```text
covered + no positive fact
-> known-none
```

without a per-Effect `NoRelation` fact.

Outside the covered region, absence remains unknown.

## Probes

Expected witnesses:

1. `validTimeKnownNoneWithoutNegativeFact` — SAT
   - valid-time cutover can encode known-none by absence.

2. `preCutoverAbsenceSupportsDifferentMeanings` — SAT
   - pre-cutover absence can still mean none or a directed relation.

3. `backdatedAdmissionPoliciesDiverge` — SAT
   - a backdated Effect admitted through a complete writer is still pre-cutover under a valid-time policy, but covered under an admission-regime policy.

4. `postValidLegacyAdmissionStillCoveredByValidPolicy` — SAT
   - valid-time completeness does not require admission provenance for a post-cutover occurrence.

5. `sameValidTimeDifferentAdmissionRegime` — SAT
   - valid time does not determine admission regime.

6. `positiveFactWorksAcrossBothBases` — SAT
   - positive relation meaning is independent from how absence completeness is established.

Expected checks:

7. `CoveredAbsenceMeansNone` — UNSAT counterexample

8. `CoveredRelationRequiresPositiveFact` — UNSAT counterexample

9. `UncoveredAbsenceMeansNone` — SAT counterexample
   - historical / uncovered absence cannot be treated as zero.

10. `ValidTimeDeterminesAdmissionRegime` — SAT counterexample
    - admission provenance cannot be reconstructed from valid time.

11. `RetainedPositiveFactCannotSilentlyBecomeNone` — UNSAT counterexample
    - completeness does not erase positive evidence; correcting a retained relation to none still needs explicit revision/retraction authority.

## Candidate boundary

If the matrix holds, a narrow compression becomes plausible:

```text
before relation-completeness cutover:
  no relation evidence -> unknown

after qualified completeness cutover:
  no positive relation evidence -> known-none
  positive relation evidence    -> known directed edge
```

The smallest currently available candidate is **valid-time completeness**, because LOAM already carries occurrence-valid coordinates as separate typed evidence.

That choice has a deliberate limitation:

```text
backdated pre-cutover Event admitted later
+ no explicit relation evidence
-> still unknown
```

An admission-regime cutover could classify that Event as known-none, but only if LOAM retained or otherwise proved which admission regime governed that Event. Current Event identity does not encode that provenance, and this observation does not propose adding it.

## Operational requirement

A valid-time completeness cutover is sound only if every writer/import path that can admit an Effect in the covered valid-time region is relation-complete or fails closed.

The cutover is therefore not merely a date literal. It is a contract over all admission paths for that valid-time region.

If an importer can silently admit a post-cutover valid-time Event while omitting an actually existing relation, then the completeness claim is false and absence must remain unknown.

## Stop conditions

This observation does **not** propose:

- production `NoRelation` facts;
- production admission-generation metadata;
- deriving chronology from file/list order;
- a global ordered fact log;
- automatic historical backfill;
- a universal Relation abstraction;
- stored payable / receivable / outstanding balances;
- silent deletion of a previously retained directed relation.

A correction from directed relation to none still requires explicit negative revision/retraction authority. Completeness only compresses ordinary baseline absence inside a qualified region.

## Candidate interpretation

The promising shape is:

```text
positive relation facts
+ one qualified completeness boundary
-> known-none by absence inside the covered region
```

rather than:

```text
one NoRelation fact per ordinary Effect
```

Whether valid-time completeness is operationally acceptable should be decided before any production type is added.
