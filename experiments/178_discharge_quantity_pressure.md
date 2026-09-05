# Observation 178: Does practical discharge need its own exact quantity?

## Context

PR #364 makes the first explicit positive `RelationUnit` writable from ordinary Movement while preserving the separation established by Observations 163–177:

```text
physical Event / Effect
!= burden meaning
!= directional open relation
```

The recurring household witness now has a practical first half:

```text
travel payment Event
+ source Effect
+ external friend -> Household RelationUnit 400
```

The next real occurrence is the friend sending money through PayPay. That later Event should be able to say which retained relation it fulfills.

Observation 165 already showed that discharge provenance must be explicit and that a later Event can discharge obligation-like units. Observation 166 showed that the later discharge endpoint can remain Event-scoped while the source meaning uses `(EventId, EffectKey)` precision.

However, Observation 165 used abstract `Unit` atoms. Its partial-settlement witness split one origin into two independent units before discharge. Current production has a different granularity:

```text
RelationUnit
  stable identity
  exact positive Quantity
```

One `RelationUnit` may therefore carry `400` rather than four hundred pre-split atoms.

That creates a new concrete question.

## Question

Is this enough?

```text
later EventId -> RelationUnitId
```

Or does partial settlement force the discharge correspondence itself to retain an exact quantity?

The candidate is:

```text
later EventId
+ target RelationUnitId
+ exact positive discharge Quantity
```

with outstanding derived rather than stored:

```text
outstanding(relation)
  = relation.quantity
    - sum(discharge.quantity for relation)
```

Observation 178 also asks whether several pieces inside the same later Event and target relation need a new identity, or whether one normalized `(EventId, RelationUnitId)` row with their exact aggregate is enough for the currently demanded questions.

## Deliberately unchanged boundaries

This observation does not reopen:

- relation endpoint identity from Observation 172;
- relation-plane partition law from Observation 173;
- source sign independence from Observation 174;
- retraction versus known-none from Observation 175;
- production relation vocabulary from Observation 176;
- Event-last relation publication from Observation 177;
- Effect-level source anchoring from Observation 166.

In particular:

```text
retraction
!=
discharge
```

Retraction says retained relation evidence is no longer current authority. Discharge says a current, semantically valid relation was fulfilled by a later actual occurrence. Observation 178 models only the second case.

## Model

The bounded Alloy model has:

```text
Event
RelationUnit { sourceEvent, quantity }
Discharge { event, target, quantity }
BareDischarge { event, target }
World
```

`BareDischarge` is not a second candidate to implement. It is the deliberately weaker quantity-free projection used to ask what information would be lost.

The candidate laws are:

```text
relation.quantity > 0
discharge.quantity > 0

discharge.event != relation.sourceEvent

sum(discharge.quantity for relation)
  <= relation.quantity

within one World:
  at most one quantified discharge row
  per (Event, RelationUnit) pair
```

The pair-uniqueness law is a normalization candidate, not a universal settlement ontology. If one actual Event contains several indistinguishable pieces that all discharge the same relation, their exact sum can be retained in one row unless a future query requires piece identity.

No discharge correction/reversal policy is modeled.

## Probe 1: partial discharge of one aggregate RelationUnit

```text
relation.quantity = 10
receipt A discharges 4
```

Expected:

```text
outstanding = 6
```

**SAT** is required.

The same world's quantity-free pair projection would say only that a discharge exists. If existence means whole settlement, it produces `0`, not `6`.

This is the first pressure for exact quantity on the discharge correspondence itself.

## Probe 2: one relation may be fulfilled across two later Events

```text
relation.quantity = 10
receipt A = 4
receipt B = 6
```

Expected:

```text
outstanding = 0
```

**SAT** is required.

This preserves Observation 165's partial-settlement capability without requiring the original RelationUnit to be pre-split according to future payment history.

## Probe 3: one later Event may discharge multiple RelationUnits

A single receipt/payment Event may settle two earlier relations from different origins:

```text
receipt Event
  -> relation A: 4
  -> relation B: 5
```

Expected: **SAT**.

This retains the many-to-many shape at the Event/relation boundary while keeping each correspondence exact.

## Probe 4: bare Event-to-relation correspondence does not determine outstanding

Two Worlds retain the same:

```text
Events
RelationUnit
BareDischarge pair
```

but one quantified discharge is `4` and the other is `7` against relation quantity `10`.

Expected: **SAT** with outstanding `6` versus `3`.

Therefore:

```text
EventId + RelationUnitId
```

alone does not determine partial outstanding quantity.

The exact discharge quantity is independent evidence. It cannot safely be inferred from the existence of the correspondence.

## Probe 5: same Event/target pieces can aggregate without new identity

Two conceptual pieces `2 + 3` inside one later Event toward the same relation are represented by one correspondence quantity `5`.

Expected: **SAT**, outstanding `5` from a relation of `10`.

For the current question, no semantic observation distinguishes the two pieces after they are known to belong to the same later Event and same RelationUnit. This is a stop condition against immediately introducing `DischargeId` or a generic quantity-slice identity.

A future correction/reversal operation that must target one discharge row could reopen identity pressure.

## Probe 6: over-discharge is rejected

```text
relation.quantity = 10
receipt A = 6
receipt B = 5
```

Expected: **UNSAT** under the candidate aggregate law.

Production admission should fail closed rather than silently clamp outstanding to zero or allow negative outstanding.

## Checks

Expected no counterexample:

- `OutstandingNeverNegative`
- `FullyDischargedExactlyAtQuantity`
- `OneEventRelationPairPerWorld`

Expected counterexamples:

- `BarePairProjectionDeterminesOutstanding`
- `AnyDischargeMeansFullySettled`

The latter two are intentionally too strong and demonstrate that quantity-free pair evidence collapses partial settlement.

## Candidate consequence

If the expected matrix holds, the minimum next semantic boundary becomes:

```text
RelationDischarge
  event: EventId
  target: RelationUnitId
  quantity: Quantity
```

where Application admission establishes:

- referenced later Event exists;
- referenced current RelationUnit exists;
- quantity is strictly positive;
- aggregate admitted discharge for one RelationUnit never exceeds that RelationUnit's quantity;
- at most one current discharge row exists for one `(EventId, RelationUnitId)` pair.

The relation's MeasureId can still be recovered through its admitted source Effect. The discharge row does not need a duplicated measure coordinate merely to preserve exactness.

Outstanding remains a projection:

```text
RelationUnit.quantity - admitted discharge total
```

not stored `OutstandingBalance` state.

## What this would not earn

Even if qualified, Observation 178 would not yet earn:

- a `Settlement` entity;
- a `DischargeId`;
- a generic `QuantityPartId` / `SliceId`;
- RelationRevision as discharge;
- discharge correction/reversal semantics;
- automatic matching by amount, date, endpoint, or sign;
- Effect-level anchoring on the later Event;
- duplicated MeasureId in discharge persistence;
- a completeness cutover;
- a discharge persistence format;
- CLI/TUI publication;
- automatic inheritance across Event correction;
- historical backfill.

The next promotion checkpoint, if this observation qualifies, should compare this three-field family-specific evidence against existing Core/Application boundaries before introducing production types.

## Stack

Observation 178 is stacked on PR #364 `cli/movement-open-relation-publication` at exact head:

`1c1cea20f0a87caccd9844f7b1d081e645ef02be`

PR #360 through #364 remain open and unmerged.
