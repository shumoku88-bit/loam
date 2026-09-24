# Observation 329 — Measure scale change and first-use publication order

Status: **QUALIFIED TLA+ TEMPORAL OBSERVATION**

## Trigger

Observation 328 established a structural gap:

> current retained quanta plus current Measure presentation configuration do
> not determine the historical scale convention.

D3 therefore needs an operational rule that prevents a used Measure from being
silently reinterpreted.

The existing policy is already fixed:

```text
unused Measure
    -> scale may change

used Measure
    -> scale is stable
    -> later change requires explicit migration
```

The remaining problem is temporal.

## Production writer inventory

Repository inspection found four current retained-quantity authority families:

```text
Actual
Scheduled
Capacity
CurrentQuantityAnchor
```

Their existing ownership topology is compatible with:

```text
Scheduled -> Actual -> Anchor
Capacity  -> independent single-authority writer
```

No production path was found that first acquires Capacity and then one of
Scheduled / Actual / Anchor.

This observation abstracts those four families as one finite authority set.

## The race in a naive check

A scale publisher that merely does:

```text
1. inspect every authority
2. observe "Measure is unused"
3. write new scale
```

is insufficient if quantity publication may occur between steps 2 and 3.

Reachable history:

```text
scale = 0
used = false

scale writer: check unused
quantity writer: publish first retained quantity under scale 0
scale writer: commit scale = 2

result:
  retained quantity historical meaning = scale 0
  current presentation scale = 2
```

The bytes of the retained quantity are unchanged, but its human meaning has been
reinterpreted.

## Candidate protocol

The candidate keeps existing quantity writers unchanged.

Only Measure-scale administration gains a cross-authority ownership interval:

```text
acquire Scheduled
acquire Actual
acquire CurrentQuantityAnchor
acquire Capacity
    |
    v
require no retained use of Measure
    |
    v
replace measure-presentation.tsv atomically
    |
    v
release in reverse order
```

Conceptually, the TLA+ model treats this nested ownership interval as one
aggregate lock over the four retained-quantity authorities.

A scale change may begin only when no quantity writer is already in flight.
While the scale writer owns the aggregate lock, no quantity writer may begin.

## Model

`tla/MeasureScalePublicationOrder.tla`

The model tracks:

- current scale;
- which authority families have retained use;
- the scale under which each authority first retained the Measure;
- in-flight quantity writers;
- naive scale-change phase;
- candidate aggregate scale lock.

The core safety invariant is:

```text
for every used authority:
    historical first-use scale = current scale
```

This is deliberately a one-Measure, two-scale model. Quantity arithmetic,
Event identity, Locus, Purpose, and persistence encoding are irrelevant to the
interleaving question.

## Qualified matrix

GitHub Actions run `35945792069`, TLA+ tools 1.7.4 / TLC:

```text
NaiveSpec + MeaningStable
    -> VIOLATED
       75 distinct states explored before the counterexample

LockedSpec + MeaningStable
    -> PASS
       513 distinct states, complete finite state space

LockedSpec + NeverScale2
    -> VIOLATED
       pre-use scale change is reachable

LockedSpec + NeverUsed
    -> VIOLATED
       quantity publication is reachable
```

The last two checks rule out a vacuous "safe" protocol that disables one side of
the interaction.

## Qualified conclusion

The matrix supports the following implementation direction:

1. keep `MeasurePresentation` outside neutral Core;
2. add one narrow scale-administration boundary;
3. make scale mutation acquire all retained-quantity authorities in a fixed
   compatible ownership order;
4. re-read those authorities under ownership and refuse ordinary scale change
   once the Measure is used;
5. publish the config through sibling staging;
6. keep explicit migration as a separate future operation.

It would **not** require:

- storing scale on every Event / Effect / Scheduled / Capacity quantity;
- a generic migration framework;
- a global currency registry;
- making every quantity writer acquire a new Measure lock.

## Model-to-production limitation

The aggregate lock is a model abstraction.

Before implementation, the concrete nested ownership order must be compared
against all current multi-authority publishers. TLC proves only the modelled
interleavings, not that source code has been wired to the model correctly.

If the protocol is selected, ordinary integration tests must still exercise the
real WriterOwnership boundaries.


## Next production step

D3 now has both a structural counterexample (Observation 328) and a temporal
protocol qualification (Observation 329).

The smallest selected production direction is therefore:

```text
Measure scale administration
    -> acquire current retained-quantity authority ownership
       in compatible fixed order
    -> re-read Actual / Scheduled / Anchor / Capacity
    -> if Measure is used: refuse ordinary scale change
    -> if unused: publish the new presentation config atomically
```

No new lock is required on every quantity writer. Existing writer ownership is
reused from the administration side.

Implementation must still verify exact source correspondence for the concrete
nested lock order and add integration tests around the real files.
