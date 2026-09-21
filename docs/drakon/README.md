# LOAM System Map v0.8

Purpose: a shared architecture navigator for reviewing LOAM with DRAKON and for exploring an Ada/SPARK implementation without losing the whole-system shape.

The map has four roles:

- a macro architecture audit gate that every structural refactor should survive;
- a small human-scale repository/system tree;
- detailed DRAKON-shaped flow diagrams for concrete production paths;
- a cross-path write atlas for deciding what is truly shared and what only looks similar.

It is deliberately not a mirror of every Lean file. A diagram should expose a meaningful path, decision, authority boundary, refusal, recovery law, or macro design law rather than reproduce file structure mechanically.

## Pinned audit checkpoint

The first cross-path audit conclusions are frozen in [`DRAKON_WRITE_PATH_AUDIT_CHECKPOINT_2026-09-14.md`](../research/DRAKON_WRITE_PATH_AUDIT_CHECKPOINT_2026-09-14.md).

That checkpoint records the evidence and non-conclusions reached after the first Record / Correction / Scheduled Completion comparison. Later map versions resolve some of those seams without rewriting the historical checkpoint.

```text
LOAM System Map
+-- 00 Architecture Audit Gate
+-- 00 Overview
+-- 01 Human Entrances
+-- 02 Commands & Questions
+-- 03 Application
+-- 04 Core Facts
|   +-- 04 Core Overview
|   +-- 04.1 Movement
|   +-- 04.2 Meaning
|   +-- 04.3 Time & Truth
|   +-- 04.4 Allocation
|   `-- 04.5 Knowledge
+-- 05 Evidence & History
+-- 06 Authority & Persistence
+-- 07 Projections & Reports
+-- 08 Formal Evidence
`-- 09 Write Path Atlas
    +-- 09 Write Path Comparison
    +-- 10 Record Movement
    |   +-- 10.0 Record Movement
    |   +-- 10.1 TUI Record Session
    |   +-- 10.2 Authoritative Movement Publish
    |   +-- 10.3 Movement Admission
    |   +-- 10.4 Atomic Actual Publish
    |   `-- 10.5 Line CLI Record Entrance
    +-- 11 Correct Actual
    |   +-- 11.0 Correct Actual
    |   +-- 11.1 Authoritative Correction Publish
    |   `-- 11.2 Correction Admission
    +-- 12 Complete Scheduled
    |   +-- 12.0 Complete Scheduled
    |   +-- 12.1 Dual-Authority Completion Publish
    |   +-- 12.2 Completion Actual Admission
    |   `-- 12.3 Interrupted Completion Recovery
    +-- 13 Reverse Actual
    |   +-- 13.0 Reverse Actual
    |   +-- 13.1 Authoritative Reversal Publish
    |   `-- 13.2 Reversal Admission
    `-- 14 Correct Actual Date
        +-- 14.0 Correct Actual Date
        +-- 14.1 Authoritative Date Publish
        `-- 14.2 Validity Revision
```

## Architecture laws

The textual source for the macro guardrails is [`ARCHITECTURE_LAWS.md`](ARCHITECTURE_LAWS.md).

The `00 Architecture Audit Gate` diagram turns those rules into a review path. Before accepting a local compression, ask whether it still preserves:

- minimal independent canonical evidence;
- explicit Measure separation and no implicit valuation;
- presentation-neutral semantics;
- authority-neutral high-level frontends;
- independent semantic authorities even when mechanics are shared;
- explicit unknown / incomplete state;
- fail-closed writes and qualified operational continuity;
- derived reports as projections rather than duplicate state;
- conservative primitive promotion after repeated independent semantic pressure;
- future capability without speculative framework-building;
- locale policy at the edge rather than in neutral Core;
- additive extension instead of distortion of an existing law.

Passing the macro gate does not prove a refactor correct. It prevents a local simplification from buying fewer lines by silently spending capabilities that make LOAM usable outside the current UI, locale, or household shape.

### Core promotion rule

A feature-specific helper starts local. Reuse alone does not earn Core status.

```text
one feature needs it
    -> keep local

multiple independent uses need the same semantic thing
    -> shared-boundary candidate

same shape but different authority / meaning
    -> share mechanics only

same semantic primitive + independent reason to exist
    -> only then consider moving inward
```

The threshold is evidential, not numerical. Two callers are a signal to investigate, not an automatic promotion rule.

## Build and open

From the repository root:

```sh
python3 docs/drakon/build_map.py
```

This creates:

```text
docs/drakon/loam-system-map.drn
```

Open that file in DRAKON Editor. The generated `.drn` is intentionally ignored by Git; `build_map.py` is the deterministic, reviewable source for the map.

The detailed diagrams use real DRAKON icon kinds such as `if`, `insertion`, `action`, `beginend`, and refusal exits. Audit-note text is explicitly wrapped by the builder so the yellow note boxes remain readable in DRAKON Editor.

The current diagrams are architecture observations: their English icon text is not yet Ada source and the `.drn` is not yet a code-generation authority.

## Inspect without a screenshot

The `.drn` file is SQLite, so its semantic contents can also be inspected as text:

```sh
python3 docs/drakon/inspect_map.py
python3 docs/drakon/inspect_map.py --diagram "00 Architecture Audit Gate"
python3 docs/drakon/inspect_map.py --diagram "09 Write Path Comparison"
python3 docs/drakon/inspect_map.py --diagram "11.2 Correction Admission"
python3 docs/drakon/inspect_map.py --diagram "12.2 Completion Actual Admission"
python3 docs/drakon/inspect_map.py --diagram "13.1 Authoritative Reversal Publish"
python3 docs/drakon/inspect_map.py --diagram "13.2 Reversal Admission"
python3 docs/drakon/inspect_map.py --diagram "14.1 Authoritative Date Publish"
python3 docs/drakon/inspect_map.py --diagram "14.2 Validity Revision"
python3 docs/drakon/inspect_map.py --all --json > /tmp/loam-map.json
```

Use the inspector for structural questions. Use an actual DRAKON Editor screenshot when spatial density, symmetry, alignment, or an unexpectedly awkward route is itself the evidence.

## Multi-Measure reading rule

LOAM should remain **multi-Measure native**, not be described as a complete FX accounting subsystem.

A current practical entrance may deliberately require JPY. That does not make JPY a global Event law. Neutral Core keeps explicit Measure identity and must not silently add or convert distinct Measures.

The practical Movement qualification now takes the expected `MeasureId` explicitly. Current Correction and Reversal callers pass JPY as product policy; the shared mechanic itself does not encode JPY. This keeps a future USD or other-Measure entrance possible without rewriting `BalancedMovement`, `Event`, or persistence.

A future base-Measure answer such as JPY net worth across JPY and USD holdings must earn the independent valuation evidence and policy it actually needs. The architecture gate should reject both extremes:

- collapsing Measures because the current household mostly uses JPY;
- adding a speculative FX framework before a real valuation question requires it.

## Frontend reading rule

High-level TUI, future GUI, Web, and AI adapters should operate on presentation-neutral commands / queries and one household root. They should not need canonical `.loam` filenames, writer-lock mechanics, durable identity allocation, serialization, or recovery policy.

The scriptable Movement CLI follows the same `HouseholdCommand.record` path as the TUI. Presentation is rendered after authoritative publication succeeds; the Movement publisher carries no frontend callback.

Actual Reversal follows the same rule. The TUI may derive inverse postings for preview, but `ActualReversalPublisher` re-reads the canonical target and re-derives the authoritative exact inverse under writer ownership.

Actual Date Correction is even narrower. The TUI owns only a date string editor and preview. `HouseholdCommand.correctActualDate` selects the canonical path, while `ActualValidityPublisher` re-reads admitted `ActualEvidence` under Actual ownership before deciding whether to reject, perform a successful no-op, or append validity revision evidence.

A low-level diagnostic CLI may still deliberately expose physical paths when explicit physical control is part of its independent purpose.

## Write-path comparison rule

The atlas exists to stop two opposite mistakes:

```text
similar shape
    -> prematurely merge different semantic authorities

different feature names
    -> miss genuinely repeated mechanics
```

The five mapped write paths now show both authority topology and mutation shape:

```text
Record Movement
    Actual + current Locus policy
    -> fresh Event identity
    -> one complete Actual generation

Correction
    Actual + current Locus policy
    -> retain target Event
    -> append replacement Event + EventCorrection
    -> replacement Effects may differ

Scheduled Completion
    Scheduled lifecycle + Actual + current Locus policy
    -> completion-specific Actual admission
    -> Scheduled terminal generation first
    -> Actual generation second

Actual Reversal
    Scheduled lifecycle + Actual + current Locus policy
    -> retain target Event
    -> append exact inverse Event + ActualReversal provenance
    -> Scheduled lifecycle remains unchanged

Actual Date Correction
    Actual only
    -> preserve EventId / Event / Effects / Measure / Description
    -> append ActualValidity revision + correction edge
    -> same-date request succeeds with no write
```

The most important v0.8 comparison is therefore not "which publishers look alike?" but **what canonical thing changes?**

```text
Correction
    Event identity moves to a replacement

Reversal
    target stays; inverse Event is added

Date Correction
    Event identity and physical Movement stay;
    only the time-coordinate evidence is revised
```

This difference is exactly why publisher-wide admission, one generic target-selection operation, or one giant authoritative snapshot should not be introduced merely because several paths load `actual.loam` and eventually publish a complete image.

### Confirmed shared mechanics

The atlas now treats these as earned shared seams:

- fixed `Scheduled -> Actual` ownership order through `Loam.ScheduledActualOwnership.withOwnership`;
- sparse Effect identity through `Loam.SparseEffectIdentity`;
- Measure-parametric practical Movement qualification through `Loam.PracticalMovement`;
- raw Correction-target membership through `EventCorrectionMemory.targetsEvent`.

Each helper answers a small question. None merges the semantic authorities of its callers.

### Keep local

Two important shapes remain deliberately operation-specific:

- ActualValidity date revision, including its revision identity and validity-correction edge;
- `targetCurrent?`-style operation semantics, where later guards and refusal meanings differ.

Date Correction now makes that distinction particularly clear. Its currentness check needs only a retained `EventId` plus raw Correction-target membership. It does not need the full target `Event`, and after v0.8 the map should not imply otherwise.

### Do not globalize

The following remain topology or operation laws rather than generic framework candidates:

- authoritative reload;
- authority topology;
- publisher-wide admission;
- crash / retry law.

Complete-image publication is already owned by each concrete authority such as `ActualAuthority`; it is not a new generic abstraction candidate.

## Lean proof and DRAKON observation

DRAKON should not invent runtime checks that Lean has already justified away.

Actual Reversal is the clearest example. The target is qualified as one balanced practical Movement. The reversal then negates every retained quantity exactly. `BalancedMovement.totalQuanta_negated` proves that exact quantity negation negates the total, so a zero target total remains zero.

Therefore `13.2 Reversal Admission` deliberately has no second `inverse balanced?` decision. The yellow audit note records the retained Lean law instead. Lean removes an unnecessary runtime box; DRAKON makes the absence of that box inspectable.

## Map-driven refactoring results

The first Record Movement audit produced concrete compression:

1. sparse Effect identity moved from `MovementPublisher` into pure `MovementAdmission`;
2. `MovementAdmission.Admitted` shrank to `world + eventId`;
3. `MovementWorldAdapter.ofActual` became the shared pure representation boundary from Actual evidence plus current Locus policy;
4. a regression fixed the counterexample that revealed preview/publication draft-shape divergence.

The second audit applied the macro gate to the publisher/frontend boundary:

1. `MovementPublisher.publishDraftWithPreview` retired;
2. the writer-owned publication corridor became presentation-neutral;
3. the scriptable Movement CLI remained, but now writes through `HouseholdCommand.record`;
4. CLI admission detail renders after successful authoritative publication instead of through a publisher callback.

The third audit came from comparing Record, Correction, and Scheduled Completion at the same DRAKON scale:

1. `Loam.SparseEffectIdentity.canonicalizeEffects` now owns the small shared law that only independently earned EffectKeys remain durable;
2. Record derives earned identity from Relation sources;
3. Correction and current Scheduled Completion erase collector-local EffectKeys because their admitted replacement/plain-Actual paths create no new Relation source;
4. production-path regressions deliberately reuse one temporary EffectKey across two postings and require successful keyless publication;
5. interrupted Scheduled completion recovery preserves the stable EventId while still erasing collector-local Effect identity;
6. Scheduled Completion now reuses `MovementWorldAdapter.ofActual` instead of hand-assembling the same Actual-plus-policy representation boundary.

The fourth audit tightened small local ownership before introducing another large abstraction:

1. `EventDescriptionMemory.add?` now owns its own append invariant instead of callers rebuilding `entries ++ [new]` through `ofEntries?`;
2. Correction and Actual Reversal now share `Loam.PracticalMovement.ofEffects?`, which is Measure-parametric while current production callers explicitly pass JPY;
3. the larger Event + base ActualValidity + optional description sequence was deliberately **not** generalized because the surrounding carriers and operation-specific failure meanings still differ;
4. DRAKON review of Reversal exposed an existing but unpinned rule: Scheduled-completion Actuals are not yet reversible;
5. a production regression now proves that such a reversal is refused without appending either an Event or an `ActualReversal` relation;
6. v0.7 maps Reversal so its read-only Scheduled dependency and exact-inverse law can be compared at the same scale as the other write paths.

The fifth audit used Reversal plus Date Correction to sharpen mutation-shape boundaries:

1. `Loam.ScheduledActualOwnership.withOwnership` now owns the repeated fixed `Scheduled -> Actual` lock order without merging the semantic authority of its callers;
2. `EventCorrectionMemory.targetsEvent` now owns only the raw "is this Event a Correction target?" membership query, while operation-specific currentness and failure meaning remain local;
3. regression coverage fixes Date Correction as independent from Reversal provenance because changing validity evidence does not change physical Effects;
4. `ActualValidityPublisher` no longer materializes a full target `Event` merely to recover its already-known `EventId`;
5. v0.8 maps Date Correction as a validity-history revision and places it beside Correction and Reversal so the three mutation shapes can be visually compared.

The important result is still not a generic publisher. Small laws and representation mechanics become shared only when the evidence earns them, while authority topology and operation-specific meaning stay explicit.

The map is expected to get shorter or more regular when an audit is resolved. It should describe the smallest justified production path, not fossilize an older implementation.

## Remaining cross-path audit seams, not conclusions

v0.8 resolves two former seams and leaves the larger boundary questions deliberately narrow.

1. Fixed `Scheduled -> Actual` ownership order is no longer merely a candidate. The mechanic is shared, while Scheduled Creation / Replacement / Completion, Actual Reversal, and AccountingRole retain separate semantic authority.

2. Raw Correction-target membership is also shared, but whole `targetCurrent?` operations are not. Correction and Reversal still need operation-specific guards; ActualValidity now only requires retained/current `EventId` evidence and does not load the target `Event` itself.

3. Movement admission, Correction, Scheduled Completion, and Actual Reversal still append different combinations of Event, base ActualValidity, description, and relation evidence. A generic Actual append engine remains unjustified because identity, carrier, additional evidence, and refusal semantics differ.

4. Date validity revision should stay local unless another genuinely independent feature needs the same revision algebra. Its shape alone is not pressure for a generic history-revision framework.

5. Current practical write entrances remain intentionally JPY-limited even though Core algebra and important persistence paths are Measure-generic. Multi-Measure expansion should begin from a real user-facing requirement, not from speculative FX infrastructure.

These are exactly the kind of seams the atlas is meant to reveal: compare first, then promote only the smallest semantic question that survives the comparison.

## Local audit rule

When the map feels wrong, do not immediately redraw it to match the code. Ask:

1. Is the map missing a genuinely independent meaning?
2. Is the code carrying a distinction that the map cannot justify?
3. Is a retained fact actually derivable?
4. Are two equal-shaped things being merged even though their authority differs?
5. Does an Ada package boundary correspond to an independent reason to change?

Then run the proposed change through `00 Architecture Audit Gate` before accepting the local simplification.

The tension between code and map is useful evidence.

## Scope

This is a design/navigation artifact. It is not canonical household-data authority and does not replace the production Lean model.

A selected diagram may later become an Ada/SPARK code-generation source, but only after the represented boundary is stable enough that generated code would be an improvement over keeping the diagram observational. Until then, the map's job is to make the machine inspectable by both the repository-aware AI and the human looking at DRAKON Editor.
