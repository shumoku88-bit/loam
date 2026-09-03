# Observation 138 — Can one stable Purpose remain a coordinate while name and Capacity change over time?

## Household question

A household purpose does not stay textually or numerically frozen.

```text
same household purpose
    earlier: "Food"       Capacity 10
    later:   "Groceries"  Capacity 7
```

Other changes may happen independently:

```text
same name, different Capacity
same Capacity, different name
```

The practical temptation is to turn every change into a new object:

```text
PurposeVersion
EnvelopeVersion
RenameEvent
CycleEnvelope
Open / Closed lifecycle
```

This observation asks whether any of those concepts are required merely to preserve a stable household coordinate while its time-local presentation and allocation authority change.

## Existing boundary

Practical Core already says `PurposeId` is stable identity for one household purpose coordinate. Capacity authority already refers to that coordinate rather than to a physical Locus.

The experiment therefore keeps exactly one Purpose identity across the boundary and changes only time-local evidence around it.

The model uses `PurposeDescription` only as experiment vocabulary for a range-local human label. It is **not** a proposed Practical Core type, persistence record, rename command, or new identity-bearing object.

## Specimen

Two adjacent half-open ranges are used:

```text
Earlier [0,2)
Later   [2,4)
```

Three stable Purpose coordinates expose independent pressures:

```text
FoodPurpose
  Earlier: Food       / Capacity 10
  Later:   Groceries  / Capacity 7

TravelPurpose
  Earlier: Travel / Capacity 4
  Later:   Travel / Capacity 6

ReservePurpose
  Earlier: Reserve  / Capacity 3
  Later:   RainyDay / Capacity 3
```

This deliberately distinguishes:

```text
name change + Capacity change
Capacity change without name change
name change without Capacity change
```

No Purpose is opened, closed, replaced, or versioned.

## Bounded questions

The Alloy model asks whether:

1. one stable Purpose can cross an authority boundary while both name and Capacity change;
2. Capacity can change while the name remains the same;
3. name can change while Capacity remains the same;
4. a later name can coexist with the earlier historical name instead of overwriting it;
5. the exact half-open boundary chooses only later evidence at day 2;
6. the specimen needs any Purpose open/closed lifecycle state;
7. Purpose identity alone forces one timeless name;
8. Purpose identity alone forces one timeless Capacity;
9. a name change necessarily implies Purpose replacement;
10. a Capacity change necessarily implies Purpose replacement;
11. range-local descriptive and Capacity evidence remain unambiguous inside the covered horizon.

## Executed result

Alloy 6.2.0 + Sat4j produced the expected result set on PR #302.

SAT witnesses:

```text
stablePurposeCrossesBoundary
nameAndCapacityCanChangeTogether
capacityCanChangeWithoutNameChange
nameCanChangeWithoutCapacityChange
historicalNameIsNotOverwritten
exactBoundarySelectsLaterEvidence
noPurposeLifecycleStateNeededInSpecimen
```

SAT counterexamples:

```text
PurposeIdentityDeterminesOneTimelessLabel
PurposeIdentityDeterminesOneTimelessCapacity
NameChangeRequiresPurposeReplacement
CapacityChangeRequiresPurposeReplacement
```

UNSAT counterexamples:

```text
TimedDescriptionIsUnambiguousWithinCoveredHorizon
TimedCapacityIsUnambiguousWithinCoveredHorizon
```

The exact-head Observation 138 workflow required this complete result set and completed successfully before this qualification note was recorded.

## Finding

The bounded result rejects the idea that a changing household purpose needs a new identity merely because one of its visible properties changed.

The specimen admits all three independently:

```text
same Purpose + new name + new Capacity
same Purpose + same name + new Capacity
same Purpose + new name + same Capacity
```

Therefore:

```text
name change
    does not imply
Purpose replacement

Capacity change
    does not imply
Purpose replacement
```

The half-open DateRange boundary remains sufficient to choose the later local evidence exactly at the boundary. Earlier descriptive evidence also remains available for an earlier coordinate, so a later human label need not rewrite historical presentation.

Most importantly, the specimen needs no `PurposeVersion`, no `EnvelopeVersion`, no canonical Cycle, and no open/closed state for Purpose. The stable Purpose remains a coordinate while time-local authority and presentation vary around it.

The smallest qualified candidate is:

```text
stable Purpose identity
+ DateRange-local Capacity authority
+ optional DateRange-local descriptive evidence
    -> historical/current presentation
```

or, as coordinate-shaped projections:

```text
Name(t)
Capacity(t)
```

around one stable Purpose identity.

## Important restraint

This result does **not** earn canonical Purpose-description storage.

`PurposeDescription` in the Alloy file is observation vocabulary only. If household dogfood needs only a current display label, historical name evidence may never need to enter Practical Core. If a future workflow must answer "what was this purpose called at that historical coordinate?", then some retained descriptive evidence will be required because stable identity and Capacity evidence do not contain that human label.

That is an evidence-storage pressure, not evidence for a versioned Purpose object.

This observation therefore proposes no production changes and earns none of the following:

- `PurposeVersion`;
- `Envelope` or `EnvelopeVersion`;
- canonical Cycle;
- open/closed lifecycle state;
- `RenameEvent`;
- canonical `PurposeDescription`;
- description persistence;
- CLI/TUI rename commands;
- policy identity;
- changes to existing `PurposeId`;
- changes to Capacity persistence.

## Tool choice

Alloy is sufficient because the immediate question is structural: can stable identity coexist with independent time-varying projections without introducing a versioned domain object?

A temporal model such as TLA+ is unnecessary until a real writer must coordinate concurrent rename/allocation updates or preserve publication ordering.
