# Observation 036 — Can Corrected Knowledge Stay Append-Only?

## Question

Observation 035 separated two time coordinates:

```text
valid time   = when a relation applies
learned time = when that relation becomes available to the system
```

Earlier Observations 022–023 separately established an append-only correction frontier:

```text
c0 <- kA
c0 <- kB

frontier = {kA, kB}
```

and append-only whole-frontier Resolution:

```text
kA \
    r0
kB /
```

This observation asks where those two threads meet:

> If later knowledge corrects or contradicts earlier knowledge about the same valid time, can the system preserve both the correction frontier and what was knowable at each earlier knowledge time without overwriting history?

## Why TLA+

The static correction graph is already known from Alloy in Observations 022–023.

The missing question is temporal:

```text
t0: c0 is known

t1: learn kA, correcting c0

t2: learn kB, also correcting c0

t3: append r0, resolving {kA, kB}
```

The new observable is not just the final graph. It is the sequence of knowledge-time views:

```text
view(t0) = {c0}
view(t1) = {kA}
view(t2) = {kA, kB}
view(t3) = {r0}
```

J adds no distinct quantitative question here. Lean is not yet earned because no new general theorem is claimed. miniKanren adds no separate inverse-synthesis answer.

TLA+ is therefore the smallest tool that adds a genuinely new answer.

## Bounded model

All interpretations concern the same valid coordinate:

```text
valid time = 0
```

The bounded event identities are:

```text
c0  original interpretation
kA  correction of c0
kB  independent correction of c0
r0  resolution of {kA, kB}
```

with fixed parent relation:

```text
Parents(c0) = {}
Parents(kA) = {c0}
Parents(kB) = {c0}
Parents(r0) = {kA, kB}
```

The two Corrections may be learned in either order at knowledge times 1 and 2. At most one observation is admitted at each learned time.

Resolution is admitted only at knowledge time 3 and only when the current frontier is exactly:

```text
{kA, kB}
```

## Knowledge-time frontier

For any knowledge time `k`, the model first keeps only interpretations whose `learned <= k`, then derives the frontier among those interpretations.

So the query is effectively:

```text
Frontier(valid_time = 0, knowledge_time = k)
```

Later events are invisible to an earlier knowledge-time query even though they remain in the same append-only history.

## Positive properties

The primary TLC configuration checks:

1. type correctness;
2. event identities are not duplicated;
3. at most one observation is learned at each knowledge time;
4. each event keeps its fixed meaning;
5. every parent was already known when a child was learned;
6. once both sibling Corrections are known and no Resolution is known, the current frontier is exactly `{kA, kB}`;
7. once `r0` is learned, the current frontier is exactly `{r0}`;
8. history only extends;
9. appending later knowledge does not rewrite any earlier knowledge-time frontier.

## Boundary 1 — later learned means winner

A deliberately strong hypothesis says:

> When both `kA` and `kB` are known, whichever Correction was learned later is the unique current interpretation.

This would turn learned chronology into authority.

The intended counterexample is:

```text
t0: c0

t1: kA corrects c0

t2: kB also corrects c0
```

Even though `kB` arrived later, its parent relation does not make it a correction of `kA`.

The truthful frontier should remain:

```text
{kA, kB}
```

rather than silently selecting `kB`.

The expected invariant violation is:

```text
LaterLearnedCorrectionWins
```

The symmetric arrival order should have the same conflict frontier.

## Boundary 2 — later Resolution rewrites earlier conflict

A second deliberately strong hypothesis says:

> Once `r0` resolves the conflict, the earlier knowledge-time view at time 2 should also become `{r0}`.

But if knowledge time is an observable coordinate, the intended distinction is:

```text
knowledge time 2 -> {kA, kB}
knowledge time 3 -> {r0}
```

The later Resolution changes the current projection without changing what the system knew at knowledge time 2.

The expected invariant violation is:

```text
ResolutionRewritesPastConflict
```

## Intended interpretation

If the positive model holds and both boundaries fail, the bounded conclusion is:

> Correction ancestry and learned chronology are different relations. Learned-later does not by itself mean semantically-later, and a later Resolution need not rewrite the knowledge frontier that existed before it was learned.

The combined geometry becomes:

```text
                         knowledge time
                              ↑
                              │
valid time 0:   c0 -> {kA,kB} -> r0
                              │
                              └── each stage remains queryable as-of
                                  the knowledge available then
```

More precisely:

```text
append-only interpretation graph
              +
learned-time coordinate
              |
              v
frontier(valid time, knowledge time)
```

Chronology remains provenance. Parentage and whole-frontier Resolution determine correction structure.

## Important boundary

This observation gives each event a fixed meaning and fixed parents.

It does not yet ask:

- whether a later correction can itself be corrected;
- whether the learned-time record can be corrected;
- whether two observations learned at different times can carry different provenance or authority;
- whether a Resolution meaning must itself preserve a valid interval;
- how this two-time correction structure should be compressed for storage.

Those are separate pressure points.

## Tool choice

**TLA+ only.**

Alloy has already supplied the static correction/frontier geometry. This experiment uses TLA+ only for the new temporal composition.
