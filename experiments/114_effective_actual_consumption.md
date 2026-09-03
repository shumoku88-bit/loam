# Observation 114: Which Actual survives into Consumption after correction?

Status: qualified bounded Alloy composition observation after Observation 113

## Question

Observation 113 found that envelope-style answers can remain projections of Capacity, Actual, and open Scheduled evidence, but its whole-system composition pass exposed an existing seam:

- physical effective-quantity views already use the Event correction frontier;
- `ConsumptionInspection` still consumes raw `EventMemory`;
- occurrence time is independently retained and independently correctable through `ActualValidityHistory`.

Before exposing practical Consumption / Remaining / Headroom, ask:

> When an Actual Event is replaced append-only, which Event and which occurrence-valid coordinate are allowed to contribute to historical routing and Consumption?

A second question follows directly:

> Does `EventCorrection target -> replacement` itself justify inheriting the target Event's occurrence day, or must the replacement Event have its own explicit Actual-validity evidence?

## Candidate composition

The selected candidate composes existing frontiers in this order:

```text
raw EventMemory
+ EventCorrectionMemory
        |
        v
current Event frontier
        |
        +-------------------------+
                                  |
raw ActualValidityHistory         |
        |                         |
        v                         |
current validity frontier         |
        |                         |
        +---- EventId ------------+
                  |
                  v
          effective occurrence day
                  |
                  v
          historical routing
                  |
                  v
             Consumption
```

The composition fails closed if a current Event has no current Actual-valid coordinate.

It does not derive a replacement Event's date from the Event correction edge.

## Competing shortcuts

### Count raw Events

If both original and replacement remain in append-only Event memory, summing raw Events can count both.

The model explicitly searches for this world.

### Inherit the target date semantically

A tempting shortcut is:

```text
EventCorrection original -> replacement
original.validOn = day
therefore replacement.validOn = day
```

The model deliberately asks whether the correction relation forces that equality.

It does not.

Event correction and temporal correction answer different questions and are retained as different evidence families in current LOAM.

## Executed result

Alloy 6.2.0 + Sat4j:

```text
rawDoubleCountsCorrectedActual                    SAT
missingReplacementValidityFailsClosed             SAT
correctionDoesNotForceSameOccurrenceDay           SAT
replacementDateCorrectionReroutesConsumption      SAT
correctionsChangeAnswerWithoutChangingRawEvents   SAT

RawAndEffectiveAgreeWithoutEventCorrection        UNSAT counterexample
EventCorrectionImpliesSameOccurrenceDay           SAT counterexample
EffectiveInputsDetermineConsumption               UNSAT counterexample
```

### Reading the results

`rawDoubleCountsCorrectedActual` is SAT.

A bounded world exists where the original and replacement Events both remain in raw memory, both route to the same Purpose, and raw summation counts both while the Event frontier counts only the replacement.

So raw Event memory is not the correct input to current Consumption once Event correction exists.

`missingReplacementValidityFailsClosed` is SAT.

A bounded world exists where the original Event has occurrence-validity evidence, the Event correction selects a replacement, and the replacement has no occurrence-validity evidence. The selected composition has no valid Consumption answer for that replacement.

The target Event's date is not silently borrowed.

`correctionDoesNotForceSameOccurrenceDay` and the check `EventCorrectionImpliesSameOccurrenceDay` both find a counterexample to semantic date inheritance.

The model admits a corrected Event pair whose current validity coordinates differ. Therefore the Event correction relation alone is too small to determine the replacement's occurrence day.

`replacementDateCorrectionReroutesConsumption` is SAT.

A replacement Event can first have one explicit valid day and later receive an append-only validity correction to another day. Historical routing can map those days to different Purposes, and Consumption follows the corrected validity frontier.

`correctionsChangeAnswerWithoutChangingRawEvents` is SAT.

Two worlds can retain the same raw Events, validity facts, and routing while differing in Event correction evidence and therefore requiring different current Consumption answers. Event correction evidence is independently relevant to the projection.

`EffectiveInputsDetermineConsumption` has no bounded counterexample.

Once the effective Event frontier, effective validity frontier, and routing evidence are fixed, changing superseded raw history does not create another Consumption answer in this model.

## Finding

The practical composition boundary should be:

```text
Event correction frontier
        first

Actual-validity correction frontier
        independently

join current EventId to its current valid coordinate
        then

historical routing at that coordinate
        then

Consumption
```

This gives one important negative rule:

> Do not infer replacement occurrence time from `EventCorrection` inside downstream projections.

If a replacement Event has no explicit current Actual-validity evidence, Consumption should fail closed rather than silently reuse the target Event's date.

## Practical writer consequence

The current movement-correction UI edits movement content, not occurrence date. A practical writer may therefore choose a convenience policy such as carrying the target's currently effective day forward when it creates the replacement.

But if LOAM adopts that convenience, the carried-forward day must be **published as the replacement Event's own explicit Actual-validity fact**. It is writer-created evidence reflecting that interaction, not a semantic theorem derived from `EventCorrection`.

A later date correction must then target the replacement Event's own validity history, and historical routing / Consumption must observe that corrected frontier.

This distinction keeps the Core small:

```text
Core / projection law
    no implicit date inheritance

practical movement-only correction writer
    may explicitly carry current date forward
    if qualified by its own publication / recovery behavior
```

Observation 114 does not yet qualify the multi-stream crash/retry protocol for adding replacement validity during movement correction. That should be handled by the practical writer change rather than hidden inside the projection.

## Existing implementation seam confirmed

Current `Loam.Application.CorrectionFrontier` already derives an effective `EventMemory` by removing correction targets.

Current `Loam.Application.ActualValidityFrontier` already derives one current `ActualValidityMemory` from append-only validity facts and corrections.

Current `Loam.Application.ConsumptionInspection`, however, still takes raw `EventMemory` plus an already-projected `ActualValidityMemory` and does not compose the Event correction frontier itself.

So the next production change can remain small:

1. add or expose a correction-aware Consumption / Remaining boundary that first obtains the admitted Event frontier;
2. keep the existing pure per-Event routing arithmetic;
3. fail closed when the effective Event frontier lacks current validity evidence;
4. separately qualify the movement-correction writer's explicit replacement-validity publication.

No generic `EffectiveActual` object graph is required by this observation.

## Whole-system composition pass

The result remains consistent with the surrounding LOAM structure:

- `QuantityBasis` and current physical balance already use correction-effective Events;
- Capacity stays independent authority evidence;
- Actual-validity remains separate temporal evidence;
- historical routing stays time-indexed rather than being rewritten to current routing;
- Scheduled Complete already creates a distinct Actual Event with explicit Actual-validity evidence;
- Observation 113's `Remaining = Entitlement - Consumption` remains viable once Consumption uses effective Actual rather than raw Actual.

The newly exposed writer seam is therefore local to ordinary movement correction, not a reason to merge Actual, Capacity, Scheduled, or temporal evidence into one state machine.

## Boundaries

- The Alloy model uses one positive quantity per Event rather than the complete signed multi-Effect / multi-Measure algebra. The question under test is frontier and temporal authority, not balance arithmetic.
- It uses two explicit days and direct day-indexed routing rather than the full ordered historical routing implementation.
- It assumes admitted disjoint correction paths, matching the existing selected Event and validity frontier boundaries.
- It does not qualify crash recovery or writer lock ordering for a future correction + replacement-validity publication protocol.
- It does not change production code.
- It is bounded Alloy evidence, not an unbounded proof.

## Composition discipline

This observation is a concrete example of the development rule added by Observation 113:

```text
local capability
    -> correction / lifecycle frontier
    -> temporal interpretation
    -> routing
    -> downstream projection
```

A locally correct feature is not considered integrated until this nearby composition path has been checked.
