from pathlib import Path


def replace_exact(path: str, old: str, new: str, expected: int = 1) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != expected:
        raise SystemExit(
            f"{path}: expected {expected} match(es), got {count}: {old[:100]!r}"
        )
    p.write_text(text.replace(old, new))


reports = "Loam/Tui/Reports.lean"
replace_exact(
    reports,
    "import Loam.ActualDate\n",
    "import Loam.ActualDate\nimport Loam.BoundaryPresetConfig\n",
)
replace_exact(
    reports,
    "inductive Mode where\n  | menu\n  | stockFlow\n  | accounting\n  | liquidity\n  | budgetWindow\n  deriving Repr, DecidableEq\n\nstructure Form where",
    "inductive Mode where\n  | menu\n  | stockFlow\n  | accounting\n  | liquidity\n  | budgetWindow\n  deriving Repr, DecidableEq\n\n/-- Presentation-only source for the explicit report coordinates. -/\ninductive WindowSource where\n  | calendarMonth\n  | preset (index : Nat)\n  | custom\n  deriving Repr, DecidableEq\n\nstructure Form where",
)
replace_exact(
    reports,
    '  calendarAnchor : String := ""\n  stockFlowSnapshot : Option Loam.StockFlowReview.Snapshot := none',
    '  calendarAnchor : String := ""\n  windowPresets : List Loam.BoundaryPresetConfig.Preset := []\n  windowSource : WindowSource := .calendarMonth\n  stockFlowSnapshot : Option Loam.StockFlowReview.Snapshot := none',
)
replace_exact(
    reports,
    '''/--
Seed the shared explicit-window editor with the Gregorian month containing the
Home selected day. This is presentation convenience only, not a household cycle.
The conditional outlook gets the final day of that same month as an editable
assumption-horizon prefill; it is not executed until the user explicitly runs it.
-/
def initialForDate (selectedDate : String) : State :=
  match Loam.Tui.Calendar.calendarMonthWindowForDate? selectedDate with
  | some (start, endExclusive) =>
      {
        mode := .menu
        form := { start := start, endExclusive := endExclusive, focus := ⟨2, by decide⟩ }
        liquidityForm := liquidityFormForEndExclusive endExclusive
        calendarAnchor := selectedDate
      }
  | none =>
      {
        mode := .menu
        calendarAnchor := selectedDate
        notice := "Calendar-month prefill unavailable; enter explicit report coordinates."
      }''',
    '''/--
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
  initialForDateWithPresets selectedDate []''',
)
replace_exact(
    reports,
    '      form := { state.form with start := start, endExclusive := endExclusive }\n      notice := ""',
    '      form := { state.form with start := start, endExclusive := endExclusive }\n      windowSource := .calendarMonth\n      notice := ""',
)
replace_exact(
    reports,
    '''  | none =>
      withError state "Calendar-month reset unavailable; enter an explicit window."

private def resetLiquidityHorizon''',
    '''  | none =>
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

private def resetLiquidityHorizon''',
)
replace_exact(
    reports,
    '''/-- Shift only when the currently visible coordinates are exactly one calendar month. -/
def shiftCalendarMonth (state : State) (forward : Bool) : State :=
  match Loam.Tui.Calendar.shiftCalendarMonthWindow?
      state.form.start state.form.endExclusive forward with
  | some (start, endExclusive) => setCalendarWindow state start endExclusive
  | none =>
      { state with
          notice := "Arrow keys shift calendar-month windows only; press m to restore one." }''',
    '''/-- Shift only while Calendar Month is the selected presentation source. -/
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
          notice := "Arrow keys shift Calendar Month only; press m or [ / ] to choose a source." }''',
)
replace_exact(
    reports,
    '''  | .left => { state := shiftCalendarMonth state false }
  | .right => { state := shiftCalendarMonth state true }
  | .tab =>''',
    '''  | .left => { state := shiftCalendarMonth state false }
  | .right => { state := shiftCalendarMonth state true }
  | .input '[' => { state := cycleWindowSource state false }
  | .input ']' => { state := cycleWindowSource state true }
  | .tab =>''',
)
replace_exact(
    reports,
    '''  | .backspace =>
      { state := clearResults { state with
          form := editActive state.form (fun text => String.ofList text.toList.dropLast)
          notice := "" } }
  | .input 'm' | .input 'M' => { state := resetCalendarMonth state }
  | .input char =>
      { state := clearResults { state with
          form := editActive state.form (fun text => text.push char)
          notice := "" } }''',
    '''  | .backspace =>
      { state := editWindowState state (fun text => String.ofList text.toList.dropLast) }
  | .input 'm' | .input 'M' => { state := resetCalendarMonth state }
  | .input char =>
      { state := editWindowState state (fun text => text.push char) }''',
)
replace_exact(
    reports,
    '''    , muted "Calendar month is only a coordinate convenience, not a household cycle."
    , blank
    , field state 0 "Start" state.form.start''',
    '''    , muted "Calendar month is only a coordinate convenience, not a household cycle."
    , line ("Window: " ++ windowSourceLabel state)
    , muted "Named presets are replaceable query config; reports still receive explicit coordinates only."
    , blank
    , field state 0 "Start" state.form.start''',
    expected=2,
)
replace_exact(
    reports,
    '''    , muted "← / → calendar month   m selected-day month"
    , muted "Tab / Shift-Tab focus   Enter next/run   Backspace delete"''',
    '''    , muted "[ / ] window source   ← / → Calendar Month   m selected-day month"
    , muted "Tab / Shift-Tab focus   Enter next/run   Backspace delete"''',
    expected=2,
)

cli = "Loam/Tui/Cli.lean"
replace_exact(
    cli,
    "import Loam.Tui.Reports\n",
    "import Loam.Tui.Reports\nimport Loam.BoundaryPresetConfig\n",
)
replace_exact(
    cli,
    '''  else if isHome && (key = .input 'v' || key = .input 'V') then
    let reports := Loam.Tui.Reports.initialForDate state.selectedDate
    let reportsFrame := compileWidget (Loam.Tui.Reports.view reports)''',
    '''  else if isHome && (key = .input 'v' || key = .input 'V') then
    let reports ←
      match ← Loam.BoundaryPresetConfig.load? (dataDir / "boundary-presets.tsv") with
      | some presets =>
          pure (Loam.Tui.Reports.initialForDateWithPresets state.selectedDate presets)
      | none =>
          let base := Loam.Tui.Reports.initialForDate state.selectedDate
          pure { base with
            notice := "Boundary preset config malformed; named presets unavailable." }
    let reportsFrame := compileWidget (Loam.Tui.Reports.view reports)''',
)

tests = "Loam/Tests/TuiReports.lean"
replace_exact(
    tests,
    '''  expect (initial.liquidityForm.focus.val == 1)
    "conditional outlook prefill did not focus explicit Run"

  let stock := (Loam.Tui.Reports.update initial .enter).state
''',
    '''  expect (initial.liquidityForm.focus.val == 1)
    "conditional outlook prefill did not focus explicit Run"

  let pension : Loam.BoundaryPresetConfig.Preset := {
    name := "Pension"
    boundaries := ["2026-08-15", "2026-10-15"]
  }
  let presetInitial := Loam.Tui.Reports.initialForDateWithPresets "2026-09-07" [pension]
  let presetStock := (Loam.Tui.Reports.update presetInitial .enter).state
  let pensionState := (Loam.Tui.Reports.update presetStock (.input ']')).state
  expect (Loam.Tui.Reports.windowSourceLabel pensionState == "Pension")
    "named report preset was not selected"
  expect (pensionState.form.start == "2026-08-15")
    "Pension preset did not resolve the explicit previous boundary"
  expect (pensionState.form.endExclusive == "2026-10-15")
    "Pension preset did not resolve the explicit next boundary"
  let pensionText := widgetText (Loam.Tui.Reports.view pensionState)
  expect (contains "Window: Pension" pensionText)
    "Reports did not render the selected replaceable preset"
  expect (contains "explicit coordinates only" pensionText)
    "Reports lost the preset-to-coordinate boundary"
  match (Loam.Tui.Reports.update pensionState .enter).query with
  | some (.stockFlow start endExclusive) =>
      expect (start == "2026-08-15") "preset Stock-Flow query changed start"
      expect (endExclusive == "2026-10-15") "preset Stock-Flow query changed end"
  | _ => throw (IO.userError "preset Stock-Flow did not reduce to an explicit coordinate query")

  let calendarAgain := (Loam.Tui.Reports.update pensionState (.input ']')).state
  expect (Loam.Tui.Reports.windowSourceLabel calendarAgain == "Calendar Month")
    "window-source cycle did not return to Calendar Month"
  expect (calendarAgain.form.start == "2026-09-01")
    "Calendar Month source did not restore selected-day month start"
  expect (calendarAgain.form.endExclusive == "2026-10-01")
    "Calendar Month source did not restore selected-day month end"

  let customEditing : Loam.Tui.Reports.State := {
    pensionState with form := { pensionState.form with focus := ⟨0, by decide⟩ }
  }
  let customState := (Loam.Tui.Reports.update customEditing .backspace).state
  expect (Loam.Tui.Reports.windowSourceLabel customState == "Custom")
    "manual coordinate edit did not become Custom presentation state"

  let outBase := Loam.Tui.Reports.initialForDateWithPresets "2026-10-15" [pension]
  let outStock := (Loam.Tui.Reports.update outBase .enter).state
  let outPreset := (Loam.Tui.Reports.update outStock (.input ']')).state
  expect (outPreset.form.start.isEmpty && outPreset.form.endExclusive.isEmpty)
    "preset without a later explicit boundary left stale coordinates visible"
  expect (contains "no explicit adjacent boundary window" outPreset.notice)
    "preset exhaustion did not fail closed with an explanation"

  let stock := (Loam.Tui.Reports.update initial .enter).state
''',
)

print("boundary preset TUI patch applied")
