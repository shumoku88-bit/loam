# LOAM System Map v0.3

Purpose: a shared architecture navigator for reviewing LOAM with DRAKON and for exploring an Ada/SPARK implementation without losing the whole-system shape.

The map has two levels:

- a small human-scale repository/system tree;
- detailed DRAKON-shaped flow diagrams for concrete production paths.

It is deliberately not a mirror of every Lean file. A diagram should expose a meaningful path, decision, authority boundary, or refusal rather than reproduce file structure mechanically.

```text
LOAM System Map
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
`-- 10 Write Path
    `-- Record Movement
        +-- 10.0 Record Movement
        +-- 10.1 TUI Record Session
        +-- 10.2 Authoritative Movement Publish
        +-- 10.3 Movement Admission
        +-- 10.4 Atomic Actual Publish
        `-- 10.5 Line CLI Record Entrance
```

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

The detailed Record Movement diagrams use real DRAKON icon kinds such as `if`, `insertion`, `action`, `beginend`, and refusal exits. Audit-note text is explicitly wrapped by the builder so the yellow note boxes remain readable in DRAKON Editor.

The current diagrams are architecture observations: their English icon text is not yet Ada source and the `.drn` is not yet a code-generation authority.

## Inspect without a screenshot

The `.drn` file is SQLite, so its semantic contents can also be inspected as text:

```sh
python3 docs/drakon/inspect_map.py
python3 docs/drakon/inspect_map.py --diagram "10.2 Authoritative Movement Publish"
python3 docs/drakon/inspect_map.py --diagram "10.2" --geometry
python3 docs/drakon/inspect_map.py --all --json > /tmp/loam-map.json
```

The inspector exposes:

- the DRAKON tree;
- icon type and text;
- YES/NO orientation for decisions;
- source-file and audit metadata;
- optional item geometry.

This is the screenshot-light bridge for human/AI collaboration. Use the inspector for structural questions. Use an actual DRAKON Editor screenshot when spatial density, visual symmetry, alignment, or an unexpectedly awkward route is itself the evidence. An AI reviewer can then ask for one exact diagram or comparison screenshot instead of requiring screenshots after every edit.

## Record Movement reading rule

The production path deliberately separates three timescales:

```text
human editing / preview
        -> canonical command selection
        -> writer-owned authoritative re-read
        -> pure Movement admission
        -> staged typed publication
        -> atomic authority switch
```

Preview does not grant write authority. Publication re-reads current Actual evidence and current Locus new-write policy under writer ownership before admission.

Collector-local Effect identity is now canonicalized inside `MovementAdmission.admit?`. Temporary EffectKeys disappear unless explicit Relation evidence references them, so preview and authoritative publication ask the same semantic admission boundary about the same canonical draft shape.

The line CLI remains visibly separate because it is an explicit low-level entrance that calls the Movement publisher directly. The high-level TUI path goes through `HouseholdCommand`.

## First map-driven refactoring result

The first detailed map produced concrete compression, not only documentation.

Resolved from the first `10.2` / `10.3` audit:

1. Sparse Effect identity moved from `MovementPublisher` into pure `MovementAdmission`. The publisher no longer owns one semantic draft transformation that preview skipped.
2. `MovementAdmission.Admitted` was reduced to `world + eventId`; relation/discharge deltas and a duplicate Event value were not independent result information in the normalized single-file publisher.
3. `ActualAuthority.movementWorld` now owns the pure `ActualEvidence + current Locus policy -> MovementAdmission.World` representation boundary, removing duplicated world assembly while preserving separate authorities.
4. A regression qualifies the counterexample that revealed the seam: two ordinary Effects may share one collector-local temporary key when no Relation earns that identity, and admission must erase the key before Event construction.

Still-open audit questions:

1. `Loam.Tui.Record.draft?` validates a draft, then TUI preview calls `MovementAdmission.admit?`, whose first step validates the canonical draft again. Existing callers/tests use `draft?` as an independently validated constructor, so the duplicate check is retained until that contract is deliberately redesigned.
2. TUI publication goes through `HouseholdCommand.record`; the explicit line CLI calls `MovementPublisher.publishDraftWithPreview` directly. That asymmetry is currently documented policy, not automatically a bug.
3. `publishDraftWithPreview` still carries a frontend callback inside the publisher even though the current line CLI does not offer a user decision after that callback. This remains a candidate for a later entrance-boundary audit.

The map is expected to change when an audit is resolved. It should describe the smallest justified production path, not fossilize an older implementation.

## Audit rule

When the map feels wrong, do not immediately redraw it to match the code. Ask:

1. Is the map missing a genuinely independent meaning?
2. Is the code carrying a distinction that the map cannot justify?
3. Is a retained fact actually derivable?
4. Are two equal-shaped things being merged even though their authority differs?
5. Does an Ada package boundary correspond to an independent reason to change?

The tension between code and map is useful evidence.

## Scope

This is a design/navigation artifact. It is not canonical household-data authority and does not replace the production Lean model.

A selected diagram may later become an Ada/SPARK code-generation source, but only after the represented boundary is stable enough that generated code would be an improvement over keeping the diagram observational. Until then, the map's job is to make the machine inspectable by both the repository-aware AI and the human looking at DRAKON Editor.
