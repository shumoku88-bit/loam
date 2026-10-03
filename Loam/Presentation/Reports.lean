import Loam.Review.RoleFlowReview

namespace Loam.Presentation.Reports

open Loam.Core

set_option autoImplicit false

/-!
# Production report presentation helpers

Only renderer-neutral transformations with a current production consumer live
here. Household report semantics remain owned by Review modules.
-/

structure IncomeExpenseMeasure where
  measure : MeasureId
  income : Quantity
  expense : Quantity
  result : Quantity
  deriving Repr, DecidableEq

structure IncomeExpense where
  start : String
  endExclusive : String
  measures : List IncomeExpenseMeasure
  unresolvedEffectCount : Nat
  deriving Repr, DecidableEq

private def addMeasureIfAbsent
    (measures : List MeasureId) (measure : MeasureId) : List MeasureId :=
  if measure ∈ measures then measures else measures ++ [measure]

private def incomeExpenseMeasures
    (snapshot : Loam.RoleFlowReview.Snapshot) : List MeasureId :=
  snapshot.rows.foldl
    (fun measures row =>
      match row.role with
      | .income | .expense => addMeasureIfAbsent measures row.coordinate.measure
      | _ => measures)
    []

private def roleQuanta
    (snapshot : Loam.RoleFlowReview.Snapshot)
    (measure : MeasureId) (role : AccountingRole) : Int :=
  snapshot.rows.foldl
    (fun total row =>
      if decide (row.coordinate.measure = measure ∧ row.role = role) then
        total + row.quantity.quanta
      else
        total)
    0

private def incomeExpenseMeasure
    (snapshot : Loam.RoleFlowReview.Snapshot)
    (measure : MeasureId) : IncomeExpenseMeasure :=
  let rawIncome := roleQuanta snapshot measure .income
  let rawExpense := roleQuanta snapshot measure .expense
  let income := -rawIncome
  let expense := rawExpense
  {
    measure := measure
    income := Quantity.ofQuanta income
    expense := Quantity.ofQuanta expense
    result := Quantity.ofQuanta (income - expense)
  }

/--
Surface-neutral Income & Expense summary used by the production Reports TUI.
Distinct Measures remain separate and the existing display-sign convention is
preserved without adding accounting recognition semantics.
-/
def incomeExpenseFromRoleFlow
    (snapshot : Loam.RoleFlowReview.Snapshot) : IncomeExpense :=
  {
    start := snapshot.start
    endExclusive := snapshot.endExclusive
    measures := (incomeExpenseMeasures snapshot).map (incomeExpenseMeasure snapshot)
    unresolvedEffectCount := snapshot.unresolvedEffects.length
  }

end Loam.Presentation.Reports
