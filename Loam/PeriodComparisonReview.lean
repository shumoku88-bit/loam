import Loam.ActualAuthority
import Loam.ActualReview
import Loam.BalanceReview
import Loam.HouseholdPaths
import Loam.Persistence.AccountingRolePersistence
import Loam.RoleFlowReview
import Loam.StockFlowReview
import Loam.TransactionsFlowReview

namespace Loam.PeriodComparisonReview

open Loam.Core
open Loam.Persistence

set_option autoImplicit false

/-!
# Paired explicit-period review composition

This boundary does not define comparison arithmetic. It evaluates the same
qualified report projection twice against one admitted evidence generation and
returns the two answers side by side.

The two windows stay independent explicit half-open coordinates. No "previous
period", equal-duration, calendar-month, percentage-change, or preferred-baseline
meaning is inferred here.
-/

structure Pair (α : Type) where
  left : α
  right : α
  deriving Repr, DecidableEq

/-- Run Stock–Flow twice over one already-admitted balance/Actual evidence image. -/
def stockFlow
    (balances : Loam.BalanceReview.Snapshot)
    (records : List Loam.ActualReview.Record)
    (leftStart leftEndExclusive rightStart rightEndExclusive : String) :
    Except String (Pair Loam.StockFlowReview.Snapshot) := do
  let left ← Loam.StockFlowReview.project balances records leftStart leftEndExclusive
  let right ← Loam.StockFlowReview.project balances records rightStart rightEndExclusive
  return { left, right }

private def loadStockFlowWithinActualObservation
    (dataDir actualRoot : System.FilePath)
    (leftStart leftEndExclusive rightStart rightEndExclusive : String) :
    IO (Except String (Pair Loam.StockFlowReview.Snapshot)) := do
  let balances ←
    match ← Loam.BalanceReview.loadSnapshot dataDir actualRoot with
    | .error message => return .error message
    | .ok snapshot => pure snapshot
  let records ←
    match ← Loam.ActualReview.loadRecordsFromActual actualRoot with
    | .error message => return .error message
    | .ok records => pure records
  return stockFlow balances records
    leftStart leftEndExclusive rightStart rightEndExclusive

/--
Load both Stock–Flow periods inside one Actual ownership interval.

Both answers therefore observe the same correction-aware Actual generation.
Independent zero-origin and balance-view evidence retain their existing authority.
-/
def loadStockFlow
    (dataDir actualRoot : System.FilePath)
    (leftStart leftEndExclusive rightStart rightEndExclusive : String) :
    IO (Except String (Pair Loam.StockFlowReview.Snapshot)) := do
  let actualPath := Loam.ActualAuthority.actualPathFromRootOrFile actualRoot
  Loam.ActualAuthority.withActualFileOwnership actualPath <|
    loadStockFlowWithinActualObservation dataDir actualRoot
      leftStart leftEndExclusive rightStart rightEndExclusive

/-- Run role-aware flow twice over one Actual record image and one role relation. -/
def incomeExpense
    (records : List Loam.ActualReview.Record)
    (roles : AccountingRoleMap)
    (leftStart leftEndExclusive rightStart rightEndExclusive : String) :
    Except String (Pair Loam.RoleFlowReview.Snapshot) := do
  let leftFlow ←
    Loam.TransactionsFlowReview.project records leftStart leftEndExclusive
  let rightFlow ←
    Loam.TransactionsFlowReview.project records rightStart rightEndExclusive
  return {
    left := Loam.RoleFlowReview.project leftFlow roles
    right := Loam.RoleFlowReview.project rightFlow roles
  }

/--
Load both Income & Expense source answers from one admitted Actual image and one
explicit AccountingRole image.

This adds no P/L or comparison semantics. It only prevents the two visible
periods from accidentally observing different source generations during one
comparison request.
-/
def loadIncomeExpense
    (dataDir actualRoot : System.FilePath)
    (leftStart leftEndExclusive rightStart rightEndExclusive : String) :
    IO (Except String (Pair Loam.RoleFlowReview.Snapshot)) := do
  let actualPath := Loam.ActualAuthority.actualPathFromRootOrFile actualRoot
  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualPath with
    | .error message => return .error message
    | .ok image => pure image
  let rolesPath := Loam.HouseholdPaths.accountingRole dataDir
  if !(← rolesPath.pathExists) then
    return .error "loam: required AccountingRole evidence is missing"
  let roles ←
    match ← loadAccountingRoleMap? rolesPath with
    | some roles => pure roles
    | none => return .error "loam: malformed or unsupported AccountingRole evidence"
  let records := Loam.ActualReview.recordsFromActualImage image
  return incomeExpense records roles
    leftStart leftEndExclusive rightStart rightEndExclusive

end Loam.PeriodComparisonReview
