# LOAM System Map v0.2

Purpose: a shared architecture navigator for reviewing LOAM with DRAKON and for exploring an Ada/SPARK implementation without losing the whole-system shape.

The map now has two levels:

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

The detailed Record Movement diagrams use real DRAKON icon kinds such as `if`, `insertion`, `action`, `beginend`, and refusal exits. The current diagrams are architecture observations: their English icon text is not yet Ada source and the `.drn` is not yet a code-generation authority.

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

The line CLI remains visibly separate because it is an explicit low-level entrance that calls the Movement publisher directly. The high-level TUI path goes through `HouseholdCommand`.

## First audit seams, not conclusions

The first detailed map already exposes three useful seams to inspect before changing production code.

1. `Loam.Tui.Record.draft?` validates a draft, then TUI preview calls `MovementAdmission.admit?`, whose first step validates the draft again. This may be redundant in the preview path, or it may be the correct cost of keeping `draft?` useful as an independently validated constructor. Do not remove either check until caller pressure is examined.

2. `ActualAuthority.loadSelectedWorld?` and `MovementPublisher` both combine Actual evidence with current Locus admission policy into a `MovementAdmission.World`. The publisher also needs the complete original `ActualEvidence` so corrections and reversals survive generation replacement. A shared world-construction helper may be possible, but replacing the publisher load with `loadSelectedWorld?` directly would lose information it still needs.

3. TUI publication goes through `HouseholdCommand.record`; the explicit line CLI calls `MovementPublisher.publishDraftWithPreview` directly. That asymmetry is currently documented policy, not automatically a bug. Keeping both routes visible makes it possible to revisit whether the distinction still earns its cost.

These are map-generated audit questions. They are not refactoring decisions.

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
