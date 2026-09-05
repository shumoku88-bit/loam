import Loam.Application.RelationDischargeFrontier

namespace Loam.Experiments.RelationDischargeFrontierQualification

open Loam.Core
open Loam.Application

set_option autoImplicit false

private def sourceEventId : EventId := ⟨"trip"⟩
private def receiptAId : EventId := ⟨"receipt-a"⟩
private def receiptBId : EventId := ⟨"receipt-b"⟩
private def effectKey : EffectKey := ⟨"travel"⟩
private def measure : MeasureId := ⟨"jpy"⟩
private def locus : LocusId := ⟨"paypay"⟩
private def friend : RelationEndpoint := .external ⟨"friend"⟩

private def sourceEffect : Effect :=
  Effect.ofQuantity effectKey locus measure (Quantity.ofQuanta (-20))

private def sourceEvent : Event :=
  {
    id := sourceEventId
    effects := [sourceEffect]
    keyNodup := by simp
  }

private def emptyEvent (id : EventId) : Event :=
  {
    id := id
    effects := []
    keyNodup := by simp
  }

private def receiptA : Event := emptyEvent receiptAId
private def receiptB : Event := emptyEvent receiptBId

private def events : EventMemory :=
  {
    events := [sourceEvent, receiptA, receiptB]
    idNodup := by native_decide
  }

private def relation
    (id : String) (quantity : Int) : RelationUnit :=
  {
    id := ⟨id⟩
    sourceEvent := sourceEventId
    sourceEffect := effectKey
    debtor := friend
    creditor := .household
    quantity := Quantity.ofQuanta quantity
  }

private def relationA : RelationUnit := relation "relation-a" 10
private def relationB : RelationUnit := relation "relation-b" 5

private def orphanRelation : RelationUnit :=
  {
    id := ⟨"orphan"⟩
    sourceEvent := ⟨"future-trip"⟩
    sourceEffect := effectKey
    debtor := friend
    creditor := .household
    quantity := Quantity.ofQuanta 4
  }

private def retractA : RelationRevision :=
  {
    id := ⟨"revision-a"⟩
    target := relationA.id
    replacement := none
  }

private def discharge
    (event : EventId) (target : RelationUnitId) (quantity : Int) :
    RelationDischarge :=
  {
    event := event
    target := target
    quantity := Quantity.ofQuanta quantity
  }

private def partialA : RelationDischarge :=
  discharge receiptAId relationA.id 4

private def remainderA : RelationDischarge :=
  discharge receiptBId relationA.id 6

private def fullBFromSameReceipt : RelationDischarge :=
  discharge receiptAId relationB.id 5

private def missingEventA : RelationDischarge :=
  discharge ⟨"missing-receipt"⟩ relationA.id 4

private def sameAsSourceA : RelationDischarge :=
  discharge sourceEventId relationA.id 4

private def zeroA : RelationDischarge :=
  discharge receiptAId relationA.id 0

private def negativeA : RelationDischarge :=
  discharge receiptAId relationA.id (-1)

private def overA1 : RelationDischarge :=
  discharge receiptAId relationA.id 6

private def overA2 : RelationDischarge :=
  discharge receiptBId relationA.id 5

private def duplicateEventA : RelationDischarge :=
  discharge receiptAId relationA.id 3

private def unrelatedMalformedB : RelationDischarge :=
  discharge ⟨"missing-for-b"⟩ relationB.id (-9)

private def q (value : Int) : Option Quantity :=
  some (Quantity.ofQuanta value)

/-- One current target can be resolved by stable RelationUnitId. -/
example :
    (currentAdmittedRelationById?
      events [relationA, relationB] [] relationA.id).isSome = true := by
  native_decide

/-- Unrelated pre-Event relation residue does not poison target identity lookup. -/
example :
    (currentAdmittedRelationById?
      events [relationA, relationB, orphanRelation] [] relationA.id).isSome = true := by
  native_decide

/-- A retained but retracted relation is not a current discharge target. -/
example :
    currentAdmittedRelationById?
      events [relationA] [retractA] relationA.id = none := by
  native_decide

/-- Exact partial fulfillment leaves exact outstanding quantity. -/
example :
    relationOutstandingQuantity?
      events [relationA, relationB] [] [partialA] relationA.id = q 6 := by
  native_decide

/-- Two later Events may exactly complete one relation. -/
example :
    relationOutstandingQuantity?
      events [relationA, relationB] [] [partialA, remainderA] relationA.id = q 0 := by
  native_decide

/-- One later Event may discharge two different RelationUnits. -/
example :
    relationOutstandingQuantity?
      events [relationA, relationB] []
        [partialA, fullBFromSameReceipt] relationA.id = q 6 := by
  native_decide

example :
    relationOutstandingQuantity?
      events [relationA, relationB] []
        [partialA, fullBFromSameReceipt] relationB.id = q 0 := by
  native_decide

/-- Malformed evidence for another target remains irrelevant to this target-local query. -/
example :
    relationOutstandingQuantity?
      events [relationA, relationB] []
        [partialA, unrelatedMalformedB] relationA.id = q 6 := by
  native_decide

/-- Missing later Event on the queried target fails closed. -/
example :
    relationOutstandingQuantity?
      events [relationA, relationB] [] [missingEventA] relationA.id = none := by
  native_decide

/-- The source Event itself is not admitted as its relation's later discharge occurrence. -/
example :
    relationOutstandingQuantity?
      events [relationA, relationB] [] [sameAsSourceA] relationA.id = none := by
  native_decide

/-- Zero and negative raw quantities cannot acquire discharge meaning. -/
example :
    relationOutstandingQuantity?
      events [relationA, relationB] [] [zeroA] relationA.id = none := by
  native_decide

example :
    relationOutstandingQuantity?
      events [relationA, relationB] [] [negativeA] relationA.id = none := by
  native_decide

/-- Repeated `(EventId, RelationUnitId)` evidence is unresolved without DischargeId. -/
example :
    relationOutstandingQuantity?
      events [relationA, relationB] []
        [partialA, duplicateEventA] relationA.id = none := by
  native_decide

/-- Aggregate discharge above the current RelationUnit quantity fails closed. -/
example :
    relationOutstandingQuantity?
      events [relationA, relationB] [] [overA1, overA2] relationA.id = none := by
  native_decide

/-- The admitted rows preserve both distinct later Events for exact completion. -/
example :
    (admittedRelationDischargesFor?
      events [relationA, relationB] [] [partialA, remainderA] relationA.id).map
      List.length = some 2 := by
  native_decide

end Loam.Experiments.RelationDischargeFrontierQualification
