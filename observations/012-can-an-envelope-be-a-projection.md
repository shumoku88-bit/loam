# Observation 012: Can an Envelope Be a Projection?

## Question

Can the live-holdings aspect of an envelope emerge as a projection instead of being stored as a primary entity?

Observation 010 found that a Purpose boundary was not yet an Envelope because a finite resource could still be used repeatedly. Observation 011 then found, in a closed consumptive unit world, that availability can be derived from initial resources and Use history.

This observation composes those findings without introducing an `Envelope` signature.

## Construction

The only new view is:

```text
liveAtPurpose(t, p)
  = derivedAvailable(t)
    ∩ units placed at Purpose p at t
```

The underlying vocabulary remains:

- `Time`
- `Purpose`
- `Unit`
- initial resource membership
- Purpose placement
- `Use`
- explicit `Change`

There is no stored envelope balance and no envelope identity.

## Executed Alloy result

Alloy 6.2.0 with Sat4j produced:

```text
nontrivialProjectionWorld                    SAT
LiveViewsPartitionAvailability               UNSAT
UseIsLocalToLiveView                         UNSAT
ConsumptionRemovesFromAllLaterLiveViews      UNSAT
LiveReassignmentMovesWithoutConsumption      UNSAT
projectedViewChangesForTwoReasons             SAT
```

The bounded checks therefore found no counterexample to four envelope-like properties of the projection:

1. every currently available Unit appears in exactly one live Purpose view;
2. a Use can consume a Unit only from the live view of its named Purpose;
3. after a Unit is consumed, it appears in no later live Purpose view;
4. an available Unit that is reassigned without being consumed moves from one live Purpose view to another.

## A world with two kinds of change

The second SAT witness contains two distinct Units at the same time coordinate:

- `moved = Unit2`, moving from `Purpose1` to `Purpose0` without consumption;
- `spent = Unit1`, consumed from a live Purpose view.

So the same derived view can change for two different reasons:

```text
reassignment  -> live resource moves between Purpose views
consumption   -> live resource disappears from all later Purpose views
```

No `Envelope` object is required to distinguish those effects.

## Finding

Within this closed unit-resource model, an envelope-like **live holdings view** can be derived as the intersection of two independently meaningful relations:

```text
Purpose placement × resource lifetime
```

More precisely:

```text
live holding = placement ∩ derived availability
```

This suggests that the presently-live contents of an envelope need not be primary state. Storing an additional envelope balance or envelope-content relation would duplicate information already present in Purpose placement and resource history, unless it carries some further meaning.

This does **not** show that the full budgeting concept of an Envelope is a projection.

## What did not emerge

The projection does not yet contain:

- a target or desired amount;
- a commitment about future resources;
- reserved future capacity;
- a rule for later arrivals;
- restoration, refund, or expiration;
- divisible quantities or partial consumption;
- any reason why a particular Purpose should continue to exist when its live holding becomes empty.

Those may be the parts for which an Envelope-like concept still earns its place.

## Tool choice

Alloy was sufficient for this observation. J was not needed because no quantitative shape comparison was required. Lean 4 was not added because the checked properties are direct structural consequences of the composition under study rather than a new general law worth preserving yet. TLA+ and miniKanren were not used.

## Next question

The experiment moved the boundary again. The live contents look derived, so the next useful question is not whether the container exists, but what information remains after its contents are removed from the ontology:

> What, if anything, must an Envelope remember beyond its live holdings?

A promising next probe is commitment: whether a future-directed purpose claim can also be derived from observations, or whether it introduces genuinely new information that cannot be reconstructed from placement and use history.
