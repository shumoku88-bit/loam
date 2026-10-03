# Baseline task 04 — Exact anchor across a later correction-root change

Status: **sealed control task**

Pinned repository revision:

```text
c4637574af4c0e289b5b0c6fca9b0eeaaa392992
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

Audit this concrete current-quantity transition:

> A `CurrentQuantityAnchor` group already supports one or more
> `Locus × Measure` coordinates and carries the reflected Event correction roots
> that were stable when the exact quantities were observed.
>
> Later, an ordinary Actual Correction is published. The resulting correction
> graph changes which Event ids are stable correction roots, so at least one Event
> id retained in that existing anchor group's `reflectedRoots` is no longer a
> current stable root. One concrete way this can happen is that an Event which was
> previously an independent root later becomes the replacement endpoint of a
> correction rooted at another Event.
>
> After that correction, the household may:
>
> 1. read the current exact quantity before any new reconciliation; and/or
> 2. observe a fresh exact quantity and attempt the ordinary
>    `CurrentQuantityAnchor` publication path again.

Determine the smallest justified behavior for that stale retained anchor state.

The audit must answer, from pinned production source and existing pinned
qualification evidence:

1. Does the previously retained anchor still justify an exact current quantity
   after one of its reflected roots ceases to be a stable correction root?
2. May a reader or publisher silently reinterpret, rebase, or replace the old
   reflected-root cut merely because the resulting scalar quantity appears
   plausible or unchanged?
3. What does the ordinary correction-aware read path do with that retained
   anchor?
4. What does the ordinary `CurrentQuantityAnchor` update/publication path do
   if a fresh exact observation is supplied while stale retained anchor support
   still exists?
5. If the retained anchor contains multiple reconciliation groups, how does stale
   root support in one group affect re-observation of a coordinate in that group
   or in another group?
6. Which authority owns the correction transition, which authority owns the
   retained anchor, and what ownership/persistence boundaries do or do not make
   them one atomic semantic update?
7. Is there an existing explicit repair, reconstruction, replacement, migration,
   or retirement path for the stale retained support? If not, distinguish a
   genuine product gap from behavior that is intentionally fail-closed.
8. Could a displayed/derived current quantity, or a newly observed scalar alone,
   become a second authority that bypasses the stale provenance problem?
9. What should happen on malformed correction evidence, stale retained roots, or
   publication failure?
10. What is the smallest existing test / proof / research evidence that qualifies
    the behavior? Is new focused executable evidence, Lean proof, Alloy, or TLA+
    work actually required?

Do not redesign the whole current-balance subsystem. Do not introduce a generic
support framework, anchor-history graph, or transaction layer merely to make the
case easier.

## Required output

Return a compact audit containing:

- the exact pinned evidence surfaces inspected first;
- the current owner(s) of Actual correction semantics and exact anchor support;
- the stale-root read behavior;
- the fresh re-observation/publication behavior;
- the authority / correction / retained-provenance / persistence semantics;
- whether one stale group affects unrelated retained groups or updates;
- any explicit repair path that already exists, or a scoped statement that it is
  absent;
- one or more concrete falsifiers or counterexamples that would expose a wrong
  implementation;
- whether new formal or executable qualification work is required;
- a scoped verdict for:
  - retained semantic support;
  - exact-current authority;
  - correction interaction;
  - publication / persistence topology.

Record any materially wrong analytical path that required backtracking. Do not
invent one if none occurred.

## Isolation note

This file contains only the control task and experiment hygiene. It intentionally
contains no expected conclusion, no skill text, and no skill-arm result.

After the baseline is complete, a separate skill-arm run may use the same pinned
revision and task statement for comparison.
