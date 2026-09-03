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

## Whole-system composition pass

A local formal result is not sufficient once practical slices coexist. The result must also be checked against the existing retained evidence and projections that feed into it or consume it.

For Observation 113, the current whole-system pass is:

```text
QuantityBasis + effective Actual
    -> physical current quantity / balance

Capacity
    -> Entitlement

Event correction frontier
    -> effective Actual content
          |
Actual-validity correction frontier
    -> effective occurrence coordinate
          |
historical Locus routing
    -> Purpose at that occurrence
          |
          +-> Consumption

Scheduled + lifecycle evidence
    -> open Scheduled
          |
historical Scheduled routing
    -> Commitment

Entitlement - Consumption
    -> Remaining

Remaining - Commitment
    -> Headroom
```

The semantic partitions remain deliberately different:

- QuantityBasis answers where an observed physical quantity starts. It does not grant Capacity.
- Event correction changes which Actual content is effective. It must not leave a derived Consumption view reading superseded raw Event facts.
- Actual-validity correction changes the effective occurrence coordinate. Historical routing must use that effective coordinate rather than storage order or current routing.
- Capacity remains authority evidence and is not mutated by Scheduled Complete / Cancel merely to keep a reservation mirror synchronized.
- Scheduled Complete contributes explicit realization evidence plus an Actual endpoint; Scheduled Cancel contributes retirement evidence. Both can change Commitment / Consumption composition without rewriting Capacity.
- Future Scheduled supersession should first remain Scheduled-local successor evidence. If Headroom can still be projected from the resulting open Scheduled frontier, no cross-family reservation mutation has been earned.

### Existing implementation seam exposed by the pass

This composition pass exposed one concrete implementation seam that the isolated slices did not expose.

The current physical-quantity path already projects Event corrections through `Loam.Application.CorrectionFrontier` before producing effective quantities. By contrast, `Loam.Application.ConsumptionInspection.consumptionAtRecorded?` currently accepts raw `EventMemory` and does not accept `EventCorrectionMemory`.

Therefore the future practical Consumption / Remaining / Headroom path must not simply call the current raw-memory projection after movement corrections exist. Otherwise a superseded Event may either remain visible to Consumption or, when a replacement Event has no corresponding validity evidence, make the raw projection fail closed for the wrong integration reason.

This does **not** earn new canonical state. It identifies a composition boundary that should be qualified before practical Headroom is exposed:

```text
raw EventMemory
+ EventCorrectionMemory
    -> effective Event frontier

raw ActualValidityHistory
    -> effective validity frontier

compatible effective Event + validity frontiers
+ historical routing
    -> Consumption
```

One further question is intentionally left open for a focused follow-up rather than answered by assumption:

> When an Event is replaced by movement correction, what occurrence-validity evidence should the replacement Event use, and how should that compose with an independently corrected occurrence date?

That question crosses two already-valid append-only correction systems. It should be observed directly rather than solved by copying the original date, inventing a new date, or relying on storage order.

### Composition discipline for future slices

From this point, a local observation or practical slice should include one explicit whole-system pass before it is considered closed:

1. identify upstream retained evidence that determines its answer;
2. identify correction / replacement / lifecycle frontiers that can change which evidence is effective;
3. identify historical coordinates or routing that affect interpretation;
4. identify downstream projections that consume the result;
5. check whether the new slice creates duplicated retained truth or a synchronization obligation with an existing family.

The purpose is not to reopen the entire household survey every time. It is a bounded integration pressure pass around the new seam.

## Practical consequence

The next Scheduled lifecycle operation can remain Scheduled-local.

In particular, supersession can be explored as explicit Scheduled -> Scheduled successor evidence without simultaneously introducing reserved-Capacity mutation.

A later practical Commitment / Headroom query should first attempt to compose:

```text
Capacity
+ correction-effective routed Actual
+ effective Actual-valid coordinates
+ routed open Scheduled
+ lifecycle evidence
```

rather than storing a second envelope-budget state.

Before that practical query is exposed, the Event-correction / Actual-validity composition seam identified above should be qualified so Consumption has one explicit effective Actual frontier.

## Boundaries

This observation is deliberately narrower than the production household system.

- Each quantity fact is already associated with a Purpose. Historical routing itself is abstracted away here; Observations 107 and 108 remain the authority for routing / Commitment pressure.
- Quantities model positive per-purpose claims, not the complete signed multi-Measure Event algebra.
- Backing is not modeled.
- Recurrence / Series is not modeled.
- Capacity's own historical writer-validity question from Observation 112 is unchanged.
- Event-correction / Actual-validity correction composition is identified here as an implementation seam but is not solved by this Alloy model.
- This does not prove that no future household operation can ever earn additional envelope evidence.
- The result is bounded Alloy evidence, not an unbounded mathematical proof.

The stop condition remains the same:

> If two worlds can agree on all retained LOAM evidence but require different household answers, the missing distinction has earned investigation.

Observation 113 did not find such missing retained envelope state for this composition. It did find the opposite pressure against an independently retained reservation mirror.
