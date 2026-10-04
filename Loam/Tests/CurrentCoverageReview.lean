import Loam.Tests.ActualWorldFixture
import Loam.Authority.ActualAuthority
import Loam.Review.CurrentCoverageReview
import Loam.Persistence.ActualRoutingPersistence
import Loam.Authority.HouseholdAuthority
import Loam.Persistence.NormalizedCapacityPersistence
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

private def allocationForMeasure
    (measure : MeasureId) (id purpose : String) (amount : Int) : IO CapacityMovement := do
  let balanced ← requireSome
    (BalancedMovement.ofChanges? measure
      [capacityChange .unallocated (-amount),
       capacityChange (.purpose ⟨purpose⟩) amount])
    "capacity allocation was not balanced"
  return { id := ⟨id⟩, movement := balanced }

private def allocation
    (id purpose : String) (amount : Int) : IO CapacityMovement :=
  allocationForMeasure ⟨"jpy"⟩ id purpose amount

private def effectForMeasure
    (measure : MeasureId) (id locus : String) (quanta : Int) : Effect :=
  Effect.ofQuantity ⟨id⟩ ⟨locus⟩ measure (Quantity.ofQuanta quanta)

private def effect (id locus : String) (quanta : Int) : Effect :=
  effectForMeasure ⟨"jpy"⟩ id locus quanta

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
  let usdActual ← requireSome
    (Event.ofEffects? ⟨"actual-usd"⟩
      [effectForMeasure ⟨"usd"⟩ "usd-pay" "paypay" (-40),
       effectForMeasure ⟨"usd"⟩ "usd-use" "expenses:food" 40])
    "USD Actual fixture"
  let events ← requireSome
    (EventMemory.ofEvents? [oldActual, actual, futureActual, usdActual]) "Event memory"
  let validity : ActualValidityHistory String := {
    facts := [
      .base ⟨"actual-old"⟩ "2026-08-14",
      .base ⟨"actual-1"⟩ "2026-09-08",
      .base ⟨"actual-future"⟩ "2026-09-09",
      .base ⟨"actual-usd"⟩ "2026-09-08"]
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

private def scheduledOccurrenceForMeasure
    (measure : MeasureId) (id : String) (amount : Int) : IO (ScheduledOccurrence String) := do
  let movement ← requireSome
    (BalancedMovement.ofChanges? measure
      [locusChange ⟨"paypay"⟩ (-amount), locusChange ⟨"fixed-expense"⟩ amount])
    "Scheduled movement was not balanced"
  return { id := ⟨id⟩, scheduledOn := "2026-09-10", movement := movement }

private def scheduledOccurrence : IO (ScheduledOccurrence String) :=
  scheduledOccurrenceForMeasure ⟨"jpy"⟩ "scheduled-1" 35

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
  let usdFood ← allocationForMeasure ⟨"usd"⟩ "capacity-usd-food" "food" 250
  let capacity ← requireSome
    (CapacityMemory.ofMovements? [food, general, future, previous, usdFood]) "Capacity memory"
  let effective ← requireSome (CapacityEffectiveMemory.ofEntries?
    [{ movement := food.id, effectiveOn := "2026-09-08" },
     { movement := general.id, effectiveOn := "2026-09-08" },
     { movement := future.id, effectiveOn := "2026-10-08" },
     { movement := previous.id, effectiveOn := "2026-08-14" },
     { movement := usdFood.id, effectiveOn := "2026-09-08" }]) "Capacity effective"
  let evidence ← requireSome (Loam.CapacityEvidence.ofParts? capacity effective) "Capacity evidence"
  let capacityBody ← requireSome
    (Loam.Persistence.encodeNormalizedCapacity? evidence)
    "encode Household Capacity evidence"
  let capacityImage : Loam.Persistence.HouseholdImage.Image := {
    sections := [{ name := "Capacity", body := capacityBody }]
  }
  let .ok _ ← Loam.HouseholdAuthority.installInitial? root capacityImage
    | throw (IO.userError "install Household Capacity evidence")
  expect (!(← (root / "capacity.loam").pathExists))
    "CurrentCoverage fixture unexpectedly retained legacy Capacity"

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
  let usdScheduled ← scheduledOccurrenceForMeasure ⟨"usd"⟩ "scheduled-usd" 15
  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [scheduled, usdScheduled]) "Scheduled memory"
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
         purpose := some ⟨"food"⟩ },
       { subject := {
           scheduled := ⟨"scheduled-usd"⟩
           locus := (⟨"fixed-expense"⟩ : LocusId) }
         effectiveOn := "2026-09-08"
         purpose := some ⟨"food"⟩ }])
    "Scheduled routing history"
  let scheduledRoutingBody ← requireSome
    (Loam.Persistence.encodeScheduledRoutingHistory? scheduledRouting)
    "encode Household Scheduled routing"
  let .ok _ ←
      Loam.Tests.ActualWorldFixture.publishHouseholdSection?
        root "ScheduledRouting" scheduledRoutingBody
    | throw (IO.userError "install Household Scheduled routing")
  IO.FS.writeFile (root / "scheduled-routing.loam")
    ("LOAM-SCHEDULED-ROUTING\t1\n" ++
     "ROUTE\tscheduled-1\tfixed-expense\tFROM\t2026-09-08\tUNMANAGED\n")

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
  expect (snapshot.actualRoutingFrontier.unroutedExpense.isEmpty)
    "baseline invented unrouted Actual Expense rows"
  expect (snapshot.actualRoutingFrontier.unresolvedRole.isEmpty)
    "baseline invented role-unresolved Actual rows"

  let .ok usdSnapshot ←
      Loam.CurrentCoverageReview.loadSnapshotAtForMeasure ⟨"usd"⟩
        root actualRoot "2026-08-15" "2026-09-08" "2026-10-15"
    | throw (IO.userError "USD current coverage review refused valid fixture")
  expect (usdSnapshot.measure == ⟨"usd"⟩)
    "CurrentCoverage lost the requested Measure"
  let usdFoodRow ← requireSome (findRow? usdSnapshot "food") "missing USD food row"
  expect (usdFoodRow.entitlement.quanta == 250) "USD food Entitlement"
  expect (usdFoodRow.consumption.quanta == 40) "USD food Consumption"
  expect (usdFoodRow.remaining.quanta == 210) "USD food Remaining"
  expect (usdFoodRow.commitment.quanta == 15) "USD food Commitment"
  expect (usdFoodRow.headroom.quanta == 195) "USD food Headroom"
  let usdGeneralRow ← requireSome (findRow? usdSnapshot "general") "missing USD general row"
  expect
    (usdGeneralRow.entitlement.quanta == 0 &&
      usdGeneralRow.consumption.quanta == 0 &&
      usdGeneralRow.commitment.quanta == 0)
    "JPY-only Purpose evidence leaked into the USD coverage projection"
  expect
    (usdSnapshot.actualRoutingFrontier.unroutedExpense.isEmpty &&
      usdSnapshot.actualRoutingFrontier.unresolvedRole.isEmpty)
    "USD coverage invented an Actual routing frontier"


  -- A route that starts after the Actual occurrence must not rewrite history.
  -- CurrentCoverage keeps its numeric Purpose answer but now exposes the exact
  -- current-window Expense row that remains unrouted at its valid coordinate.
  let delayedActualRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := (⟨"expenses:food"⟩ : LocusId),
         effectiveOn := RoutingEffective.dated "2026-09-09",
         purpose := some ⟨"food"⟩ }])
    "delayed Actual routing history"
  expect (← Loam.Persistence.saveActualRoutingHistory?
      (root / "actual-routing.loam") delayedActualRouting)
    "save delayed Actual routing"
  let .ok delayedSnapshot ←
      Loam.CurrentCoverageReview.loadSnapshotAt
        root actualRoot "2026-08-15" "2026-09-08" "2026-10-15"
    | throw (IO.userError "current coverage refused delayed routing fixture")
  let delayedFood ← requireSome (findRow? delayedSnapshot "food")
    "missing delayed-routing food row"
  expect (delayedFood.consumption.quanta == 0)
    "future route was applied backward to earlier Actual Consumption"
  expect (delayedFood.remaining.quanta == 100)
    "delayed-routing Remaining did not preserve current Purpose evidence"
  expect (delayedSnapshot.actualRoutingFrontier.unroutedExpense.length == 1)
    "current-window unrouted Expense row was not surfaced"
  let delayedGap ← requireSome delayedSnapshot.actualRoutingFrontier.unroutedExpense.head?
    "missing delayed-routing frontier row"
  expect (delayedGap.event.token == "actual-1")
    "wrong Event surfaced in Actual routing frontier"
  expect (delayedGap.validOn == "2026-09-08")
    "Actual routing frontier lost current validity coordinate"
  expect (delayedGap.locus.token == "expenses:food" &&
      delayedGap.quantity.quanta == 30 &&
      delayedGap.role == some .expense)
    "Actual routing frontier lost Expense row evidence"
  expect delayedSnapshot.actualRoutingFrontier.unresolvedRole.isEmpty
    "known Expense routing gap leaked into unresolved-role frontier"

  -- Restore the baseline route before correction-currentness assertions below.
  expect (← Loam.Persistence.saveActualRoutingHistory?
      (root / "actual-routing.loam") actualRouting)
    "restore initial Actual routing"

  -- Replace the observed Actual Event and verify current Consumption uses the
  -- admitted Actual image while Scheduled reference checks still retain all IDs.
  let replacementActual ← requireSome
    (Event.ofEffects? ⟨"actual-1-r1"⟩
      [effect "r1-pay" "paypay" (-45), effect "r1-use" "expenses:food" 45])
    "replacement Actual fixture"
  let correctedEvents ← requireSome
    (EventMemory.ofEvents? (world.events.events ++ [replacementActual]))
    "corrected CurrentCoverage Event memory"
  let correctedValidity : ActualValidityHistory String := {
    facts := [
      .base ⟨"actual-old"⟩ "2026-08-14",
      .base ⟨"actual-1"⟩ "2026-09-08",
      .base ⟨"actual-future"⟩ "2026-09-09",
      .base ⟨"actual-usd"⟩ "2026-09-08",
      .base ⟨"actual-1-r1"⟩ "2026-09-08"
    ]
    factRefNodup := by decide
    corrections := []
    correctionIdNodup := by simp
  }
  let correctedCorrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := ⟨"actual-1"⟩, replacement := ⟨"actual-1-r1"⟩ }])
    "corrected CurrentCoverage correction memory"
  let correctedActual : Loam.ActualEvidence := {
    Loam.ActualEvidence.empty with
      events := correctedEvents
      validity := correctedValidity
      corrections := correctedCorrections
  }
  let .ok _ ← Loam.ActualAuthority.publishActualFile?
      (Loam.ActualAuthority.actualPath actualRoot) correctedActual
    | throw (IO.userError "publish corrected CurrentCoverage Actual image")
  let .ok correctedSnapshot ←
      Loam.CurrentCoverageReview.loadSnapshotAt
        root actualRoot "2026-08-15" "2026-09-08" "2026-10-15"
    | throw (IO.userError "current coverage refused corrected Actual image")
  let correctedFood ← requireSome (findRow? correctedSnapshot "food")
    "missing corrected CurrentCoverage food row"
  expect (correctedFood.consumption.quanta == 45)
    "CurrentCoverage did not consume the admitted current Event frontier"
  expect (correctedFood.remaining.quanta == 55)
    "CurrentCoverage Remaining did not follow corrected Consumption"
  expect (correctedFood.headroom.quanta == 20)
    "CurrentCoverage Headroom did not preserve Scheduled pressure after correction"

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

  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root world
    | throw (IO.userError "publish fallback Actual world")
  let missingActual ←
    Loam.CurrentCoverageReview.loadSnapshotAt
      root (root / "missing-authority") "2026-08-15" "2026-09-08" "2026-10-15"
  expect (!missingActual.isOk) "missing selected Movement authority fell back to dataDir Actual"

  let writeHouseholdImage (image : Loam.Persistence.HouseholdImage.Image) : IO Unit := do
    let wire ← requireSome
      (Loam.Persistence.HouseholdImage.encode? image)
      "encode CurrentCoverage HouseholdImage refusal fixture"
    IO.FS.writeFile (Loam.HouseholdAuthority.path root) wire

  writeHouseholdImage {
    sections := [{
      name := "Capacity"
      body :=
        "LOAM-NORMALIZED-CAPACITY\t1\nMOVEMENT\tcapacity-food\t2026-09-08\tjpy\nCHANGE\tUNALLOCATED\t-100\nCHANGE\tPURPOSE\tfood\t90\nENDMOVEMENT\n"
    }]
  }
  let unbalanced ← Loam.CurrentCoverageReview.loadSnapshotAt
    root actualRoot "2026-08-15" "2026-09-08" "2026-10-15"
  expect (!unbalanced.isOk) "unbalanced Household Capacity did not fail closed"

  writeHouseholdImage {
    sections := [{ name := "Capacity", body := "not-capacity-evidence\n" }]
  }
  let malformed ← Loam.CurrentCoverageReview.loadSnapshotAt
    root actualRoot "2026-08-15" "2026-09-08" "2026-10-15"
  expect (!malformed.isOk) "malformed Household Capacity did not fail closed"

  writeHouseholdImage { sections := [] }
  let missingFile ← Loam.CurrentCoverageReview.loadSnapshotAt
    root actualRoot "2026-08-15" "2026-09-08" "2026-10-15"
  expect (!missingFile.isOk) "missing Household Capacity section did not return a visible error"

  IO.println "Current Coverage Review: production authorities, effective Actual routing and current Scheduled pressure passed."