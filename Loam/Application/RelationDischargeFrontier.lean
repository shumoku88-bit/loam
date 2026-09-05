import Loam.Application.OpenRelationFrontier

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Relation discharge admission

Observation 178 qualified exact discharge quantity as independent provenance for
an aggregate `RelationUnit`. This module composes that raw Core evidence with the
already-admitted open-relation frontier without introducing persistence,
settlement ontology, or discharge identity.

Observation 182 then qualified Event authority as the activation edge for fresh
Movement discharge publication. A raw discharge whose later Event is absent from
the acquired EventMemory snapshot is therefore inert crash residue. Once that
Event exists, the row becomes active and all ordinary target-local fail-closed
checks apply.

The projection remains target-local. Global relation identity/revision structure
is still checked by `currentRelationState?`, while unrelated pre-Event relation
residue remains inert exactly as qualified by the existing source-local frontier.
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

/--
Select only discharge rows activated by an Event visible in the caller's acquired
EventMemory snapshot.

Observation 182 qualifies this as the narrow crash-residue boundary: a raw row
may have been published before its later Event and is then inert. This helper does
not filter malformed evidence whose Event is already present; such rows proceed
to ordinary fail-closed admission below.
-/
private def activatedTargetDischarges
    (events : EventMemory)
    (discharges : List RelationDischarge)
    (id : RelationUnitId) : List RelationDischarge :=
  (targetDischarges discharges id).filter fun discharge =>
    (EventMemory.findById? events discharge.event).isSome

private def uniqueDischargeEvents : List RelationDischarge → Bool
  | [] => true
  | discharge :: rest =>
      !(rest.any fun other => decide (other.event = discharge.event)) &&
        uniqueDischargeEvents rest

/--
Admit one activated raw discharge against an already-current relation target.

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
  let active := activatedTargetDischarges events discharges target.relation.id
  if !uniqueDischargeEvents active then
    none
  else
    let admitted ← admitAllForTarget? events target active
    if dischargeTotal admitted > target.relation.quantity.quanta then
      none
    else
      some admitted

/--
Return the admitted discharge rows for one currently admitted RelationUnit.

Rows targeting other RelationUnits are irrelevant to this target-local query.
Rows targeting this RelationUnit but naming a later Event absent from the acquired
EventMemory snapshot are also inert, as qualified by Observation 182's Event-last
publication model. They become active automatically when that Event appears in a
later EventMemory snapshot.

For every activated row, however, admission remains fail-closed. Zero/negative
quantity, source-Event self-discharge, duplicate `(EventId, RelationUnitId)`
correspondence, or aggregate over-discharge cannot be silently filtered into a
numeric answer.

Observation 178 found no need for a separate `DischargeId` merely to distinguish
several pieces inside the same later occurrence; those pieces normalize to one
exact quantity before reaching this frontier.
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
current relation quantity - admitted activated discharge total
```

The enclosing `Option` is fail-closed for ambiguity or malformed **activated**
evidence. Pre-Event discharge crash residue is inert instead of suppressing the
still-valid pre-discharge outstanding answer.
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
