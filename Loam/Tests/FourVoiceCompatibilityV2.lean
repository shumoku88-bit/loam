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
private def sharedExpense : LocusId := ⟨"shared-expense"⟩
private def foodA : LocusId := ⟨"food-a"⟩
private def foodB : LocusId := ⟨"food-b"⟩

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
      , { locus := sharedExpense, role := .expense }
      , { locus := foodA, role := .expense }
      , { locus := foodB, role := .expense } ])
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

private def expectCoverage
    (label : String) (view : CurrentCoverageView)
    (consumption commitment headroom : Int) : IO Unit := do
  expect (view.entitlement.quanta == 100) s!"{label}: entitlement"
  expect (view.consumption.quanta == consumption) s!"{label}: consumption"
  expect (view.commitment.quanta == commitment) s!"{label}: commitment"
  expect (view.headroom.quanta == headroom) s!"{label}: headroom"

/--
V2a: even identical physical shape and exact quantity do not imply identical
Purpose interpretation. Scheduled and Actual routing are separate authorities.
-/
private def samePhysicalDifferentPurpose : IO Unit := do
  let (capacity, effective) ← capacity
  let roles ← roles
  let scheduled ← requireSome
    (scheduledSingle? "same-physical-scheduled" 3 sharedExpense 30)
    "same physical Scheduled"
  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [scheduled]) "same physical Scheduled memory"
  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := subject scheduled.id sharedExpense,
         effectiveOn := (0 : Nat), purpose := some food }])
    "same physical Scheduled routing"
  let actualRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := sharedExpense,
         effectiveOn := (0 : Nat), purpose := some books }])
    "same physical Actual routing"
  let events0 ← emptyEvents
  let validities0 ← emptyValidities
  let terminals0 ← emptyTerminals
  let corrections ← emptyCorrections
  let actual ← requireSome
    (event? "same-physical-actual" [(paypay, -30), (sharedExpense, 30)])
    "same physical Actual"
  let events1 ← requireSome (EventMemory.ofEvents? [actual]) "same physical events"
  let validities1 ← requireSome
    (ActualValidityMemory.ofEntries? [{ event := actual.id, validOn := (2 : Nat) }])
    "same physical validity"
  let terminals1 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := scheduled.id, target := some (.actual actual.id) }])
    "same physical completion"

  let foodBefore ← requireSome
    (coverage? capacity effective events0 corrections validities0 actualRouting
      scheduledMemory terminals0 roles scheduledRouting food)
    "same physical food before"
  let foodAfter ← requireSome
    (coverage? capacity effective events1 corrections validities1 actualRouting
      scheduledMemory terminals1 roles scheduledRouting food)
    "same physical food after"
  let booksBefore ← requireSome
    (coverage? capacity effective events0 corrections validities0 actualRouting
      scheduledMemory terminals0 roles scheduledRouting books)
    "same physical books before"
  let booksAfter ← requireSome
    (coverage? capacity effective events1 corrections validities1 actualRouting
      scheduledMemory terminals1 roles scheduledRouting books)
    "same physical books after"

  expectCoverage "V2a food before" foodBefore 0 30 70
  expectCoverage "V2a food after" foodAfter 0 0 100
  expectCoverage "V2a books before" booksBefore 0 0 100
  expectCoverage "V2a books after" booksAfter 30 0 70
  expect (scheduled.quantityAt sharedExpense == actual.quantityAt sharedExpense yen)
    "V2a fixture lost physical quantity equality"
  expect
    (scheduledRouting.statusAt (subject scheduled.id sharedExpense) (2 : Nat) = .managed food)
    "V2a Scheduled interpretation"
  expect (actualRouting.statusAt sharedExpense (2 : Nat) = .managed books)
    "V2a Actual interpretation"
  expect
    ((foodAfter.headroom.quanta - foodBefore.headroom.quanta) +
      (booksAfter.headroom.quanta - booksBefore.headroom.quanta) == 0)
    "V2a Purpose-local deltas did not transfer equally"

/--
V2b: aggregate Purpose deltas can look like a transfer even when there is no
retained coordinate-level correspondence from Scheduled subjects to Actual Effects.
-/
private def splitAmbiguousCorrespondence : IO Unit := do
  let (capacity, effective) ← capacity
  let roles ← roles
  let scheduled ← requireSome
    (scheduledSplit? "split-meaning-scheduled" 3) "split meaning Scheduled"
  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [scheduled]) "split meaning Scheduled memory"
  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [ { subject := subject scheduled.id foodA,
          effectiveOn := (0 : Nat), purpose := some food }
      , { subject := subject scheduled.id foodB,
          effectiveOn := (0 : Nat), purpose := some books } ])
    "split meaning Scheduled routing"
  let actualRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := sharedExpense,
         effectiveOn := (0 : Nat), purpose := some books }])
    "split meaning Actual routing"
  let events0 ← emptyEvents
  let validities0 ← emptyValidities
  let terminals0 ← emptyTerminals
  let corrections ← emptyCorrections
  let actual ← requireSome
    (event? "split-meaning-actual" [(paypay, -30), (sharedExpense, 30)])
    "split meaning Actual"
  let events1 ← requireSome (EventMemory.ofEvents? [actual]) "split meaning events"
  let validities1 ← requireSome
    (ActualValidityMemory.ofEntries? [{ event := actual.id, validOn := (2 : Nat) }])
    "split meaning validity"
  let terminals1 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := scheduled.id, target := some (.actual actual.id) }])
    "split meaning completion"

  let foodBefore ← requireSome
    (coverage? capacity effective events0 corrections validities0 actualRouting
      scheduledMemory terminals0 roles scheduledRouting food)
    "split meaning food before"
  let foodAfter ← requireSome
    (coverage? capacity effective events1 corrections validities1 actualRouting
      scheduledMemory terminals1 roles scheduledRouting food)
    "split meaning food after"
  let booksBefore ← requireSome
    (coverage? capacity effective events0 corrections validities0 actualRouting
      scheduledMemory terminals0 roles scheduledRouting books)
    "split meaning books before"
  let booksAfter ← requireSome
    (coverage? capacity effective events1 corrections validities1 actualRouting
      scheduledMemory terminals1 roles scheduledRouting books)
    "split meaning books after"

  expectCoverage "V2b food before" foodBefore 0 10 90
  expectCoverage "V2b food after" foodAfter 0 0 100
  expectCoverage "V2b books before" booksBefore 0 20 80
  expectCoverage "V2b books after" booksAfter 30 0 70
  expect (scheduled.quantityAt foodA == q 10 && scheduled.quantityAt foodB == q 20)
    "V2b Scheduled split changed"
  expect
    (actual.quantityAt foodA yen == 0 && actual.quantityAt foodB yen == 0 &&
      actual.quantityAt sharedExpense yen == q 30)
    "V2b Actual unexpectedly retained Scheduled coordinate shape"
  expect
    ((foodAfter.headroom.quanta - foodBefore.headroom.quanta) == 10 &&
      (booksAfter.headroom.quanta - booksBefore.headroom.quanta) == -10)
    "V2b aggregate Purpose deltas"

/--
V2c: completion plus exact physical quantity does not guarantee a comparable
Actual Purpose at all. An unrouted Actual remains a separate missing interpretation,
not evidence of reclassification.
-/
private def missingActualInterpretation : IO Unit := do
  let (capacity, effective) ← capacity
  let roles ← roles
  let scheduled ← requireSome
    (scheduledSingle? "unrouted-scheduled" 3 sharedExpense 30)
    "unrouted Scheduled"
  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [scheduled]) "unrouted Scheduled memory"
  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := subject scheduled.id sharedExpense,
         effectiveOn := (0 : Nat), purpose := some food }])
    "unrouted Scheduled routing"
  let actualRouting ← requireSome
    (RoutingHistory.ofEntries? ([] : List (RoutingEntry LocusId Nat)))
    "empty Actual routing"
  let events0 ← emptyEvents
  let validities0 ← emptyValidities
  let terminals0 ← emptyTerminals
  let corrections ← emptyCorrections
  let actual ← requireSome
    (event? "unrouted-actual" [(paypay, -30), (sharedExpense, 30)])
    "unrouted Actual"
  let events1 ← requireSome (EventMemory.ofEvents? [actual]) "unrouted events"
  let validities1 ← requireSome
    (ActualValidityMemory.ofEntries? [{ event := actual.id, validOn := (2 : Nat) }])
    "unrouted validity"
  let terminals1 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := scheduled.id, target := some (.actual actual.id) }])
    "unrouted completion"

  let foodBefore ← requireSome
    (coverage? capacity effective events0 corrections validities0 actualRouting
      scheduledMemory terminals0 roles scheduledRouting food)
    "unrouted food before"
  let foodAfter ← requireSome
    (coverage? capacity effective events1 corrections validities1 actualRouting
      scheduledMemory terminals1 roles scheduledRouting food)
    "unrouted food after"
  let booksAfter ← requireSome
    (coverage? capacity effective events1 corrections validities1 actualRouting
      scheduledMemory terminals1 roles scheduledRouting books)
    "unrouted books after"

  expectCoverage "V2c food before" foodBefore 0 30 70
  expectCoverage "V2c food after" foodAfter 0 0 100
  expectCoverage "V2c books after" booksAfter 0 0 100
  expect (scheduled.quantityAt sharedExpense == actual.quantityAt sharedExpense yen)
    "V2c fixture lost exact physical quantity"
  expect (actualRouting.statusAt sharedExpense (2 : Nat) = .unrouted)
    "V2c Actual unexpectedly acquired a Purpose"


def main : IO Unit := do
  samePhysicalDifferentPurpose
  splitAmbiguousCorrespondence
  missingActualInterpretation
  IO.println
    "Four-voice V2: equal quantity plus realization can coexist with divergent or missing Purpose interpretation; aggregate Purpose deltas do not establish a retained reclassification mapping."
