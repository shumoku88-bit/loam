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

## Boundary 1 — Event + verb do not retain enrollment

Because every modeled Event uses the same `Transfer` operation, two Worlds can retain exactly the same Event identities, coordinates, and operation vocabulary while differing only in zero-origin admission.

Expected witness:

```text
sameEventSnapshotDifferentAdmission
    SAT
```

The corresponding deliberately false assertion is:

```text
EventSnapshotDeterminesAdmission
    counterexample
```

If this appears, then retaining neutral Events plus the existing operation verb is not sufficient to reconstruct whether a coordinate was admitted.

## Boundary 2 — membership alone can still lose the origin Event

A tempting repair is to persist only:

```text
this coordinate participates in anchored-current
```

But LOAM does not treat Event list order as chronology.

With two retained Events at the same coordinate, two Worlds may agree that the coordinate is enrolled while disagreeing about which stable Event identity is its first-event origin.

Expected witness:

```text
sameMembershipSnapshotDifferentOrigin
    SAT
```

The corresponding deliberately false assertion is:

```text
EventAndMembershipSnapshotDeterminesOrigin
    counterexample
```

So restart-safe information may need more than an enrollment bit or set membership. It may need the binding:

```text
coordinate -> origin Event identity
```

## Positive retained relation

The explicit admission relation is constrained to reference only retained Events at the same coordinate.

Expected positive checks:

```text
AdmissionAlwaysReferencesRetainedEvent
    UNSAT counterexample

ExplicitAdmissionDeterminesRestartMeaning
    UNSAT counterexample
```

The second result is intentionally modest. It says that once the exact admission relation is retained, two snapshots that agree on retained Events and that relation cannot disagree on enrolled coordinates.

It does not prove a particular file format or serialization.

## Interpretation if qualified

If the expected results hold, the earned information boundary is:

```text
Event + operation verb
    -/-> restart-safe admission

Event + enrolled-coordinate membership
    -/-> restart-safe first-event origin

Event + explicit coordinate-to-origin-Event admission evidence
    -> enough information for this bounded restart meaning
```

This would answer the pressure from Observation 088 more carefully than saying "make a new typed fact" immediately.

What is required is that the admission distinction survive restart in canonical retained information.

A separate typed fact family is a strong candidate because Application 006 already showed that later canonical fact families can be added conservatively without changing Event meaning. But this observation does not force:

- one dedicated file;
- one dedicated stream;
- one particular type name;
- one wire format;
- one universal Query primitive.

The information could in principle be encoded by another explicit typed representation that preserves the same coordinate-to-origin-Event distinction.

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

After restart, the application would not have to infer the origin from file order, operation shape, or the fact that `new-wallet` first appears in the Event set.

By contrast, an activity-only use locus would simply have no such admission relation.

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
