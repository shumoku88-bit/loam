# Baseline task 05 — Partial re-observation from a legacy v1 anchor

Status: **sealed control task**

Pinned repository revision:

```text
8a73572059bc811b6e035d1912cf0e8eef06f7b8
```

## Control condition

Run this task in a fresh isolated AI context that has not read any file under:

```text
docs/research/verified-skills/
```

and has not been exposed to the Trial 05 skill-arm result.

Use only repository file contents fetched with the explicit pinned revision above
as repository evidence.

Do not fetch or rely on:

- commit metadata or commit diffs;
- issue / PR bodies, comments, reviews, or current discussion;
- default-branch code-search snippets;
- later commits;
- any Trial 05 result from another session, summary, memory, or shared context.

If any forbidden or other-arm result is already visible in the session context,
mark the run contaminated.

## Task

Audit this concrete current-quantity transition.

A persisted version-1 `CurrentQuantityAnchor` image contains one reflected-root
cut and two exact assertions observed together:

```text
reflected roots: [E0]

debt / jpy = -70
cash / jpy =  25
```

Later, retained Actual acquires a new stable Event `E1` after that observation.
For this task, assume its net effects on the two coordinates are:

```text
debt / jpy = -5
cash / jpy = +5
```

No new exact reconciliation has yet been published.

The household then observes only:

```text
debt / jpy = -75
```

and submits that one coordinate through the ordinary
`CurrentQuantityAnchor` publication path. It does **not** re-observe cash.

Determine the smallest justified retained and publication behavior.

The audit must answer from pinned production source and existing pinned
qualification evidence:

1. What semantic evidence shape does the persisted v1 image decode into before
   any new publication?
2. Before the debt re-observation, what current quantities should the ordinary
   anchor read derive for debt and cash, and why?
3. When only debt is re-observed, which coordinate(s) move to the fresh current
   reflected-root cut?
4. What retained assertion and reflected-root cut should continue to support cash?
5. Must the cash answer remain sensitive to `E1` even though debt is moved to a
   newer reconciliation group?
6. After successful publication, may debt and cash live in distinct anonymous
   groups with different reflected-root cuts?
7. Does the persisted file remain v1, become v2, or require a separate explicit
   migration operation? Distinguish wire-format upgrade from household semantic
   authority.
8. Is any stable anchor/group identity, revision history, or historical
   observation record created by this transition?
9. Could the newly observed debt scalar, a displayed current quantity, or a v2
   serialization become a second quantity authority?
10. What happens if publication instead moves all assertions from the old v1
    group to the new cut even though cash was not re-observed?
11. What overlap, malformed persistence, stale-root, or publication-failure
    behavior is relevant to this seam?
12. What is the smallest existing test / proof / research evidence that qualifies
    the behavior? Is one new focused executable test justified, or is existing
    evidence already sufficient? Is new Lean proof / Alloy / TLA+ work required?

Do not redesign the current-balance subsystem. Do not introduce stable anchor
identity, an anchor revision graph, generic migration infrastructure, or a generic
support framework merely to make the transition easier to describe.

## Required output

Return a compact audit containing:

- the exact pinned evidence surfaces inspected first;
- the current semantic owner and persistence owner;
- v1 decode semantics;
- pre-reconciliation debt and cash answers;
- the partial re-observation behavior;
- the post-publication group/cut shape;
- the v1 -> v2 persistence behavior;
- authority and no-second-authority semantics;
- one or more concrete falsifiers that would expose an incorrect
  implementation;
- whether new executable or formal qualification work is required;
- a scoped verdict for:
  - retained semantic support;
  - partial re-observation;
  - persistence compatibility;
  - exact-current authority.

Record any materially wrong analytical path that required backtracking. Do not
invent one if none occurred.

## Isolation note

This file contains only the shared sealed task and experiment hygiene. It
intentionally contains no expected conclusion and no skill-arm result.
