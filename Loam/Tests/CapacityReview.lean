import Loam.Review.CapacityReview
import Loam.Tests.Support

open Loam.Core
open Loam.Tests.Support

private def yen : MeasureId := ⟨"jpy"⟩
private def usd : MeasureId := ⟨"usd"⟩
private def food : PurposeId := ⟨"food"⟩
private def groceries : PurposeId := ⟨"groceries"⟩

private def change
    (coordinate : CapacityCoordinate)
    (quanta : Int) : MovementChange CapacityCoordinate :=
  { coordinate := coordinate, quantity := Quantity.ofQuanta quanta }

private def movementForMeasure?
    (measure : MeasureId)
    (id : String)
    (changes : List (MovementChange CapacityCoordinate)) : Option CapacityMovement := do
  let balanced ← BalancedMovement.ofChanges? measure changes
  pure { id := ⟨id⟩, movement := balanced }

private def movement?
    (id : String)
    (changes : List (MovementChange CapacityCoordinate)) : Option CapacityMovement :=
  movementForMeasure? yen id changes

def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated Capacity review directory")
  let root := System.FilePath.mk rootPath
  IO.FS.createDirAll root

  match ← Loam.CapacityReview.loadSnapshot (root / "missing.loam") with
  | .ok snapshot =>
      expect snapshot.rows.isEmpty
        "missing Capacity storage did not preserve the existing empty-history policy"
  | .error message => throw (IO.userError message)

  let emptyPath := root / "empty.loam"
  match ← Loam.CapacityAuthority.publishImage? emptyPath Loam.CapacityEvidence.empty with
  | .ok _ => pure ()
  | .error message => throw (IO.userError message)
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
  let effective ← requireSome
    (CapacityEffectiveMemory.ofEntries?
      [{ movement := allocation.id, effectiveOn := "2026-09-01" },
       { movement := reallocation.id, effectiveOn := "2026-09-02" }])
    "Capacity review effective specimen was rejected"
  let evidence ← requireSome (Loam.CapacityEvidence.ofParts? memory effective)
    "Capacity review complete image was rejected"
  let path := root / "capacity.loam"
  match ← Loam.CapacityAuthority.publishImage? path evidence with
  | .ok _ => pure ()
  | .error message => throw (IO.userError message)

  match ← Loam.CapacityReview.loadSnapshot path with
  | .error message => throw (IO.userError message)
  | .ok snapshot =>
      let rows := snapshot.rows.map fun row => (row.purpose.token, row.entitlement.quanta)
      expect (rows == [("food", 60), ("groceries", 40)])
        "shared Capacity review diverged from all-retained entitlement projection"

  let usdAllocation ← requireSome
    (movementForMeasure? usd "capacity-usd-1"
      [change .unallocated (-2500), change (.purpose food) 2500])
    "USD allocation specimen was not admitted"
  let mixedMemory ← requireSome
    (CapacityMemory.ofMovements? [allocation, reallocation, usdAllocation])
    "mixed-Measure Capacity review memory was rejected"
  let usdSnapshot := Loam.CapacityReview.snapshotForMeasure usd mixedMemory
  expect (usdSnapshot.measure == usd)
    "Capacity review lost the requested non-JPY Measure"
  let usdRows := usdSnapshot.rows.map fun row =>
      (row.purpose.token, row.entitlement.quanta)
  expect (usdRows == [("food", 2500), ("groceries", 0)])
    "Capacity review did not isolate the requested non-JPY Measure"
  let jpySnapshot := Loam.CapacityReview.snapshotForMeasure yen mixedMemory
  expect (jpySnapshot.measure == yen) "JPY Capacity review lost its Measure"
  let jpyRows := jpySnapshot.rows.map fun row =>
      (row.purpose.token, row.entitlement.quanta)
  expect (jpyRows == [("food", 60), ("groceries", 40)])
    "non-JPY Capacity evidence changed the JPY projection"

  IO.FS.writeFile (root / "malformed.loam") "not-capacity\n"
  match ← Loam.CapacityReview.loadSnapshot (root / "malformed.loam") with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "malformed Capacity storage was silently accepted")

  IO.println "Capacity review: missing/normalized-empty policy, entitlement projection and malformed refusal passed."
