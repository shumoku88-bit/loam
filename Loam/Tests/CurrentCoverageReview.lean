import Loam.Tests.ActualWorldFixture
import Loam.ActualAuthority
import Loam.CurrentCoverageReview
import Loam.Persistence.ActualRoutingPersistence
import Loam.Persistence.CapacityPersistence
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

private def locusChange (locus : LocusId) (quanta : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := Quantity.ofQuanta quanta }

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
  let oldActual ← requireSome
    (Event.ofEffects? ⟨"actual-old"⟩
      [effect "old-pay" "paypay" (-70), effect "old-use" "expenses:food" 70])
    "old Actual fixture"
  let actual ← requireSome
    (Event.ofEffects? ⟨"actual-1"⟩
      [effect "pay" "paypay" (-30), effect "use" "expenses:food" 30])
    "Actual fixture"
  let futureActual ← requireSome
    (Event.ofEffects? ⟨"actual-future"⟩
      [effect "future-pay" "paypay" (-80), effect "future-use" "expenses:food" 80])
    "future Actual fixture"
  let events ← requireSome
    (EventMemory.ofEvents? [oldActual, actual, futureActual]) "Event memory"
  let validity : ActualValidityHistory String := {
    facts := [
      .base ⟨"actual-old"⟩ "2026-08-14",
      .base ⟨"actual-1"⟩ "2026-09-08",
      .base ⟨"actual-future"⟩ "2026-09-09"]
    factRefNodup := by decide
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

private def scheduledOccurrence : IO (ScheduledOccurrence String) := do
  let movement ← requireSome
    (BalancedMovement.ofChanges? ⟨"jpy"⟩
      [locusChange ⟨"paypay"⟩ (-35), locusChange ⟨"fixed-expense"⟩ 35])
    "Scheduled movement was not balanced"
  return { id := ⟨"scheduled-1"⟩, scheduledOn := "2026-09-10", movement := movement }

private def findRow?
    (snapshot : Loam.CurrentCoverageReview.Snapshot)
    (purpose : String) : Option Loam.CurrentCoverageReview.Row :=
  snapshot.rows.find? fun row => row.purpose.token == purpose


def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated data root")
  let root := System.FilePath.mk rootPath
  let actualRoot := root / "actual-authority"
  IO.FS.createDirAll root

  let food ← allocation "capacity-food" "food" 100
  let general ← allocation "capacity-general" "general" 50
  let future ← allocation "capacity-future" "food" 600
  let previous ← allocation "capacity-previous" "food" 200
  let capacity ← requireSome
    (CapacityMemory.ofMovements? [food, general, future, previous]) "Capacity memory"
  expect (← Loam.Persistence.saveCapacityMemory? (root / "capacity.loam") capacity)
    "save Capacity"
  let effective ← requireSome (CapacityEffectiveMemory.ofEntries?
    [{ movement := food.id, effectiveOn := "2026-09-08" },
     { movement := general.id, effectiveOn := "2026-09-08" },
     { movement := future.id, effectiveOn := "2026-10-08" },
     { movement := previous.id, effectiveOn := "2026-08-14" }]) "Capacity effective"
  expect (← Loam.Persistence.saveCapacityEffectiveMemory?
    (root / "capacity.loam.effective") effective) "save Capacity effective"

  let actualRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := (⟨"expenses:food"⟩ : LocusId),
         effectiveOn := (RoutingEffective.initial : RoutingEffective String),
         purpose := some ⟨"food"⟩ }])
    "Actual routing history"
  expect (← Loam.Persistence.saveActualRoutingHistory?
      (root / "actual-routing.loam") actualRouting)
    "save Actual routing"

  let world ← movementWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? actualRoot world
    | throw (IO.userError "publish selected Movement world")

  let scheduled ← scheduledOccurrence
  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [scheduled]) "Scheduled memory"
  let terminals ← requireSome
    (ScheduledTerminalMemory.ofTerminals? []) "empty Scheduled terminal memory"
  expect (← Loam.Persistence.saveScheduledLifecycleImage?
      (root / "scheduled.loam") {
        scheduled := scheduledMemory
        terminals := terminals })
    "save Scheduled lifecycle"

  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := {
           scheduled := ⟨"scheduled-1"⟩
           locus := (⟨"fixed-expense"⟩ : LocusId) }
         effectiveOn := "2026-09-08"
         purpose := some ⟨"food"⟩ }])
    "Scheduled routing history"
  expect (← Loam.Persistence.saveScheduledRoutingHistory?
      (root / "scheduled-routing.loam") scheduledRouting)
    "save Scheduled routing"

  IO.FS.writeFile (root / "accounting-role.loam")
    ("LOAM-ACCOUNTING-ROLE-MAP\t1\n" ++
     "ROLE\tpaypay\tASSET\n" ++
     "ROLE\texpenses:food\tEXPENSE\n" ++
     "ROLE\tfixed-expense\tEXPENSE\n")

  let .ok snapshot ←
      Loam.CurrentCoverageReview.loadSnapshotAt
        root actualRoot "2026-08-15" "2026-09-08" "2026-10-15"
    | throw (IO.userError "current coverage review refused valid fixture")
  expect (snapshot.currentWindowStart == "2026-08-15") "current window start changed"
  expect (snapshot.observedAt == "2026-09-08") "observation coordinate changed"
  expect (snapshot.endExclusive == "2026-10-15") "coverage horizon changed"

  let foodRow ← requireSome (findRow? snapshot "food") "missing food row"
  expect (foodRow.entitlement.quanta == 100) "food Entitlement"
  expect (foodRow.consumption.quanta == 30) "food Consumption"
  expect (foodRow.remaining.quanta == 70) "food Remaining"
  expect (foodRow.commitment.quanta == 35) "food Commitment"
  expect (foodRow.headroom.quanta == 35) "food Headroom"

  let generalRow ← requireSome (findRow? snapshot "general") "missing general row"
  expect (generalRow.entitlement.quanta == 50) "general Entitlement"
  expect (generalRow.consumption.quanta == 0) "general Consumption"
  expect (generalRow.remaining.quanta == 50) "general Remaining"
  expect (generalRow.commitment.quanta == 0) "general Commitment"
  expect (generalRow.headroom.quanta == 50) "general Headroom"

  match snapshot.scheduledFrontier with
  | none => throw (IO.userError "missing Scheduled frontier")
  | some frontier =>
      expect (frontier.unmanaged.quanta == 0) "invented unmanaged pressure"
      expect (frontier.unrouted.quanta == 0) "invented unrouted pressure"
      expect (frontier.unresolvedEligibility.quanta == 0) "invented unresolved pressure"

  let invalid ←
    Loam.CurrentCoverageReview.loadSnapshotAt
      root actualRoot "2026-08-15" "2026-10-15" "2026-10-15"
  expect (!invalid.isOk) "non-future current coverage horizon was admitted"

  let reversedCurrentWindow ←
    Loam.CurrentCoverageReview.loadSnapshotAt
      root actualRoot "2026-09-09" "2026-09-08" "2026-10-15"
  expect (!reversedCurrentWindow.isOk) "reversed current coverage window was admitted"

  let missingActual ←
    Loam.CurrentCoverageReview.loadSnapshotAt
      root (root / "missing-authority") "2026-08-15" "2026-09-08" "2026-10-15"
  expect (!missingActual.isOk) "missing selected Movement authority did not fail closed"

  let missingEntry ← requireSome (CapacityEffectiveMemory.ofEntries?
    [{ movement := food.id, effectiveOn := "2026-09-08" }]) "incomplete evidence"
  expect (← Loam.Persistence.saveCapacityEffectiveMemory?
    (root / "capacity.loam.effective") missingEntry) "save incomplete evidence"
  let incomplete ← Loam.CurrentCoverageReview.loadSnapshotAt
    root actualRoot "2026-08-15" "2026-09-08" "2026-10-15"
  expect (!incomplete.isOk) "missing effective entry did not fail closed"

  let emptyCapacity ← requireSome (CapacityMemory.ofMovements? []) "empty capacity"
  expect (← Loam.Persistence.saveCapacityMemory? (root / "capacity.loam") emptyCapacity)
    "save empty capacity"
  let orphan ← Loam.CurrentCoverageReview.loadSnapshotAt
    root actualRoot "2026-08-15" "2026-09-08" "2026-10-15"
  expect (!orphan.isOk) "orphan evidence with no Purpose rows did not fail closed"
  IO.FS.removeFile (root / "capacity.loam.effective")
  let missingFile ← Loam.CurrentCoverageReview.loadSnapshotAt
    root actualRoot "2026-08-15" "2026-09-08" "2026-10-15"
  expect (!missingFile.isOk) "missing effective file did not return a visible error"

  IO.println "Current Coverage Review: production authorities, effective Actual routing and current Scheduled pressure passed."