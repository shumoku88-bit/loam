import Loam.ActualDate
import Loam.Review.RoleFlowReview
import Loam.Review.TransactionsFlowReview
import Loam.Persistence.AccountingRolePersistence

namespace Loam.MonthlyRoleFlowReview

open Loam.Core
open Loam.Persistence

set_option autoImplicit false

/-!
# Monthly role-flow projection

A read-only calendar-month projection over the existing Transactions-Flow
incidence image plus explicit AccountingRole evidence.

This module does not read Actual independently, retain another accounting
authority, infer roles from names or signs, or introduce an HRA Account model.
It groups the same occurrence-time quantity evidence already used by
RoleFlowReview onto a continuous calendar-month axis.

The selected half-open window remains authoritative. Boundary months may
therefore be partial, and every calendar month touched by the window is retained
even when its selected classified flow is zero. This projection does not invent
a separate observation horizon: an empty future month means only that no
currently admitted flow was selected there, not that future activity is known
to be finally zero.
-/

structure Cell where
  month : String
  quantity : Quantity
  deriving Repr, DecidableEq

structure Row where
  coordinate : EffectCoordinate
  role : AccountingRole
  cells : List Cell
  deriving Repr, DecidableEq

structure Snapshot where
  start : String := ""
  endExclusive : String := ""
  months : List String := []
  rows : List Row := []
  unresolvedEffects : List Loam.RoleFlowReview.UnresolvedEffect := []

private def padNat (width value : Nat) : String :=
  let text := toString value
  String.ofList (List.replicate (width - text.length) '0') ++ text

private def monthIndex? (date : String) : Option Nat := do
  if !Loam.ActualDate.validIsoDate date then none else do
    let [yearText, monthText, _] := date.splitOn "-" | none
    let year ← yearText.toNat?
    let month ← monthText.toNat?
    some (year * 12 + (month - 1))

private def monthLabel (index : Nat) : String :=
  let year := index / 12
  let month := index % 12 + 1
  padNat 4 year ++ "-" ++ padNat 2 month

private def monthKey? (date : String) : Option String := do
  if !Loam.ActualDate.validIsoDate date then none else do
    let [yearText, monthText, _] := date.splitOn "-" | none
    some (yearText ++ "-" ++ monthText)

private def monthsForWindow
    (start endExclusive : String) : Except String (List String) := do
  if !Loam.ActualDate.validIsoDate start ||
      !Loam.ActualDate.validIsoDate endExclusive then
    throw "loam: monthly role-flow endpoints must be real YYYY-MM-DD calendar dates"
  if !(decide (start < endExclusive)) then
    throw "loam: monthly role-flow start must be before end-exclusive"
  let some lastDate := Loam.ActualDate.shiftDays? endExclusive (-1)
    | throw "loam: monthly role-flow could not construct its final observed day"
  let some firstIndex := monthIndex? start
    | throw "loam: monthly role-flow could not resolve its start month"
  let some lastIndex := monthIndex? lastDate
    | throw "loam: monthly role-flow could not resolve its final month"
  return (List.range (lastIndex - firstIndex + 1)).map fun offset =>
    monthLabel (firstIndex + offset)

private def flowForMonth
    (flow : Loam.TransactionsFlowReview.Snapshot)
    (month : String) : Loam.TransactionsFlowReview.Snapshot :=
  { flow with
      columns := flow.columns.filter fun column =>
        monthKey? column.date == some month }

private def quantityFor
    (snapshot : Loam.RoleFlowReview.Snapshot)
    (coordinate : EffectCoordinate)
    (role : AccountingRole) : Quantity :=
  match snapshot.rows.find? fun row =>
      decide (row.coordinate = coordinate ∧ row.role = role) with
  | some row => row.quantity
  | none => Quantity.ofQuanta 0

private def isFlowRole (role : AccountingRole) : Bool :=
  decide (role = .income ∨ role = .expense)

/--
Project a continuous calendar-month axis from one already-qualified
Transactions-Flow snapshot and the same explicit AccountingRole authority used
by RoleFlowReview.

Month cells are reconstructed from month-filtered views of the retained Event
columns and then classified by RoleFlowReview. This deliberately reuses that
existing role projection instead of creating a second classification engine.
-/
def project
    (flow : Loam.TransactionsFlowReview.Snapshot)
    (roles : AccountingRoleMap) : Except String Snapshot := do
  let months ← monthsForWindow flow.start flow.endExclusive
  let whole := Loam.RoleFlowReview.project flow roles
  let monthly :=
    months.map fun month =>
      (month, Loam.RoleFlowReview.project (flowForMonth flow month) roles)
  let rows :=
    (whole.rows.filter fun row => isFlowRole row.role).map fun row =>
      {
        coordinate := row.coordinate
        role := row.role
        cells := monthly.map fun entry =>
          {
            month := entry.1
            quantity := quantityFor entry.2 row.coordinate row.role
          }
      }
  return {
    start := flow.start
    endExclusive := flow.endExclusive
    months := months
    rows := rows
    unresolvedEffects := whole.unresolvedEffects
  }

/-- Exact raw signed quantity for one row/month cell; absent means exact zero. -/
def Row.quantityAt (row : Row) (month : String) : Quantity :=
  match row.cells.find? fun cell => cell.month == month with
  | some cell => cell.quantity
  | none => Quantity.ofQuanta 0

/-- Exact raw signed period total reconstructed from retained monthly cells. -/
def Row.total (row : Row) : Quantity :=
  Quantity.ofQuanta <| row.cells.foldl (fun total cell => total + cell.quantity.quanta) 0

end Loam.MonthlyRoleFlowReview
