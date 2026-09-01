# Observation 089 — What admission evidence must survive restart?

## Question

Observation 088 established that neither first appearance nor an existing human-facing operation verb proves a zero-origin admission.

The earned distinction was:

```text
first appearance
    can locate a possible origin in time

operation kind + physical first Event
    -/-> anchored-current enrollment

explicit zero-origin admission evidence
    -> can justify a first-event origin
```

Daily use adds a restart boundary.

Suppose one operation admits a previously unseen coordinate with the premise:

```text
this coordinate begins empty here
and this Event is its first activity
```

If the process later restarts, neutral Event facts still exist. But the application must also recover:

- whether that coordinate joined anchored-current;
- which stable Event identity supplies the first-event origin.

The question is therefore:

> How much of the admission distinction must remain in retained canonical state for restart to preserve the same anchored-current meaning?

This observation asks about information sufficiency, not final storage topology.

## Why Alloy is earned here

Observation 087 and Observation 088 used TLA+ because their questions depended on transition order and first appearance.

Observation 089 asks a different question after those temporal facts have already been established:

> Can two semantically different histories collapse to the same retained snapshot?

One structural counterexample is enough to show information loss. Alloy is therefore the smaller tool for this checkpoint.

## Experiment-local representation

The model uses:

- neutral `Coordinate`;
- stable `Event` atoms;
- one deliberately fixed human-facing operation kind, `Transfer`;
- a `World` containing retained Events;
- an experiment-local relation

```text
Coordinate -> origin Event
```

named `zeroOriginAdmission`.

That relation means only:

```text
this coordinate is enrolled in the selected anchored-current question
and this exact Event is the first-event zero origin
```

It is not promoted to Core or Persistence.

All admission relations must reference a retained Event at the same coordinate.

## Observed Alloy result

Alloy 6.2.0 + Sat4j produced the expected receipt:

```text
sameEventSnapshotDifferentAdmission              SAT
sameMembershipSnapshotDifferentOrigin            SAT
EventSnapshotDeterminesAdmission                 SAT counterexample
EventAndMembershipSnapshotDeterminesOrigin       SAT counterexample
AdmissionAlwaysReferencesRetainedEvent           UNSAT counterexample
ExplicitAdmissionDeterminesRestartMeaning        UNSAT counterexample
```

## Boundary 1 — Event + verb do not retain enrollment

Because every modeled Event uses the same `Transfer` operation, Alloy found two Worlds that retain exactly the same Event identities, coordinates, and operation vocabulary while differing in zero-origin admission.

Therefore:

```text
Event + operation verb
    -/-> restart-safe admission
```

Retaining neutral Events plus the existing human-facing verb is not sufficient to reconstruct whether a coordinate was admitted.

## Boundary 2 — membership alone still loses the origin Event

A tempting repair is to persist only:

```text
this coordinate participates in anchored-current
```

But LOAM does not treat Event list order as chronology.

Alloy found two Worlds with the same retained Events and the same enrolled coordinate set while the admission relation points that coordinate at different stable Event identities.

Therefore:

```text
Event + enrolled-coordinate membership
    -/-> restart-safe first-event origin
```

The retained distinction needs more than an enrollment bit or set membership. For this bounded question it needs the binding:

```text
coordinate -> origin Event identity
```

## Positive retained relation

The explicit admission relation is constrained to reference only retained Events at the same coordinate.

Alloy found no counterexample to either positive check:

```text
AdmissionAlwaysReferencesRetainedEvent
    UNSAT counterexample

ExplicitAdmissionDeterminesRestartMeaning
    UNSAT counterexample
```

Once the exact admission relation is retained, two snapshots that agree on retained Events and that relation cannot disagree on enrolled coordinates in this model.

This is intentionally an information-sufficiency result, not a serialization proof.

## Qualified boundary

The earned information boundary is:

```text
Event + operation verb
    -/-> restart-safe admission

Event + enrolled-coordinate membership
    -/-> restart-safe first-event origin

Event + explicit coordinate-to-origin-Event admission evidence
    -> enough information for this bounded restart meaning
```

Observation 089 therefore answers the pressure from Observation 088 more carefully than saying "make a new typed fact" immediately.

What is required is that the admission distinction survive restart in canonical retained information, including the stable identity of the Event that supplies the local zero origin.

A separate typed fact family is now a strong production candidate because Application 006 already showed that later canonical fact families can be added conservatively without changing Event meaning. But this observation does not force:

- one dedicated file;
- one dedicated stream;
- one particular type name;
- one wire format;
- one universal Query primitive.

Another explicit typed representation could in principle preserve the same coordinate-to-origin-Event distinction.

## Practical implication

A future operation such as:

```text
create an empty new wallet here
and move 3000 JPY into it
```

could retain:

```text
Event
  source     -3000
  new-wallet +3000

Admission
  new-wallet -> that Event
```

After restart, the application would not infer the origin from file order, operation shape, or mere first appearance in the Event set.

By contrast, an activity-only use locus would simply have no such admission relation.

This allows a future household vocabulary in which a new current-relevant coordinate can be born through use without requiring a predeclared global account master, while its birth remains an explicit retained fact rather than an inference from syntax.

## Next pressure

The next question is no longer whether some admission information must survive restart. It is:

> What is the smallest production fact family that can retain `coordinate -> origin Event` without turning this local query evidence into a universal Account or Query framework?

A conservative append-only admission fact is an obvious candidate, but its identity, correction semantics, and interaction with application-start basis remain unearned.

## Non-goals

Observation 089 does not earn:

- production admission persistence;
- an `Account`, `HoldingRole`, `UseRole`, or Expense Category primitive;
- a generic persistent Query type;
- an automatic transfer-destination rule;
- correction semantics for admission;
- retirement/removal from anchored-current;
- a separate physical storage stream as a requirement.

Those remain later questions.

## Practical Core impact

None at this checkpoint.

- no Core change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no private household values committed.
