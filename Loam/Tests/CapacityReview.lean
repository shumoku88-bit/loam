import Loam.CapacityReview

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

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

def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated Capacity review directory")
  let root := System.FilePath.mk rootPath
  IO.FS.createDirAll root

  match ← Loam.CapacityReview.loadSnapshot (root / "missing.loam") with
  | .ok snapshot =>
      expect snapshot.rows.isEmpty
        "missing Capacity storage did not preserve the existing empty-history policy"
  | .error message => throw (IO.userError message)

  let empty ← requireSome (CapacityMemory.ofMovements? [])
    "empty Capacity memory was rejected"
  let emptyPath := root / "empty.loam"
  expect (← Loam.Persistence.saveCapacityMemory? emptyPath empty)
    "explicit empty Capacity memory could not be saved"
  match ← Loam.CapacityReview.loadSnapshot emptyPath with
  | .ok snapshot => expect snapshot.rows.isEmpty "explicit empty Capacity review was not empty"
  | .error message => throw (IO.userError message)

  let allocation ← requireSome
    (movement? "capacity-1"
      [change .unallocated (-100), change (.purpose food) 100])
    "allocation specimen was not admitted"
  let reallocation ← requireSome
    (movement? "capacity-2"
      [change (.purpose food) (-40), change (.purpose groceries) 40])
    "reallocation specimen was not admitted"
  let memory ← requireSome
    (CapacityMemory.ofMovements? [allocation, reallocation])
    "Capacity review specimen memory was rejected"
  let path := root / "capacity.loam"
  expect (← Loam.Persistence.saveCapacityMemory? path memory)
    "Capacity review specimen could not be saved"

  match ← Loam.CapacityReview.loadSnapshot path with
  | .error message => throw (IO.userError message)
  | .ok snapshot =>
      let rows := snapshot.rows.map fun row => (row.purpose.token, row.entitlement.quanta)
      expect (rows == [("food", 60), ("groceries", 40)])
        "shared Capacity review diverged from all-retained entitlement projection"

  IO.FS.writeFile (root / "malformed.loam") "not-capacity\n"
  match ← Loam.CapacityReview.loadSnapshot (root / "malformed.loam") with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "malformed Capacity storage was silently accepted")

  IO.println "Capacity review: missing/empty policy, entitlement projection and malformed refusal passed."
