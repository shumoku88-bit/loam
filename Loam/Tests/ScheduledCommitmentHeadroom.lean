import Loam.Application.ScheduledCommitmentInspection
import Loam.Core.Capacity
import Loam.Core.EventCorrection

open Loam.Core
open Loam.Application

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private def yen : MeasureId := ⟨"jpy"⟩
private def food : PurposeId := ⟨"food"⟩
private def household : PurposeId := ⟨"household"⟩

private def paypay : LocusId := ⟨"paypay"⟩
private def groceries : LocusId := ⟨"groceries"⟩
private def coffee : LocusId := ⟨"coffee"⟩
private def assetReceipt : LocusId := ⟨"asset-receipt"⟩
private def incomeSource : LocusId := ⟨"income-source"⟩
private def debt : LocusId := ⟨"debt"⟩
private def fixedExpense : LocusId := ⟨"fixed-expense"⟩
private def savings : LocusId := ⟨"savings"⟩
private def mystery : LocusId := ⟨"mystery"⟩
private def routedMystery : LocusId := ⟨"routed-mystery"⟩

private def change (locus : LocusId) (quanta : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := Quantity.ofQuanta quanta }

private def capacityChange
    (coordinate : CapacityCoordinate) (quanta : Int) : MovementChange CapacityCoordinate :=
  { coordinate := coordinate, quantity := Quantity.ofQuanta quanta }

private def scheduled?
    (id : String) (day : Nat) (changes : List (MovementChange LocusId)) :
    Option (ScheduledOccurrence Nat) := do
  let movement ← BalancedMovement.ofChanges? yen changes
  pure { id := ⟨id⟩, scheduledOn := day, movement := movement }

private def subject (scheduled : String) (locus : LocusId) : ScheduledRoutingSubject :=
  { scheduled := ⟨scheduled⟩, locus := locus }

def main : IO Unit := do
  let roles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [{ locus := paypay, role := .asset },
       { locus := groceries, role := .expense },
       { locus := coffee, role := .expense },
       { locus := assetReceipt, role := .asset },
       { locus := incomeSource, role := .income },
       { locus := debt, role := .liability },
       { locus := fixedExpense, role := .expense },
       { locus := savings, role := .asset }])
    "accounting-role fixture was not admitted"

  let capacityMovement ← requireSome
    (do
      let movement ← BalancedMovement.ofChanges? yen
        [capacityChange .unallocated (-100),
         capacityChange (.purpose food) 100]
      pure ({ id := ⟨"capacity-1"⟩, movement := movement } : CapacityMovement))
    "capacity fixture was not admitted"

  let actual ← requireSome
    (Event.ofEffects? ⟨"actual-1"⟩
      [Effect.ofQuantity ⟨"pay"⟩ paypay yen (Quantity.ofQuanta (-30)),
       Effect.ofQuantity ⟨"use"⟩ groceries yen (Quantity.ofQuanta 30)])
    "actual fixture was not admitted"
  let events ← requireSome
    (EventMemory.ofEvents? [actual])
    "event memory was not admitted"
  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections? [])
    "empty correction memory was not admitted"
  let validities ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := ⟨"actual-1"⟩, validOn := (1 : Nat) }])
    "actual validity fixture was not admitted"
  let actualRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := groceries, effectiveOn := (1 : Nat), purpose := some food }])
    "actual routing fixture was not admitted"

  let s1 ← requireSome
    (scheduled? "scheduled-1" 2
      [change paypay (-30), change groceries 20, change coffee 10])
    "split Scheduled fixture was not admitted"
  let s2 ← requireSome
    (scheduled? "scheduled-2" 3
      [change paypay (-15), change groceries 15])
    "same-Locus Scheduled fixture was not admitted"
  let s3 ← requireSome
    (scheduled? "scheduled-3" 4
      [change paypay (-40), change groceries 40])
    "end-exclusive Scheduled fixture was not admitted"
  let s4 ← requireSome
    (scheduled? "scheduled-4" 0
      [change paypay (-5), change groceries 5])
    "overdue Scheduled fixture was not admitted"
  let s5 ← requireSome
    (scheduled? "scheduled-5" 2
      [change paypay (-6), change groceries 6])
    "retired Scheduled fixture was not admitted"
  let s6 ← requireSome
    (scheduled? "scheduled-6" 2
      [change paypay (-9), change groceries 9])
    "completed Scheduled fixture was not admitted"
  let s7 ← requireSome
    (scheduled? "scheduled-7" 2
      [change paypay (-7), change groceries 7])
    "interrupted-completion Scheduled fixture was not admitted"
  let s8 ← requireSome
    (scheduled? "scheduled-8" 2
      [change paypay (-8), change groceries 8])
    "unrouted Scheduled fixture was not admitted"
  -- Repeated raw changes at one Locus form one aggregated Scheduled × Locus
  -- routing coordinate: groceries is net +10 here, not +20.
  let s9 ← requireSome
    (scheduled? "scheduled-9" 2
      [change paypay (-10), change groceries 20, change groceries (-10)])
    "aggregated-Locus Scheduled fixture was not admitted"

  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [s1, s2, s3, s4, s5, s6, s7, s8, s9])
    "Scheduled memory was not admitted"
  let completionMemory ← requireSome
    (ScheduledCompletionMemory.ofCompletions?
      [{ scheduled := ⟨"scheduled-6"⟩, actual := ⟨"actual-1"⟩ },
       { scheduled := ⟨"scheduled-7"⟩, actual := ⟨"actual-not-yet-published"⟩ }])
    "completion fixture was not admitted"
  let retirementMemory ← requireSome
    (ScheduledRetirementMemory.ofRetirements?
      [{ scheduled := ⟨"scheduled-5"⟩ }])
    "retirement fixture was not admitted"

  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := subject "scheduled-1" groceries,
         effectiveOn := (1 : Nat), purpose := some food },
       { subject := subject "scheduled-1" coffee,
         effectiveOn := (1 : Nat), purpose := some household },
       { subject := subject "scheduled-2" groceries,
         effectiveOn := (1 : Nat), purpose := some household },
       { subject := subject "scheduled-3" groceries,
         effectiveOn := (1 : Nat), purpose := some food },
       { subject := subject "scheduled-4" groceries,
         effectiveOn := (1 : Nat), purpose := some food },
       { subject := subject "scheduled-5" groceries,
         effectiveOn := (1 : Nat), purpose := some food },
       { subject := subject "scheduled-6" groceries,
         effectiveOn := (1 : Nat), purpose := some food },
       { subject := subject "scheduled-7" groceries,
         effectiveOn := (1 : Nat), purpose := none },
       { subject := subject "scheduled-9" groceries,
         effectiveOn := (1 : Nat), purpose := some food }])
    "Scheduled routing fixture was not admitted"

  let commitment ← requireSome
    (currentScheduledCommitment?
      scheduledMemory completionMemory retirementMemory events roles scheduledRouting
      food yen (2 : Nat) (4 : Nat))
    "current Scheduled commitment failed closed"

  -- Current pressure starts at observedAt=2, so the still-open day-0 occurrence
  -- is not historically replayed into this future horizon.
  expect (commitment.managed.quanta == 30)
    s!"expected food commitment 30, got {commitment.managed.quanta}"
  expect (commitment.unmanaged.quanta == 7)
    s!"expected unmanaged commitment 7, got {commitment.unmanaged.quanta}"
  expect (commitment.unrouted.quanta == 8)
    s!"expected unrouted commitment 8, got {commitment.unrouted.quanta}"
  expect (commitment.unresolvedEligibility.quanta == 0)
    "fully classified fixture unexpectedly retained unresolved eligibility"

  let headroom ← requireSome
    (headroomAtCorrectionFrontier?
      [capacityMovement]
      events corrections validities actualRouting
      scheduledMemory completionMemory retirementMemory roles scheduledRouting
      food yen (2 : Nat) (4 : Nat))
    "headroom projection failed closed"

  expect (headroom.remaining.quanta == 70)
    s!"expected Remaining 70, got {headroom.remaining.quanta}"
  expect (headroom.commitment.quanta == 30)
    s!"expected Commitment 30, got {headroom.commitment.quanta}"
  expect (headroom.headroom.quanta == 40)
    s!"expected Headroom 40, got {headroom.headroom.quanta}"
  expect (headroom.unmanagedCommitment.quanta == 7)
    "Headroom view lost unmanaged Scheduled pressure"
  expect (headroom.unroutedCommitment.quanta == 8)
    "Headroom view lost unrouted Scheduled pressure"
  expect (headroom.unresolvedEligibility.quanta == 0)
    "Headroom view invented unresolved Scheduled pressure"

  -- Observation 227 representative pressure selection.
  let incomeOccurrence ← requireSome
    (scheduled? "eligibility-income" 2
      [change incomeSource (-30), change assetReceipt 30])
    "Asset-receipt Scheduled fixture was not admitted"
  let debtOccurrence ← requireSome
    (scheduled? "eligibility-debt" 2
      [change paypay (-20), change debt 20])
    "Liability Scheduled fixture was not admitted"
  let expenseOccurrence ← requireSome
    (scheduled? "eligibility-expense" 2
      [change paypay (-10), change fixedExpense 10])
    "Expense Scheduled fixture was not admitted"
  let savingsOccurrence ← requireSome
    (scheduled? "eligibility-savings" 2
      [change paypay (-40), change savings 40])
    "routed Asset Scheduled fixture was not admitted"
  let mysteryOccurrence ← requireSome
    (scheduled? "eligibility-mystery" 2
      [change paypay (-50), change mystery 50])
    "missing-role Scheduled fixture was not admitted"
  let routedMysteryOccurrence ← requireSome
    (scheduled? "eligibility-routed-mystery" 2
      [change paypay (-60), change routedMystery 60])
    "routed missing-role Scheduled fixture was not admitted"

  let eligibilityMemory ← requireSome
    (ScheduledMemory.ofOccurrences?
      [incomeOccurrence, debtOccurrence, expenseOccurrence, savingsOccurrence,
       mysteryOccurrence, routedMysteryOccurrence])
    "eligibility Scheduled memory was not admitted"
  let emptyCompletions ← requireSome
    (ScheduledCompletionMemory.ofCompletions? [])
    "empty completion memory was not admitted"
  let emptyRetirements ← requireSome
    (ScheduledRetirementMemory.ofRetirements? [])
    "empty retirement memory was not admitted"
  let eligibilityRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := subject "eligibility-savings" savings,
         effectiveOn := (1 : Nat), purpose := some food },
       { subject := subject "eligibility-routed-mystery" routedMystery,
         effectiveOn := (1 : Nat), purpose := some food }])
    "eligibility routing fixture was not admitted"

  let eligibility ← requireSome
    (currentScheduledCommitment?
      eligibilityMemory emptyCompletions emptyRetirements events roles
      eligibilityRouting food yen (2 : Nat) (4 : Nat))
    "eligibility pressure projection failed closed"

  -- Asset receipt with no route is resolved non-pressure. Expense and Liability
  -- remain unrouted pressure. Explicit routing selects Asset and even missing-role
  -- coordinates into pressure. Missing role without a route stays visible.
  expect (eligibility.managed.quanta == 100)
    s!"expected routed pressure 100, got {eligibility.managed.quanta}"
  expect (eligibility.unmanaged.quanta == 0)
    "eligibility fixture invented unmanaged pressure"
  expect (eligibility.unrouted.quanta == 30)
    s!"expected Expense + Liability unrouted pressure 30, got {eligibility.unrouted.quanta}"
  expect (eligibility.unresolvedEligibility.quanta == 50)
    s!"expected unresolved eligibility 50, got {eligibility.unresolvedEligibility.quanta}"

  let emptyReplacements ← requireSome
    (ScheduledReplacementMemory.ofReplacements? [])
    "empty replacement memory was not admitted"

  let unresolvedRows ← requireSome
    (currentUnresolvedScheduledPressureWithReplacement?
      eligibilityMemory emptyCompletions emptyRetirements emptyReplacements events roles
      eligibilityRouting yen (2 : Nat) (4 : Nat))
    "unresolved Scheduled pressure rows failed closed"
  expect (unresolvedRows.length == 1)
    s!"expected exactly 1 unresolved row, got {unresolvedRows.length}"
  expect (((unresolvedRows.map (fun r => r.quantity.quanta)).sum) == eligibility.unresolvedEligibility.quanta)
    "unresolved row quantities did not sum to aggregate unresolved eligibility"
  match unresolvedRows with
  | [row] =>
      expect (row.subject == subject "eligibility-mystery" mystery)
        "unresolved row retained unexpected subject"
      expect (row.scheduledOn == 2)
        s!"expected scheduledOn 2, got {row.scheduledOn}"
      expect (row.measure == yen)
        "unresolved row had unexpected Measure"
      expect (row.quantity.quanta == 50)
        s!"expected quantity 50, got {row.quantity.quanta}"
  | _ => throw <| IO.userError "unresolved rows returned unexpected structure"

  let fullyResolvedRows ← requireSome
    (currentUnresolvedScheduledPressureWithReplacement?
      scheduledMemory completionMemory retirementMemory emptyReplacements events roles scheduledRouting
      yen (2 : Nat) (4 : Nat))
    "fully resolved fixture unresolved rows projection failed closed"
  expect (fullyResolvedRows.isEmpty)
    s!"expected empty unresolved rows for fully classified fixture, got {fullyResolvedRows.length}"

  -- An unknown Scheduled endpoint makes the whole current-open answer invalid.
  let unknownCompletion ← requireSome
    (ScheduledCompletionMemory.ofCompletions?
      [{ scheduled := ⟨"unknown-scheduled"⟩, actual := ⟨"actual-1"⟩ }])
    "unknown-reference completion fixture shape was not admitted"
  expect
    ((currentScheduledCommitment?
      scheduledMemory unknownCompletion retirementMemory events roles scheduledRouting
      food yen (2 : Nat) (4 : Nat)).isNone)
    "unknown Scheduled completion reference did not fail closed"
  expect
    ((currentUnresolvedScheduledPressureWithReplacement?
      scheduledMemory unknownCompletion retirementMemory emptyReplacements events roles scheduledRouting
      yen (2 : Nat) (4 : Nat)).isNone)
    "unknown Scheduled completion reference did not fail closed for unresolved rows"

  -- Conflicting completion and retirement evidence also refuses the whole view.
  let conflictRetirement ← requireSome
    (ScheduledRetirementMemory.ofRetirements?
      [{ scheduled := ⟨"scheduled-6"⟩ }])
    "conflicting retirement fixture shape was not admitted"
  expect
    ((currentScheduledCommitment?
      scheduledMemory completionMemory conflictRetirement events roles scheduledRouting
      food yen (2 : Nat) (4 : Nat)).isNone)
    "conflicting Scheduled terminal evidence did not fail closed"
  expect
    ((currentUnresolvedScheduledPressureWithReplacement?
      scheduledMemory completionMemory conflictRetirement emptyReplacements events roles scheduledRouting
      yen (2 : Nat) (4 : Nat)).isNone)
    "conflicting Scheduled terminal evidence did not fail closed for unresolved rows"

  IO.println "Scheduled Commitment / Headroom practical story succeeded."
