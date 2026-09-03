# Observation 113: Can Actual, Scheduled, and Capacity compose without reservation state?

Status: qualified bounded Alloy observation after Practical Scheduled Create / Complete / Cancel

## Question

LOAM now has practical evidence for three household planes that meet in envelope-style budgeting:

- Actual: what happened
- Scheduled: what is expected to happen
- Capacity: what spending authority has been allocated

Before adding Scheduled supersession or a practical Commitment / Headroom view, ask a local anti-bloat question:

> Does useful envelope-budget behavior require another retained state that reserves Capacity for Scheduled spending, or can the household answer remain a projection of the three existing evidence families plus explicit Scheduled lifecycle relations?

This is not a new whole-household inventory. It is a composition check at the point where separately small practical slices begin to interact.

## Candidate projection

The model deliberately treats the familiar envelope values as derived answers:

```text
Capacity evidence
    -> Entitlement

Actual evidence
    -> Consumption

open Scheduled evidence
    -> Commitment

Remaining
    = Entitlement - Consumption

Headroom
    = Remaining - Commitment
```

A Scheduled occurrence is open when it has neither completion evidence nor retirement evidence.

The model does not create an Envelope object, mutable Plan status, reserved-Capacity movement, or canonical Headroom fact.

## Completion pressure

Completion adds an Actual fact and explicit Scheduled -> Actual realization evidence while leaving Capacity unchanged.

For one purpose, the selected algebra predicts:

```text
Headroom_after - Headroom_before
    = Scheduled_expected - Actual_realized
```

Therefore:

```text
expected = actual
    -> Headroom unchanged

actual < expected
    -> Headroom increases by the difference

actual > expected
    -> Headroom decreases by the difference
```

This is useful because the household does not need to mutate Capacity merely to move a quantity from "planned" to "spent". Completion changes which upstream evidence contributes to Commitment and Consumption.

## Cancellation pressure

Cancellation adds explicit Scheduled retirement evidence while leaving Actual and Capacity unchanged.

The selected algebra predicts:

```text
Remaining_after = Remaining_before

Headroom_after - Headroom_before
    = retired Scheduled amount
```

Again, no Capacity release movement is required merely because an expectation stopped being open.

## Competing retained reservation candidate

The model also contains a deliberately competing field:

```text
reservations: set ScheduledFact
```

This represents the family of designs where open Scheduled spending is mirrored into a separately retained "reserved budget" state and Headroom is calculated from that mirror.

Two cases matter.

### Reservation is always synchronized

If:

```text
reservations = openScheduled
```

then reservation-based Headroom equals projection-based Headroom.

The additional retained state supplies no new answer in this bounded question.

### Reservation can drift

If reservation state is independently retained, Alloy can construct two worlds that agree on:

```text
Capacity
Actual
Scheduled
Completion
Retirement
```

but disagree only on `reservations`, and therefore disagree on reservation-based Headroom.

That means the extra state creates an additional synchronization obligation. It is redundant when perfectly mirrored and answer-changing when it drifts.

## Model strengthening

The first pass checked isolated one-purpose transitions. Before accepting the result, the model was strengthened so completion and cancellation preserve arbitrary background household evidence.

The final model requires explicit SAT witnesses where another Actual and another Scheduled fact already coexist. The laws are then checked in a larger exact scope with:

```text
2 Purpose
2 CapacityFact
2 ActualFact
2 ScheduledFact
2 Completion
2 Retirement
4 World
6-bit Int
```

This avoids treating a transition law as qualified merely because the transition became unreachable in the larger scope.

## Executed result

Alloy 6.2.0 + Sat4j:

```text
equalCompletionWitness                              SAT
underActualCompletionWitness                        SAT
overActualCompletionWitness                         SAT
cancellationWitness                                 SAT
scheduledChangesHeadroomWithoutChangingRemaining   SAT
actualChangesRemainingWithoutChangingEntitlement   SAT
reservationDriftWitness                             SAT
contextualCompletionWitness                         SAT
contextualCancellationWitness                       SAT

CapacityAloneDeterminesEntitlement                  UNSAT counterexample
CapacityAndActualDetermineRemaining                 UNSAT counterexample
CompletionHeadroomDeltaMatchesExpectedMinusActual  UNSAT counterexample
CancellationPreservesRemaining                      UNSAT counterexample
CancellationReleasesCommitmentIntoHeadroom          UNSAT counterexample
HouseholdEvidenceDeterminesDerivedHeadroom          UNSAT counterexample
HouseholdEvidenceDeterminesReservationHeadroom      SAT counterexample
MirroredReservationAddsNoInformation                UNSAT counterexample
```

The two contextual witnesses are SAT, so the larger transition checks are not relying on an impossible isolated lifecycle transition.

## Finding

For the selected bounded household question, the smaller composition is sufficient:

```text
Actual --------> Consumption --+
                              |
Capacity ------> Entitlement  +--> Remaining
                              |        |
Scheduled -----> Commitment --+        +--> Headroom
   |
   +-- completion / retirement decide whether it is open
```

The result gives no current reason to add any of the following canonical state:

```text
Envelope object
Reserved Capacity
Reserved budget balance
Plan-reservation synchronization record
mutable Commitment
mutable Remaining
mutable Headroom
```

The strongest anti-bloat result is:

```text
separate reservation state
    synchronized  -> same answer, no added information
    drifted       -> same household evidence, different answer
```

So a Scheduled operation should not mutate Capacity merely because the household wants a Headroom answer.

Capacity remains authority evidence. Scheduled remains expectation evidence. Actual remains occurrence evidence. Their meeting point is a projection.

## Practical consequence

The next Scheduled lifecycle operation can remain Scheduled-local.

In particular, supersession can be explored as explicit Scheduled -> Scheduled successor evidence without simultaneously introducing reserved-Capacity mutation.

A later practical Commitment / Headroom query should first attempt to compose:

```text
Capacity
+ routed Actual
+ routed open Scheduled
+ lifecycle evidence
```

rather than storing a second envelope-budget state.

## Boundaries

This observation is deliberately narrower than the production household system.

- Each quantity fact is already associated with a Purpose. Historical routing itself is abstracted away here; Observations 107 and 108 remain the authority for routing / Commitment pressure.
- Quantities model positive per-purpose claims, not the complete signed multi-Measure Event algebra.
- Backing is not modeled.
- Recurrence / Series is not modeled.
- Capacity's own historical writer-validity question from Observation 112 is unchanged.
- This does not prove that no future household operation can ever earn additional envelope evidence.
- The result is bounded Alloy evidence, not an unbounded mathematical proof.

The stop condition remains the same:

> If two worlds can agree on all retained LOAM evidence but require different household answers, the missing distinction has earned investigation.

Observation 113 did not find such missing retained envelope state for this composition. It did find the opposite pressure against an independently retained reservation mirror.
