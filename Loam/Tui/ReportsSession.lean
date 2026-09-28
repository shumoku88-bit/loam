import Loam.BudgetWindowReview
import Loam.ConditionalBalancePathReview
import Loam.IncomeExpenseProvenanceReview
import Loam.LocusTrendReview
import Loam.LocusTrendCompareReview
import Loam.MultimeasureSpendReview
import Loam.MeasurePresentation
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
    (state : Loam.Tui.Reports.State) (frame : CompiledWidget) : IO Bounds := do
  let key ← Loam.Tui.Terminal.readKey
  let activeBounds ←
    match key with
    | .other | .pointer _ _ | .pointerMotion _ _ => pure bounds
    | _ => Loam.Tui.Terminal.currentBounds
  let resized := activeBounds != bounds
  let step := Loam.Tui.Reports.updateForBounds activeBounds state key
  if step.back then return activeBounds
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
        match ← Loam.IncomeExpenseProvenanceReview.loadSnapshot
            dataDir root start endExclusive with
        | .ok snapshot => pure (Loam.Tui.Reports.withIncomeExpenseSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some (.incomeExpenseCompare leftStart leftEnd rightStart rightEnd) =>
        match ← Loam.PeriodComparisonReview.loadIncomeExpense
            dataDir root leftStart leftEnd rightStart rightEnd with
        | .ok comparison =>
            pure (Loam.Tui.Reports.withIncomeExpenseComparison step.state comparison)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some (.multimeasureSpend start endExclusive) =>
        match ← Loam.MultimeasureSpendReview.loadSnapshot
            dataDir root start endExclusive with
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
        | .ok snapshot =>
            match ← Loam.MeasurePresentation.loadMetadata dataDir with
            | .error message => pure (Loam.Tui.Reports.withError step.state message)
            | .ok presentation =>
                pure (Loam.Tui.Reports.withMultimeasureSpendSnapshot
                  step.state snapshot presentation)
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
    | some (.locusTrendCompare observedAt granularity series) =>
        match ← Loam.LocusTrendCompareReview.loadConfiguredAtGranularity
            dataDir root observedAt granularity series with
        | .ok snapshot =>
            pure (Loam.Tui.Reports.withLocusTrendCompareSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withTrendError step.state message)
    | some (.locusTrendOverview observedAt coordinate) =>
        match ← Loam.LocusTrendReview.loadConfiguredOverview
            dataDir root observedAt coordinate with
        | .ok snapshot => pure (Loam.Tui.Reports.withLocusTrendOverview step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withTrendError step.state message)
    | some (.locusTrendHistory observedAt coordinate) =>
        match ← Loam.LocusTrendReview.loadConfiguredHistory
            dataDir root observedAt coordinate with
        | .ok snapshot => pure (Loam.Tui.Reports.withLocusTrendHistory step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withTrendError step.state message)
    | some (.locusTrend start endExclusive coordinate) =>
        match ← Loam.LocusTrendReview.loadSnapshot
            root start endExclusive coordinate with
        | .ok snapshot => pure (Loam.Tui.Reports.withLocusTrendSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withTrendError step.state message)
    | some .favaProjection =>
        let notice ← Loam.Tui.FavaLaunch.launch dataDir root
        pure { step.state with notice := notice }
  /-
  Only the single-Locus Trend keeps hover-style all-pointer-motion reporting.
  Trend Compare uses ordinary button reporting from Terminal.enter, so a click
  selects one period without the cursor continuing to chase later mouse motion.
  -/
  let hadPointerMotion := state.mode == .locusTrend
  let wantsPointerMotion := next.mode == .locusTrend
  if hadPointerMotion != wantsPointerMotion then
    Loam.Tui.Terminal.setPointerMotion wantsPointerMotion
  let nextFrame := compileWidget (Loam.Tui.Reports.viewForBounds activeBounds next)
  if resized then
    Loam.Tui.Terminal.redrawFromBlank activeBounds nextFrame
  else
    Loam.Tui.Terminal.emitDirtyDiff activeBounds 0 0 frame nextFrame
  run activeBounds dataDir root next nextFrame


end Loam.Tui.ReportsSession
