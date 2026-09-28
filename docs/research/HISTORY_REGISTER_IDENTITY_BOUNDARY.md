# History / register / identity boundary

Status: **CURRENT RESEARCH BOUNDARY — Observations 254–256 graduated**

This document is the current-facing semantic record for the second
LOAM–Ledger history study. The detailed qualification narratives for
Observations 254–256 live in Git history; their formal witnesses remain live.

## Live formal witnesses

- `experiments/254_balance_history_boundary.als`
- `Loam/Observations/Observation255.lean`
- `Loam/Observations/Observation256.lean`

These witnesses protect three different layers. They must not be collapsed into
one generic "register" abstraction.

## Information ladder

Observation 254 establishes a strict information-loss boundary in the selected
bounded model:

```text
retained Event / Effect history
        |
        | may forget exact Effect membership
        v
Event-indexed quantity view
        |
        | forgets Event partition / identity
        v
balance image by LocusId × MeasureId
```

Two retained histories can therefore have the same additive balance image while
remaining distinguishable once Event identity participates in the query.
Conversely, an Event-indexed aggregate quantity view can still fail to determine
finer Effect membership.

The balance-level LOAM–REA–Ledger commutation result from Observations 250–253 is
therefore intentionally a projection result. Equal balance images do not license
reconstruction of retained Event history.

## Sparse Effect identity

Observation 255 keeps a separate boundary:

```text
physical Effect observation
    coordinate + quantity + multiplicity
    does not require EffectKey

durable reference to one nested Effect
    requires EventId + EffectKey
```

Erasing every optional `EffectKey` preserves Event identity, Effect-list
multiplicity, and every `LocusId × MeasureId` quantity projection. It destroys
the ability to resolve one durably named Effect.

This is why production keeps `EffectKey` sparse rather than mandatory. Identity
is earned when another retained fact must name one exact Effect; it is not
allocated merely because a posting row exists.

The broader production identity policy remains owned by
`docs/research/SEMANTIC_AUDIT_SA010_IDENTITY.md`.

## Concrete query boundary

Observation 256 connects the abstract identity result to current production
surfaces.

A useful correction-aware household register/history row is already determined
by `ActualReview.Record`:

```text
EventId
occurrence date
description
replacement EventId
derived currentness
physical Effect list
```

That physical row is invariant under EffectKey erasure.

By contrast, exact Relation source provenance genuinely crosses the sparse
identity boundary: `OpenRelationFrontier.relationSourceEffect?` needs the
retained `(EventId, EffectKey)` source coordinate.

A third query remains deliberately unanswered:

```text
which exact Effect after correction
is the same Effect as one before correction?
```

`EventCorrection` relates Event identities only. Reusing the same Event-local
EffectKey spelling in a replacement Event does not create cross-Event Effect
lineage. Such continuity would require independently retained correspondence
evidence if a future concrete query earns it.

## Chronology boundary

A correction-aware occurrence-date review is reconstructible from current
evidence. Exact capture, arrival, or posting chronology is not reconstructed from
`EventMemory` list position.

Representation order is not time authority.

Therefore:

```text
occurrence-date household review     existing evidence
exact Relation source Effect         EventId + EffectKey
cross-correction Effect sameness     not currently retained
capture / arrival chronology         not currently retained
```

No production `Register`, global `EffectId`, mandatory EffectKey, lineage
relation, or posting-order timestamp is justified by Observations 254–256.

## Current production owners

The selected executable boundaries already live in current code:

- `Loam/ActualReview.lean` owns correction-aware, occurrence-date-aware review;
- `Loam/Application/OpenRelationFrontier.lean` owns exact keyed Relation source
  resolution;
- `Loam/Core/Event.lean` owns Event / Effect representation and the rule that
  list position is not semantic chronology;
- `Loam/Application/CorrectionFrontier.lean` owns fail-closed EventCorrection
  topology admission;
- `docs/research/ACTUAL_REVIEW_CURRENTNESS_DERIVATION_OBLIGATION_DAG.md`
  records why currentness is derived from the admitted replacement edge rather
  than retained as a second authority.

## What remains live after this graduation

The later correction-diff sequence has its own durable current-facing record:

`docs/research/CORRECTION_DIFF_COMPOSITION_BOUNDARY.md`

Observations 257–262 remain live Lean witnesses, while their detailed prose
narratives have graduated to Git history. The sequence establishes derivable
coordinate deltas, exact finite support, safe human labels, finite composition,
and a research-only bridge from admitted EventCorrection topology.

Those results are not silently promoted into production. In particular,
Observation 262's explicit intermediate-chain reader remains research-only.

## Stop rule

Keep these distinctions separate:

```text
balance image != Event history
Event-indexed quantity != exact Effect membership
EventCorrection != cross-Event Effect lineage
occurrence date != capture chronology
optional EffectKey != missing physical Effect
```

Reopen retained identity or chronology only when a concrete household or
interoperability question cannot be answered from existing evidence.
