# Observation 090 — Do application-start basis and first-event admission share one origin shape?

## Question

Application 008 established the production starting quantity basis:

```text
current coordinate quantity
  = selected application-start basis
  + correction-aware Event quantity
```

The basis means quantity was already present when the selected application image began. It is deliberately not an Event.

Observations 087–089 established another way a coordinate may become relevant to anchored-current after that application image has begun:

```text
this coordinate is exactly zero immediately before Event E
and Event E is its first activity
```

Restart-safe retention additionally needs the stable identity of `E`.

Both constructions can play an algebraic origin role. Observation 090 asks whether that shared arithmetic shape means their evidence can be collapsed.

## Existing meanings retained

Production `QuantityBasis` means:

```text
one exact quantity already present at one Locus × Measure coordinate
when the selected application image begins
```

First-event admission instead carries:

```text
origin quantity = exact zero
origin boundary = immediately before one stable Event identity
that Event = first activity at the coordinate
```

Both may participate in the abstract sentence:

```text
current = origin quantity + activity after that origin
```

but that sentence alone does not say where the origin boundary is or why it is valid.

## Alloy probe

The experiment-local `OriginEvidence` contains:

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

A first-event origin Event must be retained in the corresponding World.

The negative probe then erases boundary and Event-reference evidence and compares only:

```text
same Coordinate
same origin quantity
same retained Event snapshot
```

## Observed Alloy 6.2.0 + Sat4j result

The receipt was:

```text
sameZeroAnchorShapeDifferentBoundary             SAT
ErasedOriginDeterminesBoundary                   SAT counterexample
ZeroQuantityDeterminesFirstEventBoundary         SAT counterexample
FirstEventOriginIsExactZero                      UNSAT counterexample
ApplicationStartOriginHasNoEvent                 UNSAT counterexample
FirstEventOriginReferencesRetainedEvent          UNSAT counterexample
```

The first witness is the key one. Two Worlds can have:

```text
same coordinate
origin quantity = zero
same retained Event set
```

while one keeps:

```text
boundary = ApplicationStart
originEvent = none
```

and the other keeps:

```text
boundary = BeforeFirstEvent
originEvent = E
```

So a representation that retains only coordinate plus origin quantity loses provenance even when the numeric input to later arithmetic is identical.

## Zero does not identify the boundary

The counterexample to:

```text
ZeroQuantityDeterminesFirstEventBoundary
```

is directly relevant to the dogfood pressure that produced an explicit zero basis for a use locus.

```text
origin quantity = 0
```

is compatible with an application-start basis. It does not by itself mean:

```text
this coordinate was born immediately before Event E
```

Therefore a zero `QuantityBasis` cannot safely stand in for first-event admission merely because both begin current arithmetic from numeric zero.

## Positive boundary checks

The positive checks confirm the premises already earned by the earlier work:

```text
BeforeFirstEvent
  -> exact-zero origin quantity
  -> retained stable origin Event

ApplicationStart
  -> no origin Event
```

No counterexample exists in the bounded model for those constraints.

## Finding

The qualified boundary is:

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

one explicit sum-shaped evidence family
    -> ApplicationStart | BeforeFirstEvent(EventId)
```

Observation 090 does not choose between them.

## Important boundary

A general production `Origin` or `Anchor` abstraction is not earned merely because the two forms share arithmetic.

The production `QuantityBasis` meaning should remain:

```text
quantity already present at application-image start
```

unless a later application earns a broader representation.

Likewise first-event admission must not be simulated by inserting a zero `QuantityBasis`, because doing so erases the stable Event boundary that Observation 089 showed restart-safe meaning may require.

## Next pressure

The remaining practical question is no longer whether the two origins are numerically similar. It is:

> What is the smallest production boundary that lets existing `QuantityBasis` and a later first-event admission family feed one current projection without weakening either fact's meaning?

That may be an application-level adapter rather than a new Core abstraction.

## Non-goals

Observation 090 does not earn:

- a production `Origin` or `Anchor` type;
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
