# Baseline task 06 — Bounded history versus same stored scalar

Status: **sealed control task**

Pinned repository revision:

```text
c376a6566f1ffe9af39d85c3afa79a71b27f35ec
```

## Control condition

Run this task in a fresh isolated AI context that has not read any file under:

```text
docs/research/verified-skills/
```

and has not been exposed to the Trial 06 skill-arm result.

Use only repository file contents fetched with the explicit pinned revision above
as repository evidence.

Do not fetch or rely on:

- commit metadata or commit diffs;
- issue / PR bodies, comments, reviews, or current discussion;
- default-branch code-search snippets;
- later commits;
- any Trial 06 result from another session, summary, memory, or shared context.

If any forbidden or other-arm result is already visible in the session context,
mark the run contaminated.

## Task

Audit this concrete current-quantity / bounded-history transition.

A coordinate `cash / jpy` has an existing exact current anchor observed against
one reflected-root cut:

```text
reflected roots: [E0]
retained assertion: cash / jpy = -100
```

The same coordinate also has active `BoundedHistorySupport` beginning on a
qualified calendar day.

Later, retained Actual acquires a new stable Event `E1` after the anchor
observation. For this task, assume `E1` contributes:

```text
cash / jpy = -20
```

No new exact reconciliation has yet been published.

The household then makes a fresh exact observation:

```text
cash / jpy = -100
```

and submits it through the ordinary `CurrentQuantityAnchor` publication path.

Notice that the newly observed scalar is numerically equal to the old retained
anchor assertion, but may or may not equal the ordinary correction-aware current
quantity derived from that retained assertion.

Determine the smallest justified behavior.

The audit must answer from pinned production source and existing pinned
qualification evidence:

1. What exact current quantity does the existing anchor justify immediately
   before the fresh observation, and why?
2. What semantic claim does `BoundedHistorySupport` make for this coordinate,
   and what does it explicitly *not* store?
3. For purposes of deciding whether bounded historical support may survive a
   fresh exact observation, which values must be compared:
   - the new observed scalar versus the old retained assertion scalar;
   - the new observed scalar versus the correction-aware current quantity;
   - or something else?
4. Should the fresh observation `-100` be accepted while bounded historical
   support remains active? Explain from the actual publication path.
5. Would a fresh observation equal to the correction-aware current quantity
   behave differently? If so, describe the resulting retained anchor semantics.
6. At what point in the publication flow is the bounded-history reconciliation
   guard evaluated relative to anchor replacement, presence refinement, and file
   writes?
7. If the fresh observation disagrees with the correction-aware current quantity,
   what existing repair choices are available? Distinguish:
   - correcting retained Actual;
   - moving/removing bounded historical support;
   - silently rebasing or overwriting the anchor.
8. After bounded historical support is explicitly removed, what authority does a
   later successful exact observation create, and what historical completeness
   claim does it *not* recreate?
9. Could equality with the old stored assertion, a displayed scalar, or a
   newly-entered scalar become a second authority that bypasses the
   correction-aware current answer?
10. Which ownership / persistence boundaries make the bounded-history check
    coherent with the Actual and anchor image? Does this require one generic
    multi-authority transaction?
11. What failure behavior is relevant for malformed bounded-history evidence,
    stale anchor roots, support overlap, or publication failure?
12. What is the smallest existing executable / proof / research evidence that
    qualifies this seam? Does the current test suite directly cover the specific
    case where the new observation equals the old stored assertion but differs
    from the correction-aware current quantity? If not, is one focused
    executable regression justified? Is new Lean proof / Alloy / TLA+ work
    required?

Do not redesign the current-balance or historical subsystem. Do not introduce a
generic support framework, anchor revision history, historical quantity cache, or
transaction layer merely to make the transition easier to describe.

## Required output

Return a compact audit containing:

- the exact pinned evidence surfaces inspected first;
- the semantic owner of exact current quantity and bounded historical support;
- the pre-observation correction-aware current quantity;
- the exact comparison used by the bounded-history publication guard;
- accept/refuse behavior for the fresh `-100` observation;
- behavior for a fresh observation equal to the correction-aware current answer;
- repair / authority / no-second-authority semantics;
- publication ordering and ownership/persistence topology;
- one or more concrete falsifiers that would expose an incorrect implementation;
- whether new executable or formal qualification work is required;
- a scoped verdict for:
  - retained semantic support;
  - bounded-history interaction;
  - exact-current authority;
  - publication / persistence topology.

Record any materially wrong analytical path that required backtracking. Do not
invent one if none occurred.

## Isolation note

This file contains only the shared sealed task and experiment hygiene. It
intentionally contains no expected conclusion and no skill-arm result.
