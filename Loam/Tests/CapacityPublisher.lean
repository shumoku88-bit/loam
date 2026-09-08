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

private def testBinaryPublisher (dataDir : System.FilePath) : IO Unit := do
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

private def testProposalPure : IO Unit := do
  let emptyProp := Loam.CapacityPublisher.Proposal.empty
  expect (!emptyProp.hasChanges) "empty proposal has changes"
  expect (emptyProp.isBalanced) "empty proposal is not balanced"
  expect (emptyProp.balance == 0) "empty proposal balance is non-zero"
  expect (emptyProp.delta ⟨"food"⟩ == 0) "empty proposal has non-zero food delta"

  let p1 := emptyProp.set ⟨"food"⟩ (-3000)
  expect (p1.hasChanges) "p1 does not have changes"
  expect (!p1.isBalanced) "p1 should not be balanced"
  expect (p1.balance == -3000) "p1 balance should be -3000"
  expect (p1.delta ⟨"food"⟩ == -3000) "p1 food delta should be -3000"

  let p2 := (p1.set ⟨"stock"⟩ 1180).set ⟨"living"⟩ 1820
  expect (p2.hasChanges) "p2 hasChanges should be true"
  expect (p2.isBalanced) "p2 should be balanced (-3000 + 1180 + 1820 = 0)"
  expect (p2.balance == 0) "p2 balance should be 0"

  let currentEntitlements : List (PurposeId × Int) :=
    [(⟨"food"⟩, 39000), (⟨"stock"⟩, 7000), (⟨"living"⟩, 22346)]
  let negs := p2.negativePurposes currentEntitlements
  expect (negs.isEmpty) "p2 should have no negative purposes"

  let pOverdraft := p2.set ⟨"stock"⟩ (-8000)
  let negsOverdraft := pOverdraft.negativePurposes currentEntitlements
  expect (negsOverdraft == [(⟨"stock"⟩, -1000)]) "pOverdraft should flag stock at -1000"

  let pCleared := p2.clearPurpose ⟨"living"⟩
  expect (pCleared.delta ⟨"living"⟩ == 0) "clearPurpose did not reset living"
  expect (!pCleared.isBalanced) "cleared proposal should be unbalanced"

  expectError (emptyProp.toBalancedDraft "2026-09-08") "empty proposal should not produce draft"
  expectError (p1.toBalancedDraft "2026-09-08") "unbalanced proposal should not produce draft"
  expectError (p2.toBalancedDraft "2026-02-30") "invalid date should not produce draft"

  let .ok balancedDraft := p2.toBalancedDraft "2026-09-08"
    | throw (IO.userError "p2 should produce valid draft")
  expect (balancedDraft.changes.length == 3) "balancedDraft should have 3 changes"

private def testBalancedPublisher (dataDir : System.FilePath) : IO Unit := do
  IO.FS.createDirAll dataDir
  let capacityFile := dataDir / "capacity.loam"

  -- Setup: seed with initial grant
  let grantDraft : Loam.CapacityPublisher.Draft := {
    effectiveOn := "2026-09-08"
    source := .unallocated
    destination := .purpose ⟨"food"⟩
    quanta := 39000
  }
  let .ok _ ← Loam.CapacityPublisher.publish capacityFile.toString grantDraft
    | throw (IO.userError "seed food")
  let .ok _ ← Loam.CapacityPublisher.publish capacityFile.toString {
    effectiveOn := "2026-09-08"
    source := .unallocated
    destination := .purpose ⟨"stock"⟩
    quanta := 7000
  } | throw (IO.userError "seed stock")
  let .ok _ ← Loam.CapacityPublisher.publish capacityFile.toString {
    effectiveOn := "2026-09-08"
    source := .unallocated
    destination := .purpose ⟨"living"⟩
    quanta := 22346
  } | throw (IO.userError "seed living")

  let seedSnapshot ← loadSnapshot capacityFile
  expect (seedSnapshot.rows.length == 3) "seed rows count"
  expect (rowQuanta? seedSnapshot.rows "food" == some 39000) "seed food"
  expect (rowQuanta? seedSnapshot.rows "stock" == some 7000) "seed stock"
  expect (rowQuanta? seedSnapshot.rows "living" == some 22346) "seed living"

  -- 1. Balanced 3-purpose rebalance
  let rebalanceDraft : Loam.CapacityPublisher.BalancedDraft := {
    effectiveOn := "2026-09-08"
    changes := [
      { coordinate := .purpose ⟨"food"⟩, quantity := Quantity.ofQuanta (-3000) },
      { coordinate := .purpose ⟨"stock"⟩, quantity := Quantity.ofQuanta 1180 },
      { coordinate := .purpose ⟨"living"⟩, quantity := Quantity.ofQuanta 1820 }
    ]
  }
  let .ok receipt ← Loam.CapacityPublisher.publishBalanced capacityFile.toString rebalanceDraft
    | throw (IO.userError "publish balanced 3-purpose rebalance")
  expect (receipt.movement.token == "capacity-4") "rebalance movement token"
  expect (receipt.changes.length == 3) "receipt changes count"

  -- 6. One atomic published CapacityMovement & 7. Fresh CapacityReview after publish
  let freshSnapshot ← loadSnapshot capacityFile
  expect (rowQuanta? freshSnapshot.rows "food" == some 36000) "rebalanced food"
  expect (rowQuanta? freshSnapshot.rows "stock" == some 8180) "rebalanced stock"
  expect (rowQuanta? freshSnapshot.rows "living" == some 24166) "rebalanced living"

  let some memory ← Loam.Persistence.loadCapacityMemory? capacityFile
    | throw (IO.userError "reload memory")
  expect (memory.movements.length == 4) "memory should contain exactly 4 movements (3 seed + 1 rebalance)"
  let some lastMovement := memory.findById? receipt.movement
    | throw (IO.userError "last movement not found")
  expect (lastMovement.movement.changes.length == 3) "atomic movement should contain exactly 3 changes"

  -- 2. Unbalanced proposal refusal
  let unbalancedDraft : Loam.CapacityPublisher.BalancedDraft := {
    effectiveOn := "2026-09-08"
    changes := [
      { coordinate := .purpose ⟨"food"⟩, quantity := Quantity.ofQuanta (-3000) },
      { coordinate := .purpose ⟨"stock"⟩, quantity := Quantity.ofQuanta 1180 },
      { coordinate := .purpose ⟨"living"⟩, quantity := Quantity.ofQuanta 1000 }
    ]
  }
  expectError (← Loam.CapacityPublisher.publishBalanced capacityFile.toString unbalancedDraft)
    "unbalanced proposal should be refused"

  -- 3. Purpose entitlement below zero refusal
  let overdraftDraft : Loam.CapacityPublisher.BalancedDraft := {
    effectiveOn := "2026-09-08"
    changes := [
      { coordinate := .purpose ⟨"food"⟩, quantity := Quantity.ofQuanta (-40000) },
      { coordinate := .purpose ⟨"stock"⟩, quantity := Quantity.ofQuanta 40000 }
    ]
  }
  expectError (← Loam.CapacityPublisher.publishBalanced capacityFile.toString overdraftDraft)
    "draft driving purpose below zero should be refused"

  -- 4. Duplicate coordinate handling
  let duplicateDraft : Loam.CapacityPublisher.BalancedDraft := {
    effectiveOn := "2026-09-08"
    changes := [
      { coordinate := .purpose ⟨"food"⟩, quantity := Quantity.ofQuanta (-1000) },
      { coordinate := .purpose ⟨"food"⟩, quantity := Quantity.ofQuanta (-2000) },
      { coordinate := .purpose ⟨"stock"⟩, quantity := Quantity.ofQuanta 3000 }
    ]
  }
  expectError (← Loam.CapacityPublisher.publishBalanced capacityFile.toString duplicateDraft)
    "duplicate coordinate should be refused"

  -- 5. No-op refusal (empty or all-zero or contains zero)
  let emptyChangesDraft : Loam.CapacityPublisher.BalancedDraft := {
    effectiveOn := "2026-09-08"
    changes := []
  }
  expectError (← Loam.CapacityPublisher.publishBalanced capacityFile.toString emptyChangesDraft)
    "empty changes should be refused"

  let zeroChangesDraft : Loam.CapacityPublisher.BalancedDraft := {
    effectiveOn := "2026-09-08"
    changes := [
      { coordinate := .purpose ⟨"food"⟩, quantity := Quantity.ofQuanta 0 },
      { coordinate := .purpose ⟨"stock"⟩, quantity := Quantity.ofQuanta 0 }
    ]
  }
  expectError (← Loam.CapacityPublisher.publishBalanced capacityFile.toString zeroChangesDraft)
    "all-zero changes should be refused"

  -- Verify memory was not mutated by any of the refused attempts
  let some memoryAfterRefusals ← Loam.Persistence.loadCapacityMemory? capacityFile
    | throw (IO.userError "reload memory after refusals")
  expect (memoryAfterRefusals.movements.length == 4) "refusals should not mutate memory"

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath

  testBinaryPublisher (dataDir / "binary")
  testProposalPure
  testBalancedPublisher (dataDir / "balanced")

  IO.println "Capacity Publisher: binary transfer, proposal pure laws, balanced 3-purpose rebalance, refusal boundaries and atomic movement passed."
