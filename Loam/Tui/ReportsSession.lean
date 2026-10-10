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
import Loam.Tui.PlainTextPrint

namespace Loam.Tui.ReportsSession

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
Reports orchestration only. Typed entrances and within-report reruns use the same
shared Review queries. No household semantics or publication authority live here.
-/

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

/-- The same execution boundary for initial queries and later Run/retry actions. -/
def executeStep (dataDir root : System.FilePath)
    (step : Loam.Tui.Reports.Step) : IO Loam.Tui.Reports.State := do
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
      | .ok comparison => pure (Loam.Tui.Reports.withStockFlowComparison step.state comparison)
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
      | .ok comparison => pure (Loam.Tui.Reports.withIncomeExpenseComparison step.state comparison)
      | .error message => pure (Loam.Tui.Reports.withError step.state message)
  | some (.multimeasureSpend start endExclusive) =>
      match ← Loam.MultimeasureSpendReview.loadSnapshot dataDir root start endExclusive with
      | .error message => pure (Loam.Tui.Reports.withError step.state message)
      | .ok snapshot =>
          match ← Loam.MeasurePresentation.loadMetadata dataDir with
          | .error message => pure (Loam.Tui.Reports.withError step.state message)
          | .ok presentation =>
              pure (Loam.Tui.Reports.withMultimeasureSpendSnapshot step.state snapshot presentation)
  | some .roleBalances =>
      match ← Loam.RoleBalanceReview.loadSnapshot dataDir root with
      | .ok snapshot => pure (Loam.Tui.Reports.withRoleBalanceSnapshot step.state snapshot)
      | .error message => pure (Loam.Tui.Reports.withError step.state message)
  | some (.conditionalLiquidity assumedCompleteThrough) =>
      match ← Loam.ConditionalBalancePathReview.loadSnapshot dataDir root assumedCompleteThrough with
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
              pure (Loam.Tui.Reports.withLocusTrendCompareSnapshot step.state snapshot presentation)
  | some .favaProjection =>
      let notice ← Loam.Tui.FavaLaunch.launch dataDir root
      pure { step.state with notice := notice }

private partial def loop (bounds : Bounds)
    (dataDir root : System.FilePath)
    (state : Loam.Tui.Reports.State)
    (prepared : Option Loam.Tui.Reports.PreparedScrollView)
    (frame : Loam.Tui.Runtime.CompiledWidget) : IO Bounds := do
  let (key, repeatCount) ← Loam.Tui.Terminal.readKeyWithRepeat
  let activeBounds ← Loam.Tui.Terminal.currentBounds
  let prepared :=
    if activeBounds == bounds then prepared
    else Loam.Tui.Reports.prepareScrollView? activeBounds state
  let frame ←
    if activeBounds == bounds then pure frame
    else do
      let view := match prepared with
        | some cached => Loam.Tui.Reports.viewPreparedScroll activeBounds state cached
        | none => Loam.Tui.Reports.viewForBounds activeBounds state
      let next := Loam.Tui.Runtime.compileWidget view
      Loam.Tui.Terminal.redrawFromBlank activeBounds next
      pure next
  let bounds := activeBounds
  if key == .other then return (← loop bounds dataDir root state prepared frame)
  if state.mode == .balances && (key == .input 'p' || key == .input 'P') then
    match Loam.Tui.Reports.prepareBalancesPrint state with
    | .error message =>
        let next := { state with notice := message }
        let nextFrame := Loam.Tui.Runtime.compileWidget
          (Loam.Tui.Reports.viewForBounds bounds next)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        return (← loop bounds dataDir root next prepared nextFrame)
    | .ok report =>
        Loam.Tui.PlainTextPrint.run "Reports / Balances" report
        let active ← Loam.Tui.Terminal.currentBounds
        let view := Loam.Tui.Reports.viewForBounds active state
        let nextFrame := Loam.Tui.Runtime.compileWidget view
        Loam.Tui.Terminal.redrawFromBlank active nextFrame
        return (← loop active dataDir root state prepared nextFrame)
  match prepared, scrollDirection? key with
  | some cached, some forward =>
      let next := Loam.Tui.Reports.scrollPrepared state cached forward repeatCount
      let nextView := Loam.Tui.Reports.viewPreparedScroll bounds next cached
      let nextFrame := Loam.Tui.Runtime.compileWidget nextView
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      loop bounds dataDir root next prepared nextFrame
  | _, _ =>
      let step := Loam.Tui.Reports.updateForBoundsWithRepeat bounds state key repeatCount
      if step.back then return bounds
      let next ← executeStep dataDir root step
      let nextPrepared := Loam.Tui.Reports.prepareScrollView? bounds next
      let nextView :=
        match nextPrepared with
        | some cached => Loam.Tui.Reports.viewPreparedScroll bounds next cached
        | none => Loam.Tui.Reports.viewForBounds bounds next
      let nextFrame := Loam.Tui.Runtime.compileWidget nextView
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      loop bounds dataDir root next nextPrepared nextFrame

/-- Direct entrance. Returns an external-launch notice to Home; internal reports
pop their own nested state before returning Home. Trend mouse mode has bounded lifetime. -/
def run (dataDir root : System.FilePath)
    (destination : Loam.Tui.Reports.Destination)
    (base : Loam.Tui.Reports.State) : IO (Bounds × String) := do
  let state ← executeStep dataDir root (Loam.Tui.Reports.openReport destination base)
  let bounds ← Loam.Tui.Terminal.currentBounds
  if destination == .favaProjection then return (bounds, state.notice)
  let state ←
    if destination == .locusTrendCompare then
      let catalog ← currentTrendCatalog dataDir root
      pure { state with trendCompare :=
        Loam.Tui.LocusTrendComparePane.withCatalog state.trendCompare catalog }
    else pure state
  let prepared := Loam.Tui.Reports.prepareScrollView? bounds state
  let initialView :=
    match prepared with
    | some cached => Loam.Tui.Reports.viewPreparedScroll bounds state cached
    | none => Loam.Tui.Reports.viewForBounds bounds state
  let frame := Loam.Tui.Runtime.compileWidget initialView
  Loam.Tui.Terminal.redrawFromBlank bounds frame
  Loam.Tui.Terminal.setButtonMotion (destination == .locusTrendCompare)
  try
    let finalBounds ← loop bounds dataDir root state prepared frame
    return (finalBounds, "")
  finally
    Loam.Tui.Terminal.setButtonMotion false

end Loam.Tui.ReportsSession
