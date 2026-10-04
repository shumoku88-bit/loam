import Loam.Authority.HouseholdAuthority
import Loam.HouseholdCommand
import Loam.Publisher.CapacityPublisher
import Loam.Review.CapacityReview
import Loam.Persistence.NormalizedCapacityPersistence

namespace Loam.Tests.HouseholdCapacityAdapter

open Loam.Core
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw (IO.userError message)

private def requireOk {α : Type}
    (value : Except String α)
    (message : String) : IO α :=
  match value with
  | .ok result => pure result
  | .error detail => throw (IO.userError (message ++ ": " ++ detail))

private def capacityBodyFromHousehold
    (root : System.FilePath) : IO (Option String) := do
  let generation ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "HouseholdImage did not load"
  pure (body? generation.image "Capacity")

private def snapshotRows
    (snapshot : Loam.CapacityReview.Snapshot) : List (String × Int) :=
  snapshot.rows.map fun row => (row.purpose.token, row.entitlement.quanta)

private def expectReviewEquivalent
    (measure : MeasureId)
    (legacyPath : System.FilePath)
    (imageRoot : System.FilePath)
    (message : String) : IO Unit := do
  let legacy ← requireOk
    (← Loam.CapacityReview.loadSnapshotForMeasure measure legacyPath)
    (message ++ " legacy")
  let household ← requireOk
    (← Loam.CapacityReview.loadHouseholdSnapshotForMeasure measure imageRoot)
    (message ++ " household")
  expect (snapshotRows legacy == snapshotRows household)
    message

private def installFutureOnly (root : System.FilePath) : IO Unit := do
  let initial : Image := {
    sections := [
      { name := "Securities", body := "FUTURE\t1\nopaque\tunknown\n" }
    ]
  }
  let _ ← requireOk
    (← Loam.HouseholdAuthority.installInitial? root initial)
    "future-only HouseholdImage installation failed"
  pure ()

def main (args : List String) : IO Unit := do
  let [rootPath] := args
    | throw (IO.userError "supply isolated Household Capacity adapter directory")
  let root := System.FilePath.mk rootPath
  let legacyRoot := root / "legacy"
  let imageRoot := root / "image"
  let commandRoot := root / "command"
  IO.FS.createDirAll legacyRoot
  IO.FS.createDirAll imageRoot
  IO.FS.createDirAll commandRoot
  installFutureOnly imageRoot
  installFutureOnly commandRoot

  let legacyPath := legacyRoot / "capacity.loam"
  let imageLegacyPath := imageRoot / "capacity.loam"
  let jpy : MeasureId := ⟨"jpy"⟩

  expectReviewEquivalent jpy legacyPath imageRoot
    "missing Capacity empty-history answer differs across storage topology"
  expect ((← capacityBodyFromHousehold imageRoot) == none)
    "missing Household Capacity section was normalized to present-empty"

  let grant : Loam.CapacityPublisher.Draft := {
    effectiveOn := "2026-10-01"
    source := .unallocated
    destination := .purpose ⟨"food"⟩
    quanta := 5000
  }
  let legacyGrant ← requireOk
    (← Loam.CapacityPublisher.publish legacyPath.toString grant)
    "legacy Capacity grant failed"
  let imageGrant ← requireOk
    (← Loam.CapacityPublisher.publishHousehold imageRoot grant)
    "Household Capacity grant failed"
  expect (legacyGrant == imageGrant)
    "Capacity identity differs after first publication"
  let firstWire ← IO.FS.readFile legacyPath
  expect ((← capacityBodyFromHousehold imageRoot) == some firstWire)
    "first Capacity canonical bytes differ across storage topology"
  expectReviewEquivalent jpy legacyPath imageRoot
    "first Capacity Review differs across storage topology"
  expect (!(← imageLegacyPath.pathExists))
    "Household Capacity adapter wrote legacy capacity.loam"

  let transfer : Loam.CapacityPublisher.Draft := {
    effectiveOn := "2026-10-02"
    source := .purpose ⟨"food"⟩
    destination := .purpose ⟨"rent"⟩
    quanta := 2000
  }
  let legacyTransfer ← requireOk
    (← Loam.CapacityPublisher.publish legacyPath.toString transfer)
    "legacy Capacity transfer failed"
  let imageTransfer ← requireOk
    (← Loam.CapacityPublisher.publishHousehold imageRoot transfer)
    "Household Capacity transfer failed"
  expect (legacyTransfer == imageTransfer)
    "Capacity identity differs after transfer"
  let secondWire ← IO.FS.readFile legacyPath
  expect ((← capacityBodyFromHousehold imageRoot) == some secondWire)
    "second Capacity canonical bytes differ across storage topology"
  expectReviewEquivalent jpy legacyPath imageRoot
    "second Capacity Review differs across storage topology"

  let previousWire ← IO.FS.readFile (Loam.HouseholdAuthority.previousPath imageRoot)
  let some previousImage := Loam.Persistence.HouseholdImage.decode? previousWire
    | throw (IO.userError "previous HouseholdImage did not decode")
  expect (body? previousImage "Capacity" == some firstWire)
    "previous HouseholdImage did not retain the prior Capacity generation"

  let rebalance : Loam.CapacityPublisher.BalancedDraft := {
    effectiveOn := "2026-10-03"
    changes := [
      { coordinate := .purpose ⟨"food"⟩, quantity := Quantity.ofQuanta (-1000) },
      { coordinate := .purpose ⟨"rent"⟩, quantity := Quantity.ofQuanta 500 },
      { coordinate := .purpose ⟨"stock"⟩, quantity := Quantity.ofQuanta 500 }
    ]
  }
  let legacyRebalance ← requireOk
    (← Loam.CapacityPublisher.publishBalanced legacyPath.toString rebalance)
    "legacy Capacity rebalance failed"
  let imageRebalance ← requireOk
    (← Loam.CapacityPublisher.publishBalancedHousehold imageRoot rebalance)
    "Household Capacity rebalance failed"
  expect (legacyRebalance == imageRebalance)
    "Capacity identity differs after balanced publication"
  let thirdWire ← IO.FS.readFile legacyPath
  expect ((← capacityBodyFromHousehold imageRoot) == some thirdWire)
    "balanced Capacity canonical bytes differ across storage topology"
  expectReviewEquivalent jpy legacyPath imageRoot
    "balanced Capacity Review differs across storage topology"

  let householdBeforeRefusal ←
    requireOk (← Loam.HouseholdAuthority.loadCurrent? imageRoot)
      "HouseholdImage disappeared before refusal test"
  let overdraft : Loam.CapacityPublisher.Draft := {
    effectiveOn := "2026-10-04"
    source := .purpose ⟨"food"⟩
    destination := .purpose ⟨"stock"⟩
    quanta := 99999
  }
  match ← Loam.CapacityPublisher.publish legacyPath.toString overdraft with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "legacy Capacity overdraft unexpectedly succeeded")
  match ← Loam.CapacityPublisher.publishHousehold imageRoot overdraft with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "Household Capacity overdraft unexpectedly succeeded")
  let householdAfterRefusal ←
    requireOk (← Loam.HouseholdAuthority.loadCurrent? imageRoot)
      "HouseholdImage disappeared after refusal test"
  expect (householdAfterRefusal.wire == householdBeforeRefusal.wire)
    "refused Capacity publication changed HouseholdImage"
  expect ((← IO.FS.readFile legacyPath) == thirdWire)
    "refused Capacity publication changed legacy evidence"

  expect
    (body? householdAfterRefusal.image "Securities" ==
      some "FUTURE\t1\nopaque\tunknown\n")
    "Capacity adapter changed unknown future evidence"
  expect (!(← imageLegacyPath.pathExists))
    "Household Capacity adapter created legacy capacity.loam"

  -- Production cutover: high-level commands and household-root review must use
  -- HouseholdImage even when a stale but valid legacy capacity.loam remains.
  let staleLegacyPath := commandRoot / "capacity.loam"
  let staleLegacy :=
    "LOAM-NORMALIZED-CAPACITY\t1\n" ++
    "MOVEMENT\tcapacity-99\t2026-09-01\tjpy\n" ++
    "CHANGE\tUNALLOCATED\t-777\n" ++
    "CHANGE\tPURPOSE\tlegacy-only\t777\n" ++
    "ENDMOVEMENT\n"
  IO.FS.writeFile staleLegacyPath staleLegacy
  let staleBefore ← IO.FS.readFile staleLegacyPath

  let commandId ← requireOk
    (← Loam.HouseholdCommand.moveCapacity commandRoot grant)
    "HouseholdCommand Capacity grant failed"
  expect (commandId == ⟨"capacity-1"⟩)
    "HouseholdCommand Capacity identity changed after cutover"
  expect ((← IO.FS.readFile staleLegacyPath) == staleBefore)
    "HouseholdCommand mutated frozen legacy capacity.loam"

  let commandSnapshot ← requireOk
    (← Loam.CapacityReview.loadSnapshotFromHouseholdRootForMeasure jpy commandRoot)
    "production Capacity review failed after cutover"
  expect (snapshotRows commandSnapshot == [("food", 5000)])
    "production Capacity review consumed stale legacy evidence"

  let commandCurrent ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? commandRoot)
    "command HouseholdImage disappeared"
  expect
    (body? commandCurrent.image "Securities" ==
      some "FUTURE\t1\nopaque\tunknown\n")
    "production Capacity cutover changed unknown future evidence"
  let commandPreviousWire ←
    IO.FS.readFile (Loam.HouseholdAuthority.previousPath commandRoot)
  let some commandPrevious :=
      Loam.Persistence.HouseholdImage.decode? commandPreviousWire
    | throw (IO.userError "command previous HouseholdImage did not decode")
  expect (body? commandPrevious "Capacity" == none)
    "command previous generation did not retain pre-Capacity state"

  IO.println
    "Household Capacity adapter: legacy equivalence plus production command/read cutover, frozen-legacy isolation, previous-generation retention, refusal, and unknown preservation passed."

end Loam.Tests.HouseholdCapacityAdapter

def main (args : List String) : IO Unit :=
  Loam.Tests.HouseholdCapacityAdapter.main args
