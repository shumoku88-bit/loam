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
      , { locus := foodC, role := .expense } ])
    "roles"

private def capacity : IO (CapacityMemory × CapacityEffectiveMemory Nat) := do
  let foodCapacity ← requireSome (capacityMovement? "capacity-food" food 100) "food capacity"
  let memory ← requireSome
    (CapacityMemory.ofMovements? [foodCapacity]) "capacity memory"
  let effective ← requireSome
    (CapacityEffectiveMemory.ofEntries?
      [{ movement := foodCapacity.id, effectiveOn := (2 : Nat) }])
    "capacity effective"
  pure (memory, effective)

private def actualRoutingFood : IO (RoutingHistory LocusId Nat) :=
  requireSome
    (RoutingHistory.ofEntries?
      [ { subject := foodA, effectiveOn := (0 : Nat), purpose := some food }
      , { subject := foodB, effectiveOn := (0 : Nat), purpose := some food }
      , { subject := foodC, effectiveOn := (0 : Nat), purpose := some food } ])
    "Actual food routing"

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
    (scheduledRouting : RoutingHistory ScheduledRoutingSubject Nat) : Option CurrentCoverageView :=
  currentCoverageAtCorrectionFrontier?
    capacity effective events corrections validities actualRouting
    scheduled terminals roles scheduledRouting
    food yen (1 : Nat) (2 : Nat) (4 : Nat)

private def expectCoverage
    (label : String) (view : CurrentCoverageView)
    (consumption commitment headroom : Int) : IO Unit := do
  expect (view.entitlement.quanta == 100) s!"{label}: entitlement"
  expect (view.consumption.quanta == consumption) s!"{label}: consumption"
  expect (view.commitment.quanta == commitment) s!"{label}: commitment"
  expect (view.headroom.quanta == headroom) s!"{label}: headroom"

private def expectedDelta
    (before after : CurrentCoverageView) : Int :=
  before.commitment.quanta - after.commitment.quanta -
    (after.consumption.quanta - before.consumption.quanta)

/-- V3a: under-realization releases exactly the unmatched local pressure. -/
private def underRealization : IO Unit := do
  let (capacity, effective) ← capacity
  let roles ← roles
  let actualRouting ← actualRoutingFood
  let scheduled ← requireSome
    (scheduledSingle? "under-scheduled" 3 foodC 30) "under Scheduled"
  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [scheduled]) "under Scheduled memory"
  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := subject scheduled.id foodC,
         effectiveOn := (0 : Nat), purpose := some food }])
    "under Scheduled routing"
  let events0 ← emptyEvents
  let validities0 ← emptyValidities
  let terminals0 ← emptyTerminals
  let corrections ← emptyCorrections
  let actual ← requireSome
    (event? "under-actual" [(paypay, -27), (foodC, 27)]) "under Actual"
  let events1 ← requireSome (EventMemory.ofEvents? [actual]) "under events"
  let validities1 ← requireSome
    (ActualValidityMemory.ofEntries? [{ event := actual.id, validOn := (2 : Nat) }])
    "under validity"
  let terminals1 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := scheduled.id, target := some (.actual actual.id) }])
    "under completion"
  let before ← requireSome
    (coverage? capacity effective events0 corrections validities0 actualRouting
      scheduledMemory terminals0 roles scheduledRouting)
    "under before"
  let after ← requireSome
    (coverage? capacity effective events1 corrections validities1 actualRouting
      scheduledMemory terminals1 roles scheduledRouting)
    "under after"
  expectCoverage "V3a before" before 0 30 70
  expectCoverage "V3a after" after 27 0 73
  expect (after.headroom.quanta - before.headroom.quanta == 3)
    "V3a under-realization delta"
  expect (after.headroom.quanta - before.headroom.quanta == expectedDelta before after)
    "V3a Headroom delta did not equal removed Commitment minus added Consumption"

/-- V3b: over-realization consumes exactly the excess beyond removed Commitment. -/
private def overRealization : IO Unit := do
  let (capacity, effective) ← capacity
  let roles ← roles
  let actualRouting ← actualRoutingFood
  let scheduled ← requireSome
    (scheduledSingle? "over-scheduled" 3 foodC 30) "over Scheduled"
  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [scheduled]) "over Scheduled memory"
  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := subject scheduled.id foodC,
         effectiveOn := (0 : Nat), purpose := some food }])
    "over Scheduled routing"
  let events0 ← emptyEvents
  let validities0 ← emptyValidities
  let terminals0 ← emptyTerminals
  let corrections ← emptyCorrections
  let actual ← requireSome
    (event? "over-actual" [(paypay, -35), (foodC, 35)]) "over Actual"
  let events1 ← requireSome (EventMemory.ofEvents? [actual]) "over events"
  let validities1 ← requireSome
    (ActualValidityMemory.ofEntries? [{ event := actual.id, validOn := (2 : Nat) }])
    "over validity"
  let terminals1 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := scheduled.id, target := some (.actual actual.id) }])
    "over completion"
  let before ← requireSome
    (coverage? capacity effective events0 corrections validities0 actualRouting
      scheduledMemory terminals0 roles scheduledRouting)
    "over before"
  let after ← requireSome
    (coverage? capacity effective events1 corrections validities1 actualRouting
      scheduledMemory terminals1 roles scheduledRouting)
    "over after"
  expectCoverage "V3b before" before 0 30 70
  expectCoverage "V3b after" after 35 0 65
  expect (after.headroom.quanta - before.headroom.quanta == -5)
    "V3b over-realization delta"
  expect (after.headroom.quanta - before.headroom.quanta == expectedDelta before after)
    "V3b Headroom delta did not equal removed Commitment minus added Consumption"

/-- V3c: split Scheduled shape does not disturb the quantity-delta law. -/
private def splitUnderRealization : IO Unit := do
  let (capacity, effective) ← capacity
  let roles ← roles
  let actualRouting ← actualRoutingFood
  let scheduled ← requireSome
    (scheduledSplit? "split-under-scheduled" 3) "split under Scheduled"
  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [scheduled]) "split under Scheduled memory"
  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [ { subject := subject scheduled.id foodA,
          effectiveOn := (0 : Nat), purpose := some food }
      , { subject := subject scheduled.id foodB,
          effectiveOn := (0 : Nat), purpose := some food } ])
    "split under Scheduled routing"
  let events0 ← emptyEvents
  let validities0 ← emptyValidities
  let terminals0 ← emptyTerminals
  let corrections ← emptyCorrections
  let actual ← requireSome
    (event? "split-under-actual" [(paypay, -27), (foodC, 27)])
    "split under Actual"
  let events1 ← requireSome (EventMemory.ofEvents? [actual]) "split under events"
  let validities1 ← requireSome
    (ActualValidityMemory.ofEntries? [{ event := actual.id, validOn := (2 : Nat) }])
    "split under validity"
  let terminals1 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := scheduled.id, target := some (.actual actual.id) }])
    "split under completion"
  let before ← requireSome
    (coverage? capacity effective events0 corrections validities0 actualRouting
      scheduledMemory terminals0 roles scheduledRouting)
    "split under before"
  let after ← requireSome
    (coverage? capacity effective events1 corrections validities1 actualRouting
      scheduledMemory terminals1 roles scheduledRouting)
    "split under after"
  expectCoverage "V3c before" before 0 30 70
  expectCoverage "V3c after" after 27 0 73
  expect (scheduled.quantityAt foodA == q 10 && scheduled.quantityAt foodB == q 20)
    "V3c Scheduled split changed"
  expect (actual.quantityAt foodA yen == 0 && actual.quantityAt foodB yen == 0)
    "V3c Actual unexpectedly preserved Scheduled locus shape"
  expect (after.headroom.quanta - before.headroom.quanta == expectedDelta before after)
    "V3c split shape broke quantity-delta law"

/--
V3d: correction replaces the raw completion quantity for the current answer.
The delta law follows the correction-frontier contribution, not the raw target.
-/
private def correctionChangesRealizedQuantity : IO Unit := do
  let (capacity, effective) ← capacity
  let roles ← roles
  let actualRouting ← actualRoutingFood
  let scheduled ← requireSome
    (scheduledSingle? "correction-v3-scheduled" 3 foodC 30) "V3 correction Scheduled"
  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [scheduled]) "V3 correction Scheduled memory"
  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := subject scheduled.id foodC,
         effectiveOn := (0 : Nat), purpose := some food }])
    "V3 correction Scheduled routing"
  let events0 ← emptyEvents
  let validities0 ← emptyValidities
  let terminals0 ← emptyTerminals
  let corrections0 ← emptyCorrections
  let raw ← requireSome
    (event? "correction-v3-raw" [(paypay, -27), (foodC, 27)]) "V3 raw Actual"
  let replacement ← requireSome
    (event? "correction-v3-replacement" [(paypay, -24), (foodC, 24)])
    "V3 replacement Actual"
  let events1 ← requireSome
    (EventMemory.ofEvents? [raw, replacement]) "V3 correction events"
  let validities1 ← requireSome
    (ActualValidityMemory.ofEntries?
      [ { event := raw.id, validOn := (2 : Nat) }
      , { event := replacement.id, validOn := (2 : Nat) } ])
    "V3 correction validities"
  let corrections1 ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := raw.id, replacement := replacement.id }])
    "V3 correction frontier"
  let terminals1 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := scheduled.id, target := some (.actual raw.id) }])
    "V3 correction completion"
  let before ← requireSome
    (coverage? capacity effective events0 corrections0 validities0 actualRouting
      scheduledMemory terminals0 roles scheduledRouting)
    "V3 correction before"
  let after ← requireSome
    (coverage? capacity effective events1 corrections1 validities1 actualRouting
      scheduledMemory terminals1 roles scheduledRouting)
    "V3 correction after"
  expectCoverage "V3d before" before 0 30 70
  expectCoverage "V3d after" after 24 0 76
  expect (raw.quantityAt foodC yen == q 27 && replacement.quantityAt foodC yen == q 24)
    "V3d correction quantities"
  expect (after.headroom.quanta - before.headroom.quanta == 6)
    "V3d current delta did not follow replacement quantity"
  expect (after.headroom.quanta - before.headroom.quanta == expectedDelta before after)
    "V3d correction frontier broke quantity-delta law"

/--
V3e: later routing history does not retroactively change an Actual whose valid
coordinate precedes that routing change. Quantity comparison uses valid-time meaning.
-/
private def laterRoutingDoesNotRewritePastMeaning : IO Unit := do
  let (capacity, effective) ← capacity
  let roles ← roles
  let actualRouting ← requireSome
    (RoutingHistory.ofEntries?
      [ { subject := foodC, effectiveOn := (0 : Nat), purpose := some food }
      , { subject := foodC, effectiveOn := (3 : Nat), purpose := some books } ])
    "V3 historical Actual routing"
  let scheduled ← requireSome
    (scheduledSingle? "routing-v3-scheduled" 3 foodC 30) "V3 routing Scheduled"
  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [scheduled]) "V3 routing Scheduled memory"
  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := subject scheduled.id foodC,
         effectiveOn := (0 : Nat), purpose := some food }])
    "V3 routing Scheduled routing"
  let events0 ← emptyEvents
  let validities0 ← emptyValidities
  let terminals0 ← emptyTerminals
  let corrections ← emptyCorrections
  let actual ← requireSome
    (event? "routing-v3-actual" [(paypay, -27), (foodC, 27)]) "V3 routing Actual"
  let events1 ← requireSome (EventMemory.ofEvents? [actual]) "V3 routing events"
  let validities1 ← requireSome
    (ActualValidityMemory.ofEntries? [{ event := actual.id, validOn := (2 : Nat) }])
    "V3 routing validity"
  let terminals1 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := scheduled.id, target := some (.actual actual.id) }])
    "V3 routing completion"
  let before ← requireSome
    (coverage? capacity effective events0 corrections validities0 actualRouting
      scheduledMemory terminals0 roles scheduledRouting)
    "V3 routing before"
  let after ← requireSome
    (coverage? capacity effective events1 corrections validities1 actualRouting
      scheduledMemory terminals1 roles scheduledRouting)
    "V3 routing after"
  expectCoverage "V3e before" before 0 30 70
  expectCoverage "V3e after" after 27 0 73
  expect (actualRouting.statusAt foodC (2 : Nat) = .managed food)
    "V3e valid-time routing did not remain food"
  expect (actualRouting.statusAt foodC (3 : Nat) = .managed books)
    "V3e later route fixture missing"
  expect (after.headroom.quanta - before.headroom.quanta == expectedDelta before after)
    "V3e later routing entry rewrote past quantity interpretation"


def main : IO Unit := do
  underRealization
  overRealization
  splitUnderRealization
  correctionChangesRealizedQuantity
  laterRoutingDoesNotRewritePastMeaning
  IO.println
    "Four-voice V3: within one Purpose/Measure and fixed query context, Headroom delta equals removed managed Commitment minus added correction-frontier Consumption; split shape, correction, and later routing history preserve the law only through the selected current evidence."