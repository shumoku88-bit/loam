import Loam.Application.ActualRoutingInspection
import Loam.Core.AccountingRole

namespace Loam.Observation275

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 275 — Actual routing answerability frontier

Current Coverage projects Purpose Consumption only from Effects whose Locus has a
managed route at the Event's current valid coordinate. An unrouted Effect is
therefore absent from every Purpose Consumption row even though the physical
Actual remains retained.

This observation does not define which unrouted Actuals should block Current
Coverage. It asks for the smaller deterministic fact needed before that policy
question:

> Can current-window unrouted Actual coordinates be derived as explicit signed
> rows while preserving Event/date/Locus/Measure/AccountingRole evidence?

The row projection is read-only and introduces no retained state.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def food : PurposeId := ⟨"food"⟩
private def paypay : LocusId := ⟨"paypay"⟩
private def groceries : LocusId := ⟨"groceries"⟩

private def baseEvent? : Option Event :=
  Event.ofEffects? ⟨"o275-spend"⟩
    [ Effect.ofQuantity ⟨"o275-source"⟩ paypay yen (Quantity.ofQuanta (-30))
    , Effect.ofQuantity ⟨"o275-use"⟩ groceries yen (Quantity.ofQuanta 30)
    ]

private def refundEvent? : Option Event :=
  Event.ofEffects? ⟨"o275-refund"⟩
    [ Effect.ofQuantity ⟨"o275-refund-source"⟩ paypay yen (Quantity.ofQuanta 10)
    , Effect.ofQuantity ⟨"o275-refund-use"⟩ groceries yen (Quantity.ofQuanta (-10))
    ]

private def roles? : Option AccountingRoleMap :=
  AccountingRoleMap.ofAssignments?
    [ { locus := paypay, role := .asset }
    , { locus := groceries, role := .expense }
    ]

private def emptyRouting? :
    Option (RoutingHistory LocusId (RoutingEffective Nat)) :=
  RoutingHistory.ofEntries? []

private def foodRouting? :
    Option (RoutingHistory LocusId (RoutingEffective Nat)) :=
  RoutingHistory.ofEntries?
    [{ subject := groceries, effectiveOn := .initial, purpose := some food }]

private def baseRowsWith
    (routing : RoutingHistory LocusId (RoutingEffective Nat)) :
    Option (List (UnroutedActualRow Nat)) := do
  let event ← baseEvent?
  let events ← EventMemory.ofEvents? [event]
  let validities ← ActualValidityMemory.ofEntries?
    [{ event := event.id, validOn := 2 }]
  let roles ← roles?
  unroutedActualRows? events validities routing roles 1 2 yen

private def noRouteWitness : Bool :=
  match emptyRouting? with
  | none => false
  | some routing =>
      match baseRowsWith routing with
      | none => false
      | some rows =>
          decide
            (rows.map (fun row => (row.locus, row.quantity.quanta, row.role)) =
              [ (paypay, -30, some .asset)
              , (groceries, 30, some .expense)
              ])

/--
With no route evidence, both sides of one balanced Actual remain visible as
signed unrouted rows. The row layer does not prematurely decide that only the
Expense side is actionable.
-/
theorem no_route_preserves_signed_asset_and_expense_rows :
    noRouteWitness = true := by
  native_decide

private def routedExpenseWitness : Bool :=
  match foodRouting? with
  | none => false
  | some routing =>
      match baseRowsWith routing with
      | none => false
      | some rows =>
          decide
            (rows.map (fun row => (row.locus, row.quantity.quanta, row.role)) =
              [(paypay, -30, some .asset)])

/--
Adding only the groceries -> food route removes only the groceries row. The
unrouted Asset source remains visible, showing why "any unrouted Actual blocks
Coverage" would be too strong.
-/
theorem routing_expense_removes_only_that_unrouted_row :
    routedExpenseWitness = true := by
  native_decide

private def refundWitness : Bool :=
  match refundEvent?, emptyRouting?, roles? with
  | some event, some routing, some roles =>
      match EventMemory.ofEvents? [event],
          ActualValidityMemory.ofEntries? [{ event := event.id, validOn := 2 }] with
      | some events, some validities =>
          match unroutedActualRows? events validities routing roles 1 2 yen with
          | some rows =>
              decide
                (rows.map (fun row => (row.locus, row.quantity.quanta)) =
                  [(paypay, 10), (groceries, -10)])
          | none => false
      | _, _ => false
  | _, _, _ => false

/--
Signed refund direction is preserved instead of being collapsed into a positive
"unrouted spending" total before product policy is qualified.
-/
theorem refund_sign_survives_unrouted_projection :
    refundWitness = true := by
  native_decide

private def missingRoleWitness : Bool :=
  match baseEvent?, emptyRouting? with
  | some event, some routing =>
      match EventMemory.ofEvents? [event],
          ActualValidityMemory.ofEntries? [{ event := event.id, validOn := 2 }] with
      | some events, some validities =>
          match unroutedActualRows?
              events validities routing AccountingRoleMap.empty 1 2 yen with
          | some rows => rows.all (fun row => row.role.isNone)
          | none => false
      | _, _ => false
  | _, _ => false

/--
Missing AccountingRole remains explicit metadata on the unresolved row; this
observation does not guess a role from sign or Locus spelling.
-/
theorem missing_role_remains_unresolved :
    missingRoleWitness = true := by
  native_decide

end Loam.Observation275
