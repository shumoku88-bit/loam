# Actual admitted read image promotion audit — 2026-09

Status: **STAGE A IMPLEMENTED ON BRANCH; READER MIGRATION DEFERRED**

Baseline main: `1c9c574cd09daf31a4e99cd2b122d63b9345aed0`.

## Question

Normalized `actual.loam` already performs full fail-closed semantic admission at decode time. Does production still recompute derived admission views often enough that a small admitted read image is earned?

## Finding

Yes, but the pressure is concentrated. The broadly repeated views are `correctionFrontierMemory?` and `admittedActualValidityMemory?`.

Representative production consumers include ActualReview, BalanceReview, JournalExport, BudgetWindowReview, CurrentCoverageReview, RoleBalanceReview, Effective quantity CLI, and Daily quantity CLI. The quantity CLIs can repeat correction-frontier work once per selected coordinate.

By contrast, full Relation, Discharge, Merchant and Reversal admission is not broadly repeated by readers. Those checks do not justify separate cached read products.

## Observation 271

Observation 271 qualified a narrow read image carrying full Actual admission success, the current correction-aware Event memory, and the current ActualValidity memory. It proved that quantity projected from the carried current Event memory is exactly the existing correction-frontier quantity answer.

The probe also exposed an important boundary: successful validity-frontier construction alone does not prove that every remembered Event has a current date. The read image must therefore arise only after full Actual admission.

## Promotion design

Do not replace `ActualEvidence`. Writers need the raw aggregate because every mutation creates a new candidate that must be requalified before publication.

Instead add one richer normalized read result, `AdmittedActualImage`, containing raw evidence, current Events, current validities, and proof fields tying both derived views to the retained evidence.

Full normalized admission remains the gate that constructs this image. Compatibility APIs continue returning raw `ActualEvidence` so writer and low-level callers are not forced through a repository-wide migration.

## Stage A

Stage A changes only the authority/decode seam:

1. `admitActualImage?` performs the existing complete Actual admission and retains the two derived read projections.
2. `admitActualEvidence?` remains as a compatibility projection.
3. `decodeNormalizedActualImage?` returns the richer admitted image.
4. `decodeNormalizedActual?` remains as a compatibility projection.
5. `ActualAuthority.Image`, `loadImageFile?`, and `loadImage?` expose the richer read boundary.
6. Existing `loadActualFile?` and `loadActual?` continue returning raw `ActualEvidence`.

No reader is migrated in Stage A.

## Why reader migration is separate

Changing all readers at once would combine two independent questions: whether the admitted authority image is sound, and whether each reader can safely delete its local re-admission logic.

Stage A answers only the first. A later Stage B should migrate readers in small semantic families and preserve raw/pure APIs for arbitrary in-memory evidence where those APIs remain useful.

Likely first candidates are ActualReview + JournalExport, BalanceReview + DailyQuantity + EffectiveCli, then BudgetWindow + CurrentCoverage.

RoleBalance should follow only after BalanceReview exposes an admitted-basis entrance, because it composes correction-aware zero-origin, opening, and current-anchor paths with distinct local obligations.

## Non-goals

Stage A introduces no wire-format change, writer behavior change, global household snapshot, new canonical semantic family, canonical household data mutation, or cached Relation/Discharge/Merchant/Reversal view.

## Verdict

- whole ActualEvidence proof-object rewrite: **DO NOT ADD**
- small admitted Actual read image: **EARNED**
- compatibility raw ActualEvidence API: **KEEP**
- reader migration: **SPLIT INTO STAGE B**
- writer candidate re-admission: **KEEP**
- global multi-authority snapshot: **DO NOT ADD**
