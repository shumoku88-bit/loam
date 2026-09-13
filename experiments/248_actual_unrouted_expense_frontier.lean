import Loam.Application.CurrentCoverageInspection
import Loam.Application.CorrectionFrontier
import Loam.Core.AccountingRole
import Loam.Core.EventCorrection
import Loam.Core.RoutingEffective

open Loam.Core
open Loam.Application

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

/-- Observation-local row only. This is not proposed retained state or identity. -/
private structure UnroutedExpenseRow (Time : Type) where
  event : EventId
  validOn : Time
  coordinate : EffectCoordinate
  quantity : Quantity
deriving Repr, DecidableEq

private def inCurrentWindow {Time : Type}
    [LE Time] [DecidableRel (· ≤ · : Time → Time → Prop)]
    (start observedAt value : Time) : Bool :=
  decide (start ≤ value) && decide (value ≤ observedAt)

private def addLocusIfAbsent (loci : List LocusId) (locus : LocusId) : List LocusId :=
  if locus ∈ loci then loci else loci ++ [locus]

/--
Recover each Locus represented by the selected Measure once. Routing is Locus-scoped,
so repeated Effects at the same Event/Locus/Measure do not earn repeated frontier rows.
-/
private def eventLociAtMeasure (event : Event) (measure : MeasureId) : List LocusId :=
  event.effects.foldl
    (fun loci effect =>
      if effect.measure = measure then addLocusIfAbsent loci effect.locus else loci)
    []

private def eventUnroutedExpenseRows
    {Time : Type}
    [LE Time] [DecidableRel (· ≤ · : Time → Time → Prop)]
    (event : Event)
    (validOn start observedAt : Time)
    (roles : AccountingRoleMap)
    (routing : RoutingHistory LocusId (RoutingEffective Time))
    (measure : MeasureId) : List (UnroutedExpenseRow Time) :=
  if !inCurrentWindow start observedAt validOn then
    []
  else
    (eventLociAtMeasure event measure).filterMap fun locus =>
      match roles.roleOf? locus, routing.statusAt locus (.dated validOn) with
      | some .expense, .unrouted =>
          some {
            event := event.id
            validOn := validOn
            coordinate := ⟨locus, measure⟩
            quantity := event.quantityAt locus measure }
      | _, _ => none

/--
Observation-local candidate frontier.

It deliberately reuses the production Event correction frontier, requires validity
for every current frontier Event before window selection, reads routing at each
Event's own valid coordinate, and uses existing partial AccountingRole evidence.
-/
private def unroutedExpenseRowsThrough?
    {Time : Type}
    [LE Time] [DecidableRel (· ≤ · : Time → Time → Prop)] [Std.IsLinearOrder Time]
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory Time)
    (roles : AccountingRoleMap)
    (routing : RoutingHistory LocusId (RoutingEffective Time))
    (start observedAt : Time)
    (measure : MeasureId) : Option (List (UnroutedExpenseRow Time)) := do
  if !validCurrentWindow start observedAt then none else
  let frontier ← correctionFrontierMemory? events corrections
  frontier.events.foldlM
    (fun rows event => do
      let validOn ← validities.findByEventId? event.id
      return rows ++ eventUnroutedExpenseRows
        event validOn start observedAt roles routing measure)
    []

private def yen : MeasureId := ⟨"jpy"⟩
private def usd : MeasureId := ⟨"usd"⟩
private def food : PurposeId := ⟨"food"⟩
private def cash : LocusId := ⟨"cash"⟩
private def openExpense : LocusId := ⟨"open-expense"⟩
private def refundExpense : LocusId := ⟨"refund-expense"⟩
private def managedExpense : LocusId := ⟨"managed-expense"⟩
private def unmanagedExpense : LocusId := ⟨"unmanaged-expense"⟩
private def lateExpense : LocusId := ⟨"late-expense"⟩
private def outsideExpense : LocusId := ⟨"outside-expense"⟩
private def otherMeasureExpense : LocusId := ⟨"other-measure-expense"⟩
private def oldExpense : LocusId := ⟨"old-expense"⟩
private def replacementExpense : LocusId := ⟨"replacement-expense"⟩

private def actual?
    (id : String) (locus : LocusId) (measure : MeasureId) (quanta : Int) : Option Event :=
  Event.ofEffects? ⟨id⟩
    [Effect.ofQuantity ⟨id ++ "-cash"⟩ cash measure (Quantity.ofQuanta (-quanta)),
     Effect.ofQuantity ⟨id ++ "-use"⟩ locus measure (Quantity.ofQuanta quanta)]

private def hasRow
    (rows : List (UnroutedExpenseRow Nat))
    (event : EventId) (locus : LocusId) (quanta : Int) : Bool :=
  rows.any fun row =>
    row.event == event && row.coordinate == ⟨locus, yen⟩ && row.quantity.quanta == quanta

def main : IO Unit := do
  let openActual ← requireSome (actual? "open" openExpense yen 30) "open Actual"
  let refund ← requireSome (actual? "refund" refundExpense yen (-5)) "refund Actual"
  let managed ← requireSome (actual? "managed" managedExpense yen 20) "managed Actual"
  let unmanaged ← requireSome (actual? "unmanaged" unmanagedExpense yen 10) "unmanaged Actual"
  let late ← requireSome (actual? "late" lateExpense yen 12) "late-routed Actual"
  let outside ← requireSome (actual? "outside" outsideExpense yen 40) "outside-window Actual"
  let otherMeasure ← requireSome (actual? "other-measure" otherMeasureExpense usd 50)
    "other-Measure Actual"
  let old ← requireSome (actual? "old" oldExpense yen 7) "old corrected Actual"
  let replacement ← requireSome (actual? "replacement" replacementExpense yen 9)
    "replacement Actual"

  let events ← requireSome
    (EventMemory.ofEvents?
      [openActual, refund, managed, unmanaged, late, outside, otherMeasure, old, replacement])
    "Event memory"
  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := old.id, replacement := replacement.id }])
    "correction memory"

  -- The superseded target deliberately has no validity evidence. Applying the
  -- correction frontier first must therefore avoid inventing a dependency on it.
  let validities ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := openActual.id, validOn := (2 : Nat) },
       { event := refund.id, validOn := (2 : Nat) },
       { event := managed.id, validOn := (2 : Nat) },
       { event := unmanaged.id, validOn := (2 : Nat) },
       { event := late.id, validOn := (2 : Nat) },
       { event := outside.id, validOn := (0 : Nat) },
       { event := otherMeasure.id, validOn := (2 : Nat) },
       { event := replacement.id, validOn := (2 : Nat) }])
    "validity memory"

  let roles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [{ locus := cash, role := .asset },
       { locus := openExpense, role := .expense },
       { locus := refundExpense, role := .expense },
       { locus := managedExpense, role := .expense },
       { locus := unmanagedExpense, role := .expense },
       { locus := lateExpense, role := .expense },
       { locus := outsideExpense, role := .expense },
       { locus := otherMeasureExpense, role := .expense },
       { locus := oldExpense, role := .expense },
       { locus := replacementExpense, role := .expense }])
    "AccountingRole map"

  let routing ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := managedExpense,
         effectiveOn := (RoutingEffective.initial : RoutingEffective Nat),
         purpose := some food },
       { subject := unmanagedExpense,
         effectiveOn := (RoutingEffective.initial : RoutingEffective Nat),
         purpose := none },
       { subject := lateExpense,
         effectiveOn := RoutingEffective.dated (3 : Nat),
         purpose := some food }])
    "Actual routing"

  let rows ← requireSome
    (unroutedExpenseRowsThrough?
      events corrections validities roles routing (1 : Nat) (2 : Nat) yen)
    "derived frontier failed closed"

  expect (rows.length == 4)
    s!"expected four unresolved rows, got {rows.length}: {repr rows}"
  expect (hasRow rows openActual.id openExpense 30)
    "in-window unrouted Expense was not surfaced"
  expect (hasRow rows refund.id refundExpense (-5))
    "signed Expense refund was incorrectly dropped"
  expect (hasRow rows late.id lateExpense 12)
    "route learned after Event-valid coordinate incorrectly closed the earlier row"
  expect (hasRow rows replacement.id replacementExpense 9)
    "correction-selected replacement Expense was not surfaced"

  expect (!hasRow rows managed.id managedExpense 20)
    "managed Expense incorrectly remained on unrouted frontier"
  expect (!hasRow rows unmanaged.id unmanagedExpense 10)
    "explicitly unmanaged Expense incorrectly remained on unrouted frontier"
  expect (!hasRow rows outside.id outsideExpense 40)
    "out-of-window Expense leaked onto current frontier"
  expect (!hasRow rows otherMeasure.id otherMeasureExpense 50)
    "other Measure leaked onto selected frontier"
  expect (!hasRow rows old.id oldExpense 7)
    "superseded correction target leaked onto frontier"
  expect (!rows.any fun row => row.coordinate.locus == cash)
    "unrouted Asset coordinate incorrectly became an Expense blocker"

  expect ((unroutedExpenseRowsThrough?
      events corrections validities roles routing (3 : Nat) (2 : Nat) yen).isNone)
    "invalid current window did not fail closed"

  let missingReplacementValidity ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := openActual.id, validOn := (2 : Nat) },
       { event := refund.id, validOn := (2 : Nat) },
       { event := managed.id, validOn := (2 : Nat) },
       { event := unmanaged.id, validOn := (2 : Nat) },
       { event := late.id, validOn := (2 : Nat) },
       { event := outside.id, validOn := (0 : Nat) },
       { event := otherMeasure.id, validOn := (2 : Nat) }])
    "incomplete validity fixture"
  expect ((unroutedExpenseRowsThrough?
      events corrections missingReplacementValidity roles routing (1 : Nat) (2 : Nat) yen).isNone)
    "missing current-frontier validity evidence did not fail closed"

  IO.println "Observation 248 witness: a pure derived Event-valid unrouted Expense frontier is sufficient in the bounded case."
