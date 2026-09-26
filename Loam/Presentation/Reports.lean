import Loam.Presentation.HouseholdSnapshot

namespace Loam.Presentation.Reports

open Loam.Core

set_option autoImplicit false

/-!
# Surface-neutral reports presentation

This module translates shared Review answers into renderer-neutral report values.
It owns no file loading, report semantics, accounting classification, or write
authority. Renderers may present the same model as terminal rows, HTML tables,
native widgets, or charts.
-/

structure StockFlow where
  start : String
  endExclusive : String
  opening : Quantity
  increases : Quantity
  decreases : Quantity
  closing : Quantity
  currentTracked : Quantity
  deriving Repr, DecidableEq

structure TransactionsFlowRow where
  coordinate : EffectCoordinate
  net : Quantity
  gross : Quantity
  positive : Quantity
  negative : Quantity
  activeEvents : Nat
  deriving Repr, DecidableEq

structure TransactionsFlow where
  start : String
  endExclusive : String
  eventCount : Nat
  rows : List TransactionsFlowRow
  deriving Repr, DecidableEq

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

structure BalanceRow where
  coordinate : EffectCoordinate
  role : AccountingRole
  quantity : Quantity
  deriving Repr, DecidableEq

structure Balances where
  rows : List BalanceRow
  unresolvedRoleCount : Nat
  unsupportedBalanceCount : Nat
  deriving Repr, DecidableEq

structure Model where
  stockFlow : Loam.Presentation.ReadState StockFlow
  transactionsFlow : Loam.Presentation.ReadState TransactionsFlow
  incomeExpense : Loam.Presentation.ReadState IncomeExpense
  balances : Loam.Presentation.ReadState Balances

private def coordinateLe (left right : EffectCoordinate) : Bool :=
  if left.locus.token == right.locus.token then
    left.measure.token <= right.measure.token
  else
    left.locus.token <= right.locus.token

private def transactionsRowLe
    (left right : TransactionsFlowRow) : Bool :=
  if left.gross.quanta == right.gross.quanta then
    coordinateLe left.coordinate right.coordinate
  else
    left.gross.quanta >= right.gross.quanta

/--
Promote only the arithmetic already exposed by TransactionsFlowReview.
Rows with no contributing Event are omitted and the remaining rows use the same
gross-activity salience ordering as the production TUI. Signs remain exact
quantity changes, not inferred income, expense, debit, credit, or transfer edges.
-/
private def presentTransactionsFlow
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : TransactionsFlow :=
  let rows :=
    (snapshot.rowActivities.map fun entry =>
      let coordinate := entry.1
      let activity := entry.2
      {
        coordinate := coordinate
        net := activity.net
        gross := activity.gross
        positive := activity.positive
        negative := activity.negative
        activeEvents := activity.activeEvents
      })
      |>.filter (fun row => row.activeEvents > 0)
      |>.mergeSort transactionsRowLe
  {
    start := snapshot.start
    endExclusive := snapshot.endExclusive
    eventCount := snapshot.columns.length
    rows := rows
  }

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

/--
Preserve the existing TUI display convention without introducing accounting
recognition semantics: Income display is the negation of raw signed Income role
flow, Expense display is raw signed Expense role flow, and Result is their
difference. Distinct Measures remain separate.
-/
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

private def presentIncomeExpense
    (snapshot : Loam.RoleFlowReview.Snapshot) : IncomeExpense :=
  {
    start := snapshot.start
    endExclusive := snapshot.endExclusive
    measures := (incomeExpenseMeasures snapshot).map (incomeExpenseMeasure snapshot)
    unresolvedEffectCount := snapshot.unresolvedEffects.length
  }

private def presentBalances
    (snapshot : Loam.RoleBalanceReview.Snapshot) : Balances :=
  {
    rows := snapshot.rows.map fun row =>
      {
        coordinate := row.coordinate
        role := row.role
        quantity := row.quantity
      }
    unresolvedRoleCount := snapshot.unresolvedRoles.length
    unsupportedBalanceCount := snapshot.unsupportedBalances.length
  }

/-- Preserve qualified Review arithmetic and evidence gaps while naming presentation roles. -/
def fromSnapshot (snapshot : Loam.Presentation.HouseholdSnapshot) : Model :=
  {
    stockFlow :=
      Loam.Presentation.ReadState.map snapshot.stockFlow fun report =>
        {
          start := report.start
          endExclusive := report.endExclusive
          opening := report.reconstructedStart
          increases := report.increasesAcrossEvents
          decreases := report.decreasesAcrossEvents
          closing := report.reconstructedEnd
          currentTracked := report.currentTracked
        }
    transactionsFlow :=
      Loam.Presentation.ReadState.map snapshot.transactionsFlow presentTransactionsFlow
    incomeExpense :=
      Loam.Presentation.ReadState.map snapshot.roleFlow presentIncomeExpense
    balances :=
      Loam.Presentation.ReadState.map snapshot.roleBalances presentBalances
  }

end Loam.Presentation.Reports
