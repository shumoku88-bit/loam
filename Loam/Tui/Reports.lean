import Loam.ActualDate
import Loam.BoundaryPresetConfig
import Loam.BudgetWindowReview
import Loam.ConditionalBalancePathReview
import Loam.StockFlowReview
import Loam.TransactionsFlowReview
import Loam.RoleFlowReview
import Loam.RoleBalanceReview
import Loam.Tui.RoleBalances
import Loam.Tui.ReportWindow
import Loam.Tui.Calendar
import Loam.Tui.Kernel
import Loam.Tui.Layout
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
  | transactionsFlow
  | incomeExpense
  | balances
  | liquidity
  | budgetWindow
  deriving Repr, DecidableEq

structure LiquidityForm where
  assumedCompleteThrough : String := ""
  focus : Fin 2 := ⟨0, by decide⟩
  deriving Repr, DecidableEq

inductive Query where
  | stockFlow (start endExclusive : String)
  | transactionsFlow (start endExclusive : String)
  | incomeExpenseFlow (start endExclusive : String)
  | roleBalances
  | conditionalLiquidity (assumedCompleteThrough : String)
  | budgetWindow (start endExclusive : String)
  deriving Repr, DecidableEq

structure State where
  mode : Mode := .menu
  menuIndex : Fin 6 := ⟨0, by decide⟩
  window : Loam.Tui.ReportWindow.State := {}
  liquidityForm : LiquidityForm := {}
  stockFlowSnapshot : Option Loam.StockFlowReview.Snapshot := none
  transactionsSnapshot : Option Loam.TransactionsFlowReview.Snapshot := none
  incomeExpenseSnapshot : Option Loam.RoleFlowReview.Snapshot := none
  roleBalanceSnapshot : Option Loam.RoleBalanceReview.Snapshot := none
  transactionsIndex : Nat := 0
  transactionsDetail : Bool := false
  liquiditySnapshot : Option Loam.ConditionalBalancePathReview.Snapshot := none
  budgetSnapshot : Option Loam.BudgetWindowReview.Snapshot := none
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


def withTransactionsFlowSnapshot
    (state : State) (snapshot : Loam.TransactionsFlowReview.Snapshot) : State :=
  { state with
      transactionsSnapshot := some snapshot
      transactionsIndex := 0
      transactionsDetail := false
      notice := ""
      scroll := 0 }


def withIncomeExpenseSnapshot
    (state : State) (snapshot : Loam.RoleFlowReview.Snapshot) : State :=
  { state with incomeExpenseSnapshot := some snapshot, notice := "", scroll := 0 }


def withRoleBalanceSnapshot
    (state : State) (snapshot : Loam.RoleBalanceReview.Snapshot) : State :=
  { state with roleBalanceSnapshot := some snapshot, notice := "", scroll := 0 }


def withLiquiditySnapshot
    (state : State) (snapshot : Loam.ConditionalBalancePathReview.Snapshot) : State :=
  { state with liquiditySnapshot := some snapshot, notice := "", scroll := 0 }


def withBudgetSnapshot
    (state : State) (snapshot : Loam.BudgetWindowReview.Snapshot) : State :=
  { state with budgetSnapshot := some snapshot, notice := "", scroll := 0 }


def withError (state : State) (message : String) : State :=
  { state with
      stockFlowSnapshot := none
      transactionsSnapshot := none
      incomeExpenseSnapshot := none
      roleBalanceSnapshot := none
      transactionsIndex := 0
      transactionsDetail := false
      liquiditySnapshot := none
      budgetSnapshot := none
      notice := message
      scroll := 0 }

private def clearResults (state : State) : State :=
  { state with
      stockFlowSnapshot := none
      transactionsSnapshot := none
      incomeExpenseSnapshot := none
      roleBalanceSnapshot := none
      transactionsIndex := 0
      transactionsDetail := false
      liquiditySnapshot := none
      budgetSnapshot := none
      scroll := 0 }


private def moveLiquidityFocus (form : LiquidityForm) : LiquidityForm :=
  let next := (form.focus.val + 1) % 2
  { form with focus := ⟨next, by
      dsimp [next]
      exact Nat.mod_lt _ (by decide)⟩ }

private def moveMenu (state : State) (back : Bool) : State :=
  let next := if back then (state.menuIndex.val + 5) % 6 else (state.menuIndex.val + 1) % 6
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
  applyWindowResult state (Loam.Tui.ReportWindow.shiftCalendarMonth state.window forward)

private def editWindowState (state : State) (edit : String → String) : State :=
  clearResults {
    state with
      window := Loam.Tui.ReportWindow.editActive state.window edit
      notice := ""
  }

/-- Human-readable label for presentation only; it never enters a report query. -/
def windowSourceLabel (state : State) : String :=
  Loam.Tui.ReportWindow.sourceLabel state.window

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
    | _ => Mode.budgetWindow
  { state with mode := mode, notice := "", scroll := 0 }

private def selectMenuStep (state : State) : Step :=
  let next := selectMenuMode state
  match next.mode with
  | .balances => { state := next, query := some .roleBalances }
  | _ => { state := next }

private def updateMenu (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'b' | .input 'B' => { state, back := true }
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
  | _ => { state }

private def queryForMode (state : State) : Option Query :=
  match state.mode with
  | .stockFlow => some (.stockFlow state.window.form.start state.window.form.endExclusive)
  | .transactionsFlow => some (.transactionsFlow state.window.form.start state.window.form.endExclusive)
  | .incomeExpense => some (.incomeExpenseFlow state.window.form.start state.window.form.endExclusive)
  | .budgetWindow => some (.budgetWindow state.window.form.start state.window.form.endExclusive)
  | _ => none

private def updateWindowReport (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'b' | .input 'B' =>
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


private def transactionCoordinateLe
    (left right : Loam.Core.EffectCoordinate) : Bool :=
  if left.locus.token == right.locus.token then
    left.measure.token <= right.measure.token
  else
    left.locus.token <= right.locus.token

private def transactionRowLe
    (left right : Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity) : Bool :=
  if left.2.gross.quanta == right.2.gross.quanta then
    transactionCoordinateLe left.1 right.1
  else
    left.2.gross.quanta >= right.2.gross.quanta

private def transactionRows
    (snapshot : Loam.TransactionsFlowReview.Snapshot) :
    List (Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity) :=
  (snapshot.rows.map fun coordinate =>
      (coordinate, Loam.TransactionsFlowReview.rowActivity snapshot coordinate))
    |>.filter (fun row => row.2.activeEvents > 0)
    |>.mergeSort transactionRowLe

private def transactionContributions
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : Loam.Core.EffectCoordinate) :
    List (Loam.TransactionsFlowReview.Column × Loam.Core.Quantity) :=
  snapshot.columns.filterMap fun column =>
    let quantity := Loam.Core.Event.quantityAt
      column.event coordinate.locus coordinate.measure
    if quantity.quanta = 0 then none else some (column, quantity)

private def moveTransactionSelection (state : State) (back : Bool) : State :=
  match state.transactionsSnapshot with
  | none => state
  | some snapshot =>
      let count := (transactionRows snapshot).length
      if count = 0 then
        { state with transactionsIndex := 0, scroll := 0 }
      else
        let maxIndex := count - 1
        let current := min state.transactionsIndex maxIndex
        let next := if back then current - 1 else min maxIndex (current + 1)
        { state with transactionsIndex := next, scroll := 0, notice := "" }

private def updateTransactionsFlow
    (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  if state.transactionsDetail then
    match key with
    | .escape | .input 'b' | .input 'B' =>
        { state := { state with transactionsDetail := false, scroll := 0, notice := "" } }
    | .up | .input 'k' | .input 'K' =>
        { state := { state with scroll := state.scroll - 1 } }
    | .down | .input 'j' | .input 'J' =>
        { state := { state with scroll := state.scroll + 1 } }
    | _ => { state }
  else
    match state.transactionsSnapshot with
    | none => updateWindowReport state key
    | some snapshot =>
        let rows := transactionRows snapshot
        match key with
        | .escape | .input 'b' | .input 'B' =>
            { state := { state with mode := .menu, notice := "", scroll := 0 } }
        | .up | .input 'k' | .input 'K' =>
            { state := moveTransactionSelection state true }
        | .down | .input 'j' | .input 'J' =>
            { state := moveTransactionSelection state false }
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
            else if rows.isEmpty then
              { state := { state with notice := "No quantity activity in this window." } }
            else
              { state := { state with transactionsDetail := true, scroll := 0, notice := "" } }
        | _ => { state }

private def updateBalances (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'b' | .input 'B' =>
      { state := { state with mode := .menu, notice := "", scroll := 0 } }
  | .up | .input 'k' | .input 'K' =>
      { state := { state with scroll := state.scroll - 1 } }
  | .down | .input 'j' | .input 'J' =>
      { state := { state with scroll := state.scroll + 1 } }
  | .enter => { state, query := some .roleBalances }
  | _ => { state }

private def updateLiquidity (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'b' | .input 'B' =>
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
  | .stockFlow => updateWindowReport state key
  | .transactionsFlow => updateTransactionsFlow state key
  | .budgetWindow => updateWindowReport state key
  | .incomeExpense => updateWindowReport state key
  | .balances => updateBalances state key
  | .liquidity => updateLiquidity state key

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def signedQuanta (quantity : Loam.Core.Quantity) : String :=
  if quantity.quanta > 0 then "+" ++ toString quantity.quanta else toString quantity.quanta

private def padNum (columns : Nat) (text : String) : String :=
  let width := Loam.Tui.Layout.displayWidth text
  if width ≥ columns then Loam.Tui.Layout.clip columns text
  else Loam.Tui.Layout.padLeft columns text


private def field (state : State) (index : Nat) (label text : String) : Widget :=
  .row
    [ span (label ++ ": ")
    , span (if text.isEmpty then "_" else text)
        (if state.window.form.focus.val = index then .selected else .normal)
    ]

private def liquidityField (state : State) : Widget :=
  .row
    [ span "Assume Scheduled complete through: "
    , span
        (if state.liquidityForm.assumedCompleteThrough.isEmpty then
          "_"
        else
          state.liquidityForm.assumedCompleteThrough)
        (if state.liquidityForm.focus.val = 0 then .selected else .normal)
    ]

private def menuRow (state : State) (index : Nat) (label note : String) : Widget :=
  .row
    [ span (if state.menuIndex.val = index then "> " else "  ")
    , span label (if state.menuIndex.val = index then .selected else .normal)
    , span ("  " ++ note) .muted
    ]

private def menuView (state : State) : Widget :=
  .column
    [ line "Reports"
    , muted "Home > Reports"
    , muted "Small derived views over shared production evidence."
    , blank
    , menuRow state 0 "Stock–Flow" "state change across an explicit window"
    , menuRow state 1 "Transactions Flow" "where quantity moved, including zero-net circulation"
    , menuRow state 2 "Income & Expense" "occurrence-time role flow"
    , menuRow state 3 "Balances" "evidence-aware current accounting projections"
    , menuRow state 4 "Liquidity" "UNKNOWN baseline + explicit conditional overlay"
    , menuRow state 5 "Budget Window" "explicit entitlement / consumption query"
    , blank
    , muted "↑/↓ or j/k select   Enter open   s/t/i/r/l/w direct"
    , muted "b / Esc home   q quit"
    , line state.notice
    ]

private def stockFlowResultLines (state : State) : List Widget :=
  match state.stockFlowSnapshot with
  | none => [muted "No explicit Stock–Flow window has been run yet."]
  | some snapshot =>
      let label := Loam.Tui.Layout.padRight 36
      [ line ("Window [" ++ snapshot.start ++ ", " ++ snapshot.endExclusive ++ ")")
      , line (label "Reconstructed at start:" ++ padNum 12 (toString snapshot.reconstructedStart.quanta) ++ " jpy")
      , line (label "Reconstructed at end:" ++ padNum 12 (toString snapshot.reconstructedEnd.quanta) ++ " jpy")
      , blank
      , line (label "Tracked increases across Events:" ++ padNum 12 (signedQuanta snapshot.increasesAcrossEvents) ++ " jpy")
      , line (label "Tracked decreases across Events:" ++ padNum 12 (signedQuanta snapshot.decreasesAcrossEvents) ++ " jpy")
      , line (label "Net change:" ++ padNum 12 (signedQuanta snapshot.netChange) ++ " jpy")
      , blank
      , muted (label "Current tracked balance now:" ++ padNum 12 (toString snapshot.currentTracked.quanta) ++ " jpy")
      , muted "Boundary values are reconstructed from current accepted evidence."
      , muted "They are not archived historical balance snapshots."
      , muted "Increase/decrease is tracked-balance motion, not income/spending."
      ]

private def stockFlowView (state : State) : Widget :=
  .column <|
    [ line "Reports / Stock–Flow"
    , muted "Why did the tracked balance change between two boundaries?"
    , muted "Calendar month is only a coordinate convenience, not a household cycle."
    , line ("Window: " ++ windowSourceLabel state)
    , muted "Named presets are replaceable query config; reports still receive explicit coordinates only."
    , blank
    , field state 0 "Start" state.window.form.start
    , field state 1 "End (exclusive)" state.window.form.endExclusive
    , .row [span "[Run]" (if state.window.form.focus.val = 2 then .selected else .normal)]
    , blank
    ] ++
    stockFlowResultLines state ++
    [ blank
    , muted "[ / ] window source   ← / → Calendar Month   m selected-day month"
    , muted "Tab / Shift-Tab focus   Enter next/run   Backspace delete"
    , muted "b / Esc Reports menu   q quit"
    , line state.notice
    ]


private def transactionWindowLines (state : State) : List Widget :=
  [ line "Reports / Transactions Flow"
  , muted "Which exact coordinates moved in this window?"
  , muted "Zero-net circulation visible via gross activity."
  , line ("Window: " ++ windowSourceLabel state)
  , muted "Presets only resolve explicit [start, end) dates."
  , blank
  , field state 0 "Start" state.window.form.start
  , field state 1 "End (exclusive)" state.window.form.endExclusive
  , .row [span "[Run]" (if state.window.form.focus.val = 2 then .selected else .normal)]
  , blank
  ]

private def transactionSummaryPrefix
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (rows : List (Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity)) :
    List Widget :=
  [ line ("Window [" ++ snapshot.start ++ ", " ++ snapshot.endExclusive ++ ")")
  , muted (toString rows.length ++ " active coordinate(s); zero cells omitted.")
  , muted "Rows ordered by gross quantity (presentation only)."
  , blank
  ]

structure TableLayout where
  coordWidth : Nat
  netWidth : Nat
  grossWidth : Nat
  posWidth : Nat
  negWidth : Nat
  evWidth? : Option Nat
  deriving Repr

private def defaultReportWidth : Nat := 72

private def tableLayoutForWidth (width : Nat) : TableLayout :=
  if width ≥ 70 then
    { coordWidth := min 26 (width - 46)
    , netWidth := 9
    , grossWidth := 9
    , posWidth := 9
    , negWidth := 9
    , evWidth? := some 8
    }
  else if width ≥ 51 then
    { coordWidth := width - 36
    , netWidth := 7
    , grossWidth := 7
    , posWidth := 7
    , negWidth := 7
    , evWidth? := some (min 6 (width - (2 + (width - 36) + 28)))
    }
  else if width ≥ 44 then
    { coordWidth := width - 30
    , netWidth := 7
    , grossWidth := 7
    , posWidth := 7
    , negWidth := 7
    , evWidth? := none
    }
  else
    { coordWidth := max 10 (width - 23)
    , netWidth := 7
    , grossWidth := 7
    , posWidth := 7
    , negWidth := 0
    , evWidth? := none
    }

private def TableLayout.totalWidth (layout : TableLayout) : Nat :=
  2 + layout.coordWidth + layout.netWidth + layout.grossWidth + layout.posWidth +
    (if layout.negWidth > 0 then layout.negWidth else 0) +
    (match layout.evWidth? with | some w => w | none => 0)


private def transactionTableHeader (layout : TableLayout) : Widget :=
  let marker := "  "
  let coord := Loam.Tui.Layout.padRight layout.coordWidth "Coordinate"
  let net := padNum layout.netWidth "Net"
  let gross := padNum layout.grossWidth "Gross"
  let pos := padNum layout.posWidth "+In"
  let neg := if layout.negWidth > 0 then padNum layout.negWidth "-Out" else ""
  let ev := match layout.evWidth? with
    | some w => if w ≥ 6 then padNum w "Events" else padNum w "Ev"
    | none => ""
  muted (marker ++ coord ++ net ++ gross ++ pos ++ neg ++ ev)

private def repeatChar (count : Nat) (char : Char) : String :=
  String.ofList (List.replicate count char)

private def transactionTableRule (layout : TableLayout) : Widget :=
  muted (repeatChar layout.totalWidth '-')

private def transactionRowLine
    (state : State) (layout : TableLayout) (index : Nat)
    (row : Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity) : Widget :=
  let coordinate := row.1
  let activity := row.2
  let marker := if state.transactionsIndex = index then "> " else "  "
  let coordToken := coordinate.locus.token ++ "/" ++ coordinate.measure.token
  let coord := Loam.Tui.Layout.padRight layout.coordWidth coordToken
  let net := padNum layout.netWidth (signedQuanta activity.net)
  let gross := padNum layout.grossWidth (toString activity.gross.quanta)
  let pos := padNum layout.posWidth (signedQuanta activity.positive)
  let neg := if layout.negWidth > 0 then padNum layout.negWidth (signedQuanta activity.negative) else ""
  let ev := match layout.evWidth? with
    | some w => padNum w (toString activity.activeEvents)
    | none => ""
  line (marker ++ coord ++ net ++ gross ++ pos ++ neg ++ ev)

private def transactionRowLines
    (state : State) (layout : TableLayout) : Nat →
    List (Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity) →
    List Widget
  | _, [] => []
  | index, row :: rest =>
      transactionRowLine state layout index row ::
        transactionRowLines state layout (index + 1) rest

private def selectedTransactionRow?
    (state : State) :
    Option (Loam.TransactionsFlowReview.Snapshot ×
      (Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity)) := do
  let snapshot ← state.transactionsSnapshot
  let row ← (transactionRows snapshot)[state.transactionsIndex]?
  some (snapshot, row)

private def transactionContributionLine
    (coordinate : Loam.Core.EffectCoordinate)
    (entry : Loam.TransactionsFlowReview.Column × Loam.Core.Quantity) : Widget :=
  let column := entry.1
  let quantity := entry.2
  let description :=
    if column.description.isEmpty then
      "[" ++ column.event.id.token ++ "]"
    else
      column.description ++ "  [" ++ column.event.id.token ++ "]"
  line
    ("- " ++ column.date ++ "  " ++ signedQuanta quantity ++ " " ++
      coordinate.measure.token ++ "  " ++ description)

private def transactionDetailLines (state : State) : List Widget :=
  match selectedTransactionRow? state with
  | none => [muted "No selected Transactions Flow coordinate is available."]
  | some (snapshot, row) =>
      let coordinate := row.1
      let activity := row.2
      let contributions := transactionContributions snapshot coordinate
      [ line ("Focused coordinate: " ++ coordinate.locus.token ++ "/" ++ coordinate.measure.token)
      , line
          ("Net " ++ toString activity.net.quanta ++
            " | Gross " ++ toString activity.gross.quanta ++
            " | +In " ++ signedQuanta activity.positive ++
            " | -Out " ++ signedQuanta activity.negative)
      , muted (toString contributions.length ++ " contributing Event(s); zero cells omitted.")
      , blank
      ] ++
      contributions.map (transactionContributionLine coordinate) ++
      [ blank
      , muted "Signs are exact quantity changes, not income/expense."
      ]

private def transactionSummaryLines (state : State) (bounds : Option Bounds) : List Widget :=
  match state.transactionsSnapshot with
  | none => [muted "No explicit Transactions Flow window has been run yet."]
  | some snapshot =>
      let rows := transactionRows snapshot
      transactionSummaryPrefix snapshot rows ++
      if rows.isEmpty then
        [muted "No quantity activity appears in this window."]
      else
        let width := match bounds with
          | some b => Loam.Tui.Layout.contentWidth b
          | none => defaultReportWidth
        let layout := tableLayoutForWidth width
        transactionTableHeader layout ::
        transactionTableRule layout ::
        transactionRowLines state layout 0 rows

private def transactionsFlowView (state : State) (bounds : Option Bounds) : Widget :=
  if state.transactionsDetail then
    .column <|
      [ line "Reports / Transactions Flow"
      , muted "Focused nonzero Event witnesses for coordinate."
      , blank
      ] ++
      transactionDetailLines state ++
      [ blank
      , muted "↑/↓ or j/k scroll contributors"
      , muted "b / Esc summary   q quit"
      , muted "No pairwise flow edge inferred from signed Effects."
      , line state.notice
      ]
  else
    .column <|
      transactionWindowLines state ++
      transactionSummaryLines state bounds ++
      [ blank
      , muted "[ / ] source   ← / → Month   m sel-day month"
      , muted "↑/↓ select coord   Enter detail   Tab window focus"
      , muted "b / Esc Reports menu   q quit"
      , line state.notice
      ]

private def addIncomeExpenseMeasureIfAbsent
    (measures : List Loam.Core.MeasureId) (measure : Loam.Core.MeasureId) :
    List Loam.Core.MeasureId :=
  if measure ∈ measures then measures else measures ++ [measure]

private def incomeExpenseMeasures
    (snapshot : Loam.RoleFlowReview.Snapshot) : List Loam.Core.MeasureId :=
  snapshot.rows.foldl
    (fun measures row =>
      match row.role with
      | .income => addIncomeExpenseMeasureIfAbsent measures row.coordinate.measure
      | .expense => addIncomeExpenseMeasureIfAbsent measures row.coordinate.measure
      | _ => measures)
    []

private def incomeExpenseRoleQuanta
    (snapshot : Loam.RoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId) (role : Loam.Core.AccountingRole) : Int :=
  snapshot.rows.foldl
    (fun total row =>
      if decide (row.coordinate.measure = measure ∧ row.role = role) then
        total + row.quantity.quanta
      else
        total)
    0

private def incomeExpenseBreakdownRows
    (snapshot : Loam.RoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId) (role : Loam.Core.AccountingRole) :
    List Loam.RoleFlowReview.Row :=
  (snapshot.rows.filter fun row =>
    decide (row.coordinate.measure = measure ∧ row.role = role)).mergeSort fun a b =>
      a.coordinate.locus.token <= b.coordinate.locus.token

private def incomeExpenseDisplayQuanta
    (role : Loam.Core.AccountingRole) (quantity : Loam.Core.Quantity) : Int :=
  if role = .income then -quantity.quanta else quantity.quanta

private def incomeExpenseBreakdownLines
    (snapshot : Loam.RoleFlowReview.Snapshot)
    (measure : Loam.Core.MeasureId) (role : Loam.Core.AccountingRole)
    (heading : String) : List Widget :=
  let rows := incomeExpenseBreakdownRows snapshot measure role
  if rows.isEmpty then
    [muted (heading ++ ": (none)")]
  else
    [muted heading] ++ rows.map fun row =>
      line
        ("  " ++ Loam.Tui.Layout.padRight 24 row.coordinate.locus.token ++
          padNum 12 (toString (incomeExpenseDisplayQuanta role row.quantity)) ++
          " " ++ measure.token)

private def incomeExpenseMeasureLines
    (snapshot : Loam.RoleFlowReview.Snapshot) (measure : Loam.Core.MeasureId) : List Widget :=
  let rawIncome := incomeExpenseRoleQuanta snapshot measure .income
  let rawExpense := incomeExpenseRoleQuanta snapshot measure .expense
  let income := -rawIncome
  let expense := rawExpense
  let result := income - expense
  let label := Loam.Tui.Layout.padRight 16
  [ line (measure.token ++ "  occurrence-time P/L-shaped flow")
  , line (label "Income:" ++ padNum 12 (toString income) ++ " " ++ measure.token)
  , line (label "Expense:" ++ padNum 12 (toString expense) ++ " " ++ measure.token)
  , line (label "Result:" ++ padNum 12 (toString result) ++ " " ++ measure.token)
  , blank
  ] ++
  incomeExpenseBreakdownLines snapshot measure .income "Income breakdown" ++
  [blank] ++
  incomeExpenseBreakdownLines snapshot measure .expense "Expense breakdown"

private def unresolvedIncomeExpenseLine
    (entry : Loam.RoleFlowReview.UnresolvedEffect) : Widget :=
  line
    ("? " ++ entry.date ++ "  " ++ entry.effect.locus.token ++ "  " ++
      signedQuanta entry.effect.quantity ++ " " ++ entry.effect.measure.token ++
      "  [" ++ entry.event.token ++ "]")

private def incomeExpenseResultLines (state : State) : List Widget :=
  match state.incomeExpenseSnapshot with
  | none => [muted "No explicit Income & Expense window has been run yet."]
  | some snapshot =>
      let measures := incomeExpenseMeasures snapshot
      let unresolved := snapshot.unresolvedEffects
      [ line ("Window [" ++ snapshot.start ++ ", " ++ snapshot.endExclusive ++ ")")
      , muted "Income display = -raw signed Income; Expense display = raw signed Expense."
      , muted "Distinct Measures remain separate and are never valued or summed together."
      , blank
      ] ++
      (if measures.isEmpty then
        [muted "No classified Income or Expense quantity appears in this window."]
       else
        measures.flatMap fun measure => incomeExpenseMeasureLines snapshot measure ++ [blank]) ++
      [ line ("Unresolved role Effects: " ++ toString unresolved.length) ] ++
      (unresolved.take 8).map unresolvedIncomeExpenseLine ++
      (if unresolved.length > 8 then
        [muted ("... " ++ toString (unresolved.length - 8) ++ " later unresolved Effect(s) omitted")]
       else
        []) ++
      [ muted
          (if unresolved.isEmpty then
            "Role classification is complete for selected quantity Effects."
           else
            "Totals are partial while unresolved role Effects remain above.")
      , muted "This is occurrence-time role flow, not accrual recognition or period closing."
      ]

private def incomeExpenseView (state : State) : Widget :=
  .column <|
    [ line "Reports / Income & Expense"
    , muted "What Income / Expense role flow occurred inside this explicit window?"
    , line ("Window: " ++ windowSourceLabel state)
    , muted "AccountingRole is explicit authority; no role is inferred from spelling or sign."
    , blank
    , field state 0 "Start" state.window.form.start
    , field state 1 "End (exclusive)" state.window.form.endExclusive
    , .row [span "[Run]" (if state.window.form.focus.val = 2 then .selected else .normal)]
    , blank
    ] ++
    incomeExpenseResultLines state ++
    [ blank
    , muted "[ / ] window source   ← / → Calendar Month   m selected-day month"
    , muted "Tab / Shift-Tab focus   Enter next/run   Backspace delete"
    , muted "b / Esc Reports menu   q quit"
    , line state.notice
    ]

private def balancesResultLines (state : State) : List Widget :=
  match state.roleBalanceSnapshot with
  | none => [muted "Current RoleBalance answer unavailable; press Enter to retry."]
  | some snapshot => Loam.Tui.RoleBalances.lines snapshot

private def balancesView (state : State) : Widget :=
  .column <|
    [ line "Reports / Balances"
    , muted "Current evidence-aware accounting projections from shared RoleBalance."
    , muted "Balance Sheet / Net Worth / Trial Balance are presentations, not separate engines."
    , blank
    ] ++
    balancesResultLines state ++
    [ blank
    , muted "Enter refresh   ↑/↓ or j/k scroll"
    , muted "b / Esc Reports menu   q quit"
    , line state.notice
    ]

private def liquidityPointLine
    (measure : Loam.Core.MeasureId)
    (point : Loam.ConditionalBalancePathReview.Point) : Widget :=
  line
    ("- " ++ point.date ++
      "  Scheduled " ++ padNum 10 (signedQuanta point.scheduledChange) ++
      "  -> " ++ padNum 10 (toString point.balance.quanta) ++ " " ++ measure.token)

private def liquidityResultLines (state : State) : List Widget :=
  match state.liquiditySnapshot with
  | none => [muted "No conditional selected-balance outlook has been run yet."]
  | some snapshot =>
      let points := snapshot.points.take 12
      [ line "CONDITIONAL selected-balance outlook"
      , line ("As of: " ++ snapshot.asOf)
      , line
          ("Assumption: no additional Scheduled items through " ++
            snapshot.assumedCompleteThrough)
      , line
          ("Current selected balance: " ++
            toString snapshot.currentSelected.quanta ++ " " ++ snapshot.measure.token)
      , blank
      ] ++
      (if points.isEmpty then
        [muted "No selected current-open Scheduled changes occur inside this horizon."]
       else
        points.map (liquidityPointLine snapshot.measure)) ++
      (if snapshot.points.length > 12 then
        [muted ("... " ++ toString (snapshot.points.length - 12) ++ " later change point(s) omitted")]
       else
        []) ++
      [ blank
      , line
          ("Conditional balance at horizon: " ++
            toString snapshot.finalAtHorizon.quanta ++ " " ++ snapshot.measure.token)
      , line
          ("Conditional day-boundary low-water: " ++
            toString snapshot.lowWater.quanta ++ " " ++ snapshot.measure.token)
      , muted "This is the replaceable balance-view selection, not canonical liquidity."
      , muted "The numbers are conditional on the explicit completeness assumption above."
      , muted "Same-day effects are netted; no intraday low-water is claimed."
      ]

private def liquidityView (state : State) : Widget :=
  .column <|
    [ line "Reports / Liquidity"
    , muted "What can LOAM safely say about the future selected-balance path?"
    , blank
    , line "Forecast path: UNKNOWN"
    , line "Known low-water mark: UNKNOWN"
    , muted "Production still has no retained complete-future evidence for this report."
    , muted "Known Scheduled items are not silently treated as all future flows."
    , blank
    , line "Read-only conditional query"
    , liquidityField state
    , .row
        [ span "[Run conditional]"
            (if state.liquidityForm.focus.val = 1 then .selected else .normal) ]
    , muted "Running this does not write or upgrade the assumption into evidence."
    , blank
    ] ++
    liquidityResultLines state ++
    [ blank
    , muted "m selected-day month end   Tab / Shift-Tab focus"
    , muted "Enter next/run   Backspace delete   b / Esc Reports menu   q quit"
    , line state.notice
    ]

private def budgetRowLine (row : Loam.BudgetWindowReview.Row) : Widget :=
  line
    (Loam.Tui.Layout.padRight 16 row.purpose.token ++
      padNum 10 (toString row.entitlement.quanta) ++
      padNum 10 (toString row.consumption.quanta) ++
      padNum 10 (toString row.remaining.quanta) ++ " jpy")

private def budgetTableHeader : Widget :=
  muted
    (Loam.Tui.Layout.padRight 16 "Purpose" ++
      padNum 10 "Entitled" ++
      padNum 10 "Consumed" ++
      padNum 10 "Remaining")

private def budgetResultLines (state : State) : List Widget :=
  match state.budgetSnapshot with
  | none => [muted "No explicit Budget Window has been run yet."]
  | some snapshot =>
      [ line ("Budget window [" ++ snapshot.start ++ ", " ++ snapshot.endExclusive ++ ")")
      , muted (toString snapshot.rows.length ++ " remembered purpose(s)")
      , budgetTableHeader
      ] ++
      (snapshot.rows.take 10).map budgetRowLine ++
      [ muted "Remaining is derived exactly as Entitlement - Consumption." ]

private def budgetView (state : State) : Widget :=
  .column <|
    [ line "Reports / Budget Window"
    , muted "Calendar month is only a coordinate convenience, not a household cycle."
    , line ("Window: " ++ windowSourceLabel state)
    , muted "Named presets are replaceable query config; reports still receive explicit coordinates only."
    , blank
    , field state 0 "Start" state.window.form.start
    , field state 1 "End (exclusive)" state.window.form.endExclusive
    , .row [span "[Run]" (if state.window.form.focus.val = 2 then .selected else .normal)]
    , muted "Coordinates stay explicit [start, end); no cycle or budget period is inferred."
    , blank
    ] ++
    budgetResultLines state ++
    [ blank
    , muted "[ / ] window source   ← / → Calendar Month   m selected-day month"
    , muted "Tab / Shift-Tab focus   Enter next/run   Backspace delete"
    , muted "b / Esc Reports menu   q quit"
    , line state.notice
    ]


private def fullView (state : State) (bounds : Option Bounds := none) : Widget :=
  match state.mode with
  | .menu => menuView state
  | .stockFlow => stockFlowView state
  | .transactionsFlow => transactionsFlowView state bounds
  | .incomeExpense => incomeExpenseView state
  | .balances => balancesView state
  | .liquidity => liquidityView state
  | .budgetWindow => budgetView state

/-- Number of existing trailing notice/help rows kept outside the scrolling body. -/
private def fixedFooterSize : Mode → Nat
  | .menu => 3
  | .stockFlow => 4
  | .transactionsFlow => 4
  | .incomeExpense => 4
  | .balances => 4
  | .liquidity => 3
  | .budgetWindow => 4

private def viewParts (state : State) (bounds : Option Bounds := none) : List Widget × List Widget :=
  match fullView state bounds with
  | .column children =>
      let footerSize := min (fixedFooterSize state.mode) children.length
      let bodySize := children.length - footerSize
      (children.take bodySize, children.drop bodySize)
  | other => ([other], [])

private def bodyPageSize (bounds : Bounds) (footer : List Widget) : Nat :=
  bounds.height - (footer.length + 1)

/-- Largest meaningful vertical offset for the current report and terminal height. -/
def scrollLimit (bounds : Bounds) (state : State) : Nat :=
  let parts := viewParts state (some bounds)
  parts.1.length - bodyPageSize bounds parts.2

private def scrollPositionLine
    (mode : Mode) (offset page total : Nat) : Widget :=
  let first := if total = 0 then 0 else offset + 1
  let last := min total (offset + page)
  let action := match mode with | .menu => "select" | .transactionsFlow => "navigate" | _ => "scroll"
  muted ("Lines " ++ toString first ++ "–" ++ toString last ++ "/" ++ toString total ++
    "   ↑/↓ or j/k " ++ action)

private def requestedOffset (state : State) (page : Nat) : Nat :=
  match state.mode with
  | .menu =>
      -- The six menu rows follow four heading/context rows in `menuView`.
      (4 + state.menuIndex.val + 1) - page
  | .transactionsFlow =>
      if state.transactionsDetail then
        state.scroll
      else
        match state.transactionsSnapshot with
        | none => state.scroll
        | some snapshot =>
            let rows := transactionRows snapshot
            if rows.isEmpty then state.scroll
            else
              let index := min state.transactionsIndex (rows.length - 1)
              let selectedLine :=
                (transactionWindowLines state).length +
                (transactionSummaryPrefix snapshot rows).length + 2 + index
              (selectedLine + 1) - page
  | _ => state.scroll

/-- Bound only presentation rows; report answers and query coordinates are unchanged. -/
def viewForBounds (bounds : Bounds) (state : State) : Widget :=
  let parts := viewParts state (some bounds)
  let page := bodyPageSize bounds parts.2
  let offset := min (requestedOffset state page) (parts.1.length - page)
  let position := scrollPositionLine state.mode offset page parts.1.length
  if bounds.height < parts.2.length + 1 then
    -- In a tiny terminal, retain as much navigation as possible. Existing views
    -- put their notice last and their most essential back/quit row immediately
    -- before it, so reverse the navigation rows and omit body before overflowing.
    let navigation := parts.2.dropLast.reverse
    let notice := parts.2.getLast?.toList
    .column <| (navigation ++ [position] ++ notice).take bounds.height
  else
    .column <|
      (parts.1.drop offset).take page ++
      [position] ++
      parts.2

/-- Apply the existing interaction grammar, then clamp presentation-only scrolling. -/
def updateForBounds
    (bounds : Bounds) (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  let step := update state key
  { step with state := { step.state with scroll := min step.state.scroll (scrollLimit bounds step.state) } }

/-- Unbounded compatibility view used by existing pure presentation tests. -/
def view (state : State) : Widget := fullView state none

end Loam.Tui.Reports
