# G2-024 — Actual Review currentness derivation obligation DAG

Status: **Generation-2 audit evidence — SIMPLIFY QUALIFIED**

Primary instruments: **DRAKONview + obligation DAG + production-consumer reachability**.

## Question

After G2-022 and G2-023 removed exact derived copies from read-side results, G2-024 asks whether `ActualReview.Record` still retains two representations of the same correction fact.

Before G2-024 one transient record retained both:

```text
replacement : Option EventId
isCurrent   : Bool
```

Production computed both from one admitted `EventCorrectionMemory`.

## Existing correction-frontier law

`CorrectionFrontier.correctionFrontierMemory?` first requires a structurally admitted correction relation:

- every referenced Event exists;
- one target has at most one successor;
- one replacement has at most one predecessor;
- replacement paths are acyclic.

For a successful frontier, `correctionFrontierMemory?_mem_iff` states that one remembered Event is in the current frontier exactly when no retained correction targets its `EventId`.

Actual Review's `replacement` field is produced by the same target lookup:

```text
find correction where correction.target == event.id
```

Therefore, after frontier admission:

```text
replacement = none
        iff
no Correction targets event.id
        iff
Event belongs to current correction frontier
        iff
isCurrent = true
```

No second fact enters the currentness answer.

## Obligation graph

```text
ActualEvidence
    |
    v
correctionFrontierMemory?
    |
    +-- admission fails --> refuse Actual Review
    |
    v
admitted disjoint finite correction paths
    |
    v
for each remembered Event
    |
    v
lookup outgoing Correction by target EventId
    |
    +-----------------------------+
    |                             |
    v                             v
none                         some replacement
    |                             |
    v                             v
current                      superseded
    |                             |
    +-------------+---------------+
                  |
                  v
retain replacement only
                  |
                  v
derive Record.isCurrent := replacement.isNone
```

The correction frontier remains an admission gate. G2-024 does not replace its graph validation with a local `Option` check.

## Why the old shape was redundant

A public `Record` could previously represent contradictory combinations such as:

```text
replacement = none
isCurrent   = false
```

or:

```text
replacement = some successor
isCurrent   = true
```

Production never emitted those combinations after successful frontier admission, but test fixtures could construct them directly. G2-024 removes that extra degree of freedom.

The fixture migration is intentionally semantic rather than cosmetic: a synthetic superseded record now carries a synthetic replacement identity instead of a Boolean that contradicts its correction label.

## Preserved boundaries

G2-024 keeps:

- correction-frontier admission and all of its fail-closed graph obligations;
- exact replacement `EventId`, because labels, detail views, and reverse correction context need the successor identity;
- Event, occurrence date, and description in the transient record;
- historical corrected records in search results;
- current-only day/week/undated filtering;
- correction semantics in `Application.CorrectionFrontier` rather than in presentation;
- ActualValidity admission independently from correction currentness.

Consumers continue to read:

```text
record.isCurrent
```

through the same field-notation surface; the name is now a derived function.

## Observation 256

Observation 256 projects a register-shaped visible row from `ActualReview.Record` and intentionally keeps an `isCurrent` value in that *observation result*. That is not a second production authority. The observation copies the already-derived visible answer while proving EffectKey erasure does not change it.

Its proof is updated only for the smaller four-field `ActualReview.Record` constructor.

## Read-side closure pressure

G2-024 followed a broader result-shape sweep:

- Stock–Flow already derives `netChange` and `reconstructedEnd`;
- Budget Window already derives `remaining`;
- Current Coverage already derives `remaining` and `headroom`;
- Cycle Funding already derives measure and residual;
- Scheduled Headroom already derives commitment/headroom and pressure aliases;
- Cycle Budget's `Except` branches are independent visible failure boundaries;
- Actual Routing's lists are distinct semantic partitions;
- Scheduled Commitment totals represent distinct pressure classes.

No additional same-shape exact consequence was found in those boundaries during this pass.

## Stop point

Do **not** remove `replacement` and attempt to derive it from currentness. A Boolean cannot recover the successor `EventId` needed by correction-aware presentation.

Do **not** bypass `correctionFrontierMemory?`. `replacement.isNone` is a sufficient local currentness answer only after the whole correction relation has passed reference, uniqueness, parent, and cycle admission.

Do **not** introduce a generic status framework. This is one local exact derivation from an already-retained correction edge.

## Qualification

Production/audit head `344d8341a7be5786e25ff7af17eb9fecc8f99616` passed every triggered workflow:

- Compression Audit: **SUCCESS**
- Selected Lean Observations: **SUCCESS**
- Shared ActualValidity Publisher: **SUCCESS**
- Production TUI: **SUCCESS**, all 62 production verification steps passed

Directly relevant Production TUI checks passed without changing consumer syntax:

- shared Actual review checks;
- Record publication and fresh canonical review;
- normalized Actual correction publication;
- selected-day Correction editor and shared publication;
- Actual Reversal and selected-day fresh review;
- full-day Actual navigation;
- Stock–Flow reconstruction and refusal boundaries;
- Transactions–Flow incidence, activity and refusal boundaries;
- sparse Transactions–Flow Reports interaction;
- integrated Reports surfaces.

Selected Lean Observations also rebuilt Observation 256 successfully with the smaller four-field `ActualReview.Record` constructor.

Synthetic superseded Stock–Flow and Transactions–Flow fixtures now carry a replacement identity instead of an independent false Boolean, and their existing filtering regressions remain green.

The DRAKON builder is committed audit instrumentation but was not independently executed during this qualification.

## Verdict

**G2-024: SIMPLIFY QUALIFIED — ActualReview retains the replacement edge and derives currentness from replacement absence after correction-frontier admission.**
