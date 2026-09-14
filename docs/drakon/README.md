# LOAM System Map v0.1

Purpose: a human-scale architecture navigator for rebuilding and reviewing LOAM with DRAKON + Ada/SPARK.

This is deliberately not a mirror of every Lean file. The first map stays small enough to inspect visually.

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
`-- 08 Formal Evidence
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

## Reading rule

The top-level production path is:

```text
Human Entrances
    -> Commands / Questions
    -> Application
    -> Core Facts
    -> Authority / Persistence
    -> Projections / Answers
```

Formal evidence is intentionally off that runtime path. Lean, Alloy, J, and TLA+ observe, challenge, and qualify the design; they are not production processing stages.

## Audit rule

When the map feels wrong, do not immediately redraw it to match the code. Ask:

1. Is the map missing a genuinely independent meaning?
2. Is the code carrying a distinction that the map cannot justify?
3. Is a retained fact actually derivable?
4. Are two equal-shaped things being merged even though their authority differs?
5. Does an Ada package boundary correspond to an independent reason to change?

That tension is the useful part of the map.

## Scope

This is a design/navigation artifact. It is not a canonical household-data authority and does not replace the production Lean model. Its job is to keep the whole machine visible while the Ada/SPARK implementation is explored.
