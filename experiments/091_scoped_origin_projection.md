# Observation 091 — Can distinct origin facts share one projection adapter?

## Question

Observation 090 established that application-start `QuantityBasis` and
first-event zero-origin admission may share the arithmetic sentence

```text
current = origin quantity + subsequent activity
```

while still asserting different origin boundaries.

The next application question is:

> Can those distinct facts feed one small derived projection adapter without
> weakening either canonical meaning?

A second question appears immediately:

> What exactly counts as `subsequent activity` for a first-event origin?

## Existing production boundary

Production `QuantityBasis` means one exact quantity already present at a
`Locus × Measure` coordinate when the selected application image begins.

Production `QuantityInspection` currently derives one correction-aware quantity
from the retained Event memory at a coordinate. With no corrections this is the
whole recorded Event-memory quantity.

The Core deliberately gives neither Event list order nor `EventId` token a
built-in temporal meaning.

Therefore an application-start basis and a first-event origin do not consume the
same activity scope automatically:

```text
application-start basis
  + all represented activity in the selected application image

first-event origin
  + activity at/after that specific origin boundary
```

The second scope is not presently derivable from storage position or EventId.

## Lean probe

`091_scoped_origin_projection.lean` keeps the canonical inputs distinct:

```text
production QuantityBasis

experiment-local FirstEventAdmission
  = coordinate
  + stable origin Event identity
```

They adapt into an experiment-local derived `OriginView`:

```text
ApplicationStart(coordinate, quantity)
BeforeFirstEvent(coordinate, originEvent)
```

This is deliberately a projection input, not a proposed storage type.

The common arithmetic consumes a second explicit input:

```text
ScopedActivity
  = coordinate
  + quantity already known to belong after this origin
```

and computes:

```text
origin quantity + scoped activity
```

only when the coordinates match.

## Expected executable witnesses

The probe checks:

```text
application-start basis 500
+ scoped activity 100
= current 600
```

and:

```text
first-event origin 0
+ scoped activity 100
= current 100
```

So the arithmetic adapter can be shared.

But it also checks a deliberately different input:

```text
first-event origin 0
+ whole retained activity 140
= 140
```

where the specimen interprets 40 as pre-origin activity and 100 as post-origin
activity.

This does not mean the adapter is wrong. It means the adapter cannot decide
which activity is in scope.

## Qualified boundary if the Lean probe passes

```text
QuantityBasis ───────────────┐
                             ├─ derived OriginView
FirstEventAdmission ─────────┘
                                      +
                               scoped activity
                                      ↓
                                current quantity
```

The shared part is only arithmetic and coordinate matching.

The canonical facts remain distinct, and first-event evidence keeps its stable
origin Event identity.

More importantly:

```text
origin Event identity
+ unordered retained Event set
    -/->
post-origin activity quantity
```

is now the next missing information boundary.

Observation 091 does not formally prove that negative relation. It exposes the
missing input by making the adapter require `ScopedActivity` rather than
silently feeding it the existing whole-memory projection.

## Why Lean is earned here

The immediate question is constructive and executable:

- can both origin forms feed the same exact quantity composition;
- can the adapter preserve the evidence distinction;
- can coordinate mismatch fail closed;
- does first-event arithmetic visibly depend on already-scoped activity.

Lean is enough for that application boundary.

A following observation may earn Alloy or TLA+ for the temporal/scope question:
which relation, if any, is sufficient to determine `before / at / after` without
turning storage order into time.

## Time implication

This observation deliberately does **not** introduce a date, timestamp, clock,
or global chronology.

But the first-event branch makes a temporal relation unavoidable in principle:

```text
activity before origin
activity at origin
activity after origin
```

Some future retained evidence must distinguish those regions if first-event
current is to be reconstructed from arbitrary retained history.

That evidence might eventually be a date/time coordinate, a causal/ordering
relation, a selected observation window, or another explicit temporal fact.
Observation 091 does not choose among them.

## Non-goals

Observation 091 does not earn:

- a production `OriginView` or generic Origin type;
- production `FirstEventAdmission` persistence;
- a timestamp or date field on Event;
- storage order as chronology;
- automatic coordinate birth;
- Account, HoldingRole, UseRole, or Expense Category;
- correction semantics for admission;
- a change to production `CurrentQuantity`.

## Practical Core impact

None.

- no Core change;
- no Application production change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no private household values committed.
