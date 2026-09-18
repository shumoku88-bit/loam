# Actual admitted read image promotion audit — 2026-09

Status: **STAGE A + B-1 + B-2 + B-3 MERGED; STAGE B-4 IMPLEMENTED ON BRANCH**

Stage A merged as `805a13726a646e55b68df117cb6e00b82ed5099c`.

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

## Stage B-1

The first reader migration is deliberately limited to ActualReview and JournalExport.

### ActualReview

Canonical loading now uses `ActualAuthority.loadImageFile?`.

ActualReview cannot simply replace its retained Event list with `currentEvents`:
the review intentionally keeps superseded historical Events so users can inspect
correction provenance. Therefore the image path:

- keeps `image.evidence.events` for the historical record list;
- reuses `image.currentValidities` instead of rebuilding validity admission;
- relies on full image admission for correction-topology safety;
- derives currentness exactly as before from outgoing replacement presence.

The raw `recordsFromActualEvidence?` API remains unchanged for arbitrary
in-memory evidence and continues to fail closed on its own.

### JournalExport

Journal export is a current readable journal rather than a retained-history
review. It therefore consumes both carried projections directly:

- `image.currentEvents`;
- `image.currentValidities`.

The former explicit calls to `correctionFrontierMemory?` and
`admittedActualValidityMemory?` are removed from the canonical path.

### B-1 invariant

Stage B-1 does not weaken raw testing entrances. It removes duplicate admission
only after the caller has crossed the normalized ActualAuthority image boundary.

## Stage B-2

The second reader migration targets current quantity projection:

- BalanceReview canonical snapshot;
- DailyQuantity CLI current/balances;
- Effective CLI.

### BalanceReview

The raw `project` function remains unchanged. It still accepts arbitrary
`EventMemory + EventCorrectionMemory` and preserves the qualified refusal order
used by raw tests and higher-level composition.

Only canonical `loadSnapshot` changes. After `ActualAuthority.Image` has already
been admitted, it projects rows from `image.currentEvents` directly. Zero-origin
coverage remains an independent gate.

### DailyQuantity

The canonical CLI now loads one `ActualAuthority.Image` and evaluates every
covered coordinate against `image.currentEvents`.

This removes per-coordinate calls through `inspectZeroOriginQuantity`, which
could reconstruct the same correction frontier once for every selected
coordinate. The raw Application function remains available unchanged.

### Effective CLI

The effective quantity command now enumerates coordinates from
`image.currentEvents` and reads quantities directly from that same admitted
basis.

The raw `inspectQuantity` Application boundary remains available for arbitrary
in-memory diagnostic callers. Canonical malformed correction topology is already
refused by `ActualAuthority.loadImageFile?`, so the CLI no longer rechecks the
same frontier for every coordinate.

### Cross-surface qualification

One correction-bearing fixture feeds all three production surfaces. The expected
current quantities are checked across:

- BalanceReview;
- `loamDailyQuantity current`;
- `loamDailyQuantity balances`;
- `loam effective`.

This pins observational agreement while removing duplicate canonical admission.

## Stage B-3

The third reader migration targets the two windowed Actual-consumption reports:

- BudgetWindowReview;
- CurrentCoverageReview.

Both reports had already compressed repeated per-Purpose work to one query-global
Correction frontier. After Stage A that intermediate admission itself became
redundant because normalized Actual loading already carries:

- `currentEvents`;
- `currentValidities`.

### BudgetWindow

The local Evidence shape now carries `ActualAuthority.Image` instead of separate
raw Events, Corrections, and re-admitted validities.

Every Purpose computes Consumption from:

```text
image.currentEvents
image.currentValidities
ActualRouting
explicit [start, end)
```

The report no longer calls `correctionFrontierMemory?` or
`admittedActualValidityMemory?`.

### CurrentCoverage

Current elapsed Consumption likewise uses the carried current Event and validity
views.

Scheduled pressure deliberately still receives `image.evidence.events`, not
`image.currentEvents`. Scheduled completion/reference checks may need identities
of retained superseded Events, so correction-aware quantity projection and
retained identity reference closure remain distinct observations.

### Qualification

Both report tests now republish correction-bearing canonical Actual images and
verify that Consumption follows the replacement Event quantity:

- BudgetWindow: 30 -> 40;
- CurrentCoverage: 30 -> 45.

CurrentCoverage additionally verifies Scheduled commitment remains unchanged
across the Actual correction.

## Stage B-4

The fourth reader migration is deliberately limited to the Actual-derived part of
RoleBalanceReview.

Role Balance composes several independent obligations:

- ordinary current correction frontier;
- zero-origin coverage;
- opening support;
- current quantity anchors;
- AccountingRole evidence.

Only the first of those is owned by the admitted Actual read image. Stage B-4
therefore does not merge support families or redesign Role Balance.

### BalanceReview admitted entrance

BalanceReview now exposes `projectImage`, which accepts a full
`ActualAuthority.Image` rather than a bare `EventMemory`.

That distinction is the provenance boundary G2-006 previously lacked:
`image.currentEvents` carries a proof tying it to the retained Events and
Corrections. Canonical readers can therefore reuse the already-admitted basis
without creating a generic "trust this EventMemory" bypass.

The raw `BalanceReview.project` entrance remains unchanged and continues to
admit arbitrary in-memory Events + Corrections fail-closed.

### RoleBalance canonical path

`RoleBalanceReview.loadSnapshot` now loads one `ActualAuthority.Image` directly.

Its ordinary current world uses `image.currentEvents` for:

- opening-support witness validation;
- current candidate coordinate discovery;
- opening-supported quantities;
- zero-origin quantities through `BalanceReview.projectImage`.

This removes the canonical RoleBalance call to
`correctionFrontierMemory?` and the nested zero-origin re-admission through
raw `BalanceReview.project`.

### CurrentQuantityAnchor stays separate

Current quantity anchors still consume:

- `image.evidence.events`;
- `image.evidence.corrections`.

That is intentional. Anchor semantics derive a reflected-root delta frontier,
not the ordinary current frontier carried by the image. Replacing that delta
world with `image.currentEvents` would double-count roots already reflected by
the reconciliation observation.

### Raw boundary and qualification

`RoleBalanceReview.project` remains a raw/in-memory entrance. It still admits
its ordinary correction frontier and delegates zero-origin rows to raw
`BalanceReview.project`.

A correction-bearing fixture now constructs one admitted Actual image and pins:

- the corrected Role Balance quantity;
- equality between admitted-image projection and raw projection.

Stage B-4 therefore deletes duplicate production admission without weakening
fail-closed diagnostic/test entrances or collapsing the anchor world.

## Non-goals

Stage A introduces no wire-format change, writer behavior change, global household snapshot, new canonical semantic family, canonical household data mutation, or cached Relation/Discharge/Merchant/Reversal view.

## Verdict

- whole ActualEvidence proof-object rewrite: **DO NOT ADD**
- small admitted Actual read image: **EARNED**
- compatibility raw ActualEvidence API: **KEEP**
- reader migration: **SPLIT INTO STAGE B**
- writer candidate re-admission: **KEEP**
- global multi-authority snapshot: **DO NOT ADD**
