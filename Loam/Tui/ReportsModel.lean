import Loam.ActualDate
import Loam.BoundaryPresetConfig
import Loam.BudgetWindowReview
import Loam.ConditionalBalancePathReview
import Loam.PeriodComparisonReview
import Loam.StockFlowReview
import Loam.TransactionsFlowReview
import Loam.RoleFlowReview
import Loam.RoleBalanceReview
import Loam.ScheduledCoverageReview
import Loam.Tui.ReportComparison
import Loam.Tui.ReportWindow
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
  | menu
  | stockFlow
  | stockFlowCompare
  | transactionsFlow
  | incomeExpense
  | incomeExpenseCompare
  | balances
  | liquidity
  | budgetWindow
  | scheduledCoverage
  deriving Repr, DecidableEq

structure LiquidityForm where
  assumedCompleteThrough : String := ""
  focus : Fin 2 := ⟨0, by decide⟩
  deriving Repr, DecidableEq

inductive Query where
  | stockFlow (start endExclusive : String)
  | stockFlowCompare
      (leftStart leftEndExclusive rightStart rightEndExclusive : String)
  | transactionsFlow (start endExclusive : String)
  | incomeExpenseFlow (start endExclusive : String)
  | incomeExpenseCompare
      (leftStart leftEndExclusive rightStart rightEndExclusive : String)
  | roleBalances
  | conditionalLiquidity (assumedCompleteThrough : String)
  | budgetWindow (start endExclusive : String)
  | scheduledCoverage (observedAt : String)
  | favaProjection
  deriving Repr, DecidableEq

structure State where
  mode : Mode := .menu
  menuIndex : Fin 8 := ⟨0, by decide⟩
  window : Loam.Tui.ReportWindow.State := {}
  comparison : Loam.Tui.ReportComparison.State := {}
  liquidityForm : LiquidityForm := {}
  stockFlowSnapshot : Option Loam.StockFlowReview.Snapshot := none
  stockFlowComparison :
    Option (Loam.PeriodComparisonReview.Pair Loam.StockFlowReview.Snapshot) := none
  transactions : Loam.Tui.TransactionsFlowPane.State := {}
  incomeExpenseSnapshot : Option Loam.RoleFlowReview.Snapshot := none
  incomeExpenseComparison :
    Option (Loam.PeriodComparisonReview.Pair Loam.RoleFlowReview.Snapshot) := none
  roleBalanceSnapshot : Option Loam.RoleBalanceReview.Snapshot := none
  liquiditySnapshot : Option Loam.ConditionalBalancePathReview.Snapshot := none
  budgetSnapshot : Option Loam.BudgetWindowReview.Snapshot := none
  scheduledCoverageSnapshot : Option Loam.ScheduledCoverageReview.Snapshot := none
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
def initialForDateWithPresets
    (selectedDate : String)
    (presets : List Loam.BoundaryPresetConfig.Preset) : State :=
  let windowResult := Loam.Tui.ReportWindow.initialForDateWithPresets selectedDate presets
  {
    mode := .menu
    window := windowResult.state
    liquidityForm := liquidityFormForEndExclusive windowResult.state.form.endExclusive
    notice := windowResult.notice
  }

/-- Compatibility initializer when no named presets were loaded. -/
def initialForDate (selectedDate : String) : State :=
  initialForDateWithPresets selectedDate []


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
    (state : State) (snapshot : Loam.RoleFlowReview.Snapshot) : State :=
  { state with incomeExpenseSnapshot := some snapshot, notice := "", scroll := 0 }


def withIncomeExpenseComparison
    (state : State)
    (comparison : Loam.PeriodComparisonReview.Pair Loam.RoleFlowReview.Snapshot) : State :=
  { state with incomeExpenseComparison := some comparison, notice := "", scroll := 0 }


def withRoleBalanceSnapshot
    (state : State) (snapshot : Loam.RoleBalanceReview.Snapshot) : State :=
  { state with roleBalanceSnapshot := some snapshot, notice := "", scroll := 0 }


def withLiquiditySnapshot
    (state : State) (snapshot : Loam.ConditionalBalancePathReview.Snapshot) : State :=
  { state with liquiditySnapshot := some snapshot, notice := "", scroll := 0 }


def withBudgetSnapshot
    (state : State) (snapshot : Loam.BudgetWindowReview.Snapshot) : State :=
  { state with budgetSnapshot := some snapshot, notice := "", scroll := 0 }


def withScheduledCoverageSnapshot
    (state : State) (snapshot : Loam.ScheduledCoverageReview.Snapshot) : State :=
  { state with scheduledCoverageSnapshot := some snapshot, notice := "", scroll := 0 }


def withError (state : State) (message : String) : State :=
  { state with
      stockFlowSnapshot := none
      stockFlowComparison := none
      transactions := Loam.Tui.TransactionsFlowPane.initial
      incomeExpenseSnapshot := none
      incomeExpenseComparison := none
      roleBalanceSnapshot := none
      liquiditySnapshot := none
      budgetSnapshot := none
      scheduledCoverageSnapshot := none
      notice := message
      scroll := 0 }

private def clearResults (state : State) : State :=
  { state with
      stockFlowSnapshot := none
      stockFlowComparison := none
      transactions := Loam.Tui.TransactionsFlowPane.initial
      incomeExpenseSnapshot := none
      incomeExpenseComparison := none
      roleBalanceSnapshot := none
      liquiditySnapshot := none
      budgetSnapshot := none
      scheduledCoverageSnapshot := none
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

private def moveMenu (state : State) (back : Bool) : State :=
  let next := if back then (state.menuIndex.val + 7) % 8 else (state.menuIndex.val + 1) % 8
  { state with menuIndex := ⟨next, by
      dsimp [next]
      split <;> exact Nat.mod_lt _ (by decide)⟩, notice := "" }


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

private def selectMenuMode (state : State) : State :=
  let mode :=
    match state.menuIndex.val with
    | 0 => Mode.stockFlow
    | 1 => Mode.transactionsFlow
    | 2 => Mode.incomeExpense
    | 3 => Mode.balances
    | 4 => Mode.liquidity
    | 5 => Mode.budgetWindow
    | _ => Mode.scheduledCoverage
  { state with mode := mode, notice := "", scroll := 0 }

private def selectMenuStep (state : State) : Step :=
  if state.menuIndex.val == 7 then
    { state, query := some .favaProjection }
  else
    let next := selectMenuMode state
    match next.mode with
    | .balances => { state := next, query := some .roleBalances }
    | .scheduledCoverage =>
        { state := next, query := some (.scheduledCoverage next.window.calendarAnchor) }
    | _ => { state := next }

private def updateMenu (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'q' | .input 'Q' => { state, back := true }
  | .up | .input 'k' | .input 'K' => { state := moveMenu state true }
  | .down | .input 'j' | .input 'J' => { state := moveMenu state false }
  | .enter => selectMenuStep state
  | .input 's' | .input 'S' =>
      { state := { state with mode := .stockFlow, notice := "", scroll := 0 } }
  | .input 't' | .input 'T' =>
      { state := { state with mode := .transactionsFlow, notice := "", scroll := 0 } }
  | .input 'i' | .input 'I' =>
      { state := { state with mode := .incomeExpense, notice := "", scroll := 0 } }
  | .input 'r' | .input 'R' =>
      { state := { state with mode := .balances, notice := "", scroll := 0 },
        query := some .roleBalances }
  | .input 'l' | .input 'L' =>
      { state := { state with mode := .liquidity, notice := "", scroll := 0 } }
  | .input 'w' | .input 'W' =>
      { state := { state with mode := .budgetWindow, notice := "", scroll := 0 } }
  | .input 'c' | .input 'C' =>
      let next := { state with mode := .scheduledCoverage, notice := "", scroll := 0 }
      { state := next, query := some (.scheduledCoverage next.window.calendarAnchor) }
  | .input 'f' | .input 'F' =>
      { state, query := some .favaProjection }
  | _ => { state }

private def queryForMode (state : State) : Option Query :=
  match state.mode with
  | .stockFlow => some (.stockFlow state.window.form.start state.window.form.endExclusive)
  | .transactionsFlow => some (.transactionsFlow state.window.form.start state.window.form.endExclusive)
  | .incomeExpense => some (.incomeExpenseFlow state.window.form.start state.window.form.endExclusive)
  | .budgetWindow => some (.budgetWindow state.window.form.start state.window.form.endExclusive)
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
            (fun text => String.ofList text.toList.dropLast) }
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
      { state := { state with mode := .menu, notice := "", scroll := 0 } }
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
      { state := editWindowState state (fun text => String.ofList text.toList.dropLast) }
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
        { state := { state with mode := .menu, notice := "", scroll := 0 } }
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
          { state := editWindowState state (fun text => String.ofList text.toList.dropLast) }
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

private def updateBalances (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'q' | .input 'Q' =>
      { state := { state with mode := .menu, notice := "", scroll := 0 } }
  | .up | .input 'k' | .input 'K' =>
      { state := { state with scroll := state.scroll - 1 } }
  | .down | .input 'j' | .input 'J' =>
      { state := { state with scroll := state.scroll + 1 } }
  | .enter => { state, query := some .roleBalances }
  | _ => { state }

private def updateScheduledCoverage
    (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'q' | .input 'Q' =>
      { state := { state with mode := .menu, notice := "", scroll := 0 } }
  | .up | .input 'k' | .input 'K' =>
      { state := { state with scroll := state.scroll - 1 } }
  | .down | .input 'j' | .input 'J' =>
      { state := { state with scroll := state.scroll + 1 } }
  | .enter =>
      { state, query := some (.scheduledCoverage state.window.calendarAnchor) }
  | _ => { state }

private def updateLiquidity (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'q' | .input 'Q' =>
      { state := { state with mode := .menu, notice := "", scroll := 0 } }
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
            (fun text => String.ofList text.toList.dropLast)
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
  | .menu => updateMenu state key
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
      | _ => updateWindowReport state key
  | .incomeExpenseCompare => updateComparison state key
  | .balances => updateBalances state key
  | .liquidity => updateLiquidity state key
  | .scheduledCoverage => updateScheduledCoverage state key

end Loam.Tui.Reports
