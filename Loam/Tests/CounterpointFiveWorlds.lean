import Loam.Application.CurrentCoverageInspection
import Loam.CurrentQuantityAnchor
import Loam.RoleBalanceReview

open Loam.Core
open Loam.Application

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def requireOk {α : Type} (value : Except String α) (message : String) : IO α :=
  match value with
  | .ok result => pure result
  | .error error => throw (IO.userError (message ++ ": " ++ error))

private def yen : MeasureId := ⟨"jpy"⟩
private def food : PurposeId := ⟨"food"⟩
private def books : PurposeId := ⟨"books"⟩
private def paypay : LocusId := ⟨"paypay"⟩
private def expense : LocusId := ⟨"expense"⟩
private def booksExpense : LocusId := ⟨"books-expense"⟩
private def debt : LocusId := ⟨"debt"⟩

private def q (amount : Int) : Quantity := Quantity.ofQuanta amount

private def change (locus : LocusId) (amount : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := q amount }

private def capacityChange
    (coordinate : CapacityCoordinate) (amount : Int) : MovementChange CapacityCoordinate :=
  { coordinate := coordinate, quantity := q amount }

private def capacityMovement?
    (id : String) (purpose : PurposeId) (amount : Int) : Option CapacityMovement := do
  let movement ← BalancedMovement.ofChanges? yen
    [capacityChange .unallocated (-amount), capacityChange (.purpose purpose) amount]
  pure { id := ⟨id⟩, movement := movement }

private def scheduled?
    (id : String) (day : Nat) (destination : LocusId) (amount : Int) :
    Option (ScheduledOccurrence Nat) := do
  let movement ← BalancedMovement.ofChanges? yen
    [change paypay (-amount), change destination amount]
  pure { id := ⟨id⟩, scheduledOn := day, movement := movement }

private def movementEvent?
    (id : String) (destination : LocusId) (amount : Int) : Option Event :=
  Event.ofEffects? ⟨id⟩
    [ Effect.ofQuantity ⟨id ++ "-source"⟩ paypay yen (q (-amount))
    , Effect.ofQuantity ⟨id ++ "-destination"⟩ destination yen (q amount) ]

private def oneEffectEvent?
    (id : String) (locus : LocusId) (amount : Int) : Option Event :=
  Event.ofEffects? ⟨id⟩
    [Effect.ofQuantity ⟨id ++ "-effect"⟩ locus yen (q amount)]

private def scheduledSubject (id : ScheduledId) (locus : LocusId) : ScheduledRoutingSubject :=
  { scheduled := id, locus := locus }

private def expectCoverage
    (label : String) (view : CurrentCoverageView)
    (entitlement consumption commitment headroom : Int) : IO Unit := do
  expect (view.entitlement.quanta == entitlement)
    s!"{label}: entitlement {view.entitlement.quanta}"
  expect (view.consumption.quanta == consumption)
    s!"{label}: consumption {view.consumption.quanta}"
  expect (view.commitment.quanta == commitment)
    s!"{label}: commitment {view.commitment.quanta}"
  expect (view.headroom.quanta == headroom)
    s!"{label}: headroom {view.headroom.quanta}"

private def emptyEvents : IO EventMemory :=
  requireSome (EventMemory.ofEvents? []) "empty EventMemory"

private def emptyCorrections : IO EventCorrectionMemory :=
  requireSome (EventCorrectionMemory.ofCorrections? []) "empty correction memory"

private def emptyValidities : IO (ActualValidityMemory Nat) :=
  requireSome (ActualValidityMemory.ofEntries? []) "empty validity memory"

private def emptyTerminals : IO ScheduledTerminalMemory :=
  requireSome (ScheduledTerminalMemory.ofTerminals? []) "empty terminal memory"

private def world12 : IO Unit := do
  let scheduledOccurrence ← requireSome
    (scheduled? "scheduled-realization" 3 expense 30)
    "scheduled realization"
  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [scheduledOccurrence])
    "scheduled memory"
  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := scheduledSubject scheduledOccurrence.id expense,
         effectiveOn := (0 : Nat), purpose := some food }])
    "scheduled routing"
  let roles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [{ locus := paypay, role := .asset }, { locus := expense, role := .expense }])
    "roles"

  let foodCapacity ← requireSome (capacityMovement? "capacity-food" food 100) "food capacity"
  let booksCapacity ← requireSome (capacityMovement? "capacity-books" books 100) "books capacity"
  let capacity ← requireSome
    (CapacityMemory.ofMovements? [foodCapacity, booksCapacity])
    "capacity memory"
  let effective ← requireSome
    (CapacityEffectiveMemory.ofEntries?
      [{ movement := foodCapacity.id, effectiveOn := (2 : Nat) },
       { movement := booksCapacity.id, effectiveOn := (2 : Nat) }])
    "capacity effective"

  let events0 ← emptyEvents
  let corrections ← emptyCorrections
  let validity0 ← emptyValidities
  let terminals0 ← emptyTerminals
  let actual ← requireSome (movementEvent? "realized" expense 30) "realized Actual"
  let events1 ← requireSome (EventMemory.ofEvents? [actual]) "realized EventMemory"
  let validity1 ← requireSome
    (ActualValidityMemory.ofEntries? [{ event := actual.id, validOn := (2 : Nat) }])
    "realized validity"
  let terminals1 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := scheduledOccurrence.id, target := some (.actual actual.id) }])
    "completion terminal"

  -- W1: Scheduled and Actual interpretations agree on food.
  let actualRoutingFood ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := expense, effectiveOn := (0 : Nat), purpose := some food }])
    "food Actual routing"
  let before1 ← requireSome
    (currentCoverageAtCorrectionFrontier?
      capacity effective events0 corrections validity0 actualRoutingFood
      scheduledMemory terminals0 roles scheduledRouting
      food yen (1 : Nat) (2 : Nat) (4 : Nat))
    "W1 before"
  let after1 ← requireSome
    (currentCoverageAtCorrectionFrontier?
      capacity effective events1 corrections validity1 actualRoutingFood
      scheduledMemory terminals1 roles scheduledRouting
      food yen (1 : Nat) (2 : Nat) (4 : Nat))
    "W1 after"
  expectCoverage "W1 before" before1 100 0 30 70
  expectCoverage "W1 after" after1 100 30 0 70
  expect (before1.headroom == after1.headroom)
    "W1 equal Purpose/Measure realization did not preserve Headroom"

  -- W2: the quantity realizes exactly, but Actual routing says books instead of food.
  let actualRoutingBooks ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := expense, effectiveOn := (0 : Nat), purpose := some books }])
    "books Actual routing"
  let beforeFood ← requireSome
    (currentCoverageAtCorrectionFrontier?
      capacity effective events0 corrections validity0 actualRoutingBooks
      scheduledMemory terminals0 roles scheduledRouting
      food yen 1 2 4)
    "W2 food before"
  let afterFood ← requireSome
    (currentCoverageAtCorrectionFrontier?
      capacity effective events1 corrections validity1 actualRoutingBooks
      scheduledMemory terminals1 roles scheduledRouting
      food yen 1 2 4)
    "W2 food after"
  let beforeBooks ← requireSome
    (currentCoverageAtCorrectionFrontier?
      capacity effective events0 corrections validity0 actualRoutingBooks
      scheduledMemory terminals0 roles scheduledRouting
      books yen 1 2 4)
    "W2 books before"
  let afterBooks ← requireSome
    (currentCoverageAtCorrectionFrontier?
      capacity effective events1 corrections validity1 actualRoutingBooks
      scheduledMemory terminals1 roles scheduledRouting
      books yen 1 2 4)
    "W2 books after"
  expectCoverage "W2 food before" beforeFood 100 0 30 70
  expectCoverage "W2 food after" afterFood 100 0 0 100
  expectCoverage "W2 books before" beforeBooks 100 0 0 100
  expectCoverage "W2 books after" afterBooks 100 30 0 70
  expect (afterFood.headroom.quanta - beforeFood.headroom.quanta == 30)
    "W2 food pressure was not released"
  expect (afterBooks.headroom.quanta - beforeBooks.headroom.quanta == -30)
    "W2 books consumption did not receive the realized quantity"
  expect
    ((afterFood.headroom.quanta - beforeFood.headroom.quanta) +
      (afterBooks.headroom.quanta - beforeBooks.headroom.quanta) == 0)
    "W2 equal quantity route drift did not transfer the Headroom delta across Purposes"

private def world3 : IO Unit := do
  let old ← requireSome (movementEvent? "correction-old" expense 30) "W3 old"
  let replacement ← requireSome
    (movementEvent? "correction-replacement" booksExpense 45)
    "W3 replacement"
  let beforeEvents ← requireSome (EventMemory.ofEvents? [old]) "W3 before events"
  let afterEvents ← requireSome
    (EventMemory.ofEvents? [old, replacement]) "W3 after events"
  let noCorrections ← emptyCorrections
  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := old.id, replacement := replacement.id }])
    "W3 corrections"
  let beforeValidity ← requireSome
    (ActualValidityMemory.ofEntries? [{ event := old.id, validOn := (2 : Nat) }])
    "W3 before validity"
  let afterValidity ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := old.id, validOn := (2 : Nat) },
       { event := replacement.id, validOn := (2 : Nat) }])
    "W3 after validity"
  let routing ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := expense, effectiveOn := (0 : Nat), purpose := some food },
       { subject := booksExpense, effectiveOn := (0 : Nat), purpose := some books }])
    "W3 routing"

  let foodBefore ← requireSome
    (consumptionAtCorrectionFrontier?
      beforeEvents noCorrections beforeValidity routing food yen)
    "W3 food before"
  let foodAfter ← requireSome
    (consumptionAtCorrectionFrontier?
      afterEvents corrections afterValidity routing food yen)
    "W3 food after"
  let booksBefore ← requireSome
    (consumptionAtCorrectionFrontier?
      beforeEvents noCorrections beforeValidity routing books yen)
    "W3 books before"
  let booksAfter ← requireSome
    (consumptionAtCorrectionFrontier?
      afterEvents corrections afterValidity routing books yen)
    "W3 books after"
  let paypayBefore ← requireSome
    (quantityAtCorrectionFrontier? beforeEvents noCorrections paypay yen)
    "W3 paypay before"
  let paypayAfter ← requireSome
    (quantityAtCorrectionFrontier? afterEvents corrections paypay yen)
    "W3 paypay after"

  expect (foodBefore.quanta == 30 && foodAfter.quanta == 0)
    "W3 food projection did not follow replacement classification"
  expect (booksBefore.quanta == 0 && booksAfter.quanta == 45)
    "W3 books projection did not follow replacement classification"
  expect (paypayBefore.quanta == -30 && paypayAfter.quanta == -45)
    "W3 physical quantity did not follow replacement frontier"
  expect (foodAfter.quanta - foodBefore.quanta == -30)
    "W3 food delta"
  expect (booksAfter.quanta - booksBefore.quanta == 45)
    "W3 books delta"
  expect (paypayAfter.quanta - paypayBefore.quanta == -15)
    "W3 physical delta"

private def world4 : IO Unit := do
  let old ← requireSome (oneEffectEvent? "anchor-old-root" debt (-40)) "W4 old"
  let replacement ← requireSome
    (oneEffectEvent? "anchor-replacement" debt (-50)) "W4 replacement"
  let later ← requireSome (oneEffectEvent? "anchor-later-root" debt 10) "W4 later"
  let events0 ← requireSome (EventMemory.ofEvents? [old, later]) "W4 events0"
  let events1 ← requireSome
    (EventMemory.ofEvents? [old, replacement, later]) "W4 events1"
  let corrections0 ← emptyCorrections
  let corrections1 ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := old.id, replacement := replacement.id }])
    "W4 corrections"
  let coordinate : EffectCoordinate := ⟨debt, yen⟩
  let anchor ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists?
      [old.id] [{ coordinate := coordinate, quantity := q (-70) }])
    "W4 anchor"

  let frontier0 ← requireSome
    (quantityAtCorrectionFrontier? events0 corrections0 debt yen)
    "W4 frontier0"
  let frontier1 ← requireSome
    (quantityAtCorrectionFrontier? events1 corrections1 debt yen)
    "W4 frontier1"
  let some anchored0 ← requireOk
    (Loam.CurrentQuantityAnchor.inspectQuantity events0 corrections0 anchor coordinate)
    "W4 anchor0"
    | throw (IO.userError "W4 anchor0 absent")
  let some anchored1 ← requireOk
    (Loam.CurrentQuantityAnchor.inspectQuantity events1 corrections1 anchor coordinate)
    "W4 anchor1"
    | throw (IO.userError "W4 anchor1 absent")

  expect (frontier0.quanta == -30 && frontier1.quanta == -40)
    "W4 correction frontier did not change by replacement delta"
  expect (anchored0.quanta == -60 && anchored1.quanta == -60)
    "W4 reflected-root correction rewrote the observed current quantity"
  expect (frontier1.quanta != frontier0.quanta && anchored1 == anchored0)
    "W4 did not separate corrected history from observed present"

private def world5 : IO Unit := do
  let opening ← requireSome
    (oneEffectEvent? "opening-witness" debt (-100)) "W5 opening"
  let replacement ← requireSome
    (oneEffectEvent? "opening-replacement" debt (-120)) "W5 replacement"
  let events0 ← requireSome (EventMemory.ofEvents? [opening]) "W5 events0"
  let events1 ← requireSome
    (EventMemory.ofEvents? [opening, replacement]) "W5 events1"
  let corrections0 ← emptyCorrections
  let corrections1 ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := opening.id, replacement := replacement.id }])
    "W5 corrections"
  let coordinate : EffectCoordinate := ⟨debt, yen⟩
  let openingSupport ← requireSome
    (OpeningSupportMap.ofSupports?
      [{ coordinate := coordinate, openingEvent := opening.id }])
    "W5 opening support"
  let roles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [{ locus := debt, role := .liability }])
    "W5 roles"
  let anchor := Loam.CurrentQuantityAnchor.Evidence.empty
  let evidence0 : Loam.BalanceReview.Evidence :=
    { events := events0, corrections := corrections0, coverage := ZeroOriginCoverage.empty }
  let evidence1 : Loam.BalanceReview.Evidence :=
    { events := events1, corrections := corrections1, coverage := ZeroOriginCoverage.empty }

  let before ← requireOk
    (Loam.RoleBalanceReview.project evidence0 openingSupport anchor roles)
    "W5 before"
  let some debtRow := before.rows.find? fun row => row.coordinate = coordinate
    | throw (IO.userError "W5 opening-supported row missing before correction")
  expect (debtRow.quantity.quanta == -100)
    "W5 opening-supported quantity before correction"
  expect
    (match Loam.RoleBalanceReview.project evidence1 openingSupport anchor roles with
      | .error _ => true
      | .ok _ => false)
    "W5 stale opening witness was silently followed through correction"


def main : IO Unit := do
  world12
  world3
  world4
  world5
  IO.println
    "Counterpoint five worlds: realization transfer, route drift, correction propagation, reflected-root stability, and stale opening refusal passed."
