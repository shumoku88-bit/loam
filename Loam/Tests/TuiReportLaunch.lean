import Loam.Tui.ReportsSession
import Loam.Tests.Support

open Loam.Tests.Support Loam.Tui.Kernel

private def text (widget : Widget) : String :=
  String.intercalate "\n" (widget.lines.map fun cells => String.ofList (cells.map Cell.glyph))

/-- Compare the session execution with the pre-existing shared Review answer,
including complete unbounded output and responsive views. Synthetic fixture only. -/
private def check (root : System.FilePath) (step : Loam.Tui.Reports.Step)
    (expected : Loam.Tui.Reports.State) : IO Unit := do
  let actual ← Loam.Tui.ReportsSession.executeStep root root step
  expect (actual.notice.isEmpty) ("report execution refused: " ++ actual.notice)
  expect (text (Loam.Tui.Reports.view actual) == text (Loam.Tui.Reports.view expected))
    "session changed shared Review report output"
  for bounds in [({ width := 140, height := 80 } : Bounds),
      { width := 80, height := 24 }, { width := 32, height := 6 }] do
    expect (text (Loam.Tui.Reports.viewForBounds bounds actual) ==
      text (Loam.Tui.Reports.viewForBounds bounds expected))
      "session changed bounded shared Review output"

def main (args : List String) : IO Unit := do
  let [path, date] := args | throw (IO.userError "supply isolated fixture directory and selected date")
  let root := System.FilePath.mk path
  let presets ← requireSome (← Loam.BoundaryPresetConfig.load?
    (root / "config" / "boundary-presets.tsv")) "fixture presets missing"
  for measure in [({ token := "jpy" } : Loam.Core.MeasureId), ⟨"usd"⟩] do
    let base := Loam.Tui.Reports.initialForDateWithPresetsForMeasure measure date presets
    let start := base.window.form.start
    let finish := base.window.form.endExclusive
    let through := base.liquidityForm.assumedCompleteThrough
    let launch := fun destination => Loam.Tui.Reports.openReport destination base
    let run := fun destination => Loam.Tui.Reports.update (launch destination).state .enter
    let stock ← requireOk (← Loam.StockFlowReview.loadSnapshot root root start finish) "Stock–Flow"
    check root (run .stockFlow) (Loam.Tui.Reports.withStockFlowSnapshot (launch .stockFlow).state stock)
    let transactions ← requireOk (← Loam.TransactionsFlowReview.loadSnapshot root root start finish)
      "Transactions Flow"
    check root (run .transactionsFlow)
      (Loam.Tui.Reports.withTransactionsFlowSnapshot (launch .transactionsFlow).state transactions)
    let income ← requireOk (← Loam.IncomeExpenseProvenanceReview.loadSnapshot root root start finish)
      "Income & Expense"
    for display in [Loam.Tui.Reports.IncomeExpenseDisplay.summary, .monthly, .daily] do
      let state := { (launch .incomeExpense).state with incomeExpenseDisplay := display }
      check root (Loam.Tui.Reports.update state .enter)
        (Loam.Tui.Reports.withIncomeExpenseSnapshot state income)
    let balances ← requireOk (← Loam.RoleBalanceReview.loadSnapshot root root) "Accounting Balances"
    check root (launch .balances) (Loam.Tui.Reports.withRoleBalanceSnapshot (launch .balances).state balances)
    let liquidity ← requireOk (← Loam.ConditionalBalancePathReview.loadSnapshot root root through)
      "Liquidity"
    check root (run .liquidity) (Loam.Tui.Reports.withLiquiditySnapshot (launch .liquidity).state liquidity)
    let budget ← requireOk (← Loam.BudgetWindowReview.loadSnapshotForMeasure measure root root start finish)
      "Budget Window"
    check root (run .budgetWindow) (Loam.Tui.Reports.withBudgetSnapshot (launch .budgetWindow).state budget)
    let spend ← requireOk (← Loam.MultimeasureSpendReview.loadSnapshot root root start finish)
      "Multicurrency Spend"
    let metadata ← requireOk (← Loam.MeasurePresentation.loadMetadata root) "Measure presentation"
    check root (run .multimeasureSpend)
      (Loam.Tui.Reports.withMultimeasureSpendSnapshot (launch .multimeasureSpend).state spend metadata)
    let trendState := (launch .locusTrendCompare).state
    let trend ← requireOk (← Loam.LocusTrendCompareReview.loadConfiguredAtScope root root date
      trendState.trendCompare.granularity
      (Loam.Tui.LocusTrendComparePane.effectiveScope trendState.trendCompare)
      trendState.trendCompareSeries) "Trend"
    check root (launch .locusTrendCompare)
      (Loam.Tui.Reports.withLocusTrendCompareSnapshot trendState trend metadata)
    let stockCompare := (Loam.Tui.Reports.update (launch .stockFlow).state (.input 'c')).state
    let pair := stockCompare.comparison
    let stockPair ← requireOk (← Loam.PeriodComparisonReview.loadStockFlow root root
      pair.leftStart pair.leftEndExclusive pair.rightStart pair.rightEndExclusive) "Stock–Flow comparison"
    check root (Loam.Tui.Reports.update stockCompare .enter)
      (Loam.Tui.Reports.withStockFlowComparison stockCompare stockPair)
    let incomeCompare := (Loam.Tui.Reports.update (launch .incomeExpense).state (.input 'c')).state
    let incomePair ← requireOk (← Loam.PeriodComparisonReview.loadIncomeExpense root root
      pair.leftStart pair.leftEndExclusive pair.rightStart pair.rightEndExclusive) "Income comparison"
    check root (Loam.Tui.Reports.update incomeCompare .enter)
      (Loam.Tui.Reports.withIncomeExpenseComparison incomeCompare incomePair)
    -- Invalid editable coordinates still refuse and can be corrected/re-run.
    let broken := { (launch .stockFlow).state with
      window := { base.window with form := { base.window.form with start := "invalid" } } }
    let failed ← Loam.Tui.ReportsSession.executeStep root root (Loam.Tui.Reports.update broken .enter)
    expect (!failed.notice.isEmpty && failed.stockFlowSnapshot.isNone) "invalid report silently succeeded"
    let restored := { failed with window := base.window }
    check root (Loam.Tui.Reports.update restored .enter)
      (Loam.Tui.Reports.withStockFlowSnapshot restored stock)
  IO.println "Reports launch/session: all eight internal Review answers, displays/comparisons, JPY/USD and refusal/retry parity passed."
