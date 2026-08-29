# Observation 006 — Relational Summary Search

## Question

Can a sufficient retained-state summary be searched from a small future operation vocabulary instead of proposed by hand?

Observation 005 left four history-visible classes behind one identical current placement:

```text
history   u0 stayed   u1 stayed
H00       false       false
H10       true        false
H01       false       true
H11       true        true
```

The new question is not whether one already-chosen summary is sufficient. It is whether sufficiency itself can become a relation that may be queried in more than one direction.

## Why miniKanren enters here

Earlier observations gave each tool a distinct job:

- Alloy produced possible structures and collisions.
- J exposed what an aggregate projection forgets.
- TLA+ checked future-visible distinctions across reachable behavior.

Observation 006 is the first question that asks for an unknown satisfying a relation:

> given a future vocabulary, which candidate summaries preserve all distinctions visible to that vocabulary?

The same relation can also be run backwards:

> given a candidate summary, which future vocabularies can it preserve?

That reverse query is the reason for introducing miniKanren rather than another ordinary predicate loop.

## Deliberately finite search space

This experiment does **not** synthesize arbitrary programs or arbitrary state representations.

The candidate grammar is intentionally tiny:

```text
constant
u0
u1
count
pair
```

Their meanings over the four Observation 005 histories are:

- `constant`: forget every history distinction;
- `u0`: retain only whether U0 stayed continuously at Target;
- `u1`: retain only whether U1 stayed continuously at Target;
- `count`: retain only how many of U0/U1 stayed;
- `pair`: retain both Boolean distinctions.

The future vocabulary is also finite:

```text
none
u0-only
u1-only
both
```

A candidate summary is sufficient when it never collapses a pair of histories that some operation in the chosen vocabulary can distinguish.

All six unordered pairs of the four history classes are checked.

## Executed environment

GitHub Actions executed the experiment with:

```text
Racket 9.3, CS, full, x64
minikanren package -> takikawa/minikanren commit 51a18cf82834fb1af7a0dc41af4b7894099a3d05
```

The miniKanren job completed successfully.

## Forward query

Query:

> Which summaries are sufficient for this future vocabulary?

Executed results:

```text
u0-only sufficient summaries: (u0 pair)
u1-only sufficient summaries: (u1 pair)
both sufficient summaries: (pair)
```

For a vocabulary that can ask only about U0 continuity, retaining U0 alone is enough, while retaining both bits also works.

The symmetric result holds for U1.

When the vocabulary can independently ask both questions, only `pair` from the candidate grammar is sufficient.

This agrees with Observation 005's four visible equivalence classes.

## Reverse query

The same sufficiency relation was then queried in the other direction.

Query:

> Which future vocabularies can this proposed summary preserve?

Executed results:

```text
count preserves vocabularies: (none)
u0 preserves vocabularies: (none u0-only)
```

`count` distinguishes zero, one, and two continuously-staying Units, but it merges H10 and H01. Therefore it cannot preserve either identity-sensitive operation.

The `u0` summary preserves an empty vocabulary and the U0-only vocabulary, but not U1-only or both.

## Finding

For this finite experiment, sufficiency can be expressed as a relation between:

```text
future vocabulary <-> retained summary
```

and queried in either direction.

The important result is not merely that `pair` wins for two questions. Observation 005 already strongly suggested that.

The new result is that **the boundary between future vocabulary and retained state can itself be made executable and reversible**.

Instead of asking only:

> Is this state representation enough?

we can also ask:

> What state representations would be enough for these operations?

and:

> What operations remain sound if this is all the state we retain?

## Boundary of the claim

This is finite candidate search, not general state synthesis.

The experiment does not yet derive the candidate grammar itself, prove minimality for arbitrary histories, or establish that household software should use these particular continuity questions.

It shows only that once a finite set of history classes, candidate summaries, and observable operations is supplied, miniKanren can make their sufficiency relation bidirectional.

## Next question

The next interesting boundary is no longer simply “add more candidates.”

Two possibilities are now visible:

1. make the candidate summary structure itself more relational, so miniKanren assembles projections rather than selecting from five named candidates; or
2. ask whether the pattern observed in 004–006 has matured into a general statement worth proving in Lean 4.

Do not assume either is necessary yet. First ask which move can produce a new counterexample or distinction rather than merely restating the current result.
