# LOAM System Map v0.6

Purpose: a shared architecture navigator for reviewing LOAM with DRAKON and for exploring an Ada/SPARK implementation without losing the whole-system shape.

The map has four roles:

- a macro architecture audit gate that every structural refactor should survive;
- a small human-scale repository/system tree;
- detailed DRAKON-shaped flow diagrams for concrete production paths;
- a cross-path write atlas for deciding what is truly shared and what only looks similar.

It is deliberately not a mirror of every Lean file. A diagram should expose a meaningful path, decision, authority boundary, refusal, recovery law, or macro design law rather than reproduce file structure mechanically.

## Pinned audit checkpoint

The first cross-path audit conclusions are frozen in [`DRAKON_WRITE_PATH_AUDIT_CHECKPOINT_2026-09-14.md`](../research/DRAKON_WRITE_PATH_AUDIT_CHECKPOINT_2026-09-14.md).

That checkpoint records the evidence and non-conclusions reached after the first Record / Correction / Scheduled Completion comparison. It intentionally still says that sparse Effect identity divergence was the next target. v0.6 resolves that target instead of rewriting the historical checkpoint.

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
    `-- 12 Complete Scheduled
        +-- 12.0 Complete Scheduled
        +-- 12.1 Dual-Authority Completion Publish
        +-- 12.2 Completion Actual Admission
        `-- 12.3 Interrupted Completion Recovery
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
python3 docs/drakon/inspect_map.py --all --json > /tmp/loam-map.json
```

Use the inspector for structural questions. Use an actual DRAKON Editor screenshot when spatial density, symmetry, alignment, or an unexpectedly awkward route is itself the evidence.

## Multi-Measure reading rule

LOAM should remain **multi-Measure native**, not be described as a complete FX accounting subsystem.

A current practical entrance may deliberately require JPY. That does not make JPY a global Event law. Neutral Core keeps explicit Measure identity and must not silently add or convert distinct Measures.

A future base-Measure answer such as JPY net worth across JPY and USD holdings must earn the independent valuation evidence and policy it actually needs. The architecture gate should reject both extremes:

- collapsing Measures because the current household mostly uses JPY;
- adding a speculative FX framework before a real valuation question requires it.

## Frontend reading rule

High-level TUI, future GUI, Web, and AI adapters should operate on presentation-neutral commands / queries and one household root. They should not need canonical `.loam` filenames, writer-lock mechanics, durable identity allocation, serialization, or recovery policy.

The scriptable Movement CLI follows the same `HouseholdCommand.record` path as the TUI. Presentation is rendered after authoritative publication succeeds; the Movement publisher carries no frontend callback.

A low-level diagnostic CLI may still deliberately expose physical paths when explicit physical control is part of its independent purpose.

## Write-path comparison rule

The atlas exists to stop two opposite mistakes:

```text
similar shape
    -> prematurely merge different semantic authorities

different feature names
    -> miss genuinely repeated mechanics
```

The first three mapped write paths currently show:

```text
Record Movement
    Actual + current Locus policy
    -> Movement admission
    -> one complete Actual generation

Correction
    Actual + current Locus policy
    -> correction-specific target/replacement admission
    -> one complete Actual generation

Scheduled Completion
    Scheduled lifecycle + Actual + current Locus policy
    -> completion-specific Actual admission
    -> Scheduled terminal generation first
    -> Actual generation second
```

Record and Correction therefore share a **one-Actual publication topology**. That is evidence for shared mechanics, not evidence that Movement admission and correction admission are one semantic operation.

Scheduled Completion has a different authority topology and crash-recovery law. Its `Scheduled -> Actual` terminal claim is published first. If Actual publication is interrupted, that retained terminal remains inert to readers until the target Actual Event appears; retry reuses the same target identity. This distinction must not be erased merely because both files use staging and rename.

v0.6 also records one confirmed cross-path semantic law:

```text
collector-local EffectKey
    -> anonymous unless independent evidence earns addressability

Record
    Relation source may earn the key

Correction
    current replacement contract earns no new Effect key

Scheduled Completion
    current plain-Actual completion contract earns no new Effect key
```

This law is shared through `Loam.SparseEffectIdentity`, but it remains outside neutral Core. `Core.Event` owns the structural law that Effect identity is optional and retained keys are unique; operation-level evidence decides whether a collector key deserves durability.

## Map-driven refactoring results

The first Record Movement audit produced concrete compression:

1. sparse Effect identity moved from `MovementPublisher` into pure `MovementAdmission`;
2. `MovementAdmission.Admitted` shrank to `world + eventId`;
3. `ActualAuthority.movementWorld` became the shared pure representation boundary from Actual evidence plus current Locus policy;
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
6. Scheduled Completion now reuses `ActualAuthority.movementWorld` instead of hand-assembling the same Actual-plus-policy representation boundary.

The important result is not a generic publisher. One small law and one representation mechanism became shared while correction semantics and the two-authority Scheduled recovery protocol stayed independent.

The map is expected to get shorter or more regular when an audit is resolved. It should describe the smallest justified production path, not fossilize an older implementation.

## Remaining cross-path audit seams, not conclusions

v0.6 leaves narrower questions for later work.

1. `CorrectionPublisher.practicalMovementValid` and `MovementAdmission.validateDraft` both express parts of the practical balanced-JPY entrance. Correction lacks a normal Movement `total` field and also validates the retained target, so similar checks do not yet prove one shared validator.

2. Movement admission, Correction, Scheduled Completion, and at least part of Actual Reversal repeatedly perform Event append plus base ActualValidity append, with several paths also appending optional EventDescription. This is now strong independent pressure to investigate a small typed append primitive. It is not evidence for a generic publisher or generic admission engine.

3. `EventDescriptionMemory` owns the one-description-per-Event invariant but callers repeatedly rebuild `entries ++ [new]` through `ofEntries?`. A local `add?` operation may be a smaller first step than abstracting the entire Event / validity / description sequence.

4. Scheduled Completion must keep its stable externally selected EventId and Scheduled-first / Actual-second retry law even if some inner Actual append mechanics become shared.

These are exactly the kind of seams the atlas is meant to reveal: compare first, then use Lean, Alloy, tests, or DRAKON only where a concrete ambiguity or counterexample needs to be fixed.

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
