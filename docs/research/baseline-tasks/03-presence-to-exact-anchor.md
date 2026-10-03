# Baseline task 03 — Presence-only support to exact current quantity

Status: **sealed control task**

Pinned repository revision:

```text
0e5f8177e26b6329d1b12d1401bc23ae5ae2546c
```

## Control condition

Run this task in a fresh AI session / agent that has not read any file under:

```text
docs/research/verified-skills/
```

Do not inspect that directory during the baseline run.

Use only repository file contents fetched with the explicit pinned revision above
as repository evidence.

Do not fetch or rely on:

- commit metadata or commit diffs;
- issue / PR comments, reviews, or current discussion;
- current issue / PR bodies;
- default-branch code-search snippets;
- later commits.

For discovery, prefer paths, imports, references, and directory listings at the
pinned revision. If an unpinned search is unavoidable for locating a path, do not
use its snippet as evidence and re-open the exact file at the pinned revision
before using any fact.

If forbidden or later text is exposed, mark the run contaminated.

## Task

Audit this concrete current-balance transition:

> One `Locus × Measure` coordinate is currently supported only by
> `CurrentQuantityPresence`: the household knows it is present / nonzero, but
> does not know the exact amount.
>
> Later, the household observes an exact current quantity for that same
> coordinate through the ordinary `CurrentQuantityAnchor` publication path.
> The exact observed quantity may be nonzero **or exactly zero**.

Determine the smallest justified retained and publication behavior after the
successful exact observation.

The audit must answer, from the pinned production source and existing pinned
qualification evidence:

1. Which evidence family or families may still support that coordinate after the
   exact observation?
2. May the old presence-only evidence coexist with the exact anchor for the same
   coordinate, or must one be refined / removed / rejected?
3. Is exact zero a valid exact current answer, or does it collapse into
   unsupported / unknown / absent?
4. Which retained value is authoritative for the exact current quantity, and
   could any convenient derived or displayed value become a second authority?
5. How do correction-aware reflected-root/frontier semantics affect the old
   presence evidence and the new exact anchor?
6. What publication / persistence boundary prevents a successful write from
   leaving contradictory current-support evidence?
7. What should happen on failure or stale retained support?
8. What is the smallest existing test / proof / research evidence that qualifies
   the behavior? Is new Lean / Alloy / TLA+ work actually required?

Do not redesign the whole current-balance subsystem. Do not introduce a generic
support framework merely to unify types or files.

## Required output

Return a compact audit containing:

- the exact pinned evidence surfaces inspected first;
- the current owner(s) of presence-only and exact current support;
- the transition behavior for same-coordinate presence -> exact anchor;
- the exact-zero behavior;
- the overlap / authority / correction / publication semantics;
- one or more concrete falsifiers or counterexamples that would expose a wrong
  implementation;
- whether new formal work is required;
- a scoped verdict for:
  - retained semantic support;
  - exact-current authority;
  - publication / persistence topology.

Record any materially wrong analytical path that required backtracking. Do not
invent one if none occurred.

## Isolation note

This file contains only the control task and experiment hygiene. It intentionally
contains no expected conclusion, no skill text, and no skill-arm result.

After the baseline is complete, a separate skill-arm run may use the same pinned
revision and task statement for comparison.
