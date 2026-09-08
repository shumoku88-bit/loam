import Loam.ActualDate
import Loam.BoundaryPresetConfig
import Loam.BudgetWindowReview
import Loam.ConditionalBalancePathReview
import Loam.StockFlowReview
import Loam.Tui.Calendar
import Loam.Tui.Kernel
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
  | conditionalLiquidity (assumedCompleteThrough : String)
  | budgetWindow (start endExclusive : String)
  deriving Repr, DecidableEq

structure State where
  mode : Mode := .menu
  menuIndex : Fin 4 := ⟨0, by decide⟩
  form : Form := {}
  liquidityForm : LiquidityForm := {}
  calendarAnchor : String := ""
  windowPresets : List Loam.BoundaryPresetConfig.Preset := []
  windowSource : WindowSource := .calendarMonth
  stockFlowSnapshot : Option Loam.StockFlowReview.Snapshot := none
  liquiditySnapshot : Option Loam.ConditionalBalancePathReview.Snapshot := none
  budgetSnapshot : Option Loam.BudgetWindowReview.Snapshot := none
  notice : String := ""
  deriving Repr, DecidableEq

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
  { state with stockFlowSnapshot := some snapshot, notice := "" }


def withLiquiditySnapshot
    (state : State) (snapshot : Loam.ConditionalBalancePathReview.Snapshot) : State :=
  { state with liquiditySnapshot := some snapshot, notice := "" }


def withBudgetSnapshot
    (state : State) (snapshot : Loam.BudgetWindowReview.Snapshot) : State :=
  { state with budgetSnapshot := some snapshot, notice := "" }

/-- Compatibility name for the pre-menu Budget Window surface. -/
def withSnapshot
    (state : State) (snapshot : Loam.BudgetWindowReview.Snapshot) : State :=
  withBudgetSnapshot state snapshot


def withError (state : State) (message : String) : State :=
  { state with
      stockFlowSnapshot := none
      liquiditySnapshot := none
      budgetSnapshot := none
      notice := message }

private def clearResults (state : State) : State :=
  { state with
      stockFlowSnapshot := none
      liquiditySnapshot := none
      budgetSnapshot := none }


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
  let next := if back then (state.menuIndex.val + 3) % 4 else (state.menuIndex.val + 1) % 4
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

/-- Human-readable label for presentation only; it never enters a report query. -/
def windowSourceLabel (state : State) : String :=
  match state.windowSource with
  | .calendarMonth => "Calendar Month"
  | .custom => "Custom"
  | .preset index =>
      match state.windowPresets.get? index with
      | some preset => preset.name
      | none => "Unavailable preset"

private def selectPreset (state : State) (index : Nat) : State :=
  match state.windowPresets.get? index with
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
    | 1 => Mode.accounting
    | 2 => Mode.liquidity
    | _ => Mode.budgetWindow
  { state with mode := mode, notice := "" }

private def updateMenu (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'b' | .input 'B' => { state, back := true }
  | .up | .input 'k' | .input 'K' => { state := moveMenu state true }
  | .down | .input 'j' | .input 'J' => { state := moveMenu state false }
  | .enter => { state := selectMenuMode state }
  | .input 's' | .input 'S' => { state := { state with mode := .stockFlow, notice := "" } }
  | .input 'a' | .input 'A' => { state := { state with mode := .accounting, notice := "" } }
  | .input 'l' | .input 'L' => { state := { state with mode := .liquidity, notice := "" } }
  | .input 'w' | .input 'W' => { state := { state with mode := .budgetWindow, notice := "" } }
  | _ => { state }

private def queryForMode (state : State) : Option Query :=
  match state.mode with
  | .stockFlow => some (.stockFlow state.form.start state.form.endExclusive)
  | .budgetWindow => some (.budgetWindow state.form.start state.form.endExclusive)
  | _ => none

private def updateWindowReport (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'b' | .input 'B' =>
      { state := { state with mode := .menu, notice := "" } }
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

private def updateLiquidity (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'b' | .input 'B' =>
      { state := { state with mode := .menu, notice := "" } }
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
      { state := { state with mode := .menu, notice := "" } }
  | _ => { state }


def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match state.mode with
  | .menu => updateMenu state key
  | .stockFlow => updateWindowReport state key
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
    , menuRow state 1 "Accounting" "role projection not justified by current authority"
    , menuRow state 2 "Liquidity" "UNKNOWN baseline + explicit conditional overlay"
    , menuRow state 3 "Budget Window" "explicit entitlement / consumption query"
    , blank
    , muted "↑/↓ or j/k select   Enter open   s/a/l/w direct"
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


def view (state : State) : Widget :=
  match state.mode with
  | .menu => menuView state
  | .stockFlow => stockFlowView state
  | .accounting => accountingView state
  | .liquidity => liquidityView state
  | .budgetWindow => budgetView state

end Loam.Tui.Reports
