import Loam.Tests.ActualWorldFixture
import Loam.ActualRoutingReview
import Loam.CapacityAuthority
import Loam.Core.Capacity

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
    (actualRoot : System.FilePath)
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
  match ← Loam.Tests.ActualWorldFixture.publishWorld? actualRoot world with
  | .ok _ => pure ()
  | .error message => throw (IO.userError message)


def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated Actual routing review directory")
  let root := System.FilePath.mk rootPath
  let dataDir := root / "data"
  let actualRoot := dataDir
  IO.FS.createDirAll dataDir

  publishWorld actualRoot ["coffee", "shipping", "cash", "yucho", "pension", "debt", "mystery"]

  IO.FS.writeFile (dataDir / "accounting-role.loam")
    ("LOAM-ACCOUNTING-ROLE-MAP\t1\n" ++
     "ROLE\tcoffee\tEXPENSE\n" ++
     "ROLE\tshipping\tEXPENSE\n" ++
     "ROLE\tcash\tASSET\n" ++
     "ROLE\tyucho\tASSET\n" ++
     "ROLE\tpension\tINCOME\n" ++
     "ROLE\tdebt\tLIABILITY\n")

  IO.FS.writeFile (dataDir / "actual-routing.loam")
    ("LOAM-ACTUAL-ROUTING\t1\n" ++
     "ROUTE\tcoffee\tINITIAL\tMANAGED\tfood\n" ++
     "ROUTE\tcoffee\tFROM\t2026-09-10\tMANAGED\tgeneral\n" ++
     "ROUTE\tyucho\tINITIAL\tMANAGED\tsavings\n" ++
     "ROUTE\told-expense\tINITIAL\tMANAGED\tfood\n")

  let food : PurposeId := ⟨"food"⟩
  let general : PurposeId := ⟨"general"⟩
  let savings : PurposeId := ⟨"savings"⟩
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
  let allocation3 ← requireSome
    (capacityMovement? "capacity-3"
      [ change .unallocated (-25)
      , change (.purpose savings) 25 ])
    "savings capacity allocation"
  let capacity ← requireSome
    (CapacityMemory.ofMovements? [allocation1, allocation2, allocation3]) "Capacity memory"
  let effective ← requireSome
    (CapacityEffectiveMemory.ofEntries?
      [{ movement := allocation1.id, effectiveOn := "2026-09-01" },
       { movement := allocation2.id, effectiveOn := "2026-09-01" },
       { movement := allocation3.id, effectiveOn := "2026-09-01" }])
    "Capacity effective memory"
  let evidence ← requireSome (Loam.CapacityEvidence.ofParts? capacity effective)
    "complete Capacity evidence"
  match ← Loam.CapacityAuthority.publishImage? (dataDir / "capacity.loam") evidence with
  | .ok _ => pure ()
  | .error message => throw (IO.userError message)

  let snapshot ←
    match ← Loam.ActualRoutingReview.loadSnapshot dataDir actualRoot "2026-09-09" with
    | .ok snapshot => pure snapshot
    | .error message => throw (IO.userError message)

  expect (snapshot.observedAt == "2026-09-09") "observed date"
  expect (snapshot.rows.length == 2) "default rows remain explicit current Expense Loci"
  expect (snapshot.rows.map (fun row => row.locus.token) == ["coffee", "shipping"])
    "Expense partition changed admission order"
  let coffee ← requireSome
    (snapshot.rows.find? fun row => row.locus.token == "coffee") "coffee row"
  let shipping ← requireSome
    (snapshot.rows.find? fun row => row.locus.token == "shipping") "shipping row"
  expect (coffee.role == .expense && coffee.status == .managed food)
    "coffee current managed Expense route"
  expect (shipping.role == .expense && shipping.status == .unrouted)
    "shipping remains visibly unrouted Expense"

  expect (snapshot.otherRows.length == 4)
    "known admitted non-Expense Loci become optional rows"
  expect (snapshot.otherRows.map (fun row => row.locus.token) == ["cash", "yucho", "pension", "debt"])
    "optional non-Expense partition changed admission order"
  let cash ← requireSome
    (snapshot.otherRows.find? fun row => row.locus.token == "cash") "cash optional row"
  let yucho ← requireSome
    (snapshot.otherRows.find? fun row => row.locus.token == "yucho") "yucho optional row"
  let pension ← requireSome
    (snapshot.otherRows.find? fun row => row.locus.token == "pension") "pension optional row"
  let debt ← requireSome
    (snapshot.otherRows.find? fun row => row.locus.token == "debt") "debt optional row"
  expect (cash.role == .asset && cash.status == .unrouted)
    "unrouted Asset remains an ordinary optional row"
  expect (yucho.role == .asset && yucho.status == .managed savings)
    "managed savings Asset route visible in optional rows"
  expect (pension.role == .income && pension.status == .unrouted)
    "Income route candidate remains optional"
  expect (debt.role == .liability && debt.status == .unrouted)
    "Liability route candidate remains optional"
  expect (!(snapshot.rows.any fun row => row.locus.token == "cash"))
    "Asset Locus must not become a default routing obligation"
  expect (Loam.ActualRoutingReview.unroutedCount snapshot == 1)
    "optional unrouted rows must not change the default Expense warning count"

  expect (snapshot.unresolvedRoleLoci.map (fun locus => locus.token) == ["mystery"])
    "missing AccountingRole stays separately visible"
  expect (snapshot.historicalOnlyRouteLoci.map (fun locus => locus.token) == ["old-expense"])
    "historical route outside current admission stays separately visible"
  expect (snapshot.purposes.map (fun purpose => purpose.token) == ["food", "general", "savings"])
    "Purpose candidates come from retained Capacity evidence"

  let laterSnapshot ←
    match ← Loam.ActualRoutingReview.loadSnapshot dataDir actualRoot "2026-09-11" with
    | .ok snapshot => pure snapshot
    | .error message => throw (IO.userError message)
  let laterCoffee ← requireSome
    (laterSnapshot.rows.find? fun row => row.locus.token == "coffee")
    "later coffee row"
  expect (laterCoffee.status == .managed general)
    "fixed-time routing image did not select the latest visible dated override"

  match ← Loam.ActualRoutingReview.loadSnapshot dataDir actualRoot "2026-02-29" with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "impossible review date was silently admitted")

  IO.println "Actual routing review: one role partition preserves default, optional and unresolved surfaces."
