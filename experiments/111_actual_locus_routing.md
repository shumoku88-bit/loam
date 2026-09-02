# Observation 111 — Which Actual coordinate should historical Purpose routing observe?

## Question

Observation 107 established a reusable historical routing shape:

```text
subject
effectiveOn
purpose?
```

while deliberately leaving the concrete Actual-side subject unspecified.

Current h-kernel household pressure routes Expense Accounts historically, while Scheduled routing uses stable Plan identity. LOAM should not import `Account` merely because the source system does. Its practical Actual evidence already has a smaller physical coordinate:

```text
Event
  -> Effect
     -> Locus
```

The new bounded question is:

> For the selected Actual Consumption-routing view, can historical routing attach to `Locus`, with each Effect read at the valid coordinate of its containing Actual occurrence, or does the selected view already require event-level or effect-level routing?

This observation also asks whether the valid coordinate is independently observable once routing may change through time.

## Why this is the next pressure point

A tempting implementation after PR #244 would jump directly to one `ActualMovement` routing subject. That is too early.

Existing qualified results already preserve:

- Event grouping;
- stable Effect identity independently from `(Locus, Measure)`;
- historical routing rather than a current-only table;
- valid time separately from learned time.

But none of those results selects the concrete Actual routing subject.

A household-shaped example is:

```text
paypay      -100
coffee       +60
groceries    +40
```

If `coffee` and `groceries` are routed to different Purposes, one Event-level Purpose cannot represent the selected per-Effect routing answer. Requiring a new route record for every Effect, however, may retain more identity-specific policy than the selected view consumes when the recurring meaning belongs to the Locus.

## Model

The Alloy model retains:

```text
ActualEvent identity
Effect identity
Effect -> Event
Effect -> Locus

RoutingEvidence
  locus
  effectiveOn
  purpose?

World.validOn
  ActualEvent -> Day
```

A route is selected as the latest evidence effective on or before the Event's valid coordinate.

The model intentionally does not include:

- quantities or balance arithmetic;
- `Account` / AccountType;
- stored Consumption state;
- learned time;
- routing correction identity;
- persistence or writer semantics.

Those are separate questions.

## Selected projection

Each Effect falls into exactly one of three route views at its Event's valid coordinate:

```text
managed
  latest visible route names a Purpose

explicitly unmanaged
  latest visible route exists and names no Purpose

unrouted
  no routing evidence is visible
```

The managed view retains the Effect-to-Purpose answer so one Event may contribute Effects to different Purposes.

## Probes

### Representative Locus-routed Actual

Can one Event contain several Effects where at least two managed Effects route to different Purposes, while another Effect is unmanaged or unrouted?

Expected: SAT.

### Same routes, different valid coordinate

Can two worlds retain the same Effects and exactly the same routing evidence but differ in the selected routing answer only because the same Event is valid on a different day relative to a route change?

Expected: SAT.

If so, routing evidence alone does not determine Actual Consumption routing. Some occurrence-valid coordinate remains independently observable.

### One Event needs more than one Purpose

Can Effects in one Event route to at least two Purposes at the Event's valid coordinate?

Expected: SAT.

If so, one Event-level single-Purpose route is too coarse for the selected answer.

### Current route can misread earlier Actual

Can routing at the final day differ from routing at the Event's own valid day?

Expected: SAT.

If so, applying current routing backward rewrites historical Consumption meaning.

### Explicitly unmanaged Actual

Can an Effect be classified as explicitly unmanaged because a latest visible route exists with no Purpose?

Expected: SAT.

This preserves Observation 107's distinction between explicit unmanaged state and absence of routing evidence.

## Checks

The deliberately too-small assertions are:

```text
RoutesWithoutValidDayDetermineSelectedRouting
OneEventSinglePurposeAlwaysEnough
```

Expected: SAT counterexamples.

The sufficiency and partition checks are:

```text
RoutesAndValidDayDetermineSelectedRouting
SelectedRoutingPartitionsEffects
LatestRouteIsUnique
```

Expected: UNSAT counterexamples.

## Interpretation boundary

If the expected matrix qualifies, the bounded conclusion will be:

```text
historical Locus routing
+ Actual occurrence valid coordinate
    -> selected per-Effect routing view

routing history without occurrence validity
    too small

one Event -> one Purpose
    too small
```

This would **not** prove that Effect-level routing is universally unnecessary. A future question could observe a distinction between two Effects at the same Locus. Observation 052 already warns against erasing Effect identity.

The narrower result would say only that the selected Consumption-routing question does not need an Effect-specific route record when Locus history plus occurrence validity already determines its answer.

Likewise, `validOn` in this model is information, not a proposed production field. Observations 092–094 explicitly did not earn a universal Event date/timestamp representation. A successful Observation 111 would earn the need for an Actual-valid coordinate in this concrete downstream question, while leaving its production ownership and representation for the next practical design step.

## Product implication if qualified

A likely practical boundary would become:

```text
Actual
  retains Event / Effect identity and multi-Measure evidence

Actual routing
  LocusId -> Purpose? @ effective coordinate

Consumption
  projection over Effects using route visible at Actual-valid coordinate
```

That is smaller than importing Expense Account objects and avoids per-Effect classification duplication for the selected view.

No Practical Core change is proposed in this observation.
