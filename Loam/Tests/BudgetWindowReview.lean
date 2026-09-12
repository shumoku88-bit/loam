import Loam.Tests.ActualWorldFixture
import Loam.ActualAuthority
import Loam.BudgetWindowReview
import Loam.Persistence.CapacityPersistence
import Loam.Persistence.CapacityEffectivePersistence
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
      .base ⟨"actual-old"⟩ "2026-08-16",
      .base ⟨"actual-inside"⟩ "2026-08-18"]
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
  let capacity ← requireSome
    (CapacityMemory.ofMovements? [food, general]) "capacity memory"
  let effective ← requireSome
    (CapacityEffectiveMemory.ofEntries?
      [{ movement := ⟨"capacity-food"⟩, effectiveOn := "2026-08-17" },
       { movement := ⟨"capacity-general"⟩, effectiveOn := "2026-08-17" }])
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

  let invalid ←
    Loam.BudgetWindowReview.loadSnapshot
      root actualRoot "2026-10-15" "2026-08-17"
  expect (!invalid.isOk) "reversed explicit window was admitted"

  let missingActual ←
    Loam.BudgetWindowReview.loadSnapshot
      root (root / "missing-authority") "2026-08-17" "2026-10-15"
  expect (!missingActual.isOk) "missing selected Movement authority did not fail closed"

  IO.println "Budget Window Review: Actual authority, explicit window and derived Remaining passed."