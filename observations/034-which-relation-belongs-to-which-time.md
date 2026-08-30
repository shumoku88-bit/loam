# Observation 034 — Which Relation Belongs to Which Time?

## Question

Observation 033 separated household event history from a neutral relation between Measures:

```text
Event -> Locus -> Measure -> Quantity

plus

Relation : Measure × Measure -> RelationValue
```

That was a static result. It showed that the same household history can coexist with different relation observations.

The next question is temporal:

> When relation observations change through time, can one current relation answer questions about the past and future as well as the present?

This observation does not yet introduce `Price`, `ExchangeRate`, market authority, source trust, or conversion arithmetic. It gives the relation observation only one new coordinate: **time**.

## Why TLA+

The core tools already answer nearby but different questions:

- Alloy can hold two static worlds side by side and showed that relation is independent from the event core.
- J is useful when the question is quotient size or finite projection geometry.
- Lean is useful once a reusable general law deserves proof.

What is missing is a transition-level observation:

```text
observe relation r0
advance time
observe relation r1
```

and then ask what may change and what must remain stable. TLA+ adds exactly that temporal answer.

## Bounded model

The model uses three abstract time coordinates:

```text
0, 1, 2
```

and two neutral relation values:

```text
r0, r1
```

At most one relation observation is admitted at each time coordinate. A relation observation is append-only:

```text
[time |-> t, value |-> r]
```

The current relation is the latest relation observed at or before `now`.

A plan may capture the current relation as an explicit **assumption** for the next time coordinate. The model deliberately does not promote that assumption into a fact about the future.

## Positive properties

The primary configuration asks TLC to preserve:

1. type correctness;
2. at most one relation observation per time coordinate;
3. no observation originates from a future time;
4. current relation agrees with append-only relation history;
5. a plan assumption remains the snapshot taken when the plan was made;
6. a future query with no observation yet returns `Unknown` rather than inventing a fact;
7. relation history only extends;
8. once a time coordinate is in the past, later relation observations do not rewrite its view.

## Boundary 1 — latest relation answers the past

The first deliberately strong hypothesis says:

> Every known past relation must equal the current relation.

A counterexample trace of the shape

```text
time 0: observe r0
advance
time 1: observe r1
```

separates:

```text
relation-as-of time 0 = r0
current relation      = r1
```

The boundary is expressed as `LatestRelationAnswersPast`.

If it fails, a system retaining only the latest relation cannot in general answer a future vocabulary that asks how a past coordinate was viewed.

## Boundary 2 — current relation determines a future plan target

A plan may explicitly capture the current relation:

```text
plan assumption = r0
```

The second strong hypothesis says that this snapshot must equal the relation later observed at the plan target.

A counterexample trace can have the shape:

```text
time 0: observe r0
        make plan for time 1 using r0
advance
time 1: observe r1
```

The boundary is expressed as `PlanAssumptionDeterminesTarget`.

This does not make planning invalid. It separates two meanings:

```text
current relation carried forward = assumption
later relation observation        = fact available later
```

An assumption can be useful without becoming a claim that the future has already been observed.

## Observed TLA+ result

TLC 2.19, from TLA+ tools 1.7.4, produced the intended result set.

### Positive model

```text
Model checking completed. No error has been found.
89 states generated
89 distinct states found
0 states left on queue
depth 7
```

The append-only temporal model therefore preserved the selected safety properties throughout the complete bounded state graph.

### Historical boundary

`LatestRelationAnswersPast` was violated.

TLC found the four-state trace:

```text
State 1: now = 0, history = <<>>, current = unknown
State 2: observe r0 at time 0
State 3: advance to time 1, current remains r0
State 4: observe r1 at time 1, current becomes r1
```

At State 4 the current relation is `r1`, while the relation as of time 0 remains `r0`.

TLC reached the counterexample after generating 13 distinct states, at depth 4.

### Future-plan boundary

`PlanAssumptionDeterminesTarget` was violated.

TLC found the five-state trace:

```text
State 1: now = 0, no relation, no plan
State 2: observe r0 at time 0
State 3: make a plan for time 1 with assumption r0
State 4: advance to time 1
State 5: observe r1 at time 1
```

At State 5 the plan still truthfully remembers its assumption `r0`, while the relation later observed at the target is `r1`.

TLC reached this counterexample after generating 33 distinct states, at depth 5.

## Bounded interpretation

The observed result supports a three-way separation:

```text
past
  relation history preserves what could be answered as of an earlier coordinate

present
  current relation is the latest observed relation as of now

future
  a present relation may be carried forward only as an explicit assumption
```

So one current relation is not sufficient for all three viewpoints.

In particular:

- applying the latest relation backward can erase an observable historical distinction;
- changing the current relation does not require rewriting earlier relation views;
- carrying the current relation into a future plan does not make it a fact about what will later be observed;
- `Unknown` is semantically different from a current value copied into the future without qualification.

This extends the LOAM pattern:

> State is sufficient only relative to the future vocabulary.

Once the vocabulary contains `relation as of time t`, flattening relation history to one current value loses an observable distinction.

## Important boundary

This observation still treats the observation time and the time to which the relation applies as the same coordinate.

That is intentionally incomplete. A later observation might report something that was valid earlier, or an observation might carry its own validity interval.

So this experiment does **not** yet settle the distinction between:

```text
when the relation was observed

and

when the relation was valid
```

That bitemporal split is now the next natural pressure point.

## Tool choice

**TLA+ only.**

No Lean theorem is claimed yet. No J quotient count is needed. miniKanren has no distinct role in this question.
