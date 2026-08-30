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

If TLC finds a counterexample, a trace of the shape

```text
time 0: observe r0
advance
time 1: observe r1
```

is enough to separate:

```text
relation-as-of time 0 = r0
current relation      = r1
```

The intended boundary result is an invariant violation of `LatestRelationAnswersPast`.

That would mean a system retaining only the latest relation cannot in general answer a future vocabulary that asks how a past coordinate was viewed.

## Boundary 2 — current relation determines a future plan target

A plan may explicitly capture the current relation:

```text
plan assumption = r0
```

The second strong hypothesis says that this snapshot must equal the relation later observed at the plan target.

TLC is asked to find a trace such as:

```text
time 0: observe r0
        make plan for time 1 using r0
advance
time 1: observe r1
```

The intended boundary result is an invariant violation of `PlanAssumptionDeterminesTarget`.

This does not make planning invalid. It separates two meanings:

```text
current relation carried forward = assumption
later relation observation        = fact available later
```

An assumption can be useful without becoming a claim that the future has already been observed.

## Intended interpretation

If the positive model holds and both boundary hypotheses fail, the bounded conclusion is:

> A relation between Measures needs temporal memory once future questions distinguish past, present, and future viewpoints.

More specifically:

- the current relation can answer a present-view question;
- historical relation questions require enough history to recover the relevant past view;
- a current relation may be carried into a plan as an explicit assumption, but it does not determine the relation that will later be observed.

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

If Observation 034 succeeds, that bitemporal split is the next natural pressure point.

## Tool choice

**TLA+ only.**

No Lean theorem is claimed yet. No J quotient count is needed. miniKanren has no distinct role in this question.
