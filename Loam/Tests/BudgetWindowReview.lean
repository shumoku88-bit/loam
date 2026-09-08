import Loam.BudgetWindowReview
import Loam.Persistence.CapacityPersistence
import Loam.Persistence.CapacityEffectivePersistence
import Loam.Persistence.ActualRoutingPersistence
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Persistence.ScheduledRoutingPersistence

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def capacityChange
    (coordinate : CapacityCoordinate) (quanta : Int) : MovementChange CapacityCoordinate :=
  { coordinate := coordinate, quantity := Quantity.ofQuanta quanta }

private def allocation
    (id purpose : String) (amount : Int) : IO CapacityMovement := do
  let balanced ← requireSome
    (BalancedMovement.ofChanges? ⟨"jpy"⟩
      [capacityChange .unallocated (-amount),
       capacityChange (.purpose ⟨purpose⟩) amount])
    "capacity allocation was not balanced"
  return { id := ⟨id⟩, movement := balanced }

private def effect (id locus : String) (quanta : Int) : Effect :=
  Effect.ofQuantity ⟨id⟩ ⟨locus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quanta)

private def movementWorld : IO Loam.MovementAdmission.World := do
  let oldEvent ← requireSome
    (Event.ofEffects? ⟨"actual-old"⟩
      [effect "old-pay" "paypay" (-20), effect "old-use" "expenses:food" 20])
    "old event"
  let insideEvent ← requireSome
    (Event.ofEffects? ⟨"actual-inside"⟩
      [effect "inside-pay" "paypay" (-30), effect "inside-use" "expenses:food" 30])
    "inside event"
  let events ← requireSome (EventMemory.ofEvents? [oldEvent, insideEvent]) "event memory"
  let validity : ActualValidityHistory String := {
    facts := [
      { id := ⟨"validity-old"⟩, event := ⟨"actual-old"⟩, validOn := "2026-08-16" },
      { id := ⟨"validity-inside"⟩, event := ⟨"actual-inside"⟩, validOn := "2026-09-05" }]
    factIdNodup := by decide
    corrections := []
    correctionIdNodup := by simp
  }
  return {
    events := events
    validity := validity
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := .empty
  }

private def scheduledMovement?
    (fromLocus toLocus : String) (amount : Int) : Option (BalancedMovement LocusId) :=
  BalancedMovement.ofChanges? ⟨"jpy"⟩
    [{ coordinate := ⟨fromLocus⟩, quantity := Quantity.ofQuanta (-amount) },
     { coordinate := ⟨toLocus⟩, quantity := Quantity.ofQuanta amount }]

private def occurrence
    (id day fromLocus toLocus : String) (amount : Int) : IO (ScheduledOccurrence String) := do
  let movement ← requireSome (scheduledMovement? fromLocus toLocus amount) "scheduled movement"
  return { id := ⟨id⟩, scheduledOn := day, movement := movement }

private def subject (scheduled locus : String) : ScheduledRoutingSubject :=
  { scheduled := ⟨scheduled⟩, locus := ⟨locus⟩ }

private def saveScheduledFixture (root : System.FilePath) : IO Unit := do
  let managed ← occurrence "scheduled-managed" "2026-09-20" "paypay" "fixed-expense" 20
  let overdue ← occurrence "scheduled-overdue" "2026-08-10" "paypay" "fixed-expense" 5
  let atEnd ← occurrence "scheduled-at-end" "2026-10-01" "paypay" "end-expense" 40
  let unmanaged ← occurrence "scheduled-unmanaged" "2026-09-22" "paypay" "unmanaged-expense" 7
  let unrouted ← occurrence "scheduled-unrouted" "2026-09-23" "paypay" "liability-bill" 8
  let unresolved ← occurrence "scheduled-unresolved" "2026-09-24" "paypay" "mystery" 9
  let assetReceipt ← occurrence "scheduled-asset-receipt" "2026-09-25" "income-source" "asset-receipt" 11
  let routedMystery ← occurrence "scheduled-routed-mystery" "2026-09-26" "paypay" "mystery-routed" 6
  let general ← occurrence "scheduled-general" "2026-09-20" "paypay" "general-expense" 12
  let futureRoute ← occurrence "scheduled-future-route" "2026-09-27" "paypay" "future-mystery" 4

  let scheduled ← requireSome
    (ScheduledMemory.ofOccurrences?
      [managed, overdue, atEnd, unmanaged, unrouted, unresolved,
       assetReceipt, routedMystery, general, futureRoute])
    "scheduled memory"
  let completions ← requireSome
    (ScheduledCompletionMemory.ofCompletions? []) "empty completions"
  let retirements ← requireSome
    (ScheduledRetirementMemory.ofRetirements? []) "empty retirements"
  let replacements ← requireSome
    (ScheduledReplacementMemory.ofReplacements? []) "empty replacements"
  expect (← Loam.Persistence.saveScheduledLifecycleImage? (root / "scheduled.loam")
      { scheduled, completions, retirements, replacements })
    "save Scheduled lifecycle"

  let routing ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := subject "scheduled-managed" "fixed-expense",
         effectiveOn := "2026-09-01", purpose := some ⟨"food"⟩ },
       { subject := subject "scheduled-overdue" "fixed-expense",
         effectiveOn := "2026-09-01", purpose := some ⟨"food"⟩ },
       { subject := subject "scheduled-at-end" "end-expense",
         effectiveOn := "2026-09-01", purpose := some ⟨"food"⟩ },
       { subject := subject "scheduled-unmanaged" "unmanaged-expense",
         effectiveOn := "2026-09-01", purpose := none },
       { subject := subject "scheduled-routed-mystery" "mystery-routed",
         effectiveOn := "2026-09-01", purpose := some ⟨"food"⟩ },
       { subject := subject "scheduled-general" "general-expense",
         effectiveOn := "2026-09-01", purpose := some ⟨"general"⟩ },
       { subject := subject "scheduled-future-route" "future-mystery",
         effectiveOn := "2026-09-09", purpose := some ⟨"food"⟩ }])
    "Scheduled routing history"
  expect (← Loam.Persistence.saveScheduledRoutingHistory?
      (root / "scheduled-routing.loam") routing)
    "save Scheduled routing"

  IO.FS.writeFile (root / "accounting-role.loam") <|
    "LOAM-ACCOUNTING-ROLE-MAP\t1\n" ++
    "ROLE\tpaypay\tASSET\n" ++
    "ROLE\texpenses:food\tEXPENSE\n" ++
    "ROLE\tfixed-expense\tEXPENSE\n" ++
    "ROLE\tend-expense\tEXPENSE\n" ++
    "ROLE\tunmanaged-expense\tEXPENSE\n" ++
    "ROLE\tliability-bill\tLIABILITY\n" ++
    "ROLE\tasset-receipt\tASSET\n" ++
    "ROLE\tincome-source\tINCOME\n" ++
    "ROLE\tgeneral-expense\tEXPENSE\n"

private def findRow?
    (snapshot : Loam.BudgetWindowReview.Snapshot)
    (purpose : String) : Option Loam.BudgetWindowReview.Row :=
  snapshot.rows.find? fun row => row.purpose.token == purpose


def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated data root")
  let root := System.FilePath.mk rootPath
  let manifestRoot := root / "movement-authority"
  IO.FS.createDirAll root

  let food ← allocation "capacity-food" "food" 100
  let general ← allocation "capacity-general" "general" 50
  let capacity ← requireSome
    (CapacityMemory.ofMovements? [food, general]) "capacity memory"
  let effective ← requireSome
    (CapacityEffectiveMemory.ofEntries?
      [{ movement := ⟨"capacity-food"⟩, effectiveOn := "2026-09-01" },
       { movement := ⟨"capacity-general"⟩, effectiveOn := "2026-09-01" }])
    "capacity effective memory"
  expect (← Loam.Persistence.saveCapacityMemory? (root / "capacity.loam") capacity)
    "save capacity"
  expect (← Loam.Persistence.saveCapacityEffectiveMemory?
      (root / "capacity.loam.effective") effective)
    "save capacity effective"

  let routing ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := (⟨"expenses:food"⟩ : LocusId),
         effectiveOn := (RoutingEffective.initial : RoutingEffective String),
         purpose := some ⟨"food"⟩ }])
    "routing history"
  expect (← Loam.Persistence.saveActualRoutingHistory? (root / "actual-routing.loam") routing)
    "save routing"

  let world ← movementWorld
  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? manifestRoot world
    | throw (IO.userError "publish selected Movement world")

  saveScheduledFixture root

  -- A frozen/legacy Movement sidecar must not influence this production review.
  IO.FS.writeFile (root / "memory.loam") "THIS FROZEN SIDECAR MUST NOT BE READ\n"

  let .ok snapshot ←
      Loam.BudgetWindowReview.loadSnapshotAt
        root manifestRoot "2026-09-01" "2026-10-01" "2026-09-08"
    | throw (IO.userError "budget-window Headroom review refused valid fixture")
  expect (snapshot.start == "2026-09-01" && snapshot.endExclusive == "2026-10-01")
    "window coordinates changed"
  expect (snapshot.observedAt == "2026-09-08") "observation coordinate changed"

  let foodRow ← requireSome (findRow? snapshot "food") "missing food row"
  expect (foodRow.entitlement.quanta == 100) "food entitlement"
  expect (foodRow.consumption.quanta == 30) "food consumption"
  expect (foodRow.remaining.quanta == 70) "food remaining"
  -- 20 managed + 5 overdue + 6 explicitly routed role-less. The +40 item
  -- exactly at endExclusive is excluded, and the future-effective +4 route is
  -- not yet visible at observedAt.
  expect (foodRow.commitment.quanta == 31)
    s!"expected food Commitment 31, got {foodRow.commitment.quanta}"
  expect (foodRow.headroom.quanta == 39)
    s!"expected food Headroom 39, got {foodRow.headroom.quanta}"

  let generalRow ← requireSome (findRow? snapshot "general") "missing general row"
  expect (generalRow.entitlement.quanta == 50) "general entitlement"
  expect (generalRow.consumption.quanta == 0) "general consumption"
  expect (generalRow.remaining.quanta == 50) "general remaining"
  expect (generalRow.commitment.quanta == 12) "general Commitment"
  expect (generalRow.headroom.quanta == 38) "general Headroom"

  let frontier ← requireSome snapshot.scheduledFrontier "missing Scheduled frontier"
  expect (frontier.unmanaged.quanta == 7)
    s!"expected unmanaged frontier 7, got {frontier.unmanaged.quanta}"
  expect (frontier.unrouted.quanta == 8)
    s!"expected unrouted frontier 8, got {frontier.unrouted.quanta}"
  expect (frontier.unresolvedEligibility.quanta == 13)
    s!"expected unresolved frontier 13, got {frontier.unresolvedEligibility.quanta}"

  -- The same window at a later observation coordinate sees only the route that
  -- became effective on September 9. Window coordinates stay unchanged.
  let .ok later ←
      Loam.BudgetWindowReview.loadSnapshotAt
        root manifestRoot "2026-09-01" "2026-10-01" "2026-09-10"
    | throw (IO.userError "later routing observation refused valid fixture")
  let laterFood ← requireSome (findRow? later "food") "missing later food row"
  expect (laterFood.commitment.quanta == 35)
    s!"future-effective route did not enter Commitment: {laterFood.commitment.quanta}"
  expect (laterFood.headroom.quanta == 35)
    s!"future-effective route did not reduce Headroom: {laterFood.headroom.quanta}"
  let laterFrontier ← requireSome later.scheduledFrontier "missing later frontier"
  expect (laterFrontier.unresolvedEligibility.quanta == 9)
    "future-effective route did not leave unresolved eligibility"

  let invalid ←
    Loam.BudgetWindowReview.loadSnapshotAt
      root manifestRoot "2026-10-01" "2026-09-01" "2026-09-08"
  expect (!invalid.isOk) "reversed explicit window was admitted"

  let missingManifest ←
    Loam.BudgetWindowReview.loadSnapshotAt
      root (root / "missing-authority") "2026-09-01" "2026-10-01" "2026-09-08"
  expect (!missingManifest.isOk) "missing selected Movement authority did not fail closed"

  IO.FS.writeFile (root / "accounting-role.loam") "BROKEN\n"
  let malformedRoles ←
    Loam.BudgetWindowReview.loadSnapshotAt
      root manifestRoot "2026-09-01" "2026-10-01" "2026-09-08"
  expect (!malformedRoles.isOk) "malformed AccountingRole authority did not fail closed"

  IO.println
    "Budget Window Review: explicit window, observed routing, Scheduled frontier and derived Headroom passed."
