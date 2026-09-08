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
  let liquidityText := widgetText (Loam.Tui.Reports.view liquidity)
  expect (contains "Forecast path: UNKNOWN" liquidityText)
    "Liquidity page converted incomplete future evidence into a forecast"
  expect (contains "Known low-water mark: UNKNOWN" liquidityText)
    "Liquidity page invented a low-water mark"
  expect (contains "No numeric path is extended" liquidityText)
    "Liquidity page lost its horizon refusal explanation"

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
    "TUI Reports: menu, Stock–Flow, evidence-gated Accounting/Liquidity, Budget Window and navigation passed."
