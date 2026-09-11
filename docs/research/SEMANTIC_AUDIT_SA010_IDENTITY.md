# Semantic audit SA-010 — remaining identity census

Status: **AUDIT COMPLETE — no further production identity deletion currently justified**

Parent ledger: `docs/research/SEMANTIC_AUDIT_LEDGER.md`

Audit checkpoint: `bb147f11267e396dfaef8e8aebeaafe67ddae966`

This audit continues the successful identity reductions from PRs #715 and #716.
Those changes established a deliberately narrow principle:

```text
base fact identity should not be allocated merely because a row exists;
use subject/endpoints when they already identify the retained fact;
allocate independent identity only when multiplicity, later reference,
revision provenance, or another independently observable distinction requires it.
```

The question here is whether any remaining production identity violates that
principle.

## 1. Scope and classification

The census includes not only names ending in `Id`, but also `EffectKey`, because
its semantic role is stable nested identity.

Remaining production identities fall into four different classes:

```text
entity / occurrence identity
  EventId
  ScheduledId
  CapacityMovementId
  AttentionId
  RelationUnitId

revision identity
  ActualValidityRevisionId

semantic coordinate identity
  LocusId
  MeasureId
  PurposeId
  ExternalEndpointId

nested local identity
  EffectKey
```

These classes must not be compressed by one blanket "IDs are expensive" rule.
A coordinate identity is not a row identity, and a revision identity is not a
base-fact identity.

## 2. EventId — KEEP

`EventId` is a stable join boundary, not a redundant row key.

Independent production evidence refers to Event identity from several semantic
families, including:

- `ActualValidity` and append-only ActualValidity history;
- Event descriptions;
- Event Correction endpoints;
- Actual Reversal endpoints;
- Open Relation source provenance;
- Relation Discharge later-event provenance;
- Scheduled completion targets.

Event contents do not identify the Event. Distinct Events may legitimately have
identical Effects, and later evidence must still be able to name exactly one of
them.

Verdict: **KEEP**.

## 3. EffectKey — KEEP

`EffectKey` is scoped nested identity inside one Event.

The Event model explicitly permits distinct Effects at the same `(LocusId,
MeasureId)` coordinate. List position is representation only, so neither the
coordinate nor list index can replace Effect identity.

Open Relation provenance also names one source Effect by `(EventId, EffectKey)`.
Removing `EffectKey` would therefore collapse worlds in which two otherwise
coordinate-equal Effects have different later relation provenance.

Verdict: **KEEP**.

## 4. ScheduledId — KEEP

Scheduled identity is externally referenced by retained lifecycle and routing
evidence:

- `ScheduledTerminal.source`;
- Scheduled replacement successor endpoints;
- completion / retirement / replacement lookup;
- `ScheduledRoutingSubject = ScheduledId × LocusId`.

Distinct Scheduled occurrences may carry identical date and movement content.
Their later completion, retirement, replacement, and routing histories can still
differ.

Verdict: **KEEP**.

## 5. CapacityMovementId — KEEP

`CapacityMovementId` identifies one retained Capacity authority occurrence.

`CapacityEffective` is independent temporal evidence whose subject is exactly
`CapacityMovementId`; its memory permits at most one effective coordinate per
movement identity. The effective coordinate is intentionally not embedded into
the Capacity movement itself.

Content-addressing the movement would also incorrectly collapse two distinct
authority occurrences with equal movement content but independently observable
effective evidence.

Verdict: **KEEP**.

## 6. AttentionId — KEEP

`AttentionId` is not derivable from context or due data.

`AttentionClosure` refers to a retained Attention item by `AttentionId`, and the
closure memory permits at most one closure fact per Attention identity. Two
household matters may legitimately have equal context and due meaning while
remaining independently closable matters.

The previously retired Attention relation vocabulary does not weaken this
requirement; current closure evidence alone already supplies an external
reference reason.

Verdict: **KEEP**.

## 7. RelationUnitId — KEEP

`RelationUnitId` has especially strong independent meaning.

The Core explicitly permits distinct RelationUnits with otherwise equal source,
endpoints, and quantity. Exact Relation Discharge provenance targets a
`RelationUnitId`, and current allocation reserves identities referenced by
retained discharges as well as retained relation rows.

Therefore endpoint/source tuples cannot replace this identity without losing the
ability to discharge one of two otherwise equal relation units independently.
Earlier bounded relation observations already explored this pressure.

Verdict: **KEEP**.

## 8. ActualValidityRevisionId — KEEP, revision-only by design

This is the positive example of the principle established by the earlier
compression work.

The base occurrence-date fact is rooted directly at `EventId` and receives no
independent fact identity. Only a later date revision receives an
`ActualValidityRevisionId`, because correction provenance must be able to refer
to a particular retained revision.

`ActualValidityCorrection` itself has no separate correction identity. Its
identity is the exact target/replacement edge.

Verdict: **KEEP** the revision identity. The base-fact identity has already been
successfully removed.

## 9. LocusId / MeasureId / PurposeId / ExternalEndpointId — KEEP as coordinates

These are semantic coordinates, not accidental persistence-row identities.

- `LocusId` names where physical Effects are observed and is reused by routing,
  admission, and presentation metadata.
- `MeasureId` distinguishes quantity kinds independently of scalar magnitude.
- `PurposeId` is the managed household-purpose coordinate used by Capacity and
  routing projections.
- `ExternalEndpointId` names an external relation endpoint independently of any
  one RelationUnit and can therefore be reused across relation evidence.

Replacing any of these with row position, display text, or neighboring fact
identity would erase a semantic coordinate rather than compress redundant fact
identity.

Verdict: **KEEP**.

## 10. Identityless evidence already demonstrates the intended rule

The strongest evidence that production is not blindly assigning IDs is the set
of retained evidence families that deliberately have no independent row ID:

```text
ActualValidity base fact
  identified by EventId

EventCorrection
  identified by target/replacement EventId endpoints

ActualReversal
  identified by target/reversal EventId endpoints

ActualValidityCorrection
  identified by target/replacement revision edge

ScheduledTerminal
  identified by Scheduled source and typed target meaning

AttentionClosure
  identified by AttentionId subject

CapacityEffective
  identified by CapacityMovementId subject

RoutingEntry
  identified by (subject, effectiveOn)

RelationDischarge
  identified by (EventId, RelationUnitId) correspondence
```

This is precisely the discipline SA-010 was intended to test.

## 11. Rejected deletions

Current evidence rejects:

```text
NO removal of EventId in favor of Event content
NO removal of EffectKey in favor of list position or Locus/Measure coordinate
NO content-addressed Scheduled identity
NO content-addressed Capacity movement identity
NO Attention identity derived from context/due values
NO RelationUnit identity derived from source/endpoints/quantity
NO removal of ActualValidityRevisionId while revision correction remains
NO merging semantic coordinates merely because each is represented by a token
```

No new generic `Identity`, `FactId`, or token ontology is justified either. The
small typed wrappers continue to prevent accidental cross-family joins.

## 12. Main architectural result

The earlier redundant identities were local historical residue, not evidence
that the current Core systematically over-identifies facts.

After #715 and #716, the production shape is now approximately:

```text
entities / independently referable occurrences -> stable identity
nested independently referable Effects         -> scoped key
later temporal revisions                        -> revision identity
semantic coordinates                            -> typed coordinate identity
endpoint- or subject-sufficient evidence        -> no extra identity
```

That is a compact and explainable identity policy.

## 13. SA-010 verdict

SA-010 is **AUDIT COMPLETE**.

No further production identity deletion is currently justified by the
revision-only principle. This is a negative audit result and should be retained
as such rather than repeatedly reopening the same IDs without new evidence.

Reopen one identity only if production semantics change in a way that removes
its current multiplicity, external-reference, or revision-provenance reason.

No production code change is authorized by this audit.
