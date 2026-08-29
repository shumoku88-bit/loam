# Observation 013: Can Commitment Be Derived?

## Question

Observation 012 found that the presently-live contents associated with a Purpose can be derived without an `Envelope` object:

```text
live holding = Purpose placement ∩ derived availability
```

That leaves a different question.

If two worlds have the same resource history and the same current live holdings, must they also have the same future commitment?

Or does a commitment carry information that is not present in the physical history at all?

## Tool choice

Alloy alone is sufficient for this observation.

The question is relational: can two otherwise-matching worlds differ only in commitment, and can that difference change what is permitted now?

J is not needed because no quantitative shape is being compared. TLA+ is not needed because interleaving or transition order is not yet the object of study. miniKanren is not needed because no inverse synthesis is requested. Lean 4 is not added because no general theorem has yet emerged that deserves proof beyond the bounded relational observation.

## Setup

The model keeps the small vocabulary:

```text
Time
Purpose
Unit
Origin
World
Use
```

There is still no `Envelope` entity.

Each `World` carries:

```text
at          : Time -> Unit -> Purpose
used        : Time -> Unit -> Purpose
commitment  : Unit -> Purpose
```

`at` and `used` describe the physical/resource trace. `commitment` is deliberately separate.

The observation uses four ordered time coordinates. The second coordinate is `present`; the first is observed past, and the later coordinates form the remaining horizon.

## Meaning admitted for commitment

A committed Unit must:

1. be a live holding at its committed Purpose at `present`;
2. not be used at `present`;
3. remain placed at that Purpose through the horizon;
4. not be used before the final horizon coordinate.

This gives commitment behavioral meaning rather than treating it as an inert label.

A Unit may be reassigned now only when it is live, unused now, moving to another Purpose, and has no commitment.

## Probes

The model asks for two witnesses.

### Same observed history, different permission

`Left` and `Right` must agree on all placement and Use facts through `present`.

One live Unit is committed in `Left` and uncommitted in `Right`.

The same proposed reassignment must therefore be forbidden in `Left` and permitted in `Right`.

### Same full physical trace, different commitment

`Left` and `Right` must agree on the entire placement and Use trace, including the future horizon, while still differing in commitment.

This distinguishes a kept promise from behavior that merely happens to look the same.

## Executed result

Alloy 6.2.0 / Sat4j:

```text
sameHistoryDifferentPermission              SAT
sameTraceDifferentCommitment                SAT
CurrentLiveViewDeterminesCommitment          SAT
ObservedHistoryDeterminesCommitment          SAT
FullPhysicalTraceDeterminesCommitment        SAT
CommitmentNamesPresentLiveHolding            UNSAT
CommitmentIsHonoredThroughHorizon            UNSAT
```

The three `DeterminesCommitment` checks are assertions. Their SAT results are counterexamples to determinability.

The first execution attempt exposed only an Alloy namespace ambiguity between integer and ordering `prev`. Qualifying `util/ordering[Time]` as `ord` resolved it without changing the model question or expected semantics.

## Witness

For `sameHistoryDifferentPermission`, Alloy found:

```text
Unit    = Unit3
commit  = Purpose1
other   = Purpose0
```

`Left` and `Right` have the same observed physical history through `present`.

In `Left`, `Unit3` is committed to `Purpose1`, so reassignment to `Purpose0` is not permitted.

In `Right`, the same `Unit3` has no commitment, so that reassignment is permitted.

The difference in permission is therefore not recoverable from the observed placement-and-Use history.

For `sameTraceDifferentCommitment`, Alloy again found `Unit3` at `Purpose1` while `Left` and `Right` share the same complete physical trace. One world contains the commitment and the other does not.

So identical behavior does not reveal whether the behavior fulfilled a promise or merely coincided with it.

## Finding

Within this bounded model:

```text
what is presently there      can be projected
what must remain there       cannot be projected from physical history
```

Current live holdings do not determine commitment.

Observed physical history does not determine commitment.

Even the complete physical trace does not determine commitment.

The strongest reading is not that an `Envelope` object is necessary. It is narrower and more useful:

> If the household system needs to distinguish what may be moved from what has been held for a purpose, some commitment-bearing information must exist in addition to the physical resource projection.

That information could be a relation, declaration, event history, policy, or some other structure. Observation 013 does not decide its representation.

## A distinction that appeared

Observation 012 and 013 now separate two kinds of knowledge:

```text
holding       extensional: what is there now
commitment    normative:  what is required to remain
```

A kept promise and an accidental match can have the same extensional trace.

That means a future-oriented household system cannot infer intention merely from what eventually happened.

## Boundary

This is still a small unit-resource world.

It does not yet model:

- creating a commitment as an event;
- releasing or cancelling a commitment;
- breach;
- competing commitments;
- priorities;
- target quantities;
- partial commitment;
- divisible resources;
- future arrivals;
- restoration or refunds;
- a chosen deadline distinct from the fixed observation horizon.

The bounded SAT counterexamples establish only that the admitted physical projection does not determine the admitted commitment relation.

## Next question exposed by the result

Observation 013 should not make `commitment` a permanent primitive by default.

The next pressure point is:

> Can active commitment itself be derived from an intentional history of declarations and releases?

That would distinguish two histories:

```text
physical history      -> live holdings
intentional history   -> active commitments ?
```

Only if order, release, breach, or competing declarations make transition behavior itself central would TLA+ earn its way into the experiment.
