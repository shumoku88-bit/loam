# G2-012 — Current Actual target obligation DAG

Status: **Generation-2 audit evidence — KEEP LOCAL**

Primary instruments: **DRAKONview + production-bound obligation DAG + historical cross-check**.

No production code change is proposed. Qualification rests on the current canonical Actual load contract, the existing `CorrectionFrontier` membership theorem, the three current production publisher tests, and the #776 historical compression change that deliberately removed per-writer whole-frontier recomputation.

## Question

Three production writers begin from the same narrow correction-currentness question:

- `CorrectionPublisher`;
- `ActualReversalPublisher`;
- `ActualValidityPublisher`.

Each must refuse an Event identity that is not retained or has already been superseded by `EventCorrection` evidence. The source shape is visibly similar, but Generation 2 asks whether that similarity earns one shared runtime helper or whether the existing local checks remain the smaller justified design.

## Canonical authority precondition

All three writers load `ActualEvidence` through `ActualAuthority.loadActual?` before admission. Canonical normalized Actual decoding runs `NormalizedActualPersistence.admitActualEvidence?`, whose first admission is the production `correctionFrontierMemory?` check.

Therefore writer-local target selection does not operate on an arbitrary raw correction graph. Before any of these local checks run, the retained world has already qualified:

```text
normalized actual.loam
        |
        v
admitActualEvidence?
        |
        v
correctionFrontierMemory?
  references closed
  source unique
  successor unique
  acyclic
        |
        v
writer-local target query
```

The existing `CorrectionFrontier.correctionFrontierMemory?_mem_iff` theorem already states the relevant semantic law after successful frontier admission:

```text
Event e is in the current correction frontier
<->
e is retained in EventMemory
AND
no retained EventCorrection targets e.id
```

No new currentness semantics are needed for G2-012.

## Same-scale target obligations

The common semantic root is:

```text
requested EventId
      |
      v
T1 retained Event exists?
      |
      v
T2 EventId absent from Correction targets?
      |
      v
correction-current target identity
```

The three writers diverge immediately after that root.

### Correction

Correction needs the retained `Event` value after T1/T2 because it additionally checks:

- practical balanced-JPY target shape;
- no retained Relation/Discharge reference to the target;
- no Reversal provenance mentioning the target;
- one current ActualValidity fact whose date is carried into the replacement Event;
- replacement construction and append-only correction provenance.

The local `targetCurrent?` therefore returns `Event`, not merely Bool.

### Reversal

Reversal also needs the retained `Event` value after T1/T2 because it additionally checks:

- target is not itself a reversal endpoint;
- target has not already been reversed;
- no retained Relation/Discharge reference to the target;
- no Scheduled-completion provenance naming the target;
- practical balanced-JPY target shape;
- exact anonymous inverse construction.

Its two target-current diagnostics are reversal-specific even though the underlying semantic predicates match Correction.

### ActualValidity date correction

Date correction uses the same T1/T2 semantic root, but does **not** consume the retained Event payload afterwards. It needs only:

- target identity retained;
- target not correction-superseded;
- current validity frontier fact for that EventId;
- same-date no-op versus one new validity revision.

Production tests deliberately qualify date correction of both sides of an existing `ActualReversal`. Date correction therefore must not inherit Correction/Reversal's provenance restrictions merely because the first two boxes look the same.

## Sharing candidates

### A. Shared `Option Event`

```text
currentTarget? : EventMemory -> EventCorrectionMemory -> EventId -> Option Event
```

This would preserve the Event payload needed by Correction/Reversal, but collapse `not retained` and `already correction-superseded` into one absence unless callers re-run one predicate to recover their existing diagnostics. Date correction would also receive an Event payload it does not otherwise use.

Verdict: **NO GAIN**.

### B. Shared Bool predicate

```text
correctionCurrent? : EventMemory -> EventCorrectionMemory -> EventId -> Bool
```

This would fit Date correction, but Correction/Reversal would then perform a second Event lookup to obtain the target value they require, or still retain their existing lookup beside the shared predicate.

Verdict: **MORE WORK OR NO REDUCTION**.

### C. Shared error algebra

A shared helper could return something like:

```text
Except CurrentTargetError Event
```

with `missing | superseded` constructors, followed by operation-specific mapping to user diagnostics.

That would add a new cross-writer type plus adapter logic only to remove two tiny local decision sequences. It would enlarge public/conceptual surface without removing an independent semantic burden.

Verdict: **REJECT**.

### D. Reuse full `correctionFrontierMemory?` in every writer

This was the older shape before #776. It re-ran global correction-frontier admission during target selection even though canonical Actual loading had already admitted the entire world. #776 deliberately reduced writer currentness to retained Event lookup plus raw target membership.

Reintroducing full frontier projection would duplicate global work and obscure the authority-load precondition.

Verdict: **REJECT; historical regression**.

### E. Move currentness into `EventCorrectionMemory`

`EventCorrectionMemory` intentionally owns raw correction facts and exact-edge uniqueness only. Whether an Event is retained requires `EventMemory`, and whether the whole relation is a valid current frontier remains an Application concern.

Moving cross-memory currentness into the raw Core memory would blur that boundary.

Verdict: **REJECT**.

## Obligation DAG

```text
canonical ActualEvidence loaded
        |
        v
whole correction frontier already admitted
        |
        v
requested EventId
        |
        +--> retained? -------- no --> operation-specific missing diagnostic
        |
        v
raw Correction target? ------- yes -> operation-specific stale diagnostic
        |
        v
shared semantic fact:
"retained and correction-current"
        |
        +-----------------------+-----------------------+
        |                       |                       |
        v                       v                       v
Correction                Reversal                Date correction
needs Event payload       needs Event payload     needs identity only
+ relation/reversal       + reversal/scheduled    + validity frontier
+ practical movement      + practical movement    + no-op/revision
+ carried validity        + exact inverse
```

The shared semantic fact is already justified by `CorrectionFrontier` and canonical Actual admission. The downstream value shape and refusal vocabulary are different enough that a new runtime helper would not reduce the real obligation graph.

## Historical cross-check

PR #776 removed repeated calls to full `correctionFrontierMemory?` from Correction and Reversal target selection and replaced them with exactly the local retained-Event plus Correction-target checks seen today. Later work centralized raw target membership in `EventCorrectionMemory.targetsEvent`.

G2-012 therefore does not uncover an unexamined accidental duplication. It confirms the stop point reached by the earlier compression work from a different visual instrument.

## Verdict

```text
shared semantic law                         ALREADY OWNED by CorrectionFrontier
canonical whole-world admission             KEEP in authority decode/load
Correction local targetCurrent?              KEEP
Reversal local targetCurrent?                KEEP
Date-correction inline T1/T2                 KEEP
new shared runtime current-target helper     DO NOT ADD
full frontier recomputation in writers       DO NOT RESTORE
```

**G2-012: KEEP LOCAL.**

Revisit only if another production writer needs the same target selection **and** consumes the same returned value and diagnostic vocabulary, or if target-currentness leaves the canonical Actual load boundary. Until then, the repeated two-box shape is smaller than the abstraction required to hide it.
