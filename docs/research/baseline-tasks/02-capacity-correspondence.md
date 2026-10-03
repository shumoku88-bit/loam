# Baseline task 02 — Capacity retained meaning and topology

Status: **sealed control task**

Pinned repository revision:

```text
a2a4018168560cabb47a92f3e76c65b0feddb7c7
```

## Control condition

Run this task in a fresh AI session / agent that has not read any file under:

```text
docs/research/verified-skills/
```

Do not inspect that directory during the baseline run.

Use the ordinary LOAM development entrances and repository evidence available at
the pinned revision, including `AGENTS.md`, `docs/AI_WORKBENCH.md`, source,
tests, research owners, and issue #700.

Do not use later commits to answer the task.

## Task

Audit issue #700 candidate 4:

> Do `CapacityMovement` and `CapacityEffective` still require distinct retained
> meanings and/or distinct physical backing topology on the pinned revision?

Determine the smallest justified current boundary.

Do not propose a generic Capacity framework merely to reduce type count, file
count, or repeated syntax.

## Required output

Return a compact audit containing:

1. the exact repository evidence surfaces inspected first;
2. the current semantic relationship between `CapacityMovement` and
   `CapacityEffective`;
3. whether either meaning can be reconstructed from the other without losing an
   intended read/write/safety answer;
4. the current physical authority / persistence topology;
5. any divergence witness or counterexample that decides the semantic question;
6. whether new Lean / Alloy / TLA+ work is actually required;
7. a final scoped recommendation: KEEP / MERGE / ALREADY COMPRESSED / NEEDS MORE
   EVIDENCE, separately for semantic meaning and physical topology.

Also record any materially wrong path that required backtracking. Do not invent a
wrong turn if none occurred.

## Isolation note

This file contains only the sealed baseline task. It intentionally contains no
skill-arm result, no expected answer, and no comparison rubric beyond the fields
needed to compare the two runs later.

After the baseline answer is complete, it may be compared against Trial 02 by a
different review step.
