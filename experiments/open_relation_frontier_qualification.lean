import Loam.Application.OpenRelationFrontier

namespace Loam.Experiments.OpenRelationFrontierQualification

open Loam.Core
open Loam.Application

set_option autoImplicit false

private def eventId : EventId := ⟨"trip"⟩
private def effectKey : EffectKey := ⟨"travel"⟩
private def measure : MeasureId := ⟨"jpy"⟩
private def locus : LocusId := ⟨"paypay"⟩
private def friend : RelationEndpoint := .external ⟨"friend"⟩

private def sourceEffect : Effect :=
  Effect.ofQuantity effectKey locus measure (Quantity.ofQuanta (-1000))

private def sourceEvent : Event :=
  {
    id := eventId
    effects := [sourceEffect]
    keyNodup := by simp
  }

private def events : EventMemory :=
  {
    events := [sourceEvent]
    idNodup := by simp
  }

private def relation
    (id : String) (quantity : Int) : RelationUnit :=
  {
    id := ⟨id⟩
    sourceEvent := eventId
    sourceEffect := effectKey
    debtor := friend
    creditor := .household
    quantity := Quantity.ofQuanta quantity
  }

private def orphanRelation (id : String) : RelationUnit :=
  {
    id := ⟨id⟩
    sourceEvent := ⟨"future-trip"⟩
    sourceEffect := effectKey
    debtor := friend
    creditor := .household
    quantity := Quantity.ofQuanta 400
  }

private def validA : RelationUnit := relation "a" 500
private def validB : RelationUnit := relation "b" 200
private def overA : RelationUnit := relation "over-a" 700
private def overB : RelationUnit := relation "over-b" 400
private def invalidZero : RelationUnit := relation "bad-zero" 0
private def orphan : RelationUnit := orphanRelation "orphan"
private def duplicateIdOrphan : RelationUnit := orphanRelation "a"

private def retract (id target : String) : RelationRevision :=
  {
    id := ⟨id⟩
    target := ⟨target⟩
    replacement := none
  }

private def replace (id target replacement : String) : RelationRevision :=
  {
    id := ⟨id⟩
    target := ⟨target⟩
    replacement := some ⟨replacement⟩
  }

private def covered (_ : EventId) (_ : EffectKey) : Bool := true
private def uncovered (_ : EventId) (_ : EffectKey) : Bool := false

private def isKnownNone : Option RelationSourceState → Bool
  | some .knownNone => true
  | _ => false

private def isUnknown : Option RelationSourceState → Bool
  | some .unknown => true
  | _ => false

private def isUnresolved : Option RelationSourceState → Bool
  | none => true
  | _ => false

private def positiveCount? : Option RelationSourceState → Option Nat
  | some (.knownPositive relations) => some relations.length
  | _ => none

/-- A valid positive relation is admitted independently of the negative source sign. -/
example :
    positiveCount?
      (currentRelationState? events [validA] [] uncovered eventId effectKey) =
      some 1 := by
  native_decide

/-- Qualified completeness turns clean covered absence into known-none. -/
example :
    isKnownNone
      (currentRelationState? events [] [] covered eventId effectKey) = true := by
  native_decide

/-- The same clean absence outside completeness remains unknown. -/
example :
    isUnknown
      (currentRelationState? events [] [] uncovered eventId effectKey) = true := by
  native_decide

/-- Malformed current evidence blocks covered known-none rather than disappearing. -/
example :
    isUnresolved
      (currentRelationState?
        events [invalidZero] [] covered eventId effectKey) = true := by
  native_decide

/-- Two individually valid units still fail closed when their plane total exceeds the source. -/
example :
    isUnresolved
      (currentRelationState?
        events [overA, overB] [] covered eventId effectKey) = true := by
  native_decide

/-- Retracting the last positive relation yields known-none only under completeness. -/
example :
    isKnownNone
      (currentRelationState?
        events [validA] [retract "r-a" "a"] covered eventId effectKey) = true := by
  native_decide

/-- The same explicit retraction outside completeness returns to unknown. -/
example :
    isUnknown
      (currentRelationState?
        events [validA] [retract "r-a" "a"] uncovered eventId effectKey) = true := by
  native_decide

/-- Retraction is local to one relation-unit identity; another current unit survives. -/
example :
    positiveCount?
      (currentRelationState?
        events [validA, validB] [retract "r-a" "a"] covered eventId effectKey) =
      some 1 := by
  native_decide

/-- A positive replacement is current when it preserves the same source Effect. -/
example :
    positiveCount?
      (currentRelationState?
        events [validA, validB] [replace "r-a-b" "a" "b"] covered eventId effectKey) =
      some 1 := by
  native_decide

/-- Sibling revision authority for one target fails closed instead of using list order. -/
example :
    isUnresolved
      (currentRelationState?
        events [validA, validB]
          [retract "r-a-none" "a", replace "r-a-b" "a" "b"]
          covered eventId effectKey) = true := by
  native_decide

/-- Pre-Event raw residue for another source cannot poison a valid positive query. -/
example :
    positiveCount?
      (currentRelationState?
        events [validA, orphan] [] uncovered eventId effectKey) = some 1 := by
  native_decide

/-- Pre-Event raw residue for another source cannot manufacture unresolved covered absence. -/
example :
    isKnownNone
      (currentRelationState?
        events [orphan] [] covered eventId effectKey) = true := by
  native_decide

/-- Relation identity remains global: an orphan cannot reuse a live RelationUnitId. -/
example :
    isUnresolved
      (currentRelationState?
        events [validA, duplicateIdOrphan] [] uncovered eventId effectKey) = true := by
  native_decide

end Loam.Experiments.OpenRelationFrontierQualification
