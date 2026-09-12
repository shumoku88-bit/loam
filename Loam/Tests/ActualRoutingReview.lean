import Loam.ActualAuthority
import Loam.ActualRoutingReview
import Loam.Core.Capacity
import Loam.Persistence.CapacityPersistence

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw (IO.userError message)

private def change
    (coordinate : CapacityCoordinate)
    (quanta : Int) : MovementChange CapacityCoordinate :=
  { coordinate := coordinate, quantity := Quantity.ofQuanta quanta }

private def capacityMovement?
    (id : String)
    (changes : List (MovementChange CapacityCoordinate)) : Option CapacityMovement := do
  let balanced ← BalancedMovement.ofChanges? (⟨"jpy"⟩ : MeasureId) changes
  pure { id := ⟨id⟩, movement := balanced }

private def publishWorld
    (manifestRoot : System.FilePath)
    (tokens : List String) : IO Unit := do
  let events ← requireSome (EventMemory.ofEvents? []) "empty Event memory"
  let loci := tokens.map fun token => (⟨token⟩ : LocusId)
  let locusAdmission ← requireSome
    (LocusAdmissionVocabulary.ofLoci? loci) "Locus admission vocabulary"
  let world : Loam.MovementAdmission.World := {
    events := events
    validity := {
      facts := []
      factRefNodup := by simp
      corrections := []
      correctionIdNodup := by simp }
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := locusAdmission
  }
  match ← Loam.ActualAuthority.publishWorld? manifestRoot world with
  | .ok _ => pure ()
  | .error message => throw (IO.userError message)


def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated Actual routing review directory")
  let root := System.FilePath.mk rootPath
  let dataDir := root / "data"
  let manifestRoot := dataDir / "movement-authority"
  IO.FS.createDirAll dataDir

  publishWorld manifestRoot ["coffee", "shipping", "cash", "mystery"]

  IO.FS.writeFile (dataDir / "accounting-role.loam")
    ("LOAM-ACCOUNTING-ROLE-MAP\t1\n" ++
     "ROLE\tcoffee\tEXPENSE\n" ++
     "ROLE\tshipping\tEXPENSE\n" ++
     "ROLE\tcash\tASSET\n")

  IO.FS.writeFile (dataDir / "actual-routing.loam")
    ("LOAM-ACTUAL-ROUTING\t1\n" ++
     "ROUTE\tcoffee\tINITIAL\tMANAGED\tfood\n" ++
     "ROUTE\told-expense\tINITIAL\tMANAGED\tfood\n")

  let food : PurposeId := ⟨"food"⟩
  let general : PurposeId := ⟨"general"⟩
  let allocation1 ← requireSome
    (capacityMovement? "capacity-1"
      [ change .unallocated (-100)
      , change (.purpose food) 100 ])
    "food capacity allocation"
  let allocation2 ← requireSome
    (capacityMovement? "capacity-2"
      [ change .unallocated (-50)
      , change (.purpose general) 50 ])
    "general capacity allocation"
  let capacity ← requireSome
    (CapacityMemory.ofMovements? [allocation1, allocation2]) "Capacity memory"
  expect (← Loam.Persistence.saveCapacityMemory? (dataDir / "capacity.loam") capacity)
    "save Capacity authority"

  let snapshot ←
    match ← Loam.ActualRoutingReview.loadSnapshot dataDir manifestRoot "2026-09-09" with
    | .ok snapshot => pure snapshot
    | .error message => throw (IO.userError message)

  expect (snapshot.observedAt == "2026-09-09") "observed date"
  expect (snapshot.rows.length == 2) "only explicit current Expense Loci become rows"
  let coffee ← requireSome
    (snapshot.rows.find? fun row => row.locus.token == "coffee") "coffee row"
  let shipping ← requireSome
    (snapshot.rows.find? fun row => row.locus.token == "shipping") "shipping row"
  expect (coffee.status == .managed food) "coffee current managed route"
  expect (shipping.status == .unrouted) "shipping remains visibly unrouted"
  expect (!(snapshot.rows.any fun row => row.locus.token == "cash"))
    "Asset Locus must not be inferred into Purpose routing administration"
  expect (snapshot.unresolvedRoleLoci.map (fun locus => locus.token) == ["mystery"])
    "missing AccountingRole stays separately visible"
  expect (snapshot.historicalOnlyRouteLoci.map (fun locus => locus.token) == ["old-expense"])
    "historical route outside current admission stays separately visible"
  expect (snapshot.purposes.map (fun purpose => purpose.token) == ["food", "general"])
    "Purpose candidates come from retained Capacity evidence"
  expect (Loam.ActualRoutingReview.unroutedCount snapshot == 1) "unrouted count"

  match ← Loam.ActualRoutingReview.loadSnapshot dataDir manifestRoot "2026-02-29" with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "impossible review date was silently admitted")

  IO.println "Actual routing review: explicit Expense scope, current status, unresolved-role and historical-only audits passed."
