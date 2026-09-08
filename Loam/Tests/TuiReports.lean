import Loam.Tui.Reports

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def isMenu (state : Loam.Tui.Reports.State) : Bool :=
  match state.mode with
  | .menu => true
  | _ => false

private def isStockFlow (state : Loam.Tui.Reports.State) : Bool :=
  match state.mode with
  | .stockFlow => true
  | _ => false

private def isLiquidity (state : Loam.Tui.Reports.State) : Bool :=
  match state.mode with
  | .liquidity => true
  | _ => false


def main : IO Unit := do
  let initial := Loam.Tui.Reports.initialForDate "2026-09-07"
  let menuText := widgetText (Loam.Tui.Reports.view initial)
  expect (contains "Reports" menuText) "Reports menu heading was not rendered"
  expect (contains "Stock–Flow" menuText) "Reports menu lost Stock–Flow"
  expect (contains "Accounting" menuText) "Reports menu lost Accounting"
  expect (contains "Liquidity" menuText) "Reports menu lost Liquidity"
  expect (contains "Budget Window" menuText) "Reports menu lost Budget Window"
  expect (initial.form.start == "2026-09-01")
    "Reports did not seed the selected-day calendar month start"
  expect (initial.form.endExclusive == "2026-10-01")
    "Reports did not seed the selected-day calendar month end"
  expect (initial.form.focus.val == 2) "calendar-month prefill did not focus Run"
  expect (initial.liquidityForm.assumedCompleteThrough == "2026-09-30")
    "conditional outlook did not prefill the selected-day calendar month end"
  expect (initial.liquidityForm.focus.val == 1)
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
  expect (isStockFlow stock) "default Reports selection did not open Stock–Flow"
  let stockText := widgetText (Loam.Tui.Reports.view stock)
  expect (contains "Reports / Stock–Flow" stockText) "Stock–Flow heading was not rendered"
  expect (contains "Start: 2026-09-01" stockText) "Stock–Flow lost explicit start"
  expect (contains "End (exclusive): 2026-10-01" stockText)
    "Stock–Flow lost explicit end"
  expect (contains "Calendar month is only a coordinate convenience" stockText)
    "Stock–Flow surface lost the calendar-coordinate non-claim"

  let previous := (Loam.Tui.Reports.update stock .left).state
  expect (previous.form.start == "2026-08-01") "left did not shift to previous calendar month"
  expect (previous.form.endExclusive == "2026-09-01")
    "left did not keep an explicit half-open calendar month"

  let next := (Loam.Tui.Reports.update stock .right).state
  expect (next.form.start == "2026-10-01") "right did not shift to next calendar month"
  expect (next.form.endExclusive == "2026-11-01")
    "right did not keep an explicit half-open calendar month"

  let decemberBase := Loam.Tui.Reports.initialForDate "2026-12-20"
  let december := (Loam.Tui.Reports.update decemberBase .enter).state
  let january := (Loam.Tui.Reports.update december .right).state
  expect (january.form.start == "2027-01-01") "calendar month shift lost year rollover"
  expect (january.form.endExclusive == "2027-02-01")
    "calendar month year rollover end was wrong"

  let explicit : Loam.Tui.Reports.State := {
    stock with
      form := {
        start := "2026-08-17"
        endExclusive := "2026-10-15"
        focus := ⟨2, by decide⟩
      }
  }
  let shiftedExplicit := (Loam.Tui.Reports.update explicit .right).state
  expect (shiftedExplicit.form.start == "2026-08-17")
    "arrow key rewrote a manually edited non-calendar window"
  expect (contains "press m to restore" shiftedExplicit.notice)
    "non-calendar arrow refusal did not explain the recovery action"

  let restored := (Loam.Tui.Reports.update explicit (.input 'm')).state
  expect (restored.form.start == "2026-09-01") "m did not restore selected-day calendar month start"
  expect (restored.form.endExclusive == "2026-10-01")
    "m did not restore selected-day calendar month end"
  expect (restored.form.focus.val == 2) "m did not return focus to Run"

  let runStep := Loam.Tui.Reports.update explicit .enter
  match runStep.query with
  | some (.stockFlow start endExclusive) =>
      expect (start == "2026-08-17") "Stock–Flow Run changed explicit start"
      expect (endExclusive == "2026-10-15") "Stock–Flow Run changed explicit end"
  | _ => throw (IO.userError "Stock–Flow Run did not emit its explicit window query")

  let stockReport := Loam.Tui.Reports.withStockFlowSnapshot explicit {
    start := "2026-08-17"
    endExclusive := "2026-10-15"
    reconstructedStart := Quantity.ofQuanta 100
    reconstructedEnd := Quantity.ofQuanta 130
    increasesAcrossEvents := Quantity.ofQuanta 50
    decreasesAcrossEvents := Quantity.ofQuanta (-20)
    netChange := Quantity.ofQuanta 30
    currentTracked := Quantity.ofQuanta 140
  }
  let stockReportText := widgetText (Loam.Tui.Reports.view stockReport)
  expect (contains "Reconstructed at start: 100 jpy" stockReportText)
    "Stock–Flow start reconstruction was not rendered"
  expect (contains "Reconstructed at end:   130 jpy" stockReportText)
    "Stock–Flow end reconstruction was not rendered"
  expect (contains "Tracked increases across Events: +50 jpy" stockReportText)
    "Stock–Flow increases were not rendered"
  expect (contains "Tracked decreases across Events: -20 jpy" stockReportText)
    "Stock–Flow decreases were not rendered"
  expect (contains "Net change:                     +30 jpy" stockReportText)
    "Stock–Flow net change was not rendered"
  expect (contains "Current tracked balance now: 140 jpy" stockReportText)
    "Stock–Flow current context was not rendered separately"
  expect (contains "not income/spending" stockReportText)
    "Stock–Flow lost its sign/classification non-claim"

  let editing : Loam.Tui.Reports.State := {
    stockReport with form := { stockReport.form with focus := ⟨0, by decide⟩ }
  }
  let edited := (Loam.Tui.Reports.update editing (.input '9')).state
  expect edited.stockFlowSnapshot.isNone
    "editing Stock–Flow coordinates left a stale report snapshot visible"

  let backToMenu := (Loam.Tui.Reports.update stockReport .escape).state
  expect (isMenu backToMenu) "Stock–Flow escape did not return to Reports menu"
  match Loam.Tui.Reports.update backToMenu .escape with
  | { back := true, .. } => pure ()
  | _ => throw (IO.userError "Reports menu escape did not return Home intent")

  let accounting := { initial with mode := Loam.Tui.Reports.Mode.accounting }
  let accountingText := widgetText (Loam.Tui.Reports.view accounting)
  expect (contains "Accounting projection: UNAVAILABLE" accountingText)
    "Accounting page invented a projection after the read-adapter revert"
  expect (contains "reverted read adapter is not restored" accountingText)
    "Accounting page lost the current authority boundary"
  expect (contains "not infer roles" accountingText)
    "Accounting page lost its no-inference boundary"

  let liquidity := { initial with mode := Loam.Tui.Reports.Mode.liquidity }
  expect (isLiquidity liquidity) "Liquidity fixture did not enter the Liquidity surface"
  let liquidityText := widgetText (Loam.Tui.Reports.view liquidity)
  expect (contains "Forecast path: UNKNOWN" liquidityText)
    "Liquidity page converted incomplete future evidence into a forecast"
  expect (contains "Known low-water mark: UNKNOWN" liquidityText)
    "Liquidity page invented an unconditional low-water mark"
  expect (contains "Read-only conditional query" liquidityText)
    "Liquidity page lost the explicit conditional overlay"
  expect (contains "Assume Scheduled complete through: 2026-09-30" liquidityText)
    "Liquidity page lost the explicit assumption horizon"
  expect (contains "does not write or upgrade the assumption into evidence" liquidityText)
    "Liquidity page lost the no-write provenance boundary"

  match (Loam.Tui.Reports.update liquidity .enter).query with
  | some (.conditionalLiquidity through) =>
      expect (through == "2026-09-30")
        "conditional Liquidity Run changed the explicit assumption horizon"
  | _ => throw (IO.userError "Liquidity Run did not emit a conditional query")

  let liquidityReport := Loam.Tui.Reports.withLiquiditySnapshot liquidity {
    asOf := "2026-09-08"
    assumedCompleteThrough := "2026-09-30"
    measure := ⟨"jpy"⟩
    currentSelected := Quantity.ofQuanta 1000
    points :=
      [ { date := "2026-09-10"
        , scheduledChange := Quantity.ofQuanta (-300)
        , balance := Quantity.ofQuanta 700 } ]
    finalAtHorizon := Quantity.ofQuanta 700
    lowWater := Quantity.ofQuanta 700
  }
  let liquidityReportText := widgetText (Loam.Tui.Reports.view liquidityReport)
  expect (contains "Forecast path: UNKNOWN" liquidityReportText)
    "conditional overlay replaced the unconditional UNKNOWN baseline"
  expect (contains "CONDITIONAL selected-balance outlook" liquidityReportText)
    "conditional result lost its epistemic label"
  expect (contains "Scheduled -300  -> 700 jpy" liquidityReportText)
    "conditional change point was not rendered"
  expect (contains "Conditional day-boundary low-water: 700 jpy" liquidityReportText)
    "conditional day-boundary low-water was not rendered"
  expect (contains "not canonical liquidity" liquidityReportText)
    "conditional result promoted balance-view into canonical liquidity"
  expect (contains "no intraday low-water is claimed" liquidityReportText)
    "conditional result lost the intraday-order non-claim"

  let liquidityEditing : Loam.Tui.Reports.State := {
    liquidityReport with
      liquidityForm := { liquidityReport.liquidityForm with focus := ⟨0, by decide⟩ }
  }
  let liquidityEdited := (Loam.Tui.Reports.update liquidityEditing .backspace).state
  expect liquidityEdited.liquiditySnapshot.isNone
    "editing the conditional horizon left a stale liquidity snapshot visible"

  let resetLiquidity := (Loam.Tui.Reports.update liquidityEditing (.input 'm')).state
  expect (resetLiquidity.liquidityForm.assumedCompleteThrough == "2026-09-30")
    "m did not restore selected-day calendar month-end assumption"
  expect (resetLiquidity.liquidityForm.focus.val == 1)
    "m did not restore conditional Run focus"

  let budget : Loam.Tui.Reports.State := {
    initial with
      mode := .budgetWindow
      form := {
        start := "2026-08-17"
        endExclusive := "2026-10-15"
        focus := ⟨2, by decide⟩
      }
  }
  match (Loam.Tui.Reports.update budget .enter).query with
  | some (.budgetWindow start endExclusive) =>
      expect (start == "2026-08-17") "Budget Window Run changed explicit start"
      expect (endExclusive == "2026-10-15") "Budget Window Run changed explicit end"
  | _ => throw (IO.userError "Budget Window Run did not emit its explicit window query")

  let food : Loam.BudgetWindowReview.Row := {
    purpose := ⟨"food"⟩
    entitlement := Quantity.ofQuanta 100
    consumption := Quantity.ofQuanta 30
    remaining := Quantity.ofQuanta 70
  }
  let budgetReport := Loam.Tui.Reports.withBudgetSnapshot budget {
    start := "2026-08-17"
    endExclusive := "2026-10-15"
    rows := [food]
  }
  let budgetText := widgetText (Loam.Tui.Reports.view budgetReport)
  expect (contains "Budget window [2026-08-17, 2026-10-15)" budgetText)
    "explicit Budget Window was not rendered"
  expect (contains "food: entitlement 100 | consumption 30 | remaining 70 jpy" budgetText)
    "Budget Window components were not rendered"
  expect (contains "Remaining is derived exactly as Entitlement - Consumption." budgetText)
    "Budget Window lost the derived Remaining boundary"

  IO.println
    "TUI Reports: menu, Stock–Flow, evidence-gated Accounting, conditional Liquidity, Budget Window and navigation passed."
