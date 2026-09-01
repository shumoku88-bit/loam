# Observation 090 — Do application-start basis and first-event admission share one origin shape?

## Question

Application 008 established a production starting quantity basis:

```text
current coordinate quantity
  = selected application-start basis
  + correction-aware Event quantity
```

The basis means that quantity was already present when the selected application image began. It is deliberately not an Event.

Observations 087–089 then established a different way a coordinate may become relevant to anchored-current after the application has already begun:

```text
this coordinate is exactly zero immediately before Event E
and Event E is its first activity
```

Restart-safe retention additionally needs the stable identity of `E`.

Both constructions look like an origin for later current-quantity arithmetic. The question is therefore:

> Do they have one common origin meaning, or does a common arithmetic shape still require distinct origin evidence?

This observation deliberately does not rename or generalize production `QuantityBasis`.

## Existing production meaning

`QuantityBasis` currently means:

```text
one exact quantity already present at one Locus × Measure coordinate
when the selected application image begins
```

Production current quantity then adds the selected basis to the effective Event contribution at that coordinate.

First-event admission differs in its premise:

```text
origin quantity = exact zero
origin boundary = immediately before one stable Event identity
that Event = first activity at the coordinate
```

So both can participate in the abstract arithmetic sentence:

```text
current = origin quantity + activity after that origin
```

but that sentence alone may erase why the origin is valid and where its boundary is.

## Alloy probe

The model retains only the structural distinction needed for this question.

An experiment-local `OriginEvidence` has:

```text
Coordinate
OriginBoundary
QuantityMark
optional origin Event
```

with two boundary forms:

```text
ApplicationStart
  arbitrary origin quantity
  no origin Event

BeforeFirstEvent
  exact zero origin quantity
  one stable origin Event
```

A first-event origin Event must be among the retained Events of that World.

The model then deliberately erases the boundary field and Event reference and compares only:

```text
same Coordinate
same origin quantity
same retained Event snapshot
```

## Boundary witness

The smallest witness asks whether two Worlds can have exactly the same erased origin inputs while one means application-start and the other means first-event origin.

Expected result:

```text
sameZeroAnchorShapeDifferentBoundary    SAT
```

Both Worlds have:

```text
same coordinate
origin quantity = zero
same retained Event set
```

but one keeps:

```text
boundary = ApplicationStart
originEvent = none
```

and the other keeps:

```text
boundary = BeforeFirstEvent
originEvent = E
```

If this is SAT, a generic origin representation containing only coordinate plus quantity would lose provenance even when the arithmetic input is identical.

The corresponding deliberately false universal assertion is:

```text
ErasedOriginDeterminesBoundary
```

Expected result:

```text
SAT counterexample
```

## Zero is not enough to identify first-event admission

An explicit zero application-start basis is already meaningful in production. Therefore zero quantity by itself must not imply that the coordinate was born at a later Event.

The deliberately false assertion is:

```text
ZeroQuantityDeterminesFirstEventBoundary
```

Expected result:

```text
SAT counterexample
```

This is directly relevant to the dogfood pressure that produced `coffee = 0`: the numeric zero alone cannot tell us whether it is a truthful application-start basis or a first-event birth claim.

## Positive shape checks

The candidate distinction also checks:

```text
FirstEventOriginIsExactZero
ApplicationStartOriginHasNoEvent
FirstEventOriginReferencesRetainedEvent
```

Expected result for each:

```text
UNSAT counterexample
```

These checks do not make either origin form a production type. They only preserve the premises already earned by Application 008 and Observations 087–089.

## Candidate interpretation

If the expected results hold, the qualified boundary is:

```text
application-start basis
first-event admission
    share an algebraic role:
      origin quantity + subsequent activity

but

coordinate + origin quantity
    -/-> sufficient origin meaning

origin boundary/evidence
    must remain explicit
```

So the two constructions may eventually feed one projection interface without becoming the same canonical fact.

Two implementation families remain plausible:

```text
separate typed fact families
    -> common projection adapter

or

one explicit sum-shaped origin evidence family
    -> ApplicationStart | BeforeFirstEvent(EventId)
```

This observation does not choose between them.

## Important boundary

A general `Origin`, `Anchor`, or `Account` abstraction is not earned merely because both forms share arithmetic.

The production `QuantityBasis` meaning should not be weakened from:

```text
quantity already present at application-image start
```

into a generic origin bag unless a later application requires that change.

Likewise first-event admission must not be simulated by inserting a zero `QuantityBasis`, because doing so would discard the stable Event boundary that Observation 089 showed restart-safe meaning may require.

## Non-goals

Observation 090 does not earn:

- a production `Origin` type;
- a production admission fact;
- a rename or generalization of `QuantityBasis`;
- one combined persistence stream;
- a timestamp or global chronology;
- automatic coordinate birth;
- Account, HoldingRole, UseRole, or Expense Category;
- correction or retirement semantics for admission;
- a new current-quantity implementation.

## Practical Core impact

None.

- no Core change;
- no Application production change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no private household values committed.
