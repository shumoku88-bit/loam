import Loam.ActualAuthority
import Loam.ActualReview
import Loam.BalanceReview
import Loam.HouseholdPaths
import Loam.IncomeExpenseProvenanceReview
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

/-- Run the provenance-aware Income / Expense projection twice over one source image. -/
def incomeExpense
    (evidence : Loam.IncomeExpenseProvenanceReview.Evidence)
    (leftStart leftEndExclusive rightStart rightEndExclusive : String) :
    Except String (Pair Loam.IncomeExpenseProvenanceReview.Snapshot) := do
  let left ←
    Loam.IncomeExpenseProvenanceReview.project
      evidence leftStart leftEndExclusive
  let right ←
    Loam.IncomeExpenseProvenanceReview.project
      evidence rightStart rightEndExclusive
  return { left, right }

/--
Load both Income & Expense answers from one coherent Actual/Scheduled source cut.

Both visible periods therefore share one correction-aware Actual image, one
AccountingRole image, and one Scheduled lifecycle observation. Scheduled
provenance remains an overlay; no comparison arithmetic is introduced here.
-/
def loadIncomeExpense
    (dataDir actualRoot : System.FilePath)
    (leftStart leftEndExclusive rightStart rightEndExclusive : String) :
    IO (Except String (Pair Loam.IncomeExpenseProvenanceReview.Snapshot)) := do
  let evidence ←
    match ← Loam.IncomeExpenseProvenanceReview.loadEvidence dataDir actualRoot with
    | .ok evidence => pure evidence
    | .error message => return .error message
  return incomeExpense evidence
    leftStart leftEndExclusive rightStart rightEndExclusive

end Loam.PeriodComparisonReview
