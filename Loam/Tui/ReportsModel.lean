import Loam.ActualDate
import Loam.Config.BoundaryPresetConfig
import Loam.Review.BudgetWindowReview
import Loam.Review.ConditionalBalancePathReview
import Loam.Review.IncomeExpenseProvenanceReview
import Loam.Presentation.LocusCatalog
import Loam.Review.LocusTrendCompareReview
import Loam.Review.MultimeasureSpendReview
import Loam.Presentation.MeasurePresentation
import Loam.Review.PeriodComparisonReview
import Loam.Review.StockFlowReview
import Loam.Review.TransactionsFlowReview
import Loam.Review.RoleFlowReview
import Loam.Review.RoleBalanceReview
import Loam.Tui.ReportDestination
import Loam.Tui.ReportComparison
import Loam.Tui.ReportWindow
import Loam.Tui.LocusTrendComparePane
import Loam.Tui.TransactionsFlowPane
import Loam.Tui.Calendar
import Loam.Tui.Terminal

namespace Loam.Tui.Reports

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Production Reports workspace

Reports is presentation and query state only. Stock–Flow, Transactions Flow,
Income & Expense, Balances, and Budget Window consume surface-independent shared
review answers. Income & Expense composes the explicit RoleFlow boundary and Balances
projects the explicit RoleBalance boundary without adding named accounting engines.
Liquidity keeps its unconditional UNKNOWN baseline while
also exposing the read-only conditional selected-balance path earned by
Observations 229 and 231.
-/

inductive Mode where
  | stockFlow
  | stockFlowCompare
  | transactionsFlow
  | incomeExpense
  | incomeExpenseCompare
  | multimeasureSpend
  | balances
  | liquidity
  | budgetWindow
  | locusTrendCompare
  deriving Repr, DecidableEq

structure LiquidityForm where
  assumedCompleteThrough : String := ""
  focus : Fin 2 := ⟨0, by decide⟩
  deriving Repr, DecidableEq

inductive IncomeExpenseDisplay where
  | summary
  | monthly
  | daily
  deriving Repr, DecidableEq

namespace IncomeExpenseDisplay

def next : IncomeExpenseDisplay → IncomeExpenseDisplay
  | .summary => .monthly
  | .monthly => .daily
  | .daily => .summary

def label : IncomeExpenseDisplay → String
  | .summary => "Summary"
  | .monthly => "Monthly"
  | .daily => "Daily"

end IncomeExpenseDisplay

inductive Query where
  | stockFlow (start endExclusive : String)
  | stockFlowCompare
      (leftStart leftEndExclusive rightStart rightEndExclusive : String)
  | transactionsFlow (start endExclusive : String)
  | incomeExpenseFlow (start endExclusive : String)
  | incomeExpenseCompare
      (leftStart leftEndExclusive rightStart rightEndExclusive : String)
  | multimeasureSpend (start endExclusive : String)
  | roleBalances
  | conditionalLiquidity (assumedCompleteThrough : String)
  | budgetWindow (start endExclusive : String)
  | locusTrendCompare
      (observedAt : String)
      (granularity : Loam.LocusTrendCompareReview.Granularity)
      (scope : Loam.LocusTrendCompareReview.Scope)
      (series : List Loam.LocusTrendCompareReview.SeriesSpec)
  | favaProjection
  deriving Repr, DecidableEq

def defaultTrendCompareSeriesForMeasure
    (measure : Loam.Core.MeasureId) : List Loam.LocusTrendCompareReview.SeriesSpec :=
  [ { label := "Tobacco", coordinate := ⟨⟨"tobacco"⟩, measure⟩ }
  , { label := "Coffee", coordinate := ⟨⟨"coffee"⟩, measure⟩ }
  , { label := "Food", coordinate := ⟨⟨"food"⟩, measure⟩ }
  ]

def defaultTrendCompareSeries : List Loam.LocusTrendCompareReview.SeriesSpec :=
  defaultTrendCompareSeriesForMeasure ⟨"jpy"⟩

structure State where
  measure : Loam.Core.MeasureId := ⟨"jpy"⟩
  mode : Mode := .stockFlow
  window : Loam.Tui.ReportWindow.State := {}
  comparison : Loam.Tui.ReportComparison.State := {}
  liquidityForm : LiquidityForm := {}
  stockFlowSnapshot : Option Loam.StockFlowReview.Snapshot := none
  stockFlowComparison :
    Option (Loam.PeriodComparisonReview.Pair Loam.StockFlowReview.Snapshot) := none
  transactions : Loam.Tui.TransactionsFlowPane.State := {}
  incomeExpenseDisplay : IncomeExpenseDisplay := .summary
  incomeExpenseSnapshot : Option Loam.IncomeExpenseProvenanceReview.Snapshot := none
  incomeExpenseComparison :
    Option (Loam.PeriodComparisonReview.Pair Loam.IncomeExpenseProvenanceReview.Snapshot) := none
  multimeasureSpendSnapshot : Option Loam.MultimeasureSpendReview.Snapshot := none
  multimeasurePresentation : List Loam.MeasurePresentation.Metadata := []
  roleBalanceSnapshot : Option Loam.RoleBalanceReview.Snapshot := none
  liquiditySnapshot : Option Loam.ConditionalBalancePathReview.Snapshot := none
  budgetSnapshot : Option Loam.BudgetWindowReview.Snapshot := none
  trendCompareSeries : List Loam.LocusTrendCompareReview.SeriesSpec :=
    defaultTrendCompareSeries
  trendCompare : Loam.Tui.LocusTrendComparePane.State := {}
  notice : String := ""
  scroll : Nat := 0

structure Step where
  state : State
  back : Bool := false
  query : Option Query := none


def initial : State := {}

private def liquidityFormForEndExclusive (endExclusive : String) : LiquidityForm :=
  match Loam.ActualDate.shiftDays? endExclusive (-1) with
  | some through =>
      { assumedCompleteThrough := through, focus := ⟨1, by decide⟩ }
  | none => {}

/--
Seed the shared explicit-window editor with the Gregorian month containing the
Home selected day. Named presets remain replaceable presentation/query
configuration; they are resolved to explicit coordinates before any report query
is emitted. The conditional outlook keeps its independent editable assumption
horizon and is not executed until the user explicitly runs it.
-/
def initialForDateWithPresetsForMeasure
    (measure : Loam.Core.MeasureId)
    (selectedDate : String)
    (presets : List Loam.BoundaryPresetConfig.Preset) : State :=
  let windowResult := Loam.Tui.ReportWindow.initialForDateWithPresets selectedDate presets
  {
    measure := measure
    mode := .stockFlow
    window := windowResult.state
    liquidityForm := liquidityFormForEndExclusive windowResult.state.form.endExclusive
    trendCompareSeries := defaultTrendCompareSeriesForMeasure measure
    notice := windowResult.notice
  }

/-- Backward-compatible Reports initializer for the current JPY household. -/
def initialForDateWithPresets
    (selectedDate : String)
    (presets : List Loam.BoundaryPresetConfig.Preset) : State :=
  initialForDateWithPresetsForMeasure ⟨"jpy"⟩ selectedDate presets

def initialForDateForMeasure
    (measure : Loam.Core.MeasureId) (selectedDate : String) : State :=
  initialForDateWithPresetsForMeasure measure selectedDate []

/-- Compatibility initializer when no named presets were loaded. -/
def initialForDate (selectedDate : String) : State :=
  initialForDateForMeasure ⟨"jpy"⟩ selectedDate


def withStockFlowSnapshot
    (state : State) (snapshot : Loam.StockFlowReview.Snapshot) : State :=
  { state with stockFlowSnapshot := some snapshot, notice := "", scroll := 0 }


def withStockFlowComparison
    (state : State)
    (comparison : Loam.PeriodComparisonReview.Pair Loam.StockFlowReview.Snapshot) : State :=
  { state with stockFlowComparison := some comparison, notice := "", scroll := 0 }


def withTransactionsFlowSnapshot
    (state : State) (snapshot : Loam.TransactionsFlowReview.Snapshot) : State :=
  { state with
      transactions := Loam.Tui.TransactionsFlowPane.withSnapshot state.transactions snapshot
      notice := ""
      scroll := 0 }


def withIncomeExpenseSnapshot
    (state : State) (snapshot : Loam.IncomeExpenseProvenanceReview.Snapshot) : State :=
  { state with incomeExpenseSnapshot := some snapshot, notice := "", scroll := 0 }


def withIncomeExpenseComparison
    (state : State)
    (comparison :
      Loam.PeriodComparisonReview.Pair Loam.IncomeExpenseProvenanceReview.Snapshot) : State :=
  { state with incomeExpenseComparison := some comparison, notice := "", scroll := 0 }


def withMultimeasureSpendSnapshot
    (state : State)
    (snapshot : Loam.MultimeasureSpendReview.Snapshot)
    (presentation : List Loam.MeasurePresentation.Metadata) : State :=
  { state with
      multimeasureSpendSnapshot := some snapshot
      multimeasurePresentation := presentation
      notice := ""
      scroll := 0 }


def withRoleBalanceSnapshot
    (state : State) (snapshot : Loam.RoleBalanceReview.Snapshot) : State :=
  { state with roleBalanceSnapshot := some snapshot, notice := "", scroll := 0 }


def withLiquiditySnapshot
    (state : State) (snapshot : Loam.ConditionalBalancePathReview.Snapshot) : State :=
  { state with liquiditySnapshot := some snapshot, notice := "", scroll := 0 }


def withBudgetSnapshot
    (state : State) (snapshot : Loam.BudgetWindowReview.Snapshot) : State :=
  { state with budgetSnapshot := some snapshot, notice := "", scroll := 0 }


def withLocusTrendCompareSnapshot
    (state : State)
    (snapshot : Loam.LocusTrendCompareReview.Snapshot)
    (presentation : List Loam.MeasurePresentation.Metadata := []) : State :=
  { state with
      trendCompare := Loam.Tui.LocusTrendComparePane.withSnapshot
        (Loam.Tui.LocusTrendComparePane.withMeasurePresentation
          state.trendCompare presentation)
        snapshot
      notice := ""
      scroll := 0 }


def withTrendError (state : State) (message : String) : State :=
  { state with notice := message, scroll := 0 }


def withError (state : State) (message : String) : State :=
  { state with
      stockFlowSnapshot := none
      stockFlowComparison := none
      transactions := Loam.Tui.TransactionsFlowPane.initial
      incomeExpenseSnapshot := none
      incomeExpenseComparison := none
      multimeasureSpendSnapshot := none
      roleBalanceSnapshot := none
      liquiditySnapshot := none
      budgetSnapshot := none
      trendCompare := Loam.Tui.LocusTrendComparePane.clear state.trendCompare
      notice := message
      scroll := 0 }

private def clearResults (state : State) : State :=
  { state with
      stockFlowSnapshot := none
      stockFlowComparison := none
      transactions := Loam.Tui.TransactionsFlowPane.initial
      incomeExpenseSnapshot := none
      incomeExpenseComparison := none
      multimeasureSpendSnapshot := none
      roleBalanceSnapshot := none
      liquiditySnapshot := none
      budgetSnapshot := none
      trendCompare := Loam.Tui.LocusTrendComparePane.clear state.trendCompare
      scroll := 0 }


private def clearComparisonResults (state : State) : State :=
  { state with
      stockFlowComparison := none
      incomeExpenseComparison := none
      scroll := 0 }

private def beginComparison (state : State) (mode : Mode) : State :=
  { (clearComparisonResults state) with
      mode := mode
      comparison := Loam.Tui.ReportComparison.fromWindow state.window
      notice := ""
      scroll := 0 }

private def editComparisonState
    (state : State) (edit : String → String) : State :=
  clearComparisonResults {
    state with
      comparison := Loam.Tui.ReportComparison.editActive state.comparison edit
      notice := ""
  }

private def applyComparisonResult
    (state : State) (result : Loam.Tui.ReportComparison.Result) : State :=
  clearComparisonResults {
    state with comparison := result.state, notice := result.notice
  }

private def cycleComparisonSource (state : State) (forward : Bool) : State :=
  applyComparisonResult state
    (Loam.Tui.ReportComparison.cycleSource state.comparison forward)

private def shiftComparisonPair (state : State) (forward : Bool) : State :=
  let result := Loam.Tui.ReportComparison.shiftPair state.comparison forward
  if result.state = state.comparison then
    { state with notice := result.notice }
  else
    applyComparisonResult state result

private def beginCustomComparisonEditing (state : State) : State :=
  clearComparisonResults {
    state with
      comparison := Loam.Tui.ReportComparison.beginCustomEditing state.comparison
      notice := ""
  }

private def moveLiquidityFocus (form : LiquidityForm) : LiquidityForm :=
  let next := (form.focus.val + 1) % 2
  { form with focus := ⟨next, by
      dsimp [next]
      exact Nat.mod_lt _ (by decide)⟩ }

private def editLiquidityActive
    (form : LiquidityForm) (edit : String → String) : LiquidityForm :=
  if form.focus.val = 0 then
    { form with assumedCompleteThrough := edit form.assumedCompleteThrough }
  else
    form

private def applyWindowResult
    (state : State) (result : Loam.Tui.ReportWindow.Result) : State :=
  clearResults { state with window := result.state, notice := result.notice }

private def resetCalendarMonth (state : State) : State :=
  applyWindowResult state (Loam.Tui.ReportWindow.resetCalendarMonth state.window)

private def cycleWindowSource (state : State) (forward : Bool) : State :=
  applyWindowResult state (Loam.Tui.ReportWindow.cycleSource state.window forward)

private def shiftCalendarMonth (state : State) (forward : Bool) : State :=
  let result := Loam.Tui.ReportWindow.shiftCalendarMonth state.window forward
  if result.state = state.window then
    { state with notice := result.notice }
  else
    applyWindowResult state result

private def editWindowState (state : State) (edit : String → String) : State :=
  clearResults {
    state with
      window := Loam.Tui.ReportWindow.editActive state.window edit
      notice := ""
  }

/-- Human-readable label for presentation only; it never enters a report query. -/
def windowSourceLabel (state : State) : String :=
  Loam.Tui.ReportWindow.sourceLabel state.window

/-- Human-readable comparison source label only; it never enters a report query. -/
def comparisonSourceLabel (state : State) : String :=
  Loam.Tui.ReportComparison.sourceLabel state.comparison

private def resetLiquidityHorizon (state : State) : State :=
  match Loam.Tui.Calendar.calendarMonthWindowForDate? state.window.calendarAnchor with
  | some (_, endExclusive) =>
      { (clearResults state) with
          liquidityForm := liquidityFormForEndExclusive endExclusive
          notice := "" }
  | none =>
      withError state "Conditional horizon reset unavailable; enter an explicit date."

/-- Typed launch plan. Editable windows still wait for Run; balances and Trend
load immediately. Fava is an external action, not an internal report screen. -/
def openReport (destination : Destination) (base : State) : Step :=
  let mode := match destination with
    | .stockFlow => Mode.stockFlow
    | .transactionsFlow => Mode.transactionsFlow
    | .incomeExpense => Mode.incomeExpense
    | .balances => Mode.balances
    | .liquidity => Mode.liquidity
    | .budgetWindow => Mode.budgetWindow
    | .multimeasureSpend => Mode.multimeasureSpend
    | .locusTrendCompare => Mode.locusTrendCompare
    | .favaProjection => base.mode
  let next := { base with mode := mode, scroll := 0 }
  let query := match destination with
    | .balances => some Query.roleBalances
    | .locusTrendCompare =>
        some (.locusTrendCompare
          next.window.calendarAnchor next.trendCompare.granularity
          (Loam.Tui.LocusTrendComparePane.effectiveScope next.trendCompare)
          next.trendCompareSeries)
    | .favaProjection => some .favaProjection
    | _ => none
  { state := next, query }

private def queryForMode (state : State) : Option Query :=
  match state.mode with
  | .stockFlow => some (.stockFlow state.window.form.start state.window.form.endExclusive)
  | .transactionsFlow => some (.transactionsFlow state.window.form.start state.window.form.endExclusive)
  | .incomeExpense => some (.incomeExpenseFlow state.window.form.start state.window.form.endExclusive)
  | .multimeasureSpend => some (.multimeasureSpend state.window.form.start state.window.form.endExclusive)
  | .budgetWindow => some (.budgetWindow state.window.form.start state.window.form.endExclusive)
  | .locusTrendCompare =>
      some (.locusTrendCompare
        state.window.calendarAnchor state.trendCompare.granularity
        (Loam.Tui.LocusTrendComparePane.effectiveScope state.trendCompare)
        state.trendCompareSeries)
  | _ => none

private def comparisonQueryForMode (state : State) : Option Query :=
  let form := state.comparison
  match state.mode with
  | .stockFlowCompare =>
      some (.stockFlowCompare
        form.leftStart form.leftEndExclusive form.rightStart form.rightEndExclusive)
  | .incomeExpenseCompare =>
      some (.incomeExpenseCompare
        form.leftStart form.leftEndExclusive form.rightStart form.rightEndExclusive)
  | _ => none

private def updateComparison
    (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'q' | .input 'Q' =>
      let mode :=
        match state.mode with
        | .stockFlowCompare => Mode.stockFlow
        | .incomeExpenseCompare => Mode.incomeExpense
        | other => other
      { state := { state with mode := mode, notice := "", scroll := 0 } }
  | .up | .input 'k' | .input 'K' =>
      { state := { state with scroll := state.scroll - 1 } }
  | .down | .input 'j' | .input 'J' =>
      { state := { state with scroll := state.scroll + 1 } }
  | .left => { state := shiftComparisonPair state false }
  | .right => { state := shiftComparisonPair state true }
  | .input '[' => { state := cycleComparisonSource state false }
  | .input ']' => { state := cycleComparisonSource state true }
  | .input 'e' | .input 'E' =>
      { state := beginCustomComparisonEditing state }
  | .tab =>
      { state := { state with
          comparison := Loam.Tui.ReportComparison.moveFocus state.comparison false
          notice := "" } }
  | .shiftTab =>
      { state := { state with
          comparison := Loam.Tui.ReportComparison.moveFocus state.comparison true
          notice := "" } }
  | .backspace =>
      if state.comparison.focus.val < 4 then
        { state := editComparisonState state
            (fun text => Loam.Tui.Terminal.backspaceText text) }
      else
        { state }
  | .input char =>
      if state.comparison.focus.val < 4 then
        { state := editComparisonState state (fun text => text.push char) }
      else
        { state }
  | .enter =>
      if state.comparison.focus.val < 4 then
        { state := { state with
            comparison := Loam.Tui.ReportComparison.moveFocus state.comparison false
            notice := "" } }
      else
        { state, query := comparisonQueryForMode state }
  | _ => { state }

private def updateWindowReport (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'q' | .input 'Q' =>
      { state, back := true }
  | .up | .input 'k' | .input 'K' =>
      { state := { state with scroll := state.scroll - 1 } }
  | .down | .input 'j' | .input 'J' =>
      { state := { state with scroll := state.scroll + 1 } }
  | .left => { state := shiftCalendarMonth state false }
  | .right => { state := shiftCalendarMonth state true }
  | .input '[' => { state := cycleWindowSource state false }
  | .input ']' => { state := cycleWindowSource state true }
  | .tab => { state := { state with window := Loam.Tui.ReportWindow.moveFocus state.window false, notice := "" } }
  | .shiftTab => { state := { state with window := Loam.Tui.ReportWindow.moveFocus state.window true, notice := "" } }
  | .backspace =>
      { state := editWindowState state (fun text => Loam.Tui.Terminal.backspaceText text) }
  | .input 'm' | .input 'M' => { state := resetCalendarMonth state }
  | .input char =>
      { state := editWindowState state (fun text => text.push char) }
  | .enter =>
      if state.window.form.focus.val < 2 then
        { state := { state with window := Loam.Tui.ReportWindow.moveFocus state.window false, notice := "" } }
      else
        { state, query := queryForMode state }
  | _ => { state }


private def updateTransactionsFlow
    (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  if state.transactions.detail then
    match key with
    | .escape | .input 'q' | .input 'Q' =>
        { state := { state with
            transactions := Loam.Tui.TransactionsFlowPane.closeDetail state.transactions
            scroll := 0
            notice := "" } }
    | .up | .input 'k' | .input 'K' =>
        { state := { state with scroll := state.scroll - 1 } }
    | .down | .input 'j' | .input 'J' =>
        { state := { state with scroll := state.scroll + 1 } }
    | _ => { state }
  else if !Loam.Tui.TransactionsFlowPane.hasSnapshot state.transactions then
    updateWindowReport state key
  else
    match key with
    | .escape | .input 'q' | .input 'Q' =>
        { state, back := true }
    | .up | .input 'k' | .input 'K' =>
        { state := { state with
            transactions := Loam.Tui.TransactionsFlowPane.moveSelection state.transactions true
            scroll := 0
            notice := "" } }
    | .down | .input 'j' | .input 'J' =>
        { state := { state with
            transactions := Loam.Tui.TransactionsFlowPane.moveSelection state.transactions false
            scroll := 0
            notice := "" } }
    | .left => { state := shiftCalendarMonth state false }
    | .right => { state := shiftCalendarMonth state true }
    | .input '[' => { state := cycleWindowSource state false }
    | .input ']' => { state := cycleWindowSource state true }
    | .tab =>
        { state := { state with window := Loam.Tui.ReportWindow.moveFocus state.window false, notice := "" } }
    | .shiftTab =>
        { state := { state with window := Loam.Tui.ReportWindow.moveFocus state.window true, notice := "" } }
    | .backspace =>
        if state.window.form.focus.val < 2 then
          { state := editWindowState state (fun text => Loam.Tui.Terminal.backspaceText text) }
        else
          { state }
    | .input 'm' | .input 'M' => { state := resetCalendarMonth state }
    | .input char =>
        if state.window.form.focus.val < 2 then
          { state := editWindowState state (fun text => text.push char) }
        else
          { state }
    | .enter =>
        if state.window.form.focus.val < 2 then
          { state := { state with window := Loam.Tui.ReportWindow.moveFocus state.window false, notice := "" } }
        else if Loam.Tui.TransactionsFlowPane.activeRowsEmpty state.transactions then
          { state := { state with notice := "No quantity activity in this window." } }
        else
          { state := { state with
              transactions := Loam.Tui.TransactionsFlowPane.openDetail state.transactions
              scroll := 0
              notice := "" } }
    | _ => { state }

private def rerunAfterWindowResult
    (state : State) (result : Loam.Tui.ReportWindow.Result) : Step :=
  let next := applyWindowResult state result
  { state := next, query := queryForMode next }

private def trendSeriesMeasureForSlot?
    (state : State) (slot : Nat) : Option Loam.Core.MeasureId :=
  match state.trendCompareSeries[slot]? with
  | some spec => some spec.coordinate.measure
  | none => state.trendCompareSeries.head?.map (·.coordinate.measure)

private def replaceTrendSeries
    (state : State) (entry : Loam.LocusCatalog.Entry) : Except String State := do
  let count := state.trendCompareSeries.length
  let slot := min state.trendCompare.pickerSlot count
  if slot >= Loam.Tui.LocusTrendComparePane.maxSeries then
    throw "Trend can display at most five series."
  let some measure := trendSeriesMeasureForSlot? state slot
    | throw "Trend requires at least one active series."
  let spec : Loam.LocusTrendCompareReview.SeriesSpec := {
    label := entry.label
    coordinate := ⟨entry.locus, measure⟩
  }
  let duplicate :=
    state.trendCompareSeries.zipIdx.any fun (current, index) =>
      index != slot && current.coordinate == spec.coordinate
  if duplicate then
    throw "That exact Locus is already active in Trend."
  let series :=
    if slot < count then
      state.trendCompareSeries.zipIdx.map fun (current, index) =>
        if index == slot then spec else current
    else if count < Loam.Tui.LocusTrendComparePane.maxSeries then
      state.trendCompareSeries ++ [spec]
    else
      state.trendCompareSeries
  return {
    state with
      trendCompareSeries := series
      trendCompare := Loam.Tui.LocusTrendComparePane.closeSeriesPicker state.trendCompare
      notice := ""
  }

private def removeTrendSeries (state : State) : Except String State := do
  if state.trendCompareSeries.length <= 1 then
    throw "Trend keeps at least one active series."
  let slot := min state.trendCompare.pickerSlot (state.trendCompareSeries.length - 1)
  let series :=
    state.trendCompareSeries.zipIdx.filterMap fun (spec, index) =>
      if index == slot then none else some spec
  return {
    state with
      trendCompareSeries := series
      trendCompare := Loam.Tui.LocusTrendComparePane.closeSeriesPicker state.trendCompare
      notice := ""
  }

private def updateTrendSeriesPicker
    (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'q' | .input 'Q' =>
      { state := { state with
          trendCompare :=
            Loam.Tui.LocusTrendComparePane.closeSeriesPicker state.trendCompare
          notice := "" } }
  | .up | .input 'k' | .input 'K' =>
      { state := { state with
          trendCompare := Loam.Tui.LocusTrendComparePane.movePicker state.trendCompare true
          notice := "" } }
  | .down | .input 'j' | .input 'J' =>
      { state := { state with
          trendCompare := Loam.Tui.LocusTrendComparePane.movePicker state.trendCompare false
          notice := "" } }
  | .input '1' | .input '2' | .input '3' | .input '4' | .input '5' =>
      let slot :=
        match key with
        | .input '1' => 0
        | .input '2' => 1
        | .input '3' => 2
        | .input '4' => 3
        | _ => 4
      if slot < min Loam.Tui.LocusTrendComparePane.maxSeries
          (state.trendCompareSeries.length + 1) then
        { state := { state with
            trendCompare :=
              Loam.Tui.LocusTrendComparePane.selectPickerSlot state.trendCompare slot
            notice := "" } }
      else
        { state := { state with notice := "Choose an occupied slot or the next empty slot." } }
  | .input 'x' | .input 'X' =>
      match removeTrendSeries state with
      | .ok next => { state := next, query := queryForMode next }
      | .error message => { state := { state with notice := message } }
  | .enter =>
      match Loam.Tui.LocusTrendComparePane.selectedPickerEntry? state.trendCompare with
      | none => { state := { state with notice := "No Trend Locus is available." } }
      | some entry =>
          match replaceTrendSeries state entry with
          | .ok next => { state := next, query := queryForMode next }
          | .error message => { state := { state with notice := message } }
  | _ => { state }

private def updateTrendOverlayEditor
    (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape =>
      { state := { state with
          trendCompare := Loam.Tui.LocusTrendComparePane.cancelOverlay state.trendCompare
          notice := "" } }
  | .tab | .shiftTab =>
      { state := { state with
          trendCompare := Loam.Tui.LocusTrendComparePane.toggleOverlayField state.trendCompare
          notice := "" } }
  | .backspace =>
      { state := { state with
          trendCompare := Loam.Tui.LocusTrendComparePane.backspaceOverlay state.trendCompare
          notice := "" } }
  | .input char =>
      { state := { state with
          trendCompare := Loam.Tui.LocusTrendComparePane.pushOverlayChar state.trendCompare char
          notice := "" } }
  | .enter =>
      match Loam.Tui.LocusTrendComparePane.acceptOverlayDraft state.trendCompare with
      | .ok trendCompare =>
          { state := { state with trendCompare := trendCompare, notice := "" } }
      | .error message =>
          { state := { state with notice := message } }
  | _ => { state }

private def updateLocusTrendCompare
    (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  if Loam.Tui.LocusTrendComparePane.isPickerOpen state.trendCompare then
    updateTrendSeriesPicker state key
  else if Loam.Tui.LocusTrendComparePane.isOverlayEditing state.trendCompare then
    updateTrendOverlayEditor state key
  else
    match key with
    | .escape | .input 'q' | .input 'Q' =>
      { state, back := true }
    | .left | .up | .input 'h' | .input 'H' =>
      { state := { state with
          trendCompare :=
            Loam.Tui.LocusTrendComparePane.moveSelection state.trendCompare true
          notice := "" } }
    | .right | .down | .input 'l' | .input 'L' =>
      { state := { state with
          trendCompare :=
            Loam.Tui.LocusTrendComparePane.moveSelection state.trendCompare false
          notice := "" } }
    | .input '[' =>
      let trendCompare :=
        Loam.Tui.LocusTrendComparePane.changeGranularity state.trendCompare false
      let next := { state with trendCompare := trendCompare, notice := "" }
      if trendCompare.granularity == state.trendCompare.granularity then
        { state := next }
      else
        { state := next, query := queryForMode next }
    | .input ']' =>
      let trendCompare :=
        Loam.Tui.LocusTrendComparePane.changeGranularity state.trendCompare true
      let next := { state with trendCompare := trendCompare, notice := "" }
      if trendCompare.granularity == state.trendCompare.granularity then
        { state := next }
      else
        { state := next, query := queryForMode next }
    | .input 's' =>
      let trendCompare :=
        Loam.Tui.LocusTrendComparePane.changeScope state.trendCompare true
      let next := { state with trendCompare := trendCompare, notice := "" }
      if trendCompare.scope == state.trendCompare.scope then
        { state := next }
      else
        { state := next, query := queryForMode next }
    | .input 'S' =>
      let trendCompare :=
        Loam.Tui.LocusTrendComparePane.changeScope state.trendCompare false
      let next := { state with trendCompare := trendCompare, notice := "" }
      if trendCompare.scope == state.trendCompare.scope then
        { state := next }
      else
        { state := next, query := queryForMode next }
    | .input 'a' | .input 'A' =>
      { state := { state with
          trendCompare :=
            Loam.Tui.LocusTrendComparePane.openSeriesPicker
              state.trendCompare state.trendCompareSeries.length
          notice := "" } }
    | .input 'o' =>
      match Loam.Tui.LocusTrendComparePane.beginOverlay state.trendCompare with
      | .ok trendCompare =>
          { state := { state with trendCompare := trendCompare, notice := "" } }
      | .error message =>
          { state := { state with notice := message } }
    | .input 'O' =>
      { state := { state with
          trendCompare := Loam.Tui.LocusTrendComparePane.clearOverlays state.trendCompare
          notice := "" } }
    | .input 'v' | .input 'V' =>
      { state := { state with
          trendCompare := Loam.Tui.LocusTrendComparePane.toggleOverlayGuides state.trendCompare
          notice := "" } }
    | .enter =>
      { state, query := queryForMode state }
    | _ => { state }


private def updateBalances (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'q' | .input 'Q' =>
      { state, back := true }
  | .up | .input 'k' | .input 'K' =>
      { state := { state with scroll := state.scroll - 1 } }
  | .down | .input 'j' | .input 'J' =>
      { state := { state with scroll := state.scroll + 1 } }
  | .enter => { state, query := some .roleBalances }
  | _ => { state }

private def updateLiquidity (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'q' | .input 'Q' =>
      { state, back := true }
  | .up | .input 'k' | .input 'K' =>
      { state := { state with scroll := state.scroll - 1 } }
  | .down | .input 'j' | .input 'J' =>
      { state := { state with scroll := state.scroll + 1 } }
  | .tab | .shiftTab =>
      { state := { state with
          liquidityForm := moveLiquidityFocus state.liquidityForm
          notice := "" } }
  | .backspace =>
      { state := clearResults { state with
          liquidityForm := editLiquidityActive state.liquidityForm
            (fun text => Loam.Tui.Terminal.backspaceText text)
          notice := "" } }
  | .input 'm' | .input 'M' => { state := resetLiquidityHorizon state }
  | .input char =>
      { state := clearResults { state with
          liquidityForm := editLiquidityActive state.liquidityForm (fun text => text.push char)
          notice := "" } }
  | .enter =>
      if state.liquidityForm.focus.val = 0 then
        { state := { state with
            liquidityForm := moveLiquidityFocus state.liquidityForm
            notice := "" } }
      else
        { state,
          query := some (.conditionalLiquidity state.liquidityForm.assumedCompleteThrough) }
  | _ => { state }

def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match state.mode with
  | .stockFlow =>
      match key with
      | .input 'c' | .input 'C' =>
          { state := beginComparison state .stockFlowCompare }
      | _ => updateWindowReport state key
  | .stockFlowCompare => updateComparison state key
  | .transactionsFlow => updateTransactionsFlow state key
  | .budgetWindow => updateWindowReport state key
  | .incomeExpense =>
      match key with
      | .input 'c' | .input 'C' =>
          { state := beginComparison state .incomeExpenseCompare }
      | .input 'g' | .input 'G' =>
          { state := { state with
              incomeExpenseDisplay := state.incomeExpenseDisplay.next
              notice := ""
              scroll := 0 } }
      | _ => updateWindowReport state key
  | .incomeExpenseCompare => updateComparison state key
  | .multimeasureSpend => updateWindowReport state key
  | .balances => updateBalances state key
  | .liquidity => updateLiquidity state key
  | .locusTrendCompare => updateLocusTrendCompare state key

end Loam.Tui.Reports
