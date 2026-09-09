import Loam.ActualDate
import Loam.BoundaryPresetConfig
import Loam.BudgetWindowReview
import Loam.ConditionalBalancePathReview
import Loam.StockFlowReview
import Loam.TransactionsFlowReview
import Loam.Tui.Calendar
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Terminal

namespace Loam.Tui.Reports

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Production Reports workspace

Reports is presentation and query state only. Stock–Flow and Budget Window consume
surface-independent shared review answers. Accounting remains an explicit
evidence-limit surface. Liquidity keeps its unconditional UNKNOWN baseline while
also exposing the read-only conditional selected-balance path earned by
Observations 229 and 231.
-/

inductive Mode where
  | menu
  | stockFlow
  | transactionsFlow
  | accounting
  | liquidity
  | budgetWindow
  deriving Repr, DecidableEq

/-- Presentation-only source for the explicit report coordinates. -/
inductive WindowSource where
  | calendarMonth
  | preset (index : Nat)
  | custom
  deriving Repr, DecidableEq

structure Form where
  start : String := ""
  endExclusive : String := ""
  focus : Fin 3 := ⟨0, by decide⟩
  deriving Repr, DecidableEq

structure LiquidityForm where
  assumedCompleteThrough : String := ""
  focus : Fin 2 := ⟨0, by decide⟩
  deriving Repr, DecidableEq

inductive Query where
  | stockFlow (start endExclusive : String)
  | transactionsFlow (start endExclusive : String)
  | conditionalLiquidity (assumedCompleteThrough : String)
  | budgetWindow (start endExclusive : String)
  deriving Repr, DecidableEq

structure State where
  mode : Mode := .menu
  menuIndex : Fin 5 := ⟨0, by decide⟩
  form : Form := {}
  liquidityForm : LiquidityForm := {}
  calendarAnchor : String := ""
  windowPresets : List Loam.BoundaryPresetConfig.Preset := []
  windowSource : WindowSource := .calendarMonth
  stockFlowSnapshot : Option Loam.StockFlowReview.Snapshot := none
  transactionsSnapshot : Option Loam.TransactionsFlowReview.Snapshot := none
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
  match Loam.Tui.Calendar.calendarMonthWindowForDate? selectedDate with
  | some (start, endExclusive) =>
      {
        mode := .menu
        form := { start := start, endExclusive := endExclusive, focus := ⟨2, by decide⟩ }
        liquidityForm := liquidityFormForEndExclusive endExclusive
        calendarAnchor := selectedDate
        windowPresets := presets
        windowSource := .calendarMonth
      }
  | none =>
      {
        mode := .menu
        calendarAnchor := selectedDate
        windowPresets := presets
        windowSource := .calendarMonth
        notice := "Calendar-month prefill unavailable; enter explicit report coordinates."
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


def withLiquiditySnapshot
    (state : State) (snapshot : Loam.ConditionalBalancePathReview.Snapshot) : State :=
  { state with liquiditySnapshot := some snapshot, notice := "", scroll := 0 }


def withBudgetSnapshot
    (state : State) (snapshot : Loam.BudgetWindowReview.Snapshot) : State :=
  { state with budgetSnapshot := some snapshot, notice := "", scroll := 0 }

/-- Compatibility name for the pre-menu Budget Window surface. -/
def withSnapshot
    (state : State) (snapshot : Loam.BudgetWindowReview.Snapshot) : State :=
  withBudgetSnapshot state snapshot


def withError (state : State) (message : String) : State :=
  { state with
      stockFlowSnapshot := none
      transactionsSnapshot := none
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
      transactionsIndex := 0
      transactionsDetail := false
      liquiditySnapshot := none
      budgetSnapshot := none
      scroll := 0 }


def moveFocus (form : Form) (back : Bool) : Form :=
  let next := if back then (form.focus.val + 2) % 3 else (form.focus.val + 1) % 3
  { form with focus := ⟨next, by
      dsimp [next]
      split <;> exact Nat.mod_lt _ (by decide)⟩ }

private def moveLiquidityFocus (form : LiquidityForm) : LiquidityForm :=
  let next := (form.focus.val + 1) % 2
  { form with focus := ⟨next, by
      dsimp [next]
      exact Nat.mod_lt _ (by decide)⟩ }

private def moveMenu (state : State) (back : Bool) : State :=
  let next := if back then (state.menuIndex.val + 4) % 5 else (state.menuIndex.val + 1) % 5
  { state with menuIndex := ⟨next, by
      dsimp [next]
      split <;> exact Nat.mod_lt _ (by decide)⟩, notice := "" }


def editActive (form : Form) (edit : String → String) : Form :=
  if form.focus.val = 0 then { form with start := edit form.start }
  else if form.focus.val = 1 then { form with endExclusive := edit form.endExclusive }
  else form

private def editLiquidityActive
    (form : LiquidityForm) (edit : String → String) : LiquidityForm :=
  if form.focus.val = 0 then
    { form with assumedCompleteThrough := edit form.assumedCompleteThrough }
  else
    form

private def setCalendarWindow
    (state : State) (start endExclusive : String) : State :=
  clearResults {
    state with
      form := { state.form with start := start, endExclusive := endExclusive }
      windowSource := .calendarMonth
      notice := ""
  }

/-- Restore the calendar month containing the Home selected day. -/
def resetCalendarMonth (state : State) : State :=
  match Loam.Tui.Calendar.calendarMonthWindowForDate? state.calendarAnchor with
  | some (start, endExclusive) =>
      { (setCalendarWindow state start endExclusive) with
          form := { state.form with
            start := start
            endExclusive := endExclusive
            focus := ⟨2, by decide⟩ } }
  | none =>
      withError state "Calendar-month reset unavailable; enter an explicit window."

private def presetAt? : List Loam.BoundaryPresetConfig.Preset → Nat → Option Loam.BoundaryPresetConfig.Preset
  | [], _ => none
  | preset :: _, 0 => some preset
  | _ :: rest, index + 1 => presetAt? rest index

/-- Human-readable label for presentation only; it never enters a report query. -/
def windowSourceLabel (state : State) : String :=
  match state.windowSource with
  | .calendarMonth => "Calendar Month"
  | .custom => "Custom"
  | .preset index =>
      match presetAt? state.windowPresets index with
      | some preset => preset.name
      | none => "Unavailable preset"

private def selectPreset (state : State) (index : Nat) : State :=
  match presetAt? state.windowPresets index with
  | none =>
      clearResults {
        state with
          form := { start := "", endExclusive := "", focus := ⟨0, by decide⟩ }
          windowSource := .preset index
          notice := "Selected report preset is unavailable."
      }
  | some preset =>
      match Loam.BoundaryPresetConfig.windowForDate? preset state.calendarAnchor with
      | some (start, endExclusive) =>
          clearResults {
            state with
              form := { start := start, endExclusive := endExclusive, focus := ⟨2, by decide⟩ }
              windowSource := .preset index
              notice := ""
          }
      | none =>
          clearResults {
            state with
              form := { start := "", endExclusive := "", focus := ⟨0, by decide⟩ }
              windowSource := .preset index
              notice :=
                "Preset " ++ preset.name ++
                " has no explicit adjacent boundary window for " ++ state.calendarAnchor ++ "."
          }

/-- Cycle only among Calendar Month and loaded named presets; Custom is reached by editing. -/
def cycleWindowSource (state : State) (forward : Bool) : State :=
  let count := state.windowPresets.length + 1
  let current :=
    match state.windowSource with
    | .calendarMonth => 0
    | .preset index => index + 1
    | .custom => 0
  let next :=
    if forward then
      (current + 1) % count
    else
      (current + count - 1) % count
  if next = 0 then resetCalendarMonth state else selectPreset state (next - 1)

private def editWindowState (state : State) (edit : String → String) : State :=
  let next := clearResults {
    state with
      form := editActive state.form edit
      notice := ""
  }
  if state.form.focus.val < 2 then { next with windowSource := .custom } else next

private def resetLiquidityHorizon (state : State) : State :=
  match Loam.Tui.Calendar.calendarMonthWindowForDate? state.calendarAnchor with
  | some (_, endExclusive) =>
      { (clearResults state) with
          liquidityForm := liquidityFormForEndExclusive endExclusive
          notice := "" }
  | none =>
      withError state "Conditional horizon reset unavailable; enter an explicit date."

/-- Shift only while Calendar Month is the selected presentation source. -/
def shiftCalendarMonth (state : State) (forward : Bool) : State :=
  match state.windowSource with
  | .calendarMonth =>
      match Loam.Tui.Calendar.shiftCalendarMonthWindow?
          state.form.start state.form.endExclusive forward with
      | some (start, endExclusive) => setCalendarWindow state start endExclusive
      | none =>
          { state with
              notice := "Calendar-month coordinates are unavailable; press m to restore them." }
  | _ =>
      { state with
          notice := "Arrow keys shift Calendar Month only; press m or [ / ] to choose a source." }

private def selectMenuMode (state : State) : State :=
  let mode :=
    match state.menuIndex.val with
    | 0 => Mode.stockFlow
    | 1 => Mode.transactionsFlow
    | 2 => Mode.accounting
    | 3 => Mode.liquidity
    | _ => Mode.budgetWindow
  { state with mode := mode, notice := "", scroll := 0 }

private def updateMenu (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'b' | .input 'B' => { state, back := true }
  | .up | .input 'k' | .input 'K' => { state := moveMenu state true }
  | .down | .input 'j' | .input 'J' => { state := moveMenu state false }
  | .enter => { state := selectMenuMode state }
  | .input 's' | .input 'S' =>
      { state := { state with mode := .stockFlow, notice := "", scroll := 0 } }
  | .input 't' | .input 'T' =>
      { state := { state with mode := .transactionsFlow, notice := "", scroll := 0 } }
  | .input 'a' | .input 'A' =>
      { state := { state with mode := .accounting, notice := "", scroll := 0 } }
  | .input 'l' | .input 'L' =>
      { state := { state with mode := .liquidity, notice := "", scroll := 0 } }
  | .input 'w' | .input 'W' =>
      { state := { state with mode := .budgetWindow, notice := "", scroll := 0 } }
  | _ => { state }

private def queryForMode (state : State) : Option Query :=
  match state.mode with
  | .stockFlow => some (.stockFlow state.form.start state.form.endExclusive)
  | .transactionsFlow => some (.transactionsFlow state.form.start state.form.endExclusive)
  | .budgetWindow => some (.budgetWindow state.form.start state.form.endExclusive)
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
  | .tab => { state := { state with form := moveFocus state.form false, notice := "" } }
  | .shiftTab => { state := { state with form := moveFocus state.form true, notice := "" } }
  | .backspace =>
      { state := editWindowState state (fun text => String.ofList text.toList.dropLast) }
  | .input 'm' | .input 'M' => { state := resetCalendarMonth state }
  | .input char =>
      { state := editWindowState state (fun text => text.push char) }
  | .enter =>
      if state.form.focus.val < 2 then
        { state := { state with form := moveFocus state.form false, notice := "" } }
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
            { state := { state with form := moveFocus state.form false, notice := "" } }
        | .shiftTab =>
            { state := { state with form := moveFocus state.form true, notice := "" } }
        | .backspace =>
            if state.form.focus.val < 2 then
              { state := editWindowState state (fun text => String.ofList text.toList.dropLast) }
            else
              { state }
        | .input 'm' | .input 'M' => { state := resetCalendarMonth state }
        | .input char =>
            if state.form.focus.val < 2 then
              { state := editWindowState state (fun text => text.push char) }
            else
              { state }
        | .enter =>
            if state.form.focus.val < 2 then
              { state := { state with form := moveFocus state.form false, notice := "" } }
            else if rows.isEmpty then
              { state := { state with notice := "No quantity activity in this window." } }
            else
              { state := { state with transactionsDetail := true, scroll := 0, notice := "" } }
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

private def updateEvidenceLimit (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'b' | .input 'B' =>
      { state := { state with mode := .menu, notice := "", scroll := 0 } }
  | .up | .input 'k' | .input 'K' =>
      { state := { state with scroll := state.scroll - 1 } }
  | .down | .input 'j' | .input 'J' =>
      { state := { state with scroll := state.scroll + 1 } }
  | _ => { state }


def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match state.mode with
  | .menu => updateMenu state key
  | .stockFlow => updateWindowReport state key
  | .transactionsFlow => updateTransactionsFlow state key
  | .budgetWindow => updateWindowReport state key
  | .accounting => updateEvidenceLimit state key
  | .liquidity => updateLiquidity state key

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def signedQuanta (quantity : Loam.Core.Quantity) : String :=
  if quantity.quanta > 0 then "+" ++ toString quantity.quanta else toString quantity.quanta

private def field (state : State) (index : Nat) (label text : String) : Widget :=
  .row
    [ span (label ++ ": ")
    , span (if text.isEmpty then "_" else text)
        (if state.form.focus.val = index then .selected else .normal)
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
    , menuRow state 2 "Accounting" "role projection not justified by current authority"
    , menuRow state 3 "Liquidity" "UNKNOWN baseline + explicit conditional overlay"
    , menuRow state 4 "Budget Window" "explicit entitlement / consumption query"
    , blank
    , muted "↑/↓ or j/k select   Enter open   s/t/a/l/w direct"
    , muted "b / Esc home   q quit"
    , line state.notice
    ]

private def stockFlowResultLines (state : State) : List Widget :=
  match state.stockFlowSnapshot with
  | none => [muted "No explicit Stock–Flow window has been run yet."]
  | some snapshot =>
      [ line ("Window [" ++ snapshot.start ++ ", " ++ snapshot.endExclusive ++ ")")
      , line ("Reconstructed at start: " ++ toString snapshot.reconstructedStart.quanta ++ " jpy")
      , line ("Reconstructed at end:   " ++ toString snapshot.reconstructedEnd.quanta ++ " jpy")
      , blank
      , line ("Tracked increases across Events: " ++ signedQuanta snapshot.increasesAcrossEvents ++ " jpy")
      , line ("Tracked decreases across Events: " ++ signedQuanta snapshot.decreasesAcrossEvents ++ " jpy")
      , line ("Net change:                     " ++ signedQuanta snapshot.netChange ++ " jpy")
      , blank
      , muted ("Current tracked balance now: " ++ toString snapshot.currentTracked.quanta ++ " jpy")
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
    , field state 0 "Start" state.form.start
    , field state 1 "End (exclusive)" state.form.endExclusive
    , .row [span "[Run]" (if state.form.focus.val = 2 then .selected else .normal)]
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
  , field state 0 "Start" state.form.start
  , field state 1 "End (exclusive)" state.form.endExclusive
  , .row [span "[Run]" (if state.form.focus.val = 2 then .selected else .normal)]
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

private def padNum (columns : Nat) (text : String) : String :=
  let width := Loam.Tui.Layout.displayWidth text
  if width ≥ columns then text
  else Loam.Tui.Layout.padLeft columns text

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
  let net := padNum layout.netWidth (toString activity.net.quanta)
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

private def accountingView (state : State) : Widget :=
  .column
    [ line "Reports / Accounting"
    , muted "Where is the accounting-role counterpart structure?"
    , blank
    , line "Accounting projection: UNAVAILABLE"
    , blank
    , muted "Current production authority does not justify the role evidence needed"
    , muted "for this report. The reverted read adapter is not restored here."
    , muted "Reports will not infer roles from Locus names, signs, Purpose,"
    , muted "or presentation state merely to make this screen numeric."
    , blank
    , muted "b / Esc Reports menu   q quit"
    , line state.notice
    ]

private def liquidityPointLine
    (measure : Loam.Core.MeasureId)
    (point : Loam.ConditionalBalancePathReview.Point) : Widget :=
  line
    ("- " ++ point.date ++
      "  Scheduled " ++ signedQuanta point.scheduledChange ++
      "  -> " ++ toString point.balance.quanta ++ " " ++ measure.token)

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
    ("- " ++ row.purpose.token ++
      ": entitlement " ++ toString row.entitlement.quanta ++
      " | consumption " ++ toString row.consumption.quanta ++
      " | remaining " ++ toString row.remaining.quanta ++ " jpy")

private def budgetResultLines (state : State) : List Widget :=
  match state.budgetSnapshot with
  | none => [muted "No explicit Budget Window has been run yet."]
  | some snapshot =>
      [ line ("Budget window [" ++ snapshot.start ++ ", " ++ snapshot.endExclusive ++ ")")
      , muted (toString snapshot.rows.length ++ " remembered purpose(s)")
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
    , field state 0 "Start" state.form.start
    , field state 1 "End (exclusive)" state.form.endExclusive
    , .row [span "[Run]" (if state.form.focus.val = 2 then .selected else .normal)]
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
  | .accounting => accountingView state
  | .liquidity => liquidityView state
  | .budgetWindow => budgetView state

/-- Number of existing trailing notice/help rows kept outside the scrolling body. -/
private def fixedFooterSize : Mode → Nat
  | .menu => 3
  | .stockFlow => 4
  | .transactionsFlow => 4
  | .accounting => 2
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
      -- The five menu rows follow four heading/context rows in `menuView`.
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
