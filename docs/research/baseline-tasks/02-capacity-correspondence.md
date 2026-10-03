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
the pinned revision, including `AGENTS.md`, `docs/AI_WORKBENCH.md`, pinned
source, pinned tests, and pinned research owners.

The task statement below is the complete issue context needed for the baseline.
Do **not** fetch issue #700, its comments, PR discussion, commit metadata, or
commit diffs.

Use only repository file contents fetched with the explicit pinned revision.
Do not use default-branch search snippets as evidence. Prefer following exact
paths, imports, and links from already-open pinned files. If an unpinned search is
unavoidable for path discovery, do not rely on its snippet and re-open the exact
file at the pinned revision before using any fact.

If forbidden or later text is exposed at any point, stop treating the run as a
clean control and report it as contaminated.

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

The first baseline attempt exposed two leakage channels: commit metadata that
included later diff text, and issue comments not safely bounded to the pinned
revision. Those channels are now explicitly prohibited. This note describes
control hygiene only; it does not reveal the skill-arm answer.

After a clean baseline answer is complete, it may be compared against Trial 02 by
a different review step.
