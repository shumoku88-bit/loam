import Loam.Core.EventMemory
import Loam.Core.HashNodup
import Loam.Core.OpenRelation
import Std.Data.HashMap
import Std.Data.HashMap.Lemmas

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Open relation admission and frontier

This module is the executable projection over the currently selected raw
open-relation vocabulary.

Raw `RelationUnit` values remain append-only provenance. This boundary decides
only whether their current semantic frontier is safe to publish. The
retraction / replacement revision capability explored by Observations 175–176
is intentionally outside production until a concrete authority and persistence
path select it.

A failed projection is represented by outer `none`: malformed or conflicting
current evidence is unresolved and must not be mistaken for absence.
-/

/--
One relation unit produced by this module after its source Effect has resolved
and its current semantic shape has passed admission.

This is an admission-produced read view, not a proof-carrying capability type:
the public structure constructor does not itself prove EventMemory membership or
the admission predicates. Production constructors in this repository obtain the
value through `admitRelationUnit?` / frontier projection.

The source Effect is retained in the read-only result so callers can obtain the
existing `MeasureId` without duplicating measure identity in `RelationUnit`.
-/
structure AdmittedRelationUnit where
  relation : RelationUnit
  source : Effect

namespace AdmittedRelationUnit

/-- Measure identity is inherited from the resolved source Effect. -/
def measure (admitted : AdmittedRelationUnit) : MeasureId :=
  admitted.source.measure

end AdmittedRelationUnit

/--
Current source-level answer after a successful frontier projection.

`knownPositive` may contain several independent relation units on one Effect.
`knownNone` is available only when the caller supplies qualified completeness
for the queried source. Uncovered clean absence remains `unknown`.

Unresolved evidence is intentionally not a constructor here: the enclosing
`Option` returns `none` instead, so callers cannot accidentally consume an
ambiguous state as a semantic answer.
-/
inductive RelationSourceState where
  | unknown
  | knownNone
  | knownPositive (relations : List AdmittedRelationUnit)

/-- Resolve the exact source Effect named by one raw relation unit. -/
def relationSourceEffect?
    (events : EventMemory) (relation : RelationUnit) : Option Effect := do
  let event ← EventMemory.findById? events relation.sourceEvent
  event.effects.find? fun effect => effect.key = some relation.sourceEffect

/-- Event-memory representation order cannot change source-Effect resolution. -/
theorem relationSourceEffect?_eventMemory_perm
    (left right : EventMemory)
    (hPerm : left.events.Perm right.events)
    (relation : RelationUnit) :
    relationSourceEffect? left relation = relationSourceEffect? right relation := by
  unfold relationSourceEffect?
  rw [EventMemory.findById?_perm left right hPerm relation.sourceEvent]

/--
The currently earned endpoint admission is exactly Household-to-external or
external-to-Household. Endpoint identity itself carries no debtor/creditor role.
-/
def relationEndpointsAdmissible (relation : RelationUnit) : Bool :=
  match relation.debtor, relation.creditor with
  | .household, .external _ => true
  | .external _, .household => true
  | _, _ => false

private def magnitudeQuanta (quantity : Quantity) : Int :=
  if quantity.quanta < 0 then
    -quantity.quanta
  else
    quantity.quanta

/--
Admit one raw relation unit only when its current semantic shape is safe.

Admission requires:

- the exact `(EventId, EffectKey)` source to resolve;
- one Household endpoint and one external endpoint;
- a strictly positive relation quantity;
- relation magnitude no greater than the absolute source-Effect magnitude.

The collection-level frontier separately enforces the Observation 173 law that
the total current relation-plane coverage on one source Effect cannot exceed the
source magnitude.

Source sign itself has no relation-direction meaning.
-/
def admitRelationUnit?
    (events : EventMemory) (relation : RelationUnit) : Option AdmittedRelationUnit := do
  let source ← relationSourceEffect? events relation
  if !relationEndpointsAdmissible relation then
    none
  else if relation.quantity.quanta ≤ 0 then
    none
  else if relation.quantity.quanta > magnitudeQuanta source.quantity then
    none
  else
    some { relation := relation, source := source }

/-- A missing source reference can never enter the admitted positive view. -/
@[simp] theorem admitRelationUnit?_missing_source
    (events : EventMemory)
    (relation : RelationUnit)
    (hMissing : relationSourceEffect? events relation = none) :
    admitRelationUnit? events relation = none := by
  simp [admitRelationUnit?, hMissing]

/-- Single-unit admission is independent of EventMemory representation order. -/
theorem admitRelationUnit?_eventMemory_perm
    (left right : EventMemory)
    (hPerm : left.events.Perm right.events)
    (relation : RelationUnit) :
    admitRelationUnit? left relation = admitRelationUnit? right relation := by
  unfold admitRelationUnit?
  rw [relationSourceEffect?_eventMemory_perm left right hPerm relation]

private theorem relationUnitIdToken_injective :
    Function.Injective (fun id : RelationUnitId => id.token) := by
  intro left right h
  cases left
  cases right
  cases h
  rfl

private def uniqueUnitIds (relations : List RelationUnit) : Bool :=
  (hashNodupBy?
    (fun id : RelationUnitId => id.token)
    relationUnitIdToken_injective
    (relations.map RelationUnit.id)).isSome

private def admitAll?
    (events : EventMemory) : List RelationUnit → Option (List AdmittedRelationUnit)
  | [] => some []
  | relation :: rest => do
      let admitted ← admitRelationUnit? events relation
      let later ← admitAll? events rest
      some (admitted :: later)

private def currentUnitsAdmissible
    (events : EventMemory)
    (relations : List RelationUnit) : Bool :=
  relations.all fun relation =>
    (admitRelationUnit? events relation).isSome

/--
Whole-list admission succeeds exactly when every retained RelationUnit succeeds
under the existing single-unit admission boundary.

This connects the public Bool predicate to the value-producing admission pass so
frontier construction can reuse that pass instead of checking every unit twice.
-/
private theorem admitAll?_isSome_eq_currentUnitsAdmissible
    (events : EventMemory) :
    ∀ relations : List RelationUnit,
      (admitAll? events relations).isSome =
        currentUnitsAdmissible events relations
  | [] => by rfl
  | relation :: rest => by
      cases hAdmission : admitRelationUnit? events relation with
      | none =>
          simp [admitAll?, currentUnitsAdmissible, hAdmission]
      | some admitted =>
          simp [admitAll?, currentUnitsAdmissible, hAdmission, Option.isSome_bind,
            admitAll?_isSome_eq_currentUnitsAdmissible events rest]

private def sameRawSource
    (sourceEvent : EventId)
    (sourceEffect : EffectKey)
    (relation : RelationUnit) : Bool :=
  decide
    (relation.sourceEvent = sourceEvent ∧
      relation.sourceEffect = sourceEffect)

private def sourceRelationUnits
    (relations : List RelationUnit)
    (sourceEvent : EventId)
    (sourceEffect : EffectKey) : List RelationUnit :=
  relations.filter (sameRawSource sourceEvent sourceEffect)

private def currentCoverageFor
    (current : List RelationUnit)
    (sourceRelation : RelationUnit) : Int :=
  current.foldr
    (fun relation total =>
      if relation.sourceEvent = sourceRelation.sourceEvent ∧
          relation.sourceEffect = sourceRelation.sourceEffect then
        relation.quantity.quanta + total
      else
        total)
    0

private def sourceRelationCoverageBounded
    (events : EventMemory)
    (relations : List RelationUnit)
    (sourceEvent : EventId)
    (sourceEffect : EffectKey) : Bool :=
  let current := sourceRelationUnits relations sourceEvent sourceEffect
  current.all fun relation =>
    match relationSourceEffect? events relation with
    | none => false
    | some source =>
        currentCoverageFor current relation <= magnitudeQuanta source.quantity

/--
Typed key for resolving source Effects and aggregating relation-plane coverage
without ad-hoc string concatenation.
-/
private structure SourceKey where
  event : EventId
  effect : EffectKey
deriving DecidableEq

private instance : BEq SourceKey where
  beq a b := a == b

private instance : Hashable SourceKey where
  hash k := mixHash (hash k.event.token) (hash k.effect.token)

/--
Build a one-pass index mapping `(EventId, EffectKey)` to the retained Effect.

Core invariants guarantee uniqueness:
- `EventMemory` proves EventId uniqueness (`idNodup`);
- `Event` proves retained EffectKey uniqueness within that Event (`keyNodup`).
Every keyed Effect in `EventMemory` therefore resolves to at most one target.
-/
private def buildSourceEffectIndex
    (events : EventMemory) : Std.HashMap SourceKey Effect :=
  events.events.foldl
    (fun index event =>
      event.effects.foldl
        (fun index' effect =>
          match effect.key with
          | some key => index'.insert { event := event.id, effect := key } effect
          | none => index')
        index)
    {}

/--
Build a one-pass transient aggregate mapping `(EventId, EffectKey)` to total
relation quantity across all relation units targeting that source.
-/
private def coverageAt
    (index : Std.HashMap SourceKey Int)
    (key : SourceKey) : Int :=
  (index.get? key).getD 0

private def buildCoverageIndex :
    List RelationUnit → Std.HashMap SourceKey Int
  | [] => {}
  | relation :: rest =>
      let index := buildCoverageIndex rest
      let key : SourceKey := { event := relation.sourceEvent, effect := relation.sourceEffect }
      let prior := coverageAt index key
      index.insert key (relation.quantity.quanta + prior)

/--
The transient source-coverage index is exactly the direct list aggregation used
by the semantic frontier, for every raw RelationUnit list and queried source.
-/
private theorem buildCoverageIndex_getD_eq_currentCoverageFor
    (relations : List RelationUnit)
    (sourceRelation : RelationUnit) :
    coverageAt (buildCoverageIndex relations) {
      event := sourceRelation.sourceEvent,
      effect := sourceRelation.sourceEffect
    } =
      currentCoverageFor relations sourceRelation := by
  induction relations with
  | nil =>
      simp [buildCoverageIndex, currentCoverageFor, coverageAt]
  | cons relation rest ih =>
      simp only [buildCoverageIndex, currentCoverageFor, List.foldr_cons, coverageAt]
      rw [Std.HashMap.get?_insert]
      by_cases hSame :
          relation.sourceEvent = sourceRelation.sourceEvent ∧
            relation.sourceEffect = sourceRelation.sourceEffect
      · have hKey :
            ({ event := relation.sourceEvent, effect := relation.sourceEffect } : SourceKey) =
              { event := sourceRelation.sourceEvent, effect := sourceRelation.sourceEffect } := by
          simp [hSame.1, hSame.2]
        simp [hKey, hSame]
        exact ih
      · have hKey :
            ({ event := relation.sourceEvent, effect := relation.sourceEffect } : SourceKey) ≠
              { event := sourceRelation.sourceEvent, effect := sourceRelation.sourceEffect } := by
          intro h
          apply hSame
          exact ⟨congrArg SourceKey.event h, congrArg SourceKey.effect h⟩
        simp [hKey, hSame]
        exact ih

/--
Transient acceleration context constructed once per whole-frontier admission pass.
-/
private structure RelationFrontierIndex where
  sourceEffects : Std.HashMap SourceKey Effect
  coverage : Std.HashMap SourceKey Int

private def buildRelationFrontierIndex
    (events : EventMemory) (relations : List RelationUnit) : RelationFrontierIndex :=
  {
    sourceEffects := buildSourceEffectIndex events
    coverage := buildCoverageIndex relations
  }

/--
Admit one relation unit using the transient acceleration context.

Validates in O(1):
1. Exact source Effect resolution;
2. Endpoint validity (Household <-> external);
3. Strictly positive quantity;
4. Single-unit magnitude bound (`quantity <= source.quantity`);
5. Aggregate source coverage bound (total coverage across relations sharing this
   source does not exceed source magnitude, enforcing Observation 173).
-/
private def admitRelationUnitIndexed?
    (index : RelationFrontierIndex)
    (relation : RelationUnit) : Option AdmittedRelationUnit := do
  let key : SourceKey := { event := relation.sourceEvent, effect := relation.sourceEffect }
  let source ← index.sourceEffects[key]?
  if !relationEndpointsAdmissible relation then
    none
  else if relation.quantity.quanta ≤ 0 then
    none
  else if relation.quantity.quanta > magnitudeQuanta source.quantity then
    none
  else
    let cov := index.coverage[key]?.getD 0
    if cov > magnitudeQuanta source.quantity then
      none
    else
      some { relation := relation, source := source }

/--
Global relation structure that must remain coherent even when some raw relation
units are not yet source-admissible.

At the currently selected production capability, stable RelationUnit identity is
the only whole-family structural law. Retraction / replacement graph laws remain
research until a concrete writer and authority select that capability.
-/
private def relationFrontierStructurallyAdmissible
    (relations : List RelationUnit) : Bool :=
  uniqueUnitIds relations

/--
Return the admitted current positive frontier, or `none` when the whole raw
frontier cannot currently be resolved safely.

Representation list order is strictly preserved from the input `relations` List.
Transient hash maps are used exclusively for lookups and aggregations; the output
order is determined by standard list traversal over `relations`.
-/
def admittedRelationFrontier?
    (events : EventMemory)
    (relations : List RelationUnit) : Option (List AdmittedRelationUnit) :=
  if !relationFrontierStructurallyAdmissible relations then
    none
  else
    let index := buildRelationFrontierIndex events relations
    relations.mapM (admitRelationUnitIndexed? index)

/--
Whether one raw relation collection has one safe append-only frontier.

The whole-frontier boundary rejects repeated relation identity, malformed current
relation units, and aggregate current relation coverage beyond a source Effect's
exact magnitude.
-/
def relationFrontierAdmissible
    (events : EventMemory)
    (relations : List RelationUnit) : Bool :=
  (admittedRelationFrontier? events relations).isSome

/--
Admit only the current units attached to one queried source while retaining the
global RelationUnit identity invariant of the raw relation family.

This is the executable counterpart of Observation 176's source-local status
projection and Observation 177's permitted pre-Event crash residue. An orphan
raw relation for another source remains inert instead of poisoning an unrelated
Effect query. Global identity collisions still fail closed because they make
retained provenance itself ambiguous.
-/
private def admittedRelationSourceFrontier?
    (events : EventMemory)
    (relations : List RelationUnit)
    (sourceEvent : EventId)
    (sourceEffect : EffectKey) : Option (List AdmittedRelationUnit) :=
  if relationFrontierStructurallyAdmissible relations &&
      sourceRelationCoverageBounded
        events relations sourceEvent sourceEffect then
    admitAll? events
      (sourceRelationUnits relations sourceEvent sourceEffect)
  else
    none

/--
Project one source Effect to `knownPositive`, `knownNone`, or `unknown`.

`completeAt` is supplied by the caller because no concrete relation completeness
writer/cutover has yet been promoted. This function never invents completeness
from storage order.

Only relation units attached to the queried `(EventId, EffectKey)` are subjected
to source admission and relation-plane coverage. Thus unrelated pre-Event raw
residue stays inert. Global RelationUnit identity remains a whole-family check,
so ambiguity is not hidden merely because it sits on another source coordinate.

A malformed current raw relation on the queried source still returns outer
`none` even when `completeAt` says the source is covered; it cannot be filtered
away and mispublished as `knownNone`.
-/
def currentRelationState?
    (events : EventMemory)
    (relations : List RelationUnit)
    (completeAt : EventId → EffectKey → Bool)
    (sourceEvent : EventId)
    (sourceEffect : EffectKey) : Option RelationSourceState := do
  let event ← EventMemory.findById? events sourceEvent
  let _source ← event.effects.find? fun effect => effect.key = some sourceEffect
  let current ← admittedRelationSourceFrontier?
    events relations sourceEvent sourceEffect
  if current.isEmpty then
    if completeAt sourceEvent sourceEffect then
      some .knownNone
    else
      some .unknown
  else
    some (.knownPositive current)

/-- A missing queried Event cannot be turned into known absence by completeness. -/
@[simp] theorem currentRelationState?_missing_event
    (events : EventMemory)
    (relations : List RelationUnit)
    (completeAt : EventId → EffectKey → Bool)
    (sourceEvent : EventId)
    (sourceEffect : EffectKey)
    (hMissing : EventMemory.findById? events sourceEvent = none) :
    currentRelationState?
      events relations completeAt sourceEvent sourceEffect = none := by
  simp [currentRelationState?, hMissing]

end Loam.Application
