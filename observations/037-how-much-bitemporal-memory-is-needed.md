# Observation 037 — How Much Bitemporal Memory Is Needed?

## Question

Observation 036 combined two LOAM structures:

```text
valid time + learned time
correction frontier + whole-frontier Resolution
```

and showed that the same valid coordinate can have several historically accurate knowledge-time views:

```text
t0 -> {c0}
t1 -> {kA}
t2 -> {kA, kB}
t3 -> {r0}
```

That raises a different question:

> Must the system retain every distinction in the knowledge history, or can some histories be merged without losing the future questions we care about?

This is the bitemporal version of LOAM's earlier memory-quotient question.

## Why J only

Observation 029 already proved the general monotonicity law in Lean:

> adding genuinely distinguishing future questions can only preserve or refine an observational quotient; it cannot make previously distinguishable states equivalent.

So another Lean theorem would currently repeat an existing law rather than add a new answer.

The new question is concrete quotient geometry over a small bitemporal history space. J is the smallest tool that makes those equivalence classes visible directly.

No Alloy relation search is needed. No TLA+ transition property is new here. miniKanren adds no distinct inverse-synthesis result.

## Bounded history space

The valid coordinate is fixed:

```text
valid time = 0
```

`c0` is already known at knowledge time 0.

Three later knowledge times are available:

```text
t1, t2, t3
```

and each may admit at most one new interpretation:

```text
kA  correction of c0
kB  independent correction of c0
r0  Resolution of {kA, kB}
```

The fixed parent graph is:

```text
c0 <- kA
c0 <- kB

kA \
    r0
kB /
```

`kA` and `kB` may be learned at any distinct later times or may remain absent. `r0` may appear only after both Corrections have already been learned.

Under those constraints there are exactly **15 admissible learned-event schedules**.

## Derived frontier timeline

Each raw schedule projects to an exact correction frontier at each knowledge time.

Frontier codes in the J experiment are:

```text
0 = {c0}
1 = {kA}
2 = {kB}
3 = {kA, kB}
4 = {r0}
```

For example:

```text
schedule: kA@t1, kB@t2, r0@t3

frontier t1 = {kA}
frontier t2 = {kA, kB}
frontier t3 = {r0}
```

A coarser observer can instead ask only whether each frontier is settled or conflicting.

## Nested future vocabularies

The experiment compares six nested vocabularies:

```text
V0  ask nothing

V1  ask only:
      is the current frontier a conflict?

V2  ask:
      what is the exact current frontier?

V3  V2 + ask settled/conflict kind at every knowledge time

V4  V3 + ask the exact frontier at t2

V5  V4 + ask the exact frontier at t1
      = exact frontier timeline for t1..t3
```

`t0` is fixed at `{c0}`, so asking it adds no distinction in this bounded space.

Two histories are equivalent for a vocabulary exactly when all questions in that vocabulary return the same answers.

## Observed J result

The J enumeration produced exactly:

```text
15 admissible histories

V0  1 class
V1  2 classes
V2  5 classes
V3  6 classes
V4  9 classes
V5 15 classes
```

or compactly:

```text
1 2 5 6 9 15
```

The observed class sizes include:

```text
V2 current exact frontier
  1 2 3 3 6

V4 current + exact t2 frontier
  1 1 1 2 2 2 2 2 2

V5 full exact frontier timeline
  1 1 1 1 1 1 1 1 1 1 1 1 1 1 1
```

A separate non-nested observer that asks only settled/conflict kind over the whole timeline needs only:

```text
4 classes
```

So exact identity through time is substantially more discriminating than merely remembering whether the interpretation was settled or conflicting.

## Concrete insufficiency witnesses

Current exact frontier alone does not recover an earlier exact frontier.

For example:

```text
history A:
  kA learned at t1

history B:
  kA learned at t2
```

Both end at:

```text
current frontier = {kA}
```

but differ at t1:

```text
history A at t1 = {kA}
history B at t1 = {c0}
```

Likewise, exact t2 plus current frontier does not recover exact t1. The two sibling-arrival orders:

```text
kA@t1, kB@t2
kB@t1, kA@t2
```

both have:

```text
t2      = {kA, kB}
current = {kA, kB}
```

while their t1 frontiers differ.

Both insufficiency witnesses are checked directly by the J script.

## Finding

The bounded conclusion is:

> There is no single context-free amount of bitemporal history that must be remembered. The minimal observational memory grows with the as-of vocabulary the future is allowed to ask.

The same 15 histories collapse to only five classes when the future asks for the exact **current** frontier and nothing historical.

But when the future may ask the exact frontier at every knowledge time in this bounded world, all 15 schedules become distinguishable.

This sharpens the earlier LOAM maxim:

```text
safe forgetting is relative to future vocabulary
```

into a temporal form:

```text
safe forgetting of the past
is relative to which past views
future queries are allowed to recover
```

There is therefore an explicit semantic cost to auditability. Allowing more exact `as-of knowledge time` questions can require more distinctions to survive in memory.

At the same time, the `4 classes` result for the kind-only timeline shows that preserving **some** history does not imply preserving exact historical identity.

## Semantic quotient versus storage encoding

This experiment measures semantic distinguishability, not bytes.

Even when V5 has 15 singleton classes, an implementation need not store a literal table of every knowledge-time frontier. A change-point representation or another compact encoding may preserve exactly the same answers.

So there are two different compression questions:

```text
semantic compression
  which histories may become indistinguishable?

representation compression
  how compactly can the required distinctions be encoded?
```

Observation 037 addresses only the first.

## Important boundary

This bounded world is intentionally unusually clean:

- every admitted interpretation changes the exact frontier;
- event meanings are fixed;
- parent relations are fixed;
- there is only one valid coordinate;
- there are only three later knowledge times;
- there are no source/provenance fields invisible to the frontier;
- there are no duplicate or semantically redundant observations.

Because of that, the exact full frontier timeline distinguishes every raw schedule here.

That must **not** be generalized into:

```text
full event history is always required
```

A richer real history can contain distinctions the selected frontier vocabulary never observes, and those may still be safely forgotten.

## Tool choice

**J only.**

The general vocabulary-monotonicity theorem already exists in Observation 029's Lean proof. Observation 037 is a concrete temporal quotient experiment rather than a new theorem.
