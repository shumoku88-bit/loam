import Loam.RoleFlowReview
import Loam.TransactionsFlowReview
import Loam.Persistence.AccountingRolePersistence

namespace Loam.DailyRoleFlowReview

open Loam.Core
open Loam.Persistence

set_option autoImplicit false

/-!
# Daily role-flow projection

A read-only sparse daily projection over the existing Transactions-Flow
incidence image plus explicit AccountingRole evidence.

This module does not read Actual independently, retain another accounting
authority, infer roles from names or signs, or introduce an HRA Account model.
It groups the same occurrence-time quantity evidence already used by
RoleFlowReview onto the dates that contain classified Income or Expense
activity.

Unlike MonthlyRoleFlowReview, the daily axis is intentionally sparse. Calendar
dates with no classified Income/Expense activity are omitted rather than filled
with zero cells. Their absence is not evidence that future or otherwise
unobserved activity is finally zero.
-/

structure Cell where
  date : String
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
  dates : List String := []
  rows : List Row := []
  unresolvedEffects : List Loam.RoleFlowReview.UnresolvedEffect := []

private def flowForDate
    (flow : Loam.TransactionsFlowReview.Snapshot)
    (date : String) : Loam.TransactionsFlowReview.Snapshot :=
  { flow with
      columns := flow.columns.filter fun column => column.date == date }

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

private def hasFlowActivity (snapshot : Loam.RoleFlowReview.Snapshot) : Bool :=
  snapshot.rows.any fun row => isFlowRole row.role

/--
Project sparse classified activity dates from one already-qualified
Transactions-Flow snapshot and the same explicit AccountingRole authority used
by RoleFlowReview.

The candidate dates come only from selected Event columns. A date survives the
axis when its date-local RoleFlow answer contains at least one Income or Expense
coordinate, including a coordinate whose same-day net happens to cancel to zero.
This preserves observed classified activity without manufacturing empty calendar
days.
-/
def project
    (flow : Loam.TransactionsFlowReview.Snapshot)
    (roles : AccountingRoleMap) : Snapshot :=
  let whole := Loam.RoleFlowReview.project flow roles
  let candidates := (flow.columns.map fun column => column.date).eraseDups
  let daily :=
    candidates.filterMap fun date =>
      let roleFlow :=
        Loam.RoleFlowReview.project (flowForDate flow date) roles
      if hasFlowActivity roleFlow then some (date, roleFlow) else none
  let rows :=
    (whole.rows.filter fun row => isFlowRole row.role).map fun row =>
      {
        coordinate := row.coordinate
        role := row.role
        cells := daily.map fun entry =>
          {
            date := entry.1
            quantity := quantityFor entry.2 row.coordinate row.role
          }
      }
  {
    start := flow.start
    endExclusive := flow.endExclusive
    dates := daily.map fun entry => entry.1
    rows := rows
    unresolvedEffects := whole.unresolvedEffects
  }

/-- Exact raw signed quantity for one row/date cell; absent means exact zero. -/
def Row.quantityAt (row : Row) (date : String) : Quantity :=
  match row.cells.find? fun cell => cell.date == date with
  | some cell => cell.quantity
  | none => Quantity.ofQuanta 0

/-- Exact raw signed selected-window total reconstructed from retained daily cells. -/
def Row.total (row : Row) : Quantity :=
  Quantity.ofQuanta <|
    row.cells.foldl (fun total cell => total + cell.quantity.quanta) 0

end Loam.DailyRoleFlowReview
