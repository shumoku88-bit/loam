import Loam.Application.CapacityInspection
import Loam.CapacityEvidence
import Loam.Persistence.NormalizedCapacityPersistence

open Loam.Core
open Loam.Application

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private def yen : MeasureId := ⟨"jpy"⟩
private def food : PurposeId := ⟨"food"⟩
private def groceries : PurposeId := ⟨"groceries"⟩

private def change
    (coordinate : CapacityCoordinate)
    (quanta : Int) : MovementChange CapacityCoordinate :=
  { coordinate := coordinate, quantity := Quantity.ofQuanta quanta }

private def movement?
    (id : String)
    (changes : List (MovementChange CapacityCoordinate)) : Option CapacityMovement := do
  let balanced ← BalancedMovement.ofChanges? yen changes
  pure { id := ⟨id⟩, movement := balanced }

def main : IO Unit := do
  let allocation ← requireSome
    (movement? "capacity-1"
      [change .unallocated (-100), change (.purpose food) 100])
    "allocation specimen was not admitted"

  let reallocation ← requireSome
    (movement? "capacity-2"
      [change (.purpose food) (-40), change (.purpose groceries) 40])
    "reallocation specimen was not admitted"

  let memory0 ← requireSome
    (CapacityMemory.ofMovements? [allocation])
    "capacity memory rejected one movement"

  expect (canMoveCapacityFrom memory0.movements .unallocated yen 1000000)
    "unallocated was incorrectly treated as finite stock"
  expect (canMoveCapacityFrom memory0.movements (.purpose food) yen 100)
    "purpose could not provide its exact current entitlement"
  expect (!(canMoveCapacityFrom memory0.movements (.purpose food) yen 101))
    "purpose could provide more than its current entitlement"
  expect (!(canMoveCapacityFrom memory0.movements (.purpose food) yen 0))
    "zero current movement quantity was admitted"

  expect (CapacityMemory.add? memory0 allocation).isNone
    "capacity memory admitted duplicate stable movement identity"

  let memory ← requireSome
    (CapacityMemory.add? memory0 reallocation)
    "capacity memory rejected distinct movement identity"

  expect ((capacityAt memory.movements .unallocated yen).quanta == -100)
    "unallocated capacity projection changed unexpectedly"
  expect ((entitlementAt memory.movements food yen).quanta == 60)
    "food entitlement did not include reallocation"
  expect ((entitlementAt memory.movements groceries yen).quanta == 40)
    "groceries entitlement did not include reallocation"
  expect (canMoveCapacityFrom memory.movements (.purpose food) yen 60)
    "purpose could not provide its exact post-reallocation entitlement"
  expect (!(canMoveCapacityFrom memory.movements (.purpose food) yen 61))
    "purpose could overdraw its post-reallocation entitlement"

  let effective ← requireSome
    (CapacityEffectiveMemory.ofEntries?
      [{ movement := allocation.id, effectiveOn := "2026-08-17" },
       { movement := reallocation.id, effectiveOn := "2026-08-29" }])
    "capacity effective memory was rejected"
  let evidence ← requireSome
    (Loam.CapacityEvidence.ofParts? memory effective)
    "capacity evidence was rejected"

  let encoded ← requireSome
    (Loam.Persistence.encodeNormalizedCapacity? evidence)
    "normalized capacity evidence could not be encoded"
  let decoded ← requireSome
    (Loam.Persistence.decodeNormalizedCapacity? encoded)
    "encoded normalized capacity evidence could not be decoded"

  expect ((entitlementAt decoded.movements.movements food yen).quanta == 60)
    "normalized capacity persistence round-trip changed entitlement"
  expect (decoded.effective.findByMovementId? allocation.id == some "2026-08-17")
    "normalized capacity persistence round-trip changed effective date"

  let malformedUnbalanced :=
    "LOAM-NORMALIZED-CAPACITY\t1\n" ++
    "MOVEMENT\tcapacity-9\t2026-08-17\tjpy\n" ++
    "CHANGE\tUNALLOCATED\t-100\n" ++
    "CHANGE\tPURPOSE\tfood\t90\n" ++
    "ENDMOVEMENT\n"
  expect (Loam.Persistence.decodeNormalizedCapacity? malformedUnbalanced).isNone
    "normalized capacity persistence admitted an unbalanced movement"
