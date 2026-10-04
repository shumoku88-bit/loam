import Loam.Tests.ActualWorldFixture
import Loam.Authority.ActualAuthority
import Loam.Review.BudgetWindowReview
import Loam.Authority.HouseholdAuthority
import Loam.Persistence.NormalizedCapacityPersistence
import Loam.Persistence.ActualRoutingPersistence

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

private def allocationForMeasure
    (measure : MeasureId)
    (id purpose : String) (amount : Int) : IO CapacityMovement := do
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
    (measure : MeasureId)
    (id locus : String) (quanta : Int) : Effect :=
  Effect.ofQuantity ⟨id⟩ ⟨locus⟩ measure (Quantity.ofQuanta quanta)

private def effect (id locus : String) (quanta : Int) : Effect :=
  effectForMeasure ⟨"jpy"⟩ id locus quanta

private def movementWorld : IO Loam.MovementAdmission.World := do
  let oldEvent ← requireSome
    (Event.ofEffects? ⟨"actual-old"⟩
      [effect "old-pay" "paypay" (-20), effect "old-use" "expenses:food" 20])
    "old event"
  let insideEvent ← requireSome
    (Event.ofEffects? ⟨"actual-inside"⟩
      [effect "inside-pay" "paypay" (-30), effect "inside-use" "expenses:food" 30])
    "inside event"
  let usd : MeasureId := ⟨"usd"⟩
  let usdEvent ← requireSome
    (Event.ofEffects? ⟨"actual-inside-usd"⟩
      [ effectForMeasure usd "usd-pay" "paypay" (-70)
      , effectForMeasure usd "usd-use" "expenses:food" 70
      ])
    "USD inside event"
  let events ← requireSome
    (EventMemory.ofEvents? [oldEvent, insideEvent, usdEvent]) "event memory"
  let validity : ActualValidityHistory String := {
    facts := [
      .base ⟨"actual-old"⟩ "2026-08-16",
      .base ⟨"actual-inside"⟩ "2026-08-18",
      .base ⟨"actual-inside-usd"⟩ "2026-08-20"]
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

private def findRow?
    (snapshot : Loam.BudgetWindowReview.Snapshot)
    (purpose : String) : Option Loam.BudgetWindowReview.Row :=
  snapshot.rows.find? fun row => row.purpose.token == purpose


def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated data root")
  let root := System.FilePath.mk rootPath
  let actualRoot := root
  IO.FS.createDirAll root

  let food ← allocation "capacity-food" "food" 100
  let general ← allocation "capacity-general" "general" 50
  let usd : MeasureId := ⟨"usd"⟩
  let usdFood ← allocationForMeasure usd "capacity-food-usd" "food" 250
  let capacity ← requireSome
    (CapacityMemory.ofMovements? [food, general, usdFood]) "capacity memory"
  let effective ← requireSome
    (CapacityEffectiveMemory.ofEntries?
      [{ movement := ⟨"capacity-food"⟩, effectiveOn := "2026-08-17" },
       { movement := ⟨"capacity-general"⟩, effectiveOn := "2026-08-17" },
       { movement := ⟨"capacity-food-usd"⟩, effectiveOn := "2026-08-17" }])
    "capacity effective memory"
  let evidence ← requireSome
    (Loam.CapacityEvidence.ofParts? capacity effective) "capacity evidence"
  let capacityBody ← requireSome
    (Loam.Persistence.encodeNormalizedCapacity? evidence)
    "encode Household Capacity evidence"
  let capacityImage : Loam.Persistence.HouseholdImage.Image := {
    sections := [{ name := "Capacity", body := capacityBody }]
  }
  let .ok _ ← Loam.HouseholdAuthority.installInitial? root capacityImage
    | throw (IO.userError "install Household Capacity evidence")
  expect (!(← (root / "capacity.loam").pathExists))
    "BudgetWindow fixture unexpectedly retained legacy Capacity"

  let routing ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := (⟨"expenses:food"⟩ : LocusId),
         effectiveOn := (RoutingEffective.initial : RoutingEffective String),
         purpose := some ⟨"food"⟩ }])
    "routing history"
  let routingBody ← requireSome
    (Loam.Persistence.encodeActualRoutingHistory? routing)
    "encode Household Actual routing"
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "ActualRouting" routingBody
    | throw (IO.userError "install Household Actual routing")
  let staleLegacyRouting := root / "actual-routing.loam"
  IO.FS.writeFile staleLegacyRouting
    ("LOAM-ACTUAL-ROUTING\t1\n" ++
     "ROUTE\texpenses:food\tINITIAL\tUNMANAGED\n")
  let staleLegacyBefore ← IO.FS.readFile staleLegacyRouting

  let world ← movementWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? actualRoot world
    | throw (IO.userError "publish selected Movement world")

  -- A frozen/legacy Movement sidecar must not influence this production review.
  IO.FS.writeFile (root / "memory.loam") "THIS FROZEN SIDECAR MUST NOT BE READ\n"

  let .ok snapshot ←
      Loam.BudgetWindowReview.loadSnapshot
        root actualRoot "2026-08-17" "2026-10-15"
    | throw (IO.userError "budget-window review refused valid fixture")
  expect (snapshot.start == "2026-08-17" && snapshot.endExclusive == "2026-10-15")
    "window coordinates changed"
  let foodRow ← requireSome (findRow? snapshot "food") "missing food row"
  expect (foodRow.entitlement.quanta == 100) "food entitlement"
  expect (foodRow.consumption.quanta == 30) "food consumption"
  expect (foodRow.remaining.quanta == 70) "food remaining"
  let generalRow ← requireSome (findRow? snapshot "general") "missing general row"
  expect (generalRow.entitlement.quanta == 50) "general entitlement"
  expect (generalRow.consumption.quanta == 0) "general consumption"
  expect (generalRow.remaining.quanta == 50) "general remaining"
  expect ((← IO.FS.readFile staleLegacyRouting) == staleLegacyBefore)
    "Budget Window mutated frozen legacy Actual routing evidence"
  expect (snapshot.measure == (⟨"jpy"⟩ : MeasureId))
    "compatibility Budget Window lost its JPY Measure"
  let .ok usdSnapshot ←
      Loam.BudgetWindowReview.loadSnapshotForMeasure usd
        root actualRoot "2026-08-17" "2026-10-15"
    | throw (IO.userError "USD budget-window review refused valid mixed fixture")
  expect (usdSnapshot.measure == usd)
    "Budget Window lost the requested USD Measure"
  let usdFoodRow ← requireSome (findRow? usdSnapshot "food") "missing USD food row"
  expect (usdFoodRow.entitlement.quanta == 250) "USD food entitlement"
  expect (usdFoodRow.consumption.quanta == 70) "USD food consumption"
  expect (usdFoodRow.remaining.quanta == 180) "USD food remaining"
  let usdGeneralRow ← requireSome (findRow? usdSnapshot "general") "missing USD general row"
  expect (usdGeneralRow.entitlement.quanta == 0) "JPY Capacity leaked into USD entitlement"
  expect (usdGeneralRow.consumption.quanta == 0) "JPY Actual leaked into USD consumption"
  let .ok usdPurpose ←
      Loam.BudgetWindowReview.loadPurposeRowForMeasure usd
        root actualRoot "2026-08-17" "2026-10-15" ⟨"food"⟩
    | throw (IO.userError "USD per-Purpose Budget Window refused valid fixture")
  expect (usdPurpose.entitlement.quanta == 250 &&
      usdPurpose.consumption.quanta == 70 &&
      usdPurpose.remaining.quanta == 180)
    "USD per-Purpose Budget Window did not preserve Measure isolation"

  -- Canonical BudgetWindow must reuse the admitted Actual image. Replace the
  -- inside-window Event and verify Consumption follows the current frontier.
  let replacementEvent ← requireSome
    (Event.ofEffects? ⟨"actual-inside-r1"⟩
      [effect "inside-r1-pay" "paypay" (-40),
       effect "inside-r1-use" "expenses:food" 40])
    "replacement event"
  let correctedEvents ← requireSome
    (EventMemory.ofEvents? (world.events.events ++ [replacementEvent]))
    "corrected Event memory"
  let correctedValidity : ActualValidityHistory String := {
    facts := [
      .base ⟨"actual-old"⟩ "2026-08-16",
      .base ⟨"actual-inside"⟩ "2026-08-18",
      .base ⟨"actual-inside-r1"⟩ "2026-08-19",
      .base ⟨"actual-inside-usd"⟩ "2026-08-20"
    ]
    factRefNodup := by decide
    corrections := []
    correctionIdNodup := by simp
  }
  let correctedCorrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := ⟨"actual-inside"⟩, replacement := ⟨"actual-inside-r1"⟩ }])
    "corrected Event correction memory"
  let correctedActual : Loam.ActualEvidence := {
    Loam.ActualEvidence.empty with
      events := correctedEvents
      validity := correctedValidity
      corrections := correctedCorrections
  }
  let correctedActualBody ← requireSome
    (Loam.Persistence.encodeNormalizedActual? correctedActual)
    "encode corrected Household Actual image"
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      actualRoot "Actual" correctedActualBody
    | throw (IO.userError "publish corrected Household Actual image")
  let .ok correctedSnapshot ←
      Loam.BudgetWindowReview.loadSnapshot
        root actualRoot "2026-08-17" "2026-10-15"
    | throw (IO.userError "budget-window review refused corrected Actual image")
  let correctedFood ← requireSome (findRow? correctedSnapshot "food")
    "missing corrected food row"
  expect (correctedFood.consumption.quanta == 40)
    "Budget Window did not consume the admitted current Event frontier"
  expect (correctedFood.remaining.quanta == 60)
    "Budget Window Remaining did not follow corrected Consumption"

  let invalid ←
    Loam.BudgetWindowReview.loadSnapshot
      root actualRoot "2026-10-15" "2026-08-17"
  expect (!invalid.isOk) "reversed explicit window was admitted"

  let missingActual ←
    Loam.BudgetWindowReview.loadSnapshot
      root (root / "missing-authority") "2026-08-17" "2026-10-15"
  expect (!missingActual.isOk) "missing selected Movement authority did not fail closed"

  IO.println "Budget Window Review: Actual authority, explicit window and derived Remaining passed."