# Observation 093 — Which time places an Event relative to an origin?

## Question

Observation 092 found that one selected quantity origin does not need a global total Event chronology merely to derive its post-origin activity scope. Information as weak as an origin-relative `Before / At / After` cut is sufficient in the bounded model.

Observation 035 had already separated two temporal coordinates:

```text
valid time    = when an observation applies
learned time  = when that observation becomes available to the system
```

The new question is therefore narrower:

> When a retained Event is learned retrospectively, which coordinate determines whether it belongs before or after a selected quantity origin?

## Pressure case

Use a selected origin with:

```text
Origin valid   = 1
Origin learned = 1
```

Then admit an Event later:

```text
Event
  valid   = 0
  learned = 2
```

The same Event has two different apparent relations to the origin:

```text
by valid time
  Event < Origin

by learned time
  Origin < Event
```

The experiment asks whether learned-time placement can substitute for valid-time placement when the query means:

```text
activity whose validity lies at or after this origin
```

## Model

`OriginScopeValidVsLearned.tla` keeps only:

- one fixed origin coordinate;
- append-only Event observation history;
- unique Event identity;
- `valid <= learned` as in Observation 035;
- no correction, conflict, quantity arithmetic, wall-clock type, or production persistence.

Observation is allowed only once the selected origin is already known. This isolates retrospective admission after origin selection rather than reopening origin discovery.

## Two candidate scopes

The model derives:

```text
InValidScope(Event)
  = Event.valid >= Origin.valid

InLearnedScope(Event)
  = Event.learned >= Origin.learned
```

and makes both knowledge-sensitive:

```text
KnownValidMembers(history, knowledgeTime)
KnownLearnedMembers(history, knowledgeTime)
```

An Event cannot appear in either known set before it has been learned.

So the distinction is not:

```text
valid time knows the Event earlier
```

It does not.

The distinction is:

```text
learned time decides when classification becomes available
valid time decides which side of the origin the Event belongs to
```

if the query is about valid activity relative to that origin.

## Positive properties

The primary TLC run checks:

1. type correctness;
2. Event identity remains unique;
3. validity never lies after learning;
4. observation does not precede origin knowledge in this experiment;
5. neither candidate scope can know an Event before learning;
6. a pre-origin valid Event never enters the valid-time post-origin scope;
7. a post-origin valid Event enters that scope once learned;
8. a retrospectively learned pre-origin Event remains outside that scope;
9. history only extends.

## Deliberately strong boundary

The boundary invariant says:

```text
for every Event learned after the origin was learned,
learned-time scope membership
=
valid-time scope membership
```

or:

```text
LearnedScopeMatchesValidScopeForLateEvents
```

The intended counterexample is a retrospective Event:

```text
now = 2
Event.valid = 0
Event.learned = 2

InValidScope(Event)   = FALSE
InLearnedScope(Event) = TRUE
```

## Observed TLC result

TLC 2.19 with TLA+ tools 1.7.4 produced:

```text
positive model
  192 states generated
  192 distinct states
  depth 6
  no error

LearnedScopeMatchesValidScopeForLateEvents
  violated as intended
  depth 4

witness
  now = 2
  history = <<[
    id      |-> "e0",
    valid   |-> 0,
    learned |-> 2
  ]>>
```

The trace is exactly the pressure case:

```text
state 1  now = 0, no Event known
state 2  now = 1, origin knowledge coordinate reached
state 3  now = 2, still no Event known
state 4  admit e0 with valid=0, learned=2
```

At state 4:

```text
valid-time relation
  e0 < Origin

learned-time relation
  Origin < e0
```

So a learned-time post-origin cut would admit a retrospectively learned pre-origin Event that the valid-time cut excludes.

## Interpretation

The bounded conclusion is:

> For a query defined as activity valid at or after a selected origin, learned time cannot substitute for valid time once retrospective admission is possible.

Observation 035's two times now play two distinct roles at the quantity-origin boundary:

```text
learned time
  when LOAM can first know the Event's classification

valid time
  which side of the selected origin the Event belongs to
```

This does **not** claim that valid time is universally more important than learned time.

Learned time still answers a distinct and necessary question:

```text
when could LOAM first have known or acted on this Event?
```

A later admission can therefore change the system's present knowledge without changing the Event's valid-time relation to the selected origin.

Likewise, this observation does not yet decide how a human supplies valid time, how coarse coordinates handle ties, or whether production Events themselves receive any temporal field.

Observation 092 already showed that a scalar time coordinate is not automatically the minimal representation for one origin query.

## Why TLA+ is earned

The important distinction appears through arrival:

```text
origin already known
advance knowledge time
admit retrospective Event
```

The Event was not available before admission, then becomes known while remaining validly before the origin.

That changing knowledge state is exactly the part Alloy does not add to Observation 092's static information-sufficiency result.

## Non-goals

Observation 093 does not earn:

- a production Event `validTime` field;
- a production Event `learnedTime` field;
- wall-clock or calendar semantics;
- timestamp uniqueness;
- storage order as time;
- a global Event chronology;
- correction semantics for temporal coordinates;
- automatic origin reassignment after retrospective admission;
- a CurrentQuantity production change.

## Practical Core impact

None.

- no Core change;
- no Application production change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no private household values committed.
