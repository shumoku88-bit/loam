# Semantic audit SA-005 — Practical Core public surface

Status: **AUDIT VERDICT COMPLETE — no semantic Core change authorized**

Parent ledger: `docs/research/SEMANTIC_AUDIT_LEDGER.md`

Audit checkpoint: `acdafe64a231a0a115c79bd47ece6796a86a0dc4`

## Question

Does `Loam/Core.lean` define the real public semantic surface of production Core, or has it become a historical umbrella whose import list should not be interpreted as the concept boundary?

The target is not to make import counts line up. The target is to prevent a build/qualification convenience from becoming a false ontology or a broad dependency that hides the actual Core modules each feature needs.

## Current shape

Physical `Loam/Core/` contains 30 modules.

`Loam/Core.lean` imports 24 modules and describes itself as the entry point for the practical Lean domain core.

The six physical Core modules not imported by that umbrella are:

```text
ActualReversal
FiniteKeyed
Scheduled
ScheduledMemory
ScheduledRouting
ScheduledTerminal
```

These omissions do not form one semantic class.

- `FiniteKeyed` is deliberately internal shared representation mechanics.
- `ActualReversal` is independently meaningful production evidence and is imported directly by its publisher and persistence boundary.
- `ScheduledMemory`, `ScheduledRouting`, and `ScheduledTerminal` are directly consumed by production Application, Persistence, Publisher, CLI, and TUI code.
- `Scheduled` is the small underlying Scheduled fact imported by those family modules.

Therefore `Core.lean` is not an authoritative inventory of independent Core concepts.

## Historical evidence

`Core.lean` was introduced by PR #66 (`refactor(lean): separate practical core from observations`) as a boundary between practical implementation and the historical Observation suite. Its first version contained no imports at all; it was primarily a direction-setting layer boundary.

Later work gradually added imports to the umbrella.

The boundary is historically contingent rather than semantically derived:

- PR #255 explicitly exposed `ActualValidityHistory` through the practical Core umbrella.
- PR #256 deliberately kept the umbrella unchanged while adding `Scheduled` and `ScheduledMemory`. The PR explains that changing broad wrapper/build surfaces unnecessarily triggered historical CI; keeping the existing executable and wrapper surface small was a compression decision for that slice.
- Later Scheduled lifecycle/routing modules and `ActualReversal` became real production semantics while remaining outside the umbrella.
- Recent Core retirement work still edits `Core.lean`, so the file remains a maintained build/aggregation surface rather than dead text.

The present 24/30 split therefore records development history and build pressure as well as semantics. It must not be read as “24 public concepts, six private concepts.”

## Actual dependency style

Production code usually imports the narrow Core module it needs.

Examples:

```text
Application/ScheduledInspection -> ScheduledMemory + ScheduledTerminal
Persistence/ScheduledLifecyclePersistence -> ScheduledTerminal
ScheduledRoutingPublisher -> ScheduledRouting
Persistence/ActualReversalPersistence -> ActualReversal
ActualReversalPublisher -> ActualReversal
```

This is the healthier architecture: module-level dependencies expose the real semantic and mechanical requirements of each feature.

The broad `Loam.Core` umbrella is visibly imported by the top-level `Loam.lean` library umbrella and by at least `Loam/Tui/ScheduledRouting.lean`. The latter also directly imports `Loam.Core.ScheduledRouting`, making the broad import a strong candidate for redundant dependency surface.

## Verdict

### V1 — Do not complete the barrel merely to make counts match

Adding the six omitted modules just because physical Core has 30 files would turn a historical/build convenience into an asserted public ontology without evidence.

`FiniteKeyed` in particular is intentionally shared mechanics rather than a household concept.

### V2 — Do not use `Core.lean` as the semantic public-contract definition

The file should not answer “what concepts exist in Core?” or “which concepts are public?”

Those questions should be answered by independent information, authority, and observable behavior, not by membership in an import barrel.

### V3 — Prefer narrow feature imports

Production Application, Persistence, Publisher, CLI, and TUI modules should continue importing the exact Core modules they require.

A broad `import Loam.Core` inside feature code is a topology smell because it hides accidental dependencies and makes future Core growth silently widen that feature's compile surface.

### V4 — Keep the umbrella for now, but treat it as non-authoritative aggregation/qualification surface

`Loam.lean` currently imports `Loam.Core`, and `lean_lib Loam` is the default library target. The umbrella therefore still has build/qualification value.

Deleting it now would be topology churn without semantic gain.

The more accurate interpretation is:

```text
Core modules                 = actual semantic/mechanical units
narrow imports               = actual feature dependency graph
Loam/Core.lean               = non-authoritative aggregation convenience
Loam.lean                    = whole-library qualification umbrella
```

## Small implementation candidate

The first concrete subtraction should be narrow and falsifiable:

1. remove `import Loam.Core` from `Loam/Tui/ScheduledRouting.lean`;
2. retain its explicit `import Loam.Core.ScheduledRouting` and existing Application/Review imports;
3. run the exact TUI/build qualification;
4. if elaboration fails, add only the specific missing Core module rather than restoring the broad umbrella.

This directly tests whether the broad Core dependency carries any real requirement.

A separate docs-only cleanup may later reword `Core.lean` / `Loam.lean` so the file is not described as the authoritative public semantic entry point.

## Formal/topological test

SA-005 is primarily an import-graph problem rather than a household-state problem, so Alloy/TLA+ would add little here.

Use the module dependency DAG instead:

- broad umbrella nodes should not sit inside feature dependency paths when narrower nodes suffice;
- removing an umbrella edge must preserve elaboration and executable behavior;
- if one missing direct edge appears, add exactly that edge;
- no semantic type, persisted byte, authority, or household answer should change.

The deletion criterion is therefore compile/reachability equivalence rather than state-space equivalence.

## Final classification

```text
Loam/Core.lean
  semantic authority:      NO
  concept inventory:       NO
  build aggregation value: YES
  feature import target:   PREFER NO
  delete now:              NO
  narrow consumers:        YES
```

SA-005 is audit-complete at this checkpoint. The result supports one small dependency subtraction, not a Core redesign.
