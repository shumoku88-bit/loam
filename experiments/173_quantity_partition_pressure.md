# Observation 173: Is exact quantity partition one global partition, or plane-local evidence?

Status: bounded Alloy observation stacked on Observation 172.

Observation 167 found that one Effect may contain mixed burden and left the likely future shape as:

```text
(EventId, EffectKey)
+ exact quantity partition
+ bearer evidence
```

Observation 168 then showed that burden and directional open-relation evidence are independent planes. Observation 172 further found that a relation needs only a small endpoint identity boundary rather than a general Party ontology.

One representation question is still unresolved before any production burden/relation type is justified:

> Does one source Effect need a single shared identity-bearing partition beneath all semantic overlays, or can each semantic plane carry exact scalar quantities directly against the Effect anchor?

## Existing production pressure

Production `Effect` already carries one exact signed `Quantity` and a stable `EffectKey` inside an `EventId`-identified Event. The current observation does not change that structure.

The model deliberately uses a positive source `magnitude` rather than reproducing the full signed `Quantity` algebra. The question here is partition topology, not whether future overlay quantities should retain sign, use magnitude, or derive orientation from semantic direction. That sign/orientation choice remains unearned.

## Observation-local shape

The bounded model has:

```text
Effect {
  Event
  Key
  magnitude
}
```

and two independent semantic planes.

### Burden plane

For a *known* burden interpretation, one observation-local allocation maps the source Effect to exact scalar amounts:

```text
HouseholdBearer -> quantity
OutsideBearer   -> quantity
```

with the law:

```text
household quantity + outside quantity = source magnitude
```

This observation is conditioned on known burden evidence. Absence / correction / conflict remain governed by Observation 167 and are not reopened here.

### Open-relation plane

Each relation unit retains its already-earned family-specific identity and carries:

```text
source Effect
exact positive quantity
debtor endpoint
creditor endpoint
```

The total relation quantity for one Effect may cover none, some, or all of the source magnitude, but not more than the source magnitude within this bounded partition model.

This observation is likewise not reopening relation absence or correction authority from Observations 168–171.

## Crucial modeling choice: no shared QuantityPart entity

There is deliberately no observation-local object shaped like:

```text
QuantityPartId
UnitId
SliceId
```

that burden and relation must both reference.

Burden carries exact scalar allocation directly. Relation carries exact scalar quantity on its own family-specific relation unit.

The observation asks whether the recurring household cases still fit without a shared identity-bearing partition substrate.

## Probe 1: recurring shared-cost split

A source Effect with magnitude 10 can be represented as:

```text
burden plane
  Household 6
  Outside   4

relation plane
  Outside -> Household 4
```

Expected: **SAT**.

This is the concrete transport-sharing pressure that motivated the observation sequence.

## Probe 2: relation may cover only a strict subset

A source Effect with magnitude 10 may carry only 3 units of open relation.

Expected: **SAT**.

Therefore the relation plane is not required to be a total partition merely because burden is.

## Probe 3: burden and relation cuts need not coincide

A source Effect may have:

```text
Outside burden       4
relation coverage    3
```

Expected: **SAT**.

This preserves Observation 168's independence at exact-quantity level:

```text
outside burden quantity
-/->
open-relation quantity
```

## Probe 4: quantity is not relation identity

Two distinct relation units may share:

```text
same source Effect
same debtor
same creditor
same exact quantity
```

Expected: **SAT**.

So an exact scalar amount does not replace the relation-unit identity already pressured by Observation 172.

## Probe 5: outside burden without relation

A known outside-borne share may exist while that Effect carries no open relation at all.

Expected: **SAT**.

This is the quantity-level version of Observation 168's semantic independence.

## Probe 6: household burden can overlap a payable

A source Effect may be wholly household-borne while the same full magnitude participates in:

```text
Household -> ExternalEndpoint
```

Expected: **SAT**.

This is the key overlap witness.

The burden plane already accounts for the full source quantity, yet relation meaning may simultaneously apply to that same quantity.

Therefore adding burden quantities and relation quantities together as though they were disjoint pieces of one global partition would double-count meaning rather than detect an error.

## Retained checks

### Burden allocation exactly covers source

Expected counterexample: **UNSAT**.

Within a known burden allocation, exact quantities partition the full source magnitude.

### Relation coverage never exceeds source

Expected counterexample: **UNSAT**.

Within this bounded model, relation units form a partial partition of the source magnitude.

## Deliberately too-strong checks

### Relation coverage must equal source

Expected counterexample: **SAT**.

Open relation is not a total semantic classification of every source quantity.

### Outside burden equals relation coverage

Expected counterexample: **SAT**.

Burden quantity does not determine relation quantity.

### All semantic quantities form one globally disjoint partition

Expected counterexample: **SAT**.

This is the central pressure. Burden and relation are independent semantic planes that may overlap on the same source quantity.

### Effect + endpoints + quantity determine relation identity

Expected counterexample: **SAT**.

Multiple relation units may remain distinct even when those coordinates coincide.

## Candidate finding if the matrix holds

The smallest shape pressured so far is not:

```text
Effect
  -> global QuantityPart identity
       -> burden or relation meaning
```

It is closer to:

```text
source anchor
  (EventId, EffectKey)

plane-local exact quantity evidence
  burden:
    exact total allocation by bearer

  open relation:
    zero or more identity-bearing relation units
    each with exact quantity + endpoints
```

The same source quantity may carry meaning on multiple independent planes. Therefore **partition exactness is plane-local, not a theorem of global semantic disjointness**.

This also means the recurring cases do not yet pressure a universal `QuantityPartId` / `UnitId` production primitive.

## What this does not earn

Observation 173 does **not** earn:

- production `BurdenAllocation`, `BurdenFact`, or `RelationUnit` types;
- a generic `QuantityPart`, `Slice`, or `Unit` identity;
- one universal partition shared by all semantic overlays;
- a production choice between signed overlay quantity and positive magnitude;
- automatic equality between outside burden and receivable quantity;
- automatic equality between household burden and payable quantity;
- relation endpoint registry or Party ontology;
- positive-to-none relation retraction representation;
- relation or burden persistence formats;
- completeness cutover date;
- CLI/TUI changes;
- historical backfill.

## Dependency note

This observation is stacked on Observation 172 head `86826fcfb96ef6b0b4c42858e25a81ecc778a52e` so that the quantity question can assume the endpoint-identity boundary without merging PR #355 first.

PR #355 remains an independent prerequisite and is not merged by this observation.
