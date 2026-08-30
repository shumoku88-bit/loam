# Observation 035 — Does Knowing Need Another Time?

## Question

Observation 034 gave a neutral relation observation one time coordinate and found that one current relation cannot answer past, present, and future viewpoints without losing distinctions.

But Observation 034 deliberately identified two different questions:

```text
when the relation was learned

and

when the relation was valid
```

The next question is:

> If a relation may be learned after the time for which it was valid, do those two notions require distinct coordinates?

This observation still does not introduce `Price`, `ExchangeRate`, market authority, source trust, or conversion arithmetic.

## Why TLA+

The missing distinction is temporal and epistemic rather than arithmetic:

```text
time 0: nothing is known yet about valid time 0
advance
time 1: learn that r0 was valid at time 0
```

Alloy could place the two records side by side, but the pressure point is what a system could answer **before** and **after** the later observation arrives. J adds no distinct quotient question yet, and no reusable Lean theorem is claimed yet.

TLA+ therefore remains the smallest tool that adds a genuinely new answer.

## Bounded model

The model has three coordinates:

```text
0, 1, 2
```

and two neutral relation values:

```text
r0, r1
```

Each admitted observation contains both:

```text
[valid   |-> when the relation applies,
 learned |-> when it entered knowledge,
 value   |-> relation value]
```

For this experiment only:

```text
valid <= learned
```

So it admits present and retrospective observations but no prediction about a future valid time.

At most one observation is admitted for each valid time. This intentionally avoids correction/conflict semantics and isolates only the two-time question.

## Selected vocabulary

The central query is:

```text
Answer(validTime, knowledgeTime)
```

It asks:

> At knowledge time `knowledgeTime`, what could the system answer about relation-valid time `validTime`?

If the relevant observation had not yet been learned, the answer is `Unknown`.

## Positive properties

The primary TLC configuration checks:

1. type correctness;
2. at most one observation for each valid time;
3. validity never lies in the future relative to learning;
4. before an observation is learned, its valid-time answer is `Unknown`;
5. after it is learned, the corresponding valid-time answer is recoverable;
6. no answer is available before the valid time itself;
7. observation history only extends.

## Boundary 1 — one time coordinate is enough

The first deliberately strong hypothesis says:

```text
learned time = valid time
```

for every observation.

TLC found the minimal counterexample:

```text
time 0: no observation
advance
time 1: learn r0, valid at time 0
```

The invariant `ObservationTimeEqualsValidity` was violated at depth 3.

So the two coordinates can differ even in this tiny retrospective world.

## Boundary 2 — later knowledge does not change the past view

The second strong hypothesis says that for any past valid time, the answer available now must equal the answer available at that valid time itself:

```text
Answer(validTime, now)
  =
Answer(validTime, validTime)
```

TLC found the same three-state counterexample:

```text
time 0: no observation
advance
time 1: learn r0, valid at time 0
```

It separates:

```text
what was knowable at time 0 about time 0 = Unknown
what is knowable at time 1 about time 0 = r0
```

The invariant `RetrospectiveViewEqualsContemporaneousView` was violated at depth 3.

The past valid coordinate did not change. What changed is the knowledge available about it.

## Observed TLC result

TLC 2.19 with TLA+ tools 1.7.4 produced:

```text
positive model
  215 states generated
  215 distinct states
  depth 6
  no error

ObservationTimeEqualsValidity
  violated as intended
  depth 3
  witness: learned=1, valid=0, value=r0

RetrospectiveViewEqualsContemporaneousView
  violated as intended
  depth 3
  same late-observation witness
```

## Interpretation

The bounded conclusion is:

> A validity coordinate and a knowledge coordinate carry distinct observable information once the future vocabulary can ask both “what was true then?” and “what did we know then?”.

This refines the emerging LOAM time geometry:

```text
valid time     : when a relation applies
learned time   : when that relation becomes available to the system
```

and the query itself becomes two-dimensional:

```text
view(valid time, knowledge time)
```

A later observation can therefore change a retrospective **view of the past** without rewriting the past valid coordinate.

This is not merely a storage detail. Flattening the pair into one time coordinate loses an observable distinction:

```text
past fact coordinate
      !=
knowledge available at that moment
```

## Important boundary

This observation intentionally allows only one observation per valid time.

It therefore does not yet answer what happens when later knowledge corrects or contradicts earlier knowledge about the same valid time. That would reconnect this bitemporal structure with LOAM's append-only correction and conflict frontier work.

## Tool choice

**TLA+ only.**

No J quotient count is needed. No Lean theorem is claimed yet. miniKanren has no distinct role in this question.
