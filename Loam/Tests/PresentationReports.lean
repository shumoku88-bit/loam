import Loam.Presentation.Reports

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

def main : IO Unit := do
  let budget : Loam.CycleBudgetReview.Snapshot := {
    observedAt := "2026-09-24"
    window := .error "window unavailable"
    coverage := .error "coverage unavailable"
    physical := .error "physical unavailable"
    selection := .error "selection unavailable"
    funding := .error "funding unavailable"
  }
  let stockFlow : Loam.StockFlowReview.Snapshot := {
    start := "2026-09-01"
    endExclusive := "2026-10-01"
    reconstructedStart := Quantity.ofQuanta 10000
    increasesAcrossEvents := Quantity.ofQuanta 5000
    decreasesAcrossEvents := Quantity.ofQuanta (-3000)
    currentTracked := Quantity.ofQuanta 12000
  }
  let jpy : MeasureId := { token := "jpy" }
  let usd : MeasureId := { token := "usd" }
  let salary : LocusId := { token := "salary" }
  let food : LocusId := { token := "food" }
  let cash : LocusId := { token := "cash" }
  let some flowEvent1 := Event.ofEffects? { token := "flow-1" } [
      Effect.ofAnonymousQuantity cash jpy (Quantity.ofQuanta 500),
      Effect.ofAnonymousQuantity food jpy (Quantity.ofQuanta (-500))
    ]
    | throw (IO.userError "could not build first Transactions Flow fixture Event")
  let some flowEvent2 := Event.ofEffects? { token := "flow-2" } [
      Effect.ofAnonymousQuantity cash jpy (Quantity.ofQuanta (-200)),
      Effect.ofAnonymousQuantity food jpy (Quantity.ofQuanta 200)
    ]
    | throw (IO.userError "could not build second Transactions Flow fixture Event")
  let transactionsFlow : Loam.TransactionsFlowReview.Snapshot := {
    start := "2026-09-01"
    endExclusive := "2026-10-01"
    columns := [
      { event := flowEvent1, date := "2026-09-10", description := "first" },
      { event := flowEvent2, date := "2026-09-11", description := "second" }
    ]
  }
  let roleFlow : Loam.RoleFlowReview.Snapshot := {
    start := "2026-09-01"
    endExclusive := "2026-10-01"
    rows := [
      { coordinate := { locus := salary, measure := jpy }
        role := .income
        quantity := Quantity.ofQuanta (-5000) },
      { coordinate := { locus := food, measure := jpy }
        role := .expense
        quantity := Quantity.ofQuanta 1200 },
      { coordinate := { locus := salary, measure := usd }
        role := .income
        quantity := Quantity.ofQuanta (-20) }
    ]
    unresolvedEffects := []
  }
  let roleBalances : Loam.RoleBalanceReview.Snapshot := {
    rows := [
      { coordinate := { locus := cash, measure := jpy }
        role := .asset
        quantity := Quantity.ofQuanta 12000 }
    ]
    unresolvedRoles := [
      { coordinate := { locus := food, measure := jpy }
        quantity := Quantity.ofQuanta 300 }
    ]
    unsupportedBalances := [
      { coordinate := { locus := salary, measure := usd }
        role := some .asset }
    ]
  }
  let snapshot : Loam.Presentation.HouseholdSnapshot := {
    observedAt := "2026-09-24"
    actual := .loaded []
    scheduled := .loaded []
    attention := .unavailable
    budget := budget
    capacity := .failed "capacity unavailable"
    stockFlow := .loaded stockFlow
    transactionsFlow := .loaded transactionsFlow
    roleFlow := .loaded roleFlow
    roleBalances := .loaded roleBalances
    purposeMetadata := []
  }

  let reports := Loam.Presentation.Reports.fromSnapshot snapshot
  match reports.stockFlow with
  | .failed message =>
      throw (IO.userError ("Reports unexpectedly lost Stock-Flow evidence: " ++ message))
  | .loaded report =>
      expect (report.start == "2026-09-01")
        "Reports changed Stock-Flow start"
      expect (report.endExclusive == "2026-10-01")
        "Reports changed Stock-Flow end"
      expect (report.opening.quanta == 10000)
        "Reports changed Stock-Flow opening"
      expect (report.increases.quanta == 5000)
        "Reports changed Stock-Flow increases"
      expect (report.decreases.quanta == -3000)
        "Reports changed Stock-Flow decreases"
      expect (report.closing.quanta == 12000)
        "Reports did not preserve exact reconstructed closing"
      expect (report.currentTracked.quanta == 12000)
        "Reports changed current tracked quantity"

  match reports.transactionsFlow with
  | .failed message =>
      throw (IO.userError ("Reports unexpectedly lost Transactions Flow evidence: " ++ message))
  | .loaded report =>
      expect (report.start == "2026-09-01" && report.endExclusive == "2026-10-01")
        "Reports changed Transactions Flow window"
      expect (report.eventCount == 2)
        "Reports changed Transactions Flow Event count"
      expect (report.rows.length == 2)
        "Reports changed Transactions Flow active coordinate count"
      let some cashRow := report.rows.find? (fun row => decide (row.coordinate.locus = cash))
        | throw (IO.userError "Reports lost cash Transactions Flow row")
      expect
        (cashRow.net.quanta == 300 &&
          cashRow.gross.quanta == 700 &&
          cashRow.positive.quanta == 500 &&
          cashRow.negative.quanta == -200 &&
          cashRow.activeEvents == 2)
        "Reports changed Transactions Flow two-sided activity"

  match reports.incomeExpense with
  | .failed message =>
      throw (IO.userError ("Reports unexpectedly lost Income & Expense evidence: " ++ message))
  | .loaded report =>
      expect (report.measures.length == 2)
        "Reports merged distinct Measures in Income & Expense"
      let some jpySummary := report.measures.find? (fun row => decide (row.measure = jpy))
        | throw (IO.userError "Reports lost JPY Income & Expense measure")
      expect (jpySummary.income.quanta == 5000)
        "Reports changed displayed Income sign"
      expect (jpySummary.expense.quanta == 1200)
        "Reports changed displayed Expense quantity"
      expect (jpySummary.result.quanta == 3800)
        "Reports changed Income & Expense result"
      let some usdSummary := report.measures.find? (fun row => decide (row.measure = usd))
        | throw (IO.userError "Reports lost USD Income & Expense measure")
      expect (usdSummary.income.quanta == 20 && usdSummary.expense.quanta == 0)
        "Reports did not keep USD separate from JPY"
      expect (report.unresolvedEffectCount == 0)
        "Reports changed unresolved role Effect count"

  match reports.balances with
  | .failed message =>
      throw (IO.userError ("Reports unexpectedly lost Balances evidence: " ++ message))
  | .loaded report =>
      expect (report.rows.length == 1)
        "Reports changed supported Role Balance row count"
      let some row := report.rows.head?
        | throw (IO.userError "Reports lost supported Role Balance row")
      expect
        (decide (row.coordinate.locus = cash ∧ row.role = .asset) &&
          row.quantity.quanta == 12000)
        "Reports changed supported Role Balance row"
      expect (report.unresolvedRoleCount == 1)
        "Reports changed unresolved Role count"
      expect (report.unsupportedBalanceCount == 1)
        "Reports changed unsupported Balance count"

  IO.println "Reports presentation: Stock-Flow, Transactions Flow, Income & Expense, and Balances preserve shared Review evidence."
