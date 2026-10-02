import Loam.Authority.ActualAuthority
import Loam.Review.BudgetWindowReview
import Loam.Review.ConditionalBalancePathReview
import Loam.Review.IncomeExpenseProvenanceReview
import Loam.Authority.LocusAdmissionAuthority
import Loam.Presentation.LocusCatalog
import Loam.Review.LocusTrendCompareReview
import Loam.Review.MultimeasureSpendReview
import Loam.Presentation.MeasurePresentation
import Loam.Review.PeriodComparisonReview
import Loam.Review.RoleBalanceReview
import Loam.Review.RoleFlowReview
import Loam.Review.StockFlowReview
import Loam.Review.TransactionsFlowReview
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

Mouse-wheel input is normalized to Up/Down before it reaches this session, and
j/k are the keyboard aliases for the same high-frequency vertical navigation.
Running `stty size` for every wheel notch or j/k repeat can queue subprocess
latency behind ordinary scrolling, especially on long report surfaces. Other
actionable keys still refresh the terminal geometry, so a resize is picked up at
the next non-scroll interaction.
-/
def refreshBoundsForKey : Loam.Tui.Terminal.Key → Bool
  | .up | .down
  | .input 'j' | .input 'J' | .input 'k' | .input 'K' => false
  | .other | .pointer _ _ | .pointerDrag _ _ | .pointerMotion _ _ => false
  | _ => true

private def scrollDirection? : Loam.Tui.Terminal.Key → Option Bool
  | .up | .input 'k' | .input 'K' => some false
  | .down | .input 'j' | .input 'J' => some true
  | _ => none

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

private partial def loop (bounds : Bounds)
    (dataDir root : System.FilePath)
    (state : Loam.Tui.Reports.State)
    (prepared : Option Loam.Tui.Reports.PreparedScrollView)
    (frame : Loam.Tui.Runtime.CompiledWidget) : IO Bounds := do
  let key ← Loam.Tui.Terminal.readKey
  match prepared, scrollDirection? key with
  | some cached, some forward =>
      let next := Loam.Tui.Reports.scrollPrepared state cached forward
      let nextView := Loam.Tui.Reports.viewPreparedScroll bounds next cached
      let nextFrame := Loam.Tui.Runtime.compileWidget nextView
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      loop bounds dataDir root next prepared nextFrame
  | _, _ =>
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
            match ← Loam.BudgetWindowReview.loadSnapshotForMeasure
                step.state.measure dataDir root start endExclusive with
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
        | some (.locusTrendCompare observedAt granularity scope series) =>
            match ← Loam.LocusTrendCompareReview.loadConfiguredAtScope
                dataDir root observedAt granularity scope series with
            | .error message => pure (Loam.Tui.Reports.withTrendError step.state message)
            | .ok snapshot =>
                match ← Loam.MeasurePresentation.loadMetadata dataDir with
                | .error message => pure (Loam.Tui.Reports.withTrendError step.state message)
                | .ok presentation =>
                    pure (Loam.Tui.Reports.withLocusTrendCompareSnapshot
                      step.state snapshot presentation)
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
      let hadButtonMotion := state.mode == .locusTrendCompare
      let wantsButtonMotion := next.mode == .locusTrendCompare
      if hadButtonMotion != wantsButtonMotion then
        Loam.Tui.Terminal.setButtonMotion wantsButtonMotion
      let nextPrepared := Loam.Tui.Reports.prepareScrollView? activeBounds next
      let nextView :=
        match nextPrepared with
        | some cached => Loam.Tui.Reports.viewPreparedScroll activeBounds next cached
        | none => Loam.Tui.Reports.viewForBounds activeBounds next
      Loam.Tui.Terminal.redrawWidgetDirect activeBounds nextView
      let nextFrame := Loam.Tui.Runtime.compileWidget nextView
      loop activeBounds dataDir root next nextPrepared nextFrame

/-- Reports session; q/Esc moves back one level and eventually returns Home. -/
def run (bounds : Bounds)
    (dataDir root : System.FilePath)
    (state : Loam.Tui.Reports.State) : IO Bounds := do
  let prepared := Loam.Tui.Reports.prepareScrollView? bounds state
  let initialView :=
    match prepared with
    | some cached => Loam.Tui.Reports.viewPreparedScroll bounds state cached
    | none => Loam.Tui.Reports.viewForBounds bounds state
  let frame := Loam.Tui.Runtime.compileWidget initialView
  loop bounds dataDir root state prepared frame


end Loam.Tui.ReportsSession
