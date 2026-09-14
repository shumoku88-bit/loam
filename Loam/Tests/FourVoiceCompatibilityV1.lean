import Loam.Application.CurrentCoverageInspection

open Loam.Core
open Loam.Application

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def yen : MeasureId := ⟨"jpy"⟩
private def food : PurposeId := ⟨"food"⟩
private def books : PurposeId := ⟨"books"⟩
private def paypay : LocusId := ⟨"paypay"⟩
private def foodA : LocusId := ⟨"food-a"⟩
private def foodB : LocusId := ⟨"food-b"⟩
private def foodC : LocusId := ⟨"food-c"⟩
private def booksExpense : LocusId := ⟨"books-expense"⟩

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

private def scheduledSingle?
    (id : String) (day : Nat) (destination : LocusId) (amount : Int) :
    Option (ScheduledOccurrence Nat) := do
  let movement ← BalancedMovement.ofChanges? yen
    [change paypay (-amount), change destination amount]
  pure { id := ⟨id⟩, scheduledOn := day, movement := movement }

private def scheduledSplit?
    (id : String) (day : Nat) : Option (ScheduledOccurrence Nat) := do
  let movement ← BalancedMovement.ofChanges? yen
    [change paypay (-30), change foodA 10, change foodB 20]
  pure { id := ⟨id⟩, scheduledOn := day, movement := movement }

private def event? (id : String) (effects : List (LocusId × Int)) : Option Event :=
  Event.ofEffects? ⟨id⟩ <|
    effects.map fun (locus, amount) =>
      Effect.ofAnonymousQuantity locus yen (q amount)

private def subject (scheduled : ScheduledId) (locus : LocusId) : ScheduledRoutingSubject :=
  { scheduled := scheduled, locus := locus }

private def emptyEvents : IO EventMemory :=
  requireSome (EventMemory.ofEvents? []) "empty events"

private def emptyCorrections : IO EventCorrectionMemory :=
  requireSome (EventCorrectionMemory.ofCorrections? []) "empty corrections"

private def emptyValidities : IO (ActualValidityMemory Nat) :=
  requireSome (ActualValidityMemory.ofEntries? []) "empty validities"

private def emptyTerminals : IO ScheduledTerminalMemory :=
  requireSome (ScheduledTerminalMemory.ofTerminals? []) "empty terminals"

private def roles : IO AccountingRoleMap :=
  requireSome
    (AccountingRoleMap.ofAssignments?
      [ { locus := paypay, role := .asset }
      , { locus := foodA, role := .expense }
      , { locus := foodB, role := .expense }
      , { locus := foodC, role := .expense }
      , { locus := booksExpense, role := .expense } ])
    "roles"

private def capacity : IO (CapacityMemory × CapacityEffectiveMemory Nat) := do
  let foodCapacity ← requireSome (capacityMovement? "capacity-food" food 100) "food capacity"
  let booksCapacity ← requireSome (capacityMovement? "capacity-books" books 100) "books capacity"
  let memory ← requireSome
    (CapacityMemory.ofMovements? [foodCapacity, booksCapacity]) "capacity memory"
  let effective ← requireSome
    (CapacityEffectiveMemory.ofEntries?
      [ { movement := foodCapacity.id, effectiveOn := (2 : Nat) }
      , { movement := booksCapacity.id, effectiveOn := (2 : Nat) } ])
    "capacity effective"
  pure (memory, effective)

private def actualRouting : IO (RoutingHistory LocusId Nat) :=
  requireSome
    (RoutingHistory.ofEntries?
      [ { subject := foodA, effectiveOn := (0 : Nat), purpose := some food }
      , { subject := foodB, effectiveOn := (0 : Nat), purpose := some food }
      , { subject := foodC, effectiveOn := (0 : Nat), purpose := some food }
      , { subject := booksExpense, effectiveOn := (0 : Nat), purpose := some books } ])
    "Actual routing"

private def coverage?
    (capacity : CapacityMemory)
    (effective : CapacityEffectiveMemory Nat)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory Nat)
    (actualRouting : RoutingHistory LocusId Nat)
    (scheduled : ScheduledMemory Nat)
    (terminals : ScheduledTerminalMemory)
    (roles : AccountingRoleMap)
    (scheduledRouting : RoutingHistory ScheduledRoutingSubject Nat)
    (purpose : PurposeId) : Option CurrentCoverageView :=
  currentCoverageAtCorrectionFrontier?
    capacity effective events corrections validities actualRouting
    scheduled terminals roles scheduledRouting
    purpose yen (1 : Nat) (2 : Nat) (4 : Nat)

private def expectHeadroom
    (label : String) (view : CurrentCoverageView)
    (consumption commitment headroom : Int) : IO Unit := do
  expect (view.entitlement.quanta == 100) s!"{label}: entitlement"
  expect (view.consumption.quanta == consumption) s!"{label}: consumption"
  expect (view.commitment.quanta == commitment) s!"{label}: commitment"
  expect (view.headroom.quanta == headroom) s!"{label}: headroom"

/-- V1a: split physical loci can differ while Purpose/Measure pressure transfers exactly. -/
private def splitLocusWorld : IO Unit := do
  let (capacity, effective) ← capacity
  let roles ← roles
  let actualRouting ← actualRouting
  let scheduled ← requireSome (scheduledSplit? "split-scheduled" 3) "split Scheduled"
  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [scheduled]) "split Scheduled memory"
  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [ { subject := subject scheduled.id foodA, effectiveOn := (0 : Nat), purpose := some food }
      , { subject := subject scheduled.id foodB, effectiveOn := (0 : Nat), purpose := some food } ])
    "split Scheduled routing"
  let events0 ← emptyEvents
  let validities0 ← emptyValidities
  let terminals0 ← emptyTerminals
  let corrections ← emptyCorrections
  let actual ← requireSome
    (event? "split-realized" [(paypay, -30), (foodC, 30)]) "split Actual"
  let events1 ← requireSome (EventMemory.ofEvents? [actual]) "split events"
  let validities1 ← requireSome
    (ActualValidityMemory.ofEntries? [{ event := actual.id, validOn := (2 : Nat) }])
    "split validity"
  let terminals1 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := scheduled.id, target := some (.actual actual.id) }])
    "split completion"
  let before ← requireSome
    (coverage? capacity effective events0 corrections validities0 actualRouting
      scheduledMemory terminals0 roles scheduledRouting food)
    "split before"
  let after ← requireSome
    (coverage? capacity effective events1 corrections validities1 actualRouting
      scheduledMemory terminals1 roles scheduledRouting food)
    "split after"
  expectHeadroom "split before" before 0 30 70
  expectHeadroom "split after" after 30 0 70
  expect (before.headroom == after.headroom) "split loci changed Headroom"
  expect (scheduled.quantityAt foodA != actual.quantityAt foodA yen)
    "split fixture accidentally preserved physical locus shape"

/-- V1b: extra physical movement outside the queried Purpose does not disturb local Headroom. -/
private def extraPhysicalWorld : IO Unit := do
  let (capacity, effective) ← capacity
  let roles ← roles
  let actualRouting ← actualRouting
  let scheduled ← requireSome
    (scheduledSingle? "extra-scheduled" 3 foodC 30) "extra Scheduled"
  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [scheduled]) "extra Scheduled memory"
  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := subject scheduled.id foodC, effectiveOn := (0 : Nat), purpose := some food }])
    "extra Scheduled routing"
  let events0 ← emptyEvents
  let validities0 ← emptyValidities
  let terminals0 ← emptyTerminals
  let corrections ← emptyCorrections
  let actual ← requireSome
    (event? "extra-realized"
      [(paypay, -37), (foodC, 30), (booksExpense, 7)])
    "extra Actual"
  let events1 ← requireSome (EventMemory.ofEvents? [actual]) "extra events"
  let validities1 ← requireSome
    (ActualValidityMemory.ofEntries? [{ event := actual.id, validOn := (2 : Nat) }])
    "extra validity"
  let terminals1 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := scheduled.id, target := some (.actual actual.id) }])
    "extra completion"
  let before ← requireSome
    (coverage? capacity effective events0 corrections validities0 actualRouting
      scheduledMemory terminals0 roles scheduledRouting food)
    "extra before"
  let after ← requireSome
    (coverage? capacity effective events1 corrections validities1 actualRouting
      scheduledMemory terminals1 roles scheduledRouting food)
    "extra after"
  expectHeadroom "extra before" before 0 30 70
  expectHeadroom "extra after" after 30 0 70
  expect (before.headroom == after.headroom) "extra movement changed food Headroom"
  expect (scheduled.quantityAt paypay != actual.quantityAt paypay yen)
    "extra fixture accidentally preserved whole physical movement"

/-- V1c: an equal raw realization outside the elapsed Actual window does not preserve Headroom. -/
private def timeMismatchWorld : IO Unit := do
  let (capacity, effective) ← capacity
  let roles ← roles
  let actualRouting ← actualRouting
  let scheduled ← requireSome
    (scheduledSingle? "time-scheduled" 3 foodC 30) "time Scheduled"
  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [scheduled]) "time Scheduled memory"
  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := subject scheduled.id foodC, effectiveOn := (0 : Nat), purpose := some food }])
    "time Scheduled routing"
  let events0 ← emptyEvents
  let validities0 ← emptyValidities
  let terminals0 ← emptyTerminals
  let corrections ← emptyCorrections
  let actual ← requireSome
    (event? "time-realized" [(paypay, -30), (foodC, 30)]) "time Actual"
  let events1 ← requireSome (EventMemory.ofEvents? [actual]) "time events"
  let validities1 ← requireSome
    (ActualValidityMemory.ofEntries? [{ event := actual.id, validOn := (3 : Nat) }])
    "future validity"
  let terminals1 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := scheduled.id, target := some (.actual actual.id) }])
    "time completion"
  let before ← requireSome
    (coverage? capacity effective events0 corrections validities0 actualRouting
      scheduledMemory terminals0 roles scheduledRouting food)
    "time before"
  let after ← requireSome
    (coverage? capacity effective events1 corrections validities1 actualRouting
      scheduledMemory terminals1 roles scheduledRouting food)
    "time after"
  expectHeadroom "time before" before 0 30 70
  expectHeadroom "time after" after 0 0 100
  expect (before.headroom != after.headroom)
    "future-valid raw realization incorrectly preserved current Headroom"

/-- V1d: the current correction-frontier contribution, not the raw completion Event, controls Headroom. -/
private def correctionWorld : IO Unit := do
  let (capacity, effective) ← capacity
  let roles ← roles
  let actualRouting ← actualRouting
  let scheduled ← requireSome
    (scheduledSingle? "correction-scheduled" 3 foodC 30) "correction Scheduled"
  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [scheduled]) "correction Scheduled memory"
  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := subject scheduled.id foodC, effectiveOn := (0 : Nat), purpose := some food }])
    "correction Scheduled routing"
  let events0 ← emptyEvents
  let validities0 ← emptyValidities
  let terminals0 ← emptyTerminals
  let corrections0 ← emptyCorrections
  let actual ← requireSome
    (event? "correction-realized" [(paypay, -30), (foodC, 30)]) "raw realized Actual"
  let replacement ← requireSome
    (event? "correction-replacement" [(paypay, -35), (foodC, 35)]) "replacement Actual"
  let events1 ← requireSome
    (EventMemory.ofEvents? [actual, replacement]) "correction events"
  let validities1 ← requireSome
    (ActualValidityMemory.ofEntries?
      [ { event := actual.id, validOn := (2 : Nat) }
      , { event := replacement.id, validOn := (2 : Nat) } ])
    "correction validities"
  let corrections1 ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := actual.id, replacement := replacement.id }])
    "correction frontier"
  let terminals1 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := scheduled.id, target := some (.actual actual.id) }])
    "correction completion"
  let before ← requireSome
    (coverage? capacity effective events0 corrections0 validities0 actualRouting
      scheduledMemory terminals0 roles scheduledRouting food)
    "correction before"
  let after ← requireSome
    (coverage? capacity effective events1 corrections1 validities1 actualRouting
      scheduledMemory terminals1 roles scheduledRouting food)
    "correction after"
  expectHeadroom "correction before" before 0 30 70
  expectHeadroom "correction after" after 35 0 65
  expect (scheduled.quantityAt foodC == actual.quantityAt foodC yen)
    "raw completion Event no longer matches Scheduled quantity"
  expect (before.headroom != after.headroom)
    "raw equality incorrectly overrode the current correction frontier"

def main : IO Unit := do
  splitLocusWorld
  extraPhysicalWorld
  timeMismatchWorld
  correctionWorld
  IO.println
    "Four-voice V1: Headroom invariance tracks Purpose/Measure pressure transfer, not whole-event exactness; time and the current correction frontier remain independent conditions."
