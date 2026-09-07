import Loam.CapacityPublisher
import Loam.CapacityReview
import Loam.Persistence.CapacityEffectivePersistence
import Loam.Persistence.CapacityPersistence

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def rowQuanta?
    (rows : List Loam.CapacityReview.Row) (token : String) : Option Int :=
  match rows with
  | [] => none
  | row :: rest =>
      if row.purpose.token = token then some row.entitlement.quanta
      else rowQuanta? rest token

private def expectError {α : Type}
    (result : Except String α) (message : String) : IO Unit :=
  match result with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError message)

private def loadSnapshot (capacityFile : System.FilePath) : IO Loam.CapacityReview.Snapshot := do
  let .ok snapshot ← Loam.CapacityReview.loadSnapshot capacityFile
    | throw (IO.userError "load Capacity snapshot")
  pure snapshot

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let capacityFile := dataDir / "capacity.loam"
  let effectiveFile := Loam.Persistence.capacityEffectivePathForMemory capacityFile

  let grant : Loam.CapacityPublisher.Draft := {
    effectiveOn := "2026-09-08"
    source := .unallocated
    destination := .purpose ⟨"food"⟩
    quanta := 5000
  }
  let .ok grantReceipt ← Loam.CapacityPublisher.publish capacityFile.toString grant
    | throw (IO.userError "publish initial Capacity grant")
  expect (grantReceipt.movement.token == "capacity-1")
    "initial Capacity publication did not allocate capacity-1"
  let first ← loadSnapshot capacityFile
  expect (rowQuanta? first.rows "food" == some 5000)
    "initial Capacity grant did not produce 5000 JPY food entitlement"

  let transfer : Loam.CapacityPublisher.Draft := {
    effectiveOn := "2026-09-09"
    source := .purpose ⟨"food"⟩
    destination := .purpose ⟨"rent"⟩
    quanta := 2000
  }
  let .ok transferReceipt ← Loam.CapacityPublisher.publish capacityFile.toString transfer
    | throw (IO.userError "publish Capacity transfer")
  expect (transferReceipt.movement.token == "capacity-2")
    "second Capacity publication did not allocate capacity-2"
  let second ← loadSnapshot capacityFile
  expect (rowQuanta? second.rows "food" == some 3000)
    "Capacity transfer did not reduce food entitlement"
  expect (rowQuanta? second.rows "rent" == some 2000)
    "Capacity transfer did not increase rent entitlement"

  let release : Loam.CapacityPublisher.Draft := {
    effectiveOn := "2026-09-10"
    source := .purpose ⟨"rent"⟩
    destination := .unallocated
    quanta := 500
  }
  let .ok releaseReceipt ← Loam.CapacityPublisher.publish capacityFile.toString release
    | throw (IO.userError "publish Capacity return to unallocated")
  expect (releaseReceipt.movement.token == "capacity-3")
    "third Capacity publication did not allocate capacity-3"
  let third ← loadSnapshot capacityFile
  expect (rowQuanta? third.rows "food" == some 3000)
    "Capacity return changed unrelated food entitlement"
  expect (rowQuanta? third.rows "rent" == some 1500)
    "Capacity return did not reduce rent entitlement"

  expectError (← Loam.CapacityPublisher.publish capacityFile.toString {
      effectiveOn := "2026-09-10"
      source := .purpose ⟨"food"⟩
      destination := .purpose ⟨"rent"⟩
      quanta := 4000 })
    "Capacity publisher admitted more than current named-source entitlement"
  expectError (← Loam.CapacityPublisher.publish capacityFile.toString {
      effectiveOn := "2026-09-10"
      source := .purpose ⟨"food"⟩
      destination := .purpose ⟨"food"⟩
      quanta := 1 })
    "Capacity publisher admitted identical endpoints"
  expectError (← Loam.CapacityPublisher.publish capacityFile.toString {
      effectiveOn := "2026-02-30"
      source := .unallocated
      destination := .purpose ⟨"buffer"⟩
      quanta := 1 })
    "Capacity publisher admitted an impossible effective date"

  let some memory ← Loam.Persistence.loadCapacityMemory? capacityFile
    | throw (IO.userError "reload Capacity authority")
  let some effective ← Loam.Persistence.loadCapacityEffectiveMemory? effectiveFile
    | throw (IO.userError "reload Capacity effective evidence")
  expect (memory.movements.length == 3 && effective.entries.length == 3)
    "refused Capacity drafts changed retained evidence"

  let some orphanedEffective := CapacityEffectiveMemory.ofEntries?
      (effective.entries ++ [{ movement := ⟨"capacity-4"⟩, effectiveOn := "2026-09-11" }])
    | throw (IO.userError "construct orphan Capacity effective evidence")
  expect (← Loam.Persistence.saveCapacityEffectiveMemory? effectiveFile orphanedEffective)
    "seed orphan Capacity effective evidence"
  expectError (← Loam.CapacityPublisher.publish capacityFile.toString {
      effectiveOn := "2026-09-11"
      source := .unallocated
      destination := .purpose ⟨"buffer"⟩
      quanta := 100 })
    "Capacity publisher guessed through incomplete effective evidence"

  let some finalMemory ← Loam.Persistence.loadCapacityMemory? capacityFile
    | throw (IO.userError "reload final Capacity authority")
  expect (finalMemory.movements.length == 3)
    "fail-closed incomplete-evidence refusal appended Capacity authority"

  IO.println "Capacity Publisher: grant/transfer/return, fresh identity, source entitlement, validation and incomplete-evidence refusal passed."
