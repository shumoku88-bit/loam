import Loam.BudgetWindowReview
import Loam.ConditionalBalancePathReview
import Loam.PeriodComparisonReview
import Loam.RoleBalanceReview
import Loam.RoleFlowReview
import Loam.ScheduledCoverageReview
import Loam.StockFlowReview
import Loam.TransactionsFlowReview
import Loam.Tui.FavaLaunch
import Loam.Tui.Kernel
import Loam.Tui.Reports
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.ReportsSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Reports workspace session

Owns only the TUI orchestration that turns a Reports query into an existing
shared Review answer and redraws the Reports workspace. Household semantics,
query meaning, and report rendering remain in their existing owners.
-/

/-- Reports session; q/Esc moves back one level and eventually returns Home. -/
partial def run (bounds : Bounds)
    (dataDir root : System.FilePath)
    (state : Loam.Tui.Reports.State) (frame : CompiledWidget) : IO Unit := do
  let key ← Loam.Tui.Terminal.readKey
  let step := Loam.Tui.Reports.updateForBounds bounds state key
  if step.back then return ()
  let next ←
    match step.query with
    | none => pure step.state
    | some (.budgetWindow start endExclusive) =>
        match ← Loam.BudgetWindowReview.loadSnapshot dataDir root start endExclusive with
        | .ok snapshot => pure (Loam.Tui.Reports.withBudgetSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some (.stockFlow start endExclusive) =>
        match ← Loam.StockFlowReview.loadSnapshot dataDir root start endExclusive with
        | .ok snapshot => pure (Loam.Tui.Reports.withStockFlowSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some (.stockFlowCompare leftStart leftEnd rightStart rightEnd) =>
        match ← Loam.PeriodComparisonReview.loadStockFlow
            dataDir root leftStart leftEnd rightStart rightEnd with
        | .ok comparison =>
            pure (Loam.Tui.Reports.withStockFlowComparison step.state comparison)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some (.transactionsFlow start endExclusive) =>
        match ← Loam.TransactionsFlowReview.loadSnapshot dataDir root start endExclusive with
        | .ok snapshot => pure (Loam.Tui.Reports.withTransactionsFlowSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some (.incomeExpenseFlow start endExclusive) =>
        match ← Loam.RoleFlowReview.loadSnapshot dataDir root start endExclusive with
        | .ok snapshot => pure (Loam.Tui.Reports.withIncomeExpenseSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some (.incomeExpenseCompare leftStart leftEnd rightStart rightEnd) =>
        match ← Loam.PeriodComparisonReview.loadIncomeExpense
            dataDir root leftStart leftEnd rightStart rightEnd with
        | .ok comparison =>
            pure (Loam.Tui.Reports.withIncomeExpenseComparison step.state comparison)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some .roleBalances =>
        match ← Loam.RoleBalanceReview.loadSnapshot dataDir root with
        | .ok snapshot => pure (Loam.Tui.Reports.withRoleBalanceSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some (.conditionalLiquidity assumedCompleteThrough) =>
        match ← Loam.ConditionalBalancePathReview.loadSnapshot
            dataDir root assumedCompleteThrough with
        | .ok snapshot => pure (Loam.Tui.Reports.withLiquiditySnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some (.scheduledCoverage observedAt) =>
        match ← Loam.ScheduledCoverageReview.loadSnapshot
            dataDir root observedAt with
        | .ok snapshot => pure (Loam.Tui.Reports.withScheduledCoverageSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some .favaProjection =>
        let notice ← Loam.Tui.FavaLaunch.launch dataDir root
        pure { step.state with notice := notice }
  let nextFrame := compileWidget (Loam.Tui.Reports.viewForBounds bounds next)
  Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
  run bounds dataDir root next nextFrame


end Loam.Tui.ReportsSession
