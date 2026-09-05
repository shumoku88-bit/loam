import Loam.Application.OpenRelationFrontier

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Relation discharge admission

Observation 178 qualified exact discharge quantity as independent provenance for
an aggregate `RelationUnit`. This module composes that raw Core evidence with the
already-admitted open-relation frontier without introducing persistence, writer
protocol, settlement ontology, or discharge identity.

The projection is target-local. Global relation identity/revision structure is
still checked by `currentRelationState?`, while unrelated pre-Event relation
residue remains inert exactly as qualified by the existing source-local frontier.
A discharge attached to the queried target fails closed when its later Event is
missing, its quantity is malformed, its `(event, target)` pair is repeated, or
the target's aggregate discharge would exceed the relation quantity.
-/

/-- One discharge after both its later Event and current target relation resolve. -/
structure AdmittedRelationDischarge where
  discharge : RelationDischarge
  event : Event
  target : AdmittedRelationUnit

private def findRawRelationById? :
    List RelationUnit → RelationUnitId → Option RelationUnit
  | [], _ => none
  | relation :: rest, id =>
      if relation.id = id then
        some relation
      else
        findRawRelationById? rest id

private def findAdmittedRelationById? :
    List AdmittedRelationUnit → RelationUnitId → Option AdmittedRelationUnit
  | [], _ => none
  | admitted :: rest, id =>
      if admitted.relation.id = id then
        some admitted
      else
        findAdmittedRelationById? rest id

private def uncovered (_ : EventId) (_ : EffectKey) : Bool := false

/--
Resolve one relation identity through the existing source-local current frontier.

The raw row is used only to discover its source coordinate. `currentRelationState?`
then rechecks the whole retained relation/revision structure plus the queried
source's current admission and aggregate relation-plane bound. A retracted or
replaced target therefore does not survive merely because its historical row is
still retained.
-/
def currentAdmittedRelationById?
    (events : EventMemory)
    (relations : List RelationUnit)
    (revisions : List RelationRevision)
    (id : RelationUnitId) : Option AdmittedRelationUnit := do
  let raw ← findRawRelationById? relations id
  let state ← currentRelationState?
    events relations revisions uncovered raw.sourceEvent raw.sourceEffect
  match state with
  | .knownPositive current => findAdmittedRelationById? current id
  | .unknown => none
  | .knownNone => none

private def dischargeTargets
    (id : RelationUnitId) (discharge : RelationDischarge) : Bool :=
  decide (discharge.target = id)

private def targetDischarges
    (discharges : List RelationDischarge)
    (id : RelationUnitId) : List RelationDischarge :=
  discharges.filter (dischargeTargets id)

private def uniqueDischargeEvents : List RelationDischarge → Bool
  | [] => true
  | discharge :: rest =>
      !(rest.any fun other => decide (other.event = discharge.event)) &&
        uniqueDischargeEvents rest

/--
Admit one raw discharge against an already-current relation target.

The later Event remains Event-scoped, as qualified by Observation 166. The
quantity is raw signed Core `Quantity`; this boundary gives it positive-discharge
meaning. One discharge cannot point back to the Event that established the target
relation, and one row cannot exceed the target quantity by itself.
-/
private def admitRelationDischargeForTarget?
    (events : EventMemory)
    (target : AdmittedRelationUnit)
    (discharge : RelationDischarge) : Option AdmittedRelationDischarge := do
  if discharge.target != target.relation.id then
    none
  else
    let later ← EventMemory.findById? events discharge.event
    if discharge.event = target.relation.sourceEvent then
      none
    else if discharge.quantity.quanta ≤ 0 then
      none
    else if discharge.quantity.quanta > target.relation.quantity.quanta then
      none
    else
      some { discharge := discharge, event := later, target := target }

private def admitAllForTarget?
    (events : EventMemory)
    (target : AdmittedRelationUnit) :
    List RelationDischarge → Option (List AdmittedRelationDischarge)
  | [] => some []
  | discharge :: rest => do
      let admitted ← admitRelationDischargeForTarget? events target discharge
      let later ← admitAllForTarget? events target rest
      some (admitted :: later)

private def dischargeTotal (admitted : List AdmittedRelationDischarge) : Int :=
  admitted.foldl
    (fun total item => total + item.discharge.quantity.quanta)
    0

private def admittedForCurrentTarget?
    (events : EventMemory)
    (target : AdmittedRelationUnit)
    (discharges : List RelationDischarge) : Option (List AdmittedRelationDischarge) := do
  let relevant := targetDischarges discharges target.relation.id
  if !uniqueDischargeEvents relevant then
    none
  else
    let admitted ← admitAllForTarget? events target relevant
    if dischargeTotal admitted > target.relation.quantity.quanta then
      none
    else
      some admitted

/--
Return the admitted discharge rows for one currently admitted RelationUnit.

Rows targeting other RelationUnits are irrelevant to this target-local query.
For the requested target, however, every retained row must admit; a missing later
Event or malformed quantity cannot be silently filtered out and mistaken for a
larger outstanding amount.

At most one row may exist for one `(EventId, RelationUnitId)` pair. Observation
178 found no need for a separate `DischargeId` merely to distinguish several
pieces inside the same later occurrence; those pieces normalize to one exact
quantity before reaching this frontier.
-/
def admittedRelationDischargesFor?
    (events : EventMemory)
    (relations : List RelationUnit)
    (revisions : List RelationRevision)
    (discharges : List RelationDischarge)
    (targetId : RelationUnitId) : Option (List AdmittedRelationDischarge) := do
  let target ← currentAdmittedRelationById? events relations revisions targetId
  admittedForCurrentTarget? events target discharges

/--
Derive the exact outstanding quantity for one current RelationUnit.

Outstanding is projection state only. It is never retained as a separate balance:

```text
current relation quantity - admitted discharge total
```

The enclosing `Option` is fail-closed. In particular over-discharge, duplicate
Event/target correspondence, malformed target discharge, unresolved target
relation, or a missing later Event cannot produce a numeric answer.
-/
def relationOutstandingQuantity?
    (events : EventMemory)
    (relations : List RelationUnit)
    (revisions : List RelationRevision)
    (discharges : List RelationDischarge)
    (targetId : RelationUnitId) : Option Quantity := do
  let target ← currentAdmittedRelationById? events relations revisions targetId
  let admitted ← admittedForCurrentTarget? events target discharges
  some <| Quantity.ofQuanta
    (target.relation.quantity.quanta - dischargeTotal admitted)

end Loam.Application
