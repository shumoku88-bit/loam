# Observation 122 — Does a completed Scheduled occurrence need distinct continuation provenance?

## Household question

LOAM can already retain one Scheduled occurrence, later retain an Actual Event that realizes it, and keep those two facts connected by explicit completion evidence.

Daily use adds a different pressure:

```text
September Scheduled
    -> September Actual
    -> October Scheduled?
```

Sometimes the next occurrence should be added only after the current one is paid. Sometimes several future occurrences are already present. Sometimes there is no next occurrence at all. The question is therefore not whether LOAM should automatically generate recurrence.

The narrower question is:

> If a later Scheduled occurrence already exists, can LOAM know that it is the next occurrence of the completed one from date and movement similarity alone, or is distinct continuation provenance observable?

This observation also compares that relation with Observation 105's existing Scheduled -> Scheduled successor/replacement meaning.

## Competing meanings

Observation 105 earned a terminal successor/replacement relation:

```text
old Scheduled
    -> replacement Scheduled
```

The old occurrence is superseded rather than realized.

The new household pressure has a different shape:

```text
old Scheduled
    -> Actual

old Scheduled
    -> next Scheduled
```

Completion and next-occurrence provenance may therefore coexist for the same source.

The model calls the second relation `continuation` only as observation vocabulary. It is not a proposed Practical Core type or persistence record.

## Bounded questions

The Alloy model asks whether:

1. one Scheduled occurrence can be completed and still retain a linked next occurrence;
2. a chain of future occurrences can be linked before the current occurrence is completed;
3. that pre-created chain can remain after completion without generating another occurrence;
4. Observation 105's terminal replacement edge can be reused unchanged as next-occurrence provenance;
5. exactly one later Scheduled fact with the same movement shape is enough to reconstruct "this is the next one";
6. two worlds can have the same completion/replacement lifecycle and the same Scheduled facts while differing only in continuation provenance;
7. continuation alone leaves the source Scheduled live until independent terminal evidence exists.

## Executed result

Alloy 6.2.0 + Sat4j produced the expected result set:

```text
completedOccurrenceCanHaveLinkedNext          SAT
precreatedFutureChainBeforeCompletion          SAT
precreatedFutureChainSurvivesCompletion        SAT
completionPlusReplacementAsNext                UNSAT
oneSimilarFutureStillNeedsProvenance            SAT
sameLifecycleDifferentContinuation              SAT
StructuralFutureDeterminesContinuation          SAT counterexample
ContinuationDoesNotCloseSource                  UNSAT counterexample
```

The exact-head Observation 122 workflow required this complete result set and completed successfully.

## Finding

The result separates three meanings that a daily UI could otherwise blur.

First, realization and next-occurrence provenance are compatible:

```text
Scheduled A -> Actual A
Scheduled A -> Scheduled B
```

A completed occurrence can therefore still point to an already-retained future occurrence.

Second, several future occurrences can already form a continuation chain before the current occurrence is paid, and that chain remains valid after completion. Therefore:

```text
pay current occurrence
    does not imply
create exactly one new future occurrence now
```

The household may pre-create a longer horizon and simply consume it over time.

Third, Observation 105's replacement edge cannot carry this meaning unchanged. Under its already-earned lifecycle semantics, completion and replacement are competing terminal claims for the same source, while continuation must be able to coexist with completion.

The information boundary is therefore:

```text
future Scheduled similarity
    !=
next-occurrence provenance

Observation-105 replacement
    !=
post-completion continuation
```

Even when there is exactly one later Scheduled fact with the same retained movement shape, two otherwise lifecycle-equivalent worlds can disagree about whether it is the linked next occurrence. Date and movement similarity do not reconstruct that provenance.

Continuation also does not close the current occurrence by itself. It may be retained ahead of time while the source remains live until independent completion/replacement/retirement evidence arrives.

## UI consequence

A future practical UI now has a sound distinction to project:

```text
linked next occurrence already exists
    -> show it after realization
    -> do not ask the user to replenish it again

no linked next occurrence
    -> optionally offer "Add next scheduled movement"
```

The second case is only an offer. Absence of a linked next occurrence does **not** establish that recurrence ended, and this observation gives no reason to auto-generate a future occurrence after every payment.

This also leaves room for both household styles:

```text
just-in-time
    complete September
    -> add October when useful

pre-filled horizon
    September -> October -> November -> December already linked
    -> completing September simply reveals October as the next retained occurrence
```

## Deliberate boundary

This observation does **not** introduce:

- Recurrence;
- Series;
- frequency or monthly rules;
- automatic future generation;
- a retained "recurrence ended" state;
- copy-forward amount/date policy;
- UI layout or final user-facing wording;
- a Practical Core `ScheduledContinuation` type;
- persistence or CLI changes.

The solver establishes that continuation provenance is independently observable. A retained Practical Core relation should still wait until a practical Scheduled UI or dogfood workflow actually needs to preserve that answer.

## Tool choice

Alloy is sufficient because the immediate question is static distinguishability and information sufficiency: can the same retained Scheduled/Actual shapes support different answers about which future occurrence is "next"?

TLA+ or SPIN would become useful later if the pressure becomes operational, for example completion racing with another writer that adds or links a future occurrence. J is unnecessary until the question becomes about coverage shape across a larger calendar horizon.
