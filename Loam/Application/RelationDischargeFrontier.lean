import Loam.Application.OpenRelationFrontier
import Loam.Core.HashNodup
import Std.Data.HashMap
import Std.Data.HashMap.Lemmas

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

The projection remains target-local. Global RelationUnit identity is still
checked by `currentRelationState?`, while unrelated pre-Event relation residue
remains inert exactly as qualified by the existing source-local frontier.
-/

/--
One discharge produced by this module after both its later Event and current
target relation resolve.

Like `AdmittedRelationUnit`, this is an admission-produced read view rather
than a standalone proof-carrying capability. Production construction remains
inside the target-local admission path below.
-/
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
then rechecks the whole retained relation structure plus the queried source's
current admission and aggregate relation-plane bound.
-/
def currentAdmittedRelationById?
    (events : EventMemory)
    (relations : List RelationUnit)
    (id : RelationUnitId) : Option AdmittedRelationUnit := do
  let raw ← findRawRelationById? relations id
  let state ← currentRelationState?
    events relations uncovered raw.sourceEvent raw.sourceEffect
  match state with
  | .knownPositive current => findAdmittedRelationById? current id
  | .unknown => none
  | .knownNone => none

private theorem eventIdToken_injective :
    Function.Injective (fun id : EventId => id.token) := by
  intro left right h
  cases left
  cases right
  cases h
  rfl

private def uniqueDischargeEvents
    (discharges : List RelationDischarge) : Bool :=
  (hashNodupBy?
    (fun id : EventId => id.token)
    eventIdToken_injective
    (discharges.map RelationDischarge.event)).isSome

/--
Transient lookup index for remembered Events.

The structurally recursive shape makes the correspondence to the canonical
list lookup explicit: the head Event overrides the recursively indexed tail,
matching `EventMemory.findById?` exactly even before using EventId uniqueness.
-/
private def buildEventIndexFrom :
    List Event → Std.HashMap String Event
  | [] => {}
  | event :: rest =>
      (buildEventIndexFrom rest).insert event.id.token event

private def buildEventIndex
    (events : EventMemory) : Std.HashMap String Event :=
  buildEventIndexFrom events.events

/--
The transient Event index is extensionally identical to canonical EventMemory
identity lookup.
-/
theorem buildEventIndex_get?_eq_findById?
    (events : EventMemory)
    (id : EventId) :
    (buildEventIndex events)[id.token]? =
      EventMemory.findById? events id := by
  cases events with
  | mk eventList hNodup =>
      simp only [buildEventIndex, EventMemory.findById?]
      induction eventList with
      | nil =>
          simp [buildEventIndexFrom, FiniteKeyed.findBy?]
      | cons event rest ih =>
          simp only [buildEventIndexFrom, FiniteKeyed.findBy?]
          rw [Std.HashMap.get?_insert]
          by_cases hId : event.id = id
          · subst hId
            simp
          · have hToken : event.id.token ≠ id.token := by
              intro h
              exact hId (eventIdToken_injective h)
            simp [hToken, hId, ih]

/--
Build a target-keyed bucket index from the raw discharge list.

Recursing through the tail and then prepending the head into its target bucket
preserves the exact raw List order for every target in expected O(D) time.
-/
private def buildDischargeBuckets :
    List RelationDischarge → Std.HashMap String (List RelationDischarge)
  | [] => {}
  | discharge :: rest =>
      let index := buildDischargeBuckets rest
      let prior := index[discharge.target.token]?.getD []
      index.insert discharge.target.token (discharge :: prior)

/--
Each transient target bucket is exactly the raw discharge list filtered to that
RelationUnitId, including representation order.
-/
theorem buildDischargeBuckets_getD_eq_filter
    (discharges : List RelationDischarge)
    (target : RelationUnitId) :
    (buildDischargeBuckets discharges)[target.token]?.getD [] =
      discharges.filter (fun discharge => discharge.target = target) := by
  induction discharges with
  | nil =>
      simp [buildDischargeBuckets]
  | cons discharge rest ih =>
      simp only [buildDischargeBuckets]
      rw [Std.HashMap.get?_insert]
      by_cases hTarget : discharge.target = target
      · subst hTarget
        simp [ih]
      · have hToken : discharge.target.token ≠ target.token := by
          intro h
          exact hTarget (relationUnitIdToken_injective h)
        simp [hToken, hTarget, ih]

/--
Transient acceleration context constructed once per whole-frontier admission pass.
-/
private structure DischargeFrontierIndex where
  events : Std.HashMap String Event
  byTarget : Std.HashMap String (List RelationDischarge)

private def buildDischargeFrontierIndex
    (events : EventMemory)
    (discharges : List RelationDischarge) : DischargeFrontierIndex :=
  {
    events := buildEventIndex events
    byTarget := buildDischargeBuckets discharges
  }

/--
Admit one activated raw discharge against an already-current relation target.

The discharge occurrence remains Event-scoped, as qualified by Observation 166.
No calendar-order law is asserted here; current occurrence dates remain an
independent Actual coordinate. The quantity is raw signed Core `Quantity`; this
boundary gives it positive-discharge meaning. One discharge cannot point back to the Event that established the target
relation, and one row cannot exceed the target quantity by itself.
-/
private def admitRelationDischargeForTarget?
    (eventIndex : Std.HashMap String Event)
    (target : AdmittedRelationUnit)
    (discharge : RelationDischarge) : Option AdmittedRelationDischarge := do
  if discharge.target != target.relation.id then
    none
  else
    let later ← eventIndex[discharge.event.token]?
    if discharge.event = target.relation.sourceEvent then
      none
    else if discharge.quantity.quanta ≤ 0 then
      none
    else if discharge.quantity.quanta > target.relation.quantity.quanta then
      none
    else
      some { discharge := discharge, event := later, target := target }

private def admitAllForTarget?
    (eventIndex : Std.HashMap String Event)
    (target : AdmittedRelationUnit) :
    List RelationDischarge → Option (List AdmittedRelationDischarge)
  | [] => some []
  | discharge :: rest => do
      let admitted ← admitRelationDischargeForTarget? eventIndex target discharge
      let later ← admitAllForTarget? eventIndex target rest
      some (admitted :: later)

private def dischargeTotal (admitted : List AdmittedRelationDischarge) : Int :=
  admitted.foldl
    (fun total item => total + item.discharge.quantity.quanta)
    0

/--
Validate and admit all active discharges for one current target using the
transient acceleration context.
-/
private def admittedForCurrentTargetIndexed?
    (index : DischargeFrontierIndex)
    (target : AdmittedRelationUnit) : Option (List AdmittedRelationDischarge) := do
  let targetDischarges := index.byTarget[target.relation.id.token]?.getD []
  let active := targetDischarges.filter fun discharge =>
    index.events[discharge.event.token]?.isSome
  if !uniqueDischargeEvents active then
    none
  else
    let admitted ← admitAllForTarget? index.events target active
    if dischargeTotal admitted > target.relation.quantity.quanta then
      none
    else
      some admitted

private def admittedForCurrentTarget?
    (events : EventMemory)
    (target : AdmittedRelationUnit)
    (discharges : List RelationDischarge) : Option (List AdmittedRelationDischarge) :=
  let index := buildDischargeFrontierIndex events discharges
  admittedForCurrentTargetIndexed? index target

/--
Validate all target-local discharge frontiers against one already-admitted whole
RelationUnit frontier.

The equality proof ties the supplied admitted values to this exact EventMemory
and raw RelationUnit collection. It is proof-only authority: callers cannot use
an arbitrary manually constructed `AdmittedRelationUnit` list to bypass relation
admission. At runtime, the already-admitted targets are traversed directly, so
this path does not re-enter `currentRelationState?` or repeat whole-family
RelationUnit admission for every target.

This boundary intentionally does not own persistence reference closure for raw
discharge rows. A persistence caller that requires every raw discharge Event and
target to exist must establish that generation-level property separately.
-/
def admitRelationDischargesForFrontier?
    (events : EventMemory)
    (relations : List RelationUnit)
    (frontier : List AdmittedRelationUnit)
    (_hFrontier : admittedRelationFrontier? events relations = some frontier)
    (discharges : List RelationDischarge) : Option Unit := do
  let index := buildDischargeFrontierIndex events discharges
  for target in frontier do
    let _ ← admittedForCurrentTargetIndexed? index target
  some ()

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
    (discharges : List RelationDischarge)
    (targetId : RelationUnitId) : Option (List AdmittedRelationDischarge) := do
  let target ← currentAdmittedRelationById? events relations targetId
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
    (discharges : List RelationDischarge)
    (targetId : RelationUnitId) : Option Quantity := do
  let target ← currentAdmittedRelationById? events relations targetId
  let admitted ← admittedForCurrentTarget? events target discharges
  some <| Quantity.ofQuanta
    (target.relation.quantity.quanta - dischargeTotal admitted)

end Loam.Application
