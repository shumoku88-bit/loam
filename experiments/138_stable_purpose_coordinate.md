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

## Expected result

Expected SAT witnesses:

```text
stablePurposeCrossesBoundary
nameAndCapacityCanChangeTogether
capacityCanChangeWithoutNameChange
nameCanChangeWithoutCapacityChange
historicalNameIsNotOverwritten
exactBoundarySelectsLaterEvidence
noPurposeLifecycleStateNeededInSpecimen
```

Expected SAT counterexamples:

```text
PurposeIdentityDeterminesOneTimelessLabel
PurposeIdentityDeterminesOneTimelessCapacity
NameChangeRequiresPurposeReplacement
CapacityChangeRequiresPurposeReplacement
```

Expected UNSAT counterexamples:

```text
TimedDescriptionIsUnambiguousWithinCoveredHorizon
TimedCapacityIsUnambiguousWithinCoveredHorizon
```

Qualification is pending exact-head Observation 138 CI.

## Candidate interpretation

If the expected result qualifies, the smallest candidate is:

```text
stable Purpose identity
+ DateRange-local Capacity authority
+ optional DateRange-local descriptive evidence
    -> historical/current presentation
```

rather than:

```text
PurposeVersion
EnvelopeVersion
CycleEnvelope
Open / Closed Purpose state
```

The intended coordinate view is:

```text
Purpose identity persists

Name(t)      changes by time-local descriptive evidence
Capacity(t)  changes by time-local authority evidence
```

The Purpose itself does not need to become a mutable record whose fields are overwritten.

## Important restraint

Even a successful model does **not** earn canonical Purpose-description storage.

If household dogfood only needs a current display label, historical name evidence may be unnecessary. If historical presentation later matters, some retained evidence must exist because a changed human label cannot be reconstructed from stable `PurposeId` plus Capacity facts alone.

That future evidence should be introduced only when practical pressure requires preserving the historical answer.

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
