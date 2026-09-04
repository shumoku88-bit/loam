# Observation 156 — Initial historical-routing coordinate

## Question

Observation 107 qualified a reusable historical routing shape and Observation 111 selected `LocusId` as the Actual-side subject for the current Consumption view. The practical Lean algebra currently models one route as:

```text
subject
+ effectiveOn : Time
+ purpose?
```

Real household dogfood now adds one concrete pressure that those observations did not model: the source routing policy has an explicit **initial** effective coordinate which is ordered strictly before every dated coordinate. It is not a calendar date.

The question is deliberately narrow:

> Can that initial coordinate be losslessly collapsed to an ordinary date, such as the earliest representable day, or does selected historical routing already observe the distinction between `initial` and `from first-day`?

This observation does not model Envelope, Capacity, Consumption arithmetic, persistence, writer behavior, or household values.

## Candidate shapes

### Current dated-only shape

```text
effectiveOn : Day
```

A tempting migration shortcut would encode source `initial` as the first available day.

### Pressured shape

```text
Effective
  = Initial
  | From Day
```

with:

```text
Initial < From d
```

for every day `d`.

## Pressure

The bounded model asks for three witnesses.

### Initial route overridden on the first day

One subject has:

```text
Initial    -> Purpose A
From first -> Purpose B
```

At the first day, Purpose B must win while the initial assertion remains retained.

Expected: SAT.

### Initial route overridden on a later day

The initial route is visible before a later dated override and the dated override wins from its own day onward.

Expected: SAT.

### Fake-date collision

If `Initial` is collapsed to the first day, then `Initial` and `From first` map to the same effective coordinate for one subject.

Expected: SAT.

## Checks

The positive laws are:

```text
InitialIsVisibleAtEveryDay
LatestVisibleRouteIsUnique
```

Expected: no counterexample.

The deliberately too-small law is:

```text
FakeDateCollapsePreservesEffectiveCoordinateIdentity
```

Expected: counterexample.

## Interpretation boundary

If the expected matrix is qualified, the result is only:

```text
initial historical routing coordinate
    !=
earliest dated routing coordinate
```

for the selected routing vocabulary.

It does **not** require a general temporal ontology or a universal sentinel type. The smallest practical follow-up would be a routing-specific effective coordinate such as:

```text
RoutingEffective Time
  | initial
  | from Time
```

and an explicit projection that asks which routing evidence is visible at an Actual valid coordinate.

The source system's initial marker must not be silently rewritten as a fabricated household date merely to fit the current persistence shape.

No production type or persistence format is added by this observation.
