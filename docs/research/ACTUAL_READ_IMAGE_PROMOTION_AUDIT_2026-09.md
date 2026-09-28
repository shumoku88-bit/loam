# Actual admitted read image — durable audit

Status: **PROMOTED / CURRENT PRODUCTION BOUNDARY**

This document keeps only the durable ownership and safety conclusions from the
2026-09 Actual read-image investigation. The step-by-step promotion history is
available in Git history.

## Current decision

Canonical Actual reads cross one admitted boundary:

```text
actual.loam
  -> normalized decode
  -> full fail-closed Actual admission
  -> AdmittedActualImage
       evidence
       currentEvents
       currentValidities
       settlement
       proof / qualification links
```

The image is a derived read product, not a second authority.

Raw `ActualEvidence` remains the retained aggregate and remains necessary for
writers, because every mutation constructs a new candidate that must be admitted
again before publication.

## Production owners

`Loam/Persistence/NormalizedActualAdmission.lean` owns
`AdmittedActualImage` and `admitActualImage?`.

The image carries proof fields tying:

```text
currentEvents
  = admitted correction frontier of retained Events + Corrections

currentValidities
  = admitted current ActualValidity view
```

and also carries the admitted Settlement projection for the same Actual
generation.

`Loam/Persistence/NormalizedActualPersistence.lean` owns normalized decoding
into that image.

`Loam/ActualAuthority.lean` exposes the canonical image loading boundary.

## Why this image exists

Before promotion, several production readers independently rebuilt the same two
derived views:

- correction-aware current Event frontier;
- current ActualValidity memory.

That repeated admission was unnecessary once normalized Actual decoding had
already established both views fail-closed.

The narrow image therefore caches only derived views with demonstrated shared
read pressure. It does not turn Relation, Discharge, Merchant, Reversal, or
description evidence into independent cached authorities.

## Canonical reader rule

After a caller has crossed `ActualAuthority.Image`, it should reuse the carried
views instead of reconstructing the same admission.

Current production examples include:

- ActualReview;
- ActualJournalProjection;
- BalanceReview admitted-image projection;
- BudgetWindowReview;
- CurrentCoverageReview;
- RoleBalanceReview canonical loading;
- effective quantity CLI;
- daily quantity CLI;
- TransactionsFlowReview and other image-based reports.

Raw/in-memory entrances may still perform their own admission. They are useful
for tests, diagnostics, and callers that have not crossed the canonical
authority boundary.

## Historical versus current Events

The image does not mean every reader should discard retained Events.

Historical review surfaces may use `image.evidence.events` to preserve
superseded provenance while using `image.currentValidities` or
`image.currentEvents` for current interpretation.

Current-journal and quantity surfaces may use `image.currentEvents` directly.

The distinction is intentional.

## Independent worlds that must stay separate

`CurrentQuantityAnchor` still works from retained Events and Corrections because
its reflected-root delta world is not the ordinary current Event frontier.
Replacing that logic with `image.currentEvents` would change reconciliation
semantics.

Scheduled reference closure may likewise need retained Event identity even when
Actual quantity projection uses current Events.

An admitted image is therefore a shared basis, not permission to collapse every
historical or reflected projection onto one Event list.

## Compatibility boundary

Keep:

- `admitActualEvidence?` as the raw-evidence compatibility projection while
  current writers/tests still require it;
- raw normalized decode/load APIs where mutation or low-level qualification
  requires `ActualEvidence`;
- writer candidate re-admission after every mutation.

Do not infer that a successful old image authorizes a newly mutated candidate.

## Retirement of Observation 271

Observation 271 originally proved, with an observation-local `ReadImage`, that
the carried current Event and validity views agreed with the then-existing raw
projection functions and that malformed correction/validity evidence failed.

Those obligations are now owned more strongly by production:

- `AdmittedActualImage` carries the correspondence proof fields directly;
- normalized Actual admission is the construction gate;
- production persistence and report tests exercise correction-bearing admitted
  images and malformed evidence;
- canonical readers consume the production image.

The observation-local Lean probe and its experimental prose therefore graduated
from the working tree on 2026-09-28. Their exact source remains in Git history.

## Durable non-goals

Do not add:

- a second Actual semantic authority;
- a whole-`ActualEvidence` proof-object rewrite solely for read reuse;
- cached derived families without demonstrated repeated read pressure;
- a generic trusted `EventMemory` bypass;
- a global multi-authority snapshot merely to reduce file or function count.

The durable rule is smaller:

> admit the complete Actual generation once, carry the shared derived views whose
> provenance is proven, and keep mutation/re-admission and genuinely different
> historical worlds explicit.
