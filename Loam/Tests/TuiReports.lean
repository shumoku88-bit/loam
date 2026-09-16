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
  expect (contains "Income & Expense" menuText) "Reports menu lost Income & Expense"
  expect (contains "Balances" menuText) "Reports menu lost evidence-aware Balances"
  expect (contains "Liquidity" menuText) "Reports menu lost Liquidity"
  expect (contains "Budget Window" menuText) "Reports menu lost Budget Window"
  expect (initial.window.form.start == "2026-09-01")
    "Reports did not seed the selected-day calendar month start"
  expect (initial.window.form.endExclusive == "2026-10-01")
    "Reports did not seed the selected-day calendar month end"
  expect (initial.window.form.focus.val == 2) "calendar-month prefill did not focus Run"
  expect (initial.liquidityForm.assumedCompleteThrough == "2026-09-30")
    "conditional outlook did not prefill the selected-day calendar month end"
  expect (initial.liquidityForm.focus.val == 1)
    "conditional outlook prefill did not focus explicit Run"

  let balancesStep := Loam.Tui.Reports.update initial (.input 'r')
  expect (match balancesStep.state.mode with | .balances => true | _ => false)
    "Reports direct Balances key did not enter the shared RoleBalance surface"
  match balancesStep.query with
  | some .roleBalances => pure ()
  | _ => throw (IO.userError "Reports Balances surface did not request the shared RoleBalance answer")

  let cashCoordinate : EffectCoordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩
  let unsupportedDebt : EffectCoordinate := ⟨⟨"debt-mother-wifi"⟩, ⟨"jpy"⟩⟩
  let balancesReport := Loam.Tui.Reports.withRoleBalanceSnapshot balancesStep.state {
    rows :=
      [ { coordinate := cashCoordinate
        , role := .asset
        , quantity := Quantity.ofQuanta 12000 } ]
    unresolvedRoles := []
    unsupportedBalances :=
      [ { coordinate := unsupportedDebt, role := some .liability } ]
  }
  let balancesText := widgetText (Loam.Tui.Reports.view balancesReport)
  expect (contains "One RoleBalance answer; three presentation projections" balancesText)
    "Balances surface introduced or hid the shared projection boundary"
  expect (contains "Balance Sheet support: INCOMPLETE" balancesText)
    "Balances surface hid missing stock-role support"
  expect (contains "Known Net Worth subtotal: 12000 jpy" balancesText)
    "Balances surface lost the supported Asset subtotal"
  expect (contains "Qualified Net Worth: UNKNOWN" balancesText)
    "Balances surface promoted an incomplete Net Worth to knowledge"
  expect (contains "debt-mother-wifi" balancesText && contains "balance unsupported" balancesText)
    "Balances surface hid the unsupported liability witness"
  expect (contains "Trial Balance-shaped frontier" balancesText)
    "Balances surface did not preserve the coordinate-wide Trial Balance projection"

  let pension : Loam.BoundaryPresetConfig.Preset := {
    name := "Pension"
    boundaries := ["2026-08-15", "2026-10-15"]
  }
  let presetInitial := Loam.Tui.Reports.initialForDateWithPresets "2026-09-07" [pension]
  let presetStock := (Loam.Tui.Reports.update presetInitial .enter).state
  let pensionState := (Loam.Tui.Reports.update presetStock (.input ']')).state
  expect (Loam.Tui.Reports.windowSourceLabel pensionState == "Pension")
    "named report preset was not selected"
  expect (pensionState.window.form.start == "2026-08-15")
    "Pension preset did not resolve the explicit previous boundary"
  expect (pensionState.window.form.endExclusive == "2026-10-15")
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
  expect (calendarAgain.window.form.start == "2026-09-01")
    "Calendar Month source did not restore selected-day month start"
  expect (calendarAgain.window.form.endExclusive == "2026-10-01")
    "Calendar Month source did not restore selected-day month end"

  let customEditing : Loam.Tui.Reports.State := {
    pensionState with
      window := { pensionState.window with
        form := { pensionState.window.form with focus := ⟨0, by decide⟩ } }
  }
  let customState := (Loam.Tui.Reports.update customEditing .backspace).state
  expect (Loam.Tui.Reports.windowSourceLabel customState == "Custom")
    "manual coordinate edit did not become Custom presentation state"

  let outBase := Loam.Tui.Reports.initialForDateWithPresets "2026-10-15" [pension]
  let outStock := (Loam.Tui.Reports.update outBase .enter).state
  let outPreset := (Loam.Tui.Reports.update outStock (.input ']')).state
  expect (outPreset.window.form.start.isEmpty && outPreset.window.form.endExclusive.isEmpty)
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
  expect (previous.window.form.start == "2026-08-01") "left did not shift to previous calendar month"
  expect (previous.window.form.endExclusive == "2026-09-01")
    "left did not keep an explicit half-open calendar month"

  let next := (Loam.Tui.Reports.update stock .right).state
  expect (next.window.form.start == "2026-10-01") "right did not shift to next calendar month"
  expect (next.window.form.endExclusive == "2026-11-01")
    "right did not keep an explicit half-open calendar month"

  let decemberBase := Loam.Tui.Reports.initialForDate "2026-12-20"
  let december := (Loam.Tui.Reports.update decemberBase .enter).state
  let january := (Loam.Tui.Reports.update december .right).state
  expect (january.window.form.start == "2027-01-01") "calendar month shift lost year rollover"
  expect (january.window.form.endExclusive == "2027-02-01")
    "calendar month year rollover end was wrong"

  let explicit : Loam.Tui.Reports.State := {
    stock with
      window := { stock.window with
        form := {
          start := "2026-08-17"
          endExclusive := "2026-10-15"
          focus := ⟨2, by decide⟩
        }
      }
  }
  let shiftedExplicit := (Loam.Tui.Reports.update explicit .right).state
  expect (shiftedExplicit.window.form.start == "2026-08-17")
    "arrow key rewrote a manually edited non-calendar window"
  expect (contains "press m to restore" shiftedExplicit.notice)
    "non-calendar arrow refusal did not explain the recovery action"

  let restored := (Loam.Tui.Reports.update explicit (.input 'm')).state
  expect (restored.window.form.start == "2026-09-01") "m did not restore selected-day calendar month start"
  expect (restored.window.form.endExclusive == "2026-10-01")
    "m did not restore selected-day calendar month end"
  expect (restored.window.form.focus.val == 2) "m did not return focus to Run"

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
    increasesAcrossEvents := Quantity.ofQuanta 50
    decreasesAcrossEvents := Quantity.ofQuanta (-20)
    currentTracked := Quantity.ofQuanta 140
  }
  let refusedShiftFromReport := (Loam.Tui.Reports.update stockReport .right).state
  expect refusedShiftFromReport.stockFlowSnapshot.isSome
    "refused non-calendar shift discarded the existing Stock-Flow snapshot"

  let stockReportText := widgetText (Loam.Tui.Reports.view stockReport)
  expect (contains "Reconstructed at start:" stockReportText && contains "100 jpy" stockReportText)
    "Stock–Flow start reconstruction was not rendered"
  expect (contains "Reconstructed at end:" stockReportText && contains "130 jpy" stockReportText)
    "Stock–Flow end reconstruction was not rendered"
  expect (contains "Tracked increases across Events:" stockReportText && contains "+50 jpy" stockReportText)
    "Stock–Flow increases were not rendered"
  expect (contains "Tracked decreases across Events:" stockReportText && contains "-20 jpy" stockReportText)
    "Stock–Flow decreases were not rendered"
  expect (contains "Net change:" stockReportText && contains "+30 jpy" stockReportText)
    "Stock–Flow net change was not rendered"
  expect (contains "Current tracked balance now:" stockReportText && contains "140 jpy" stockReportText)
    "Stock–Flow current context was not rendered separately"
  expect (contains "not income/spending" stockReportText)
    "Stock–Flow lost its sign/classification non-claim"

  let editing : Loam.Tui.Reports.State := {
    stockReport with
      window := { stockReport.window with
        form := { stockReport.window.form with focus := ⟨0, by decide⟩ } }
  }
  let edited := (Loam.Tui.Reports.update editing (.input '9')).state
  expect edited.stockFlowSnapshot.isNone
    "editing Stock–Flow coordinates left a stale report snapshot visible"

  let backToMenu := (Loam.Tui.Reports.update stockReport .escape).state
  expect (isMenu backToMenu) "Stock–Flow escape did not return to Reports menu"
  match Loam.Tui.Reports.update backToMenu .escape with
  | { back := true, .. } => pure ()
  | _ => throw (IO.userError "Reports menu escape did not return Home intent")

  let incomeExpense := { initial with mode := Loam.Tui.Reports.Mode.incomeExpense }
  let incomeExpenseText := widgetText (Loam.Tui.Reports.view incomeExpense)
  expect (contains "Reports / Income & Expense" incomeExpenseText)
    "Income & Expense heading was not rendered"
  expect (contains "No explicit Income & Expense window has been run yet" incomeExpenseText)
    "Income & Expense page did not preserve the explicit-run boundary"
  expect (contains "no role is inferred" incomeExpenseText)
    "Income & Expense page lost its no-inference boundary"
  match (Loam.Tui.Reports.update incomeExpense .enter).query with
  | some (.incomeExpenseFlow start endExclusive) =>
      expect (start == "2026-09-01") "Income & Expense Run changed explicit start"
      expect (endExclusive == "2026-10-01") "Income & Expense Run changed explicit end"
  | _ => throw (IO.userError "Income & Expense Run did not emit its explicit role-flow query")

  let pensionCoordinate : EffectCoordinate := ⟨⟨"pension"⟩, ⟨"jpy"⟩⟩
  let foodCoordinate : EffectCoordinate := ⟨⟨"food"⟩, ⟨"jpy"⟩⟩
  let incomeExpenseReport := Loam.Tui.Reports.withIncomeExpenseSnapshot incomeExpense {
    start := "2026-09-01"
    endExclusive := "2026-10-01"
    rows :=
      [ { coordinate := pensionCoordinate
        , role := .income
        , quantity := Quantity.ofQuanta (-225276) }
      , { coordinate := foodCoordinate
        , role := .expense
        , quantity := Quantity.ofQuanta 50000 }
      ]
    unresolvedEffects :=
      [ { event := ⟨"actual-unresolved"⟩
        , date := "2026-09-12"
        , effect := Effect.ofAnonymousQuantity
            ⟨"mystery"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 5) }
      ]
  }
  let incomeExpenseReportText := widgetText (Loam.Tui.Reports.view incomeExpenseReport)
  expect (contains "Income:" incomeExpenseReportText && contains "225276 jpy" incomeExpenseReportText)
    "Income & Expense view did not present credit-normal Income"
  expect (contains "Expense:" incomeExpenseReportText && contains "50000 jpy" incomeExpenseReportText)
    "Income & Expense view did not present debit-normal Expense"
  expect (contains "Result:" incomeExpenseReportText && contains "175276 jpy" incomeExpenseReportText)
    "Income & Expense view did not derive the occurrence-time result"
  expect (contains "Income breakdown" incomeExpenseReportText && contains "pension" incomeExpenseReportText) "Income & Expense view did not expose coordinate-preserving Income detail"
  expect (contains "Expense breakdown" incomeExpenseReportText && contains "food" incomeExpenseReportText) "Income & Expense view did not expose coordinate-preserving Expense detail"
  expect (contains "Unresolved role Effects: 1" incomeExpenseReportText && contains "mystery" incomeExpenseReportText)
    "Income & Expense view hid unresolved role evidence"
  expect (contains "not accrual recognition or period closing" incomeExpenseReportText)
    "Income & Expense view overstated occurrence-time flow as a closed P/L"

  let incomeExpenseEditing : Loam.Tui.Reports.State := {
    incomeExpenseReport with
      window := { incomeExpenseReport.window with
        form := { incomeExpenseReport.window.form with focus := ⟨0, by decide⟩ } }
  }
  let incomeExpenseEdited := (Loam.Tui.Reports.update incomeExpenseEditing .backspace).state
  expect incomeExpenseEdited.incomeExpenseSnapshot.isNone
    "editing Income & Expense coordinates left a stale role-flow snapshot visible"

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
  }
  let liquidityReportText := widgetText (Loam.Tui.Reports.view liquidityReport)
  expect (contains "Forecast path: UNKNOWN" liquidityReportText)
    "conditional overlay replaced the unconditional UNKNOWN baseline"
  expect (contains "CONDITIONAL selected-balance outlook" liquidityReportText)
    "conditional result lost its epistemic label"
  expect (contains "Scheduled" liquidityReportText && contains "-300" liquidityReportText && contains "700 jpy" liquidityReportText)
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
      window := { initial.window with
        form := {
          start := "2026-08-17"
          endExclusive := "2026-10-15"
          focus := ⟨2, by decide⟩
        }
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
  }
  let budgetReport := Loam.Tui.Reports.withBudgetSnapshot budget {
    start := "2026-08-17"
    endExclusive := "2026-10-15"
    rows := [food]
  }
  let budgetText := widgetText (Loam.Tui.Reports.view budgetReport)
  expect (contains "Budget window [2026-08-17, 2026-10-15)" budgetText)
    "explicit Budget Window was not rendered"
  expect (contains "food" budgetText && contains "100" budgetText && contains "30" budgetText && contains "70 jpy" budgetText)
    "Budget Window components were not rendered"
  expect (contains "Remaining is derived exactly as Entitlement - Consumption." budgetText)
    "Budget Window lost the derived Remaining boundary"

  let small : Bounds := { width := 80, height := 9 }
  let lastMenuItem := (List.range 5).foldl
    (fun state _ => (Loam.Tui.Reports.updateForBounds small state .down).state)
    initial
  let smallMenuText := widgetText (Loam.Tui.Reports.viewForBounds small lastMenuItem)
  expect (contains "Budget Window" smallMenuText)
    "bounded Reports menu let its selected item leave the viewport"
  expect (contains "b / Esc home   q quit" smallMenuText)
    "bounded Reports menu did not pin its navigation"

  let topBoundedText := widgetText (Loam.Tui.Reports.viewForBounds small stockReport)
  expect (contains "Reports / Stock–Flow" topBoundedText)
    "bounded Stock–Flow lost the top of its report body"
  expect (contains "Lines 1–" topBoundedText)
    "bounded report did not expose its scroll position"
  expect (contains "b / Esc Reports menu   q quit" topBoundedText)
    "bounded report did not pin navigation at the top position"
  expect ((Loam.Tui.Reports.viewForBounds small stockReport).lines.length <= small.height)
    "bounded report exceeded the terminal height"

  let bottom := (List.range 100).foldl
    (fun state _ => (Loam.Tui.Reports.updateForBounds small state .down).state)
    stockReport
  expect (bottom.scroll == Loam.Tui.Reports.scrollLimit small bottom && bottom.scroll > 0)
    "bounded report did not stop at its final meaningful offset"
  let bottomBoundedText := widgetText (Loam.Tui.Reports.viewForBounds small bottom)
  expect (contains "not income/spending" bottomBoundedText)
    "bounded report could not scroll to the end of its body"
  expect (contains "b / Esc Reports menu   q quit" bottomBoundedText)
    "bounded report did not pin navigation at the bottom position"
  expect ((Loam.Tui.Reports.updateForBounds small bottom .down).state.scroll == bottom.scroll)
    "bounded report scrolled beyond its final meaningful offset"

  let returnedTop := (List.range 100).foldl
    (fun state _ => (Loam.Tui.Reports.updateForBounds small state .up).state)
    bottom
  expect (returnedTop.scroll == 0)
    "bounded report did not return to its first offset"
  expect ((Loam.Tui.Reports.updateForBounds small returnedTop .up).state.scroll == 0)
    "bounded report scrolled above its first offset"
  let returnedMenu := (Loam.Tui.Reports.updateForBounds small bottom .escape).state
  expect (isMenu returnedMenu && returnedMenu.scroll == 0)
    "returning to the Reports menu retained stale report scrolling"
  let reopened := (Loam.Tui.Reports.updateForBounds small returnedMenu .enter).state
  expect (isStockFlow reopened && reopened.scroll == 0)
    "opening a report retained stale scrolling from the previous mode"

  let tall : Bounds := { width := 120, height := 100 }
  for report in [stockReport, liquidityReport, budgetReport] do
    let originalLines := (widgetText (Loam.Tui.Reports.view report)).splitOn "\n"
    let boundedLines := (widgetText (Loam.Tui.Reports.viewForBounds tall report)).splitOn "\n"
    expect (originalLines.all (fun original => original ∈ boundedLines))
      "bounds-aware presentation lost existing production report content"

  for heightIndex in List.range 8 do
    let tiny : Bounds := { width := 80, height := heightIndex + 1 }
    for report in [initial, stockReport, incomeExpense, liquidityReport, budgetReport] do
      let rendered := Loam.Tui.Reports.viewForBounds tiny report
      expect (rendered.lines.length <= tiny.height)
        ("Reports exceeded tiny terminal height " ++ toString tiny.height)
      expect (contains "q quit" (widgetText rendered))
        ("Reports lost essential navigation at tiny terminal height " ++ toString tiny.height)

  IO.println
    "TUI Reports: menu, Stock–Flow, Income & Expense, conditional Liquidity, Budget Window and navigation passed."
