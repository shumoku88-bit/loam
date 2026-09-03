import Loam.Application.CapacityInspection
import Loam.CapacityPersistence

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

  let encoded ← requireSome
    (Loam.Persistence.encodeCapacityMemory? memory)
    "capacity memory could not be encoded"
  let decoded ← requireSome
    (Loam.Persistence.decodeCapacityMemory? encoded)
    "encoded capacity memory could not be decoded"

  expect ((entitlementAt decoded.movements food yen).quanta == 60)
    "capacity persistence round-trip changed entitlement"

  let malformedUnbalanced :=
    "LOAM-CAPACITY-MEMORY\t1\n" ++
    "MOVEMENT\tcapacity-9\tjpy\n" ++
    "CHANGE\tUNALLOCATED\t-100\n" ++
    "CHANGE\tPURPOSE\tfood\t90\n"
  expect (Loam.Persistence.decodeCapacityMemory? malformedUnbalanced).isNone
    "capacity persistence admitted an unbalanced movement"
