import Loam.Application.CapacityInspection

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
private def usd : MeasureId := ⟨"usd"⟩

private def coffee : PurposeId := ⟨"coffee"⟩
private def groceries : PurposeId := ⟨"groceries"⟩

private def capacityChange
    (coordinate : CapacityCoordinate) (quanta : Int) :
    MovementChange CapacityCoordinate :=
  { coordinate := coordinate, quantity := Quantity.ofQuanta quanta }

private def capacityMovement?
    (id : String)
    (changes : List (MovementChange CapacityCoordinate)) : Option CapacityMovement := do
  let movement ← BalancedMovement.ofChanges? yen changes
  pure { id := ⟨id⟩, movement := movement }

private def grant? : Option CapacityMovement :=
  capacityMovement? "capacity-1"
    [capacityChange .unallocated (-100),
     capacityChange (.purpose coffee) 100]

private def reallocation? : Option CapacityMovement :=
  capacityMovement? "capacity-2"
    [capacityChange (.purpose coffee) (-40),
     capacityChange (.purpose groceries) 40]

private def release? : Option CapacityMovement :=
  capacityMovement? "capacity-3"
    [capacityChange (.purpose groceries) (-10),
     capacityChange .unallocated 10]

private def physicalMovement? : Option (BalancedMovement LocusId) :=
  BalancedMovement.ofChanges? yen
    [{ coordinate := ⟨"bank"⟩, quantity := Quantity.ofQuanta (-75) },
     { coordinate := ⟨"wallet"⟩, quantity := Quantity.ofQuanta 75 }]

private def unbalancedCapacity? : Option (BalancedMovement CapacityCoordinate) :=
  BalancedMovement.ofChanges? yen
    [capacityChange .unallocated (-10),
     capacityChange (.purpose coffee) 9]

def main : IO Unit := do
  expect physicalMovement?.isSome
    "the shared balanced movement kernel rejected a physical Locus movement"

  expect unbalancedCapacity?.isNone
    "the shared balanced movement kernel admitted a non-zero capacity total"

  let grant ← requireSome grant? "capacity grant specimen was not admitted"
  let reallocation ← requireSome reallocation? "capacity reallocation specimen was not admitted"
  let release ← requireSome release? "capacity release specimen was not admitted"
  let movements := [grant, reallocation, release]

  expect ((entitlementAt movements coffee yen).quanta == 60)
    "coffee entitlement did not derive from capacity movement history"
  expect ((entitlementAt movements groceries yen).quanta == 30)
    "groceries entitlement did not derive from capacity movement history"
  expect ((capacityAt movements .unallocated yen).quanta == -90)
    "unallocated capacity projection lost the balancing counterpart"
  expect ((entitlementAt movements coffee usd).quanta == 0)
    "capacity evidence leaked across Measure coordinates"
