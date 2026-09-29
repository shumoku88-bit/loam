import Loam.ActualAuthority
import Loam.BudgetWindowReview
import Loam.ConditionalBalancePathReview
import Loam.IncomeExpenseProvenanceReview
import Loam.LocusAdmissionAuthority
import Loam.LocusCatalog
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

set_option autoImplicit false

/-!
# Reports workspace session

Owns only the TUI orchestration that turns a Reports query into an existing
shared Review answer and redraws the Reports workspace. Household semantics,
query meaning, and report rendering remain in their existing owners.
-/

/--
High-frequency vertical navigation reuses the already observed terminal bounds.

Mouse-wheel input is normalized to Up/Down before it reaches this session. Running
`stty size` for every wheel notch can queue subprocess latency behind ordinary
scrolling, especially on long report surfaces. Other actionable keys still
refresh the terminal geometry, so a resize is picked up at the next non-scroll
interaction.
-/
def refreshBoundsForKey : Loam.Tui.Terminal.Key → Bool
  | .up | .down => false
  | .other | .pointer _ _ | .pointerDrag _ _ | .pointerMotion _ _ => false
  | _ => true

private def currentTrendCatalog
    (dataDir root : System.FilePath) : IO Loam.LocusCatalog.Catalog := do
  let admitted ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? dataDir with
    | .ok vocabulary => pure vocabulary.approved
    | .error _ => pure []
  let historical ←
    match ← Loam.ActualAuthority.loadImage? root with
    | .ok image =>
        pure <| image.evidence.events.events.flatMap fun event =>
          event.effects.map fun effect => effect.coordinate.locus
    | .error _ => pure []
  let metadata ←
    match ← Loam.LocusCatalog.loadMetadata dataDir with
    | .ok metadata => pure metadata
    | .error _ => pure []
  pure <| Loam.LocusCatalog.forLoci (admitted ++ historical) metadata

/-- Reports session; q/Esc moves back one level and eventually returns Home. -/
partial def run (bounds : Bounds)
    (dataDir root : System.FilePath)
    (state : Loam.Tui.Reports.State) : IO Bounds := do
  let key ← Loam.Tui.Terminal.readKey
  let activeBounds ←
    if refreshBoundsForKey key then
      Loam.Tui.Terminal.currentBounds
    else
      pure bounds
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
    | some (.locusTrendCompare observedAt granularity scope series) =>
        match ← Loam.LocusTrendCompareReview.loadConfiguredAtScope
            dataDir root observedAt granularity scope series with
        | .ok snapshot =>
            pure (Loam.Tui.Reports.withLocusTrendCompareSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withTrendError step.state message)
    | some .favaProjection =>
        let notice ← Loam.Tui.FavaLaunch.launch dataDir root
        pure { step.state with notice := notice }
  let next ←
    if state.mode != .locusTrendCompare && next.mode == .locusTrendCompare then
      let catalog ← currentTrendCatalog dataDir root
      pure {
        next with
          trendCompare :=
            Loam.Tui.LocusTrendComparePane.withCatalog next.trendCompare catalog
      }
    else
      pure next
  /-
  Unified Trend uses button-motion reporting: click and drag can scrub periods,
  while passive hover remains inert.
  -/
  let hadButtonMotion := state.mode == .locusTrendCompare
  let wantsButtonMotion := next.mode == .locusTrendCompare
  if hadButtonMotion != wantsButtonMotion then
    Loam.Tui.Terminal.setButtonMotion wantsButtonMotion
  Loam.Tui.Terminal.redrawWidgetDirect
    activeBounds (Loam.Tui.Reports.viewForBounds activeBounds next)
  run activeBounds dataDir root next


end Loam.Tui.ReportsSession
