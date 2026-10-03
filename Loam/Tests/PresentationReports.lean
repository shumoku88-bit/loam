import Loam.Presentation.Reports

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

def main : IO Unit := do
  let jpy : MeasureId := ⟨"jpy"⟩
  let usd : MeasureId := ⟨"usd"⟩
  let salary : LocusId := ⟨"salary"⟩
  let food : LocusId := ⟨"food"⟩
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

  let report := Loam.Presentation.Reports.incomeExpenseFromRoleFlow roleFlow
  expect (report.start == "2026-09-01" && report.endExclusive == "2026-10-01")
    "Income & Expense presentation changed the explicit window"
  expect (report.measures.length == 2)
    "Income & Expense presentation merged distinct Measures"

  let some jpySummary := report.measures.find? (fun row => decide (row.measure = jpy))
    | throw (IO.userError "Income & Expense presentation lost JPY")
  expect
    (jpySummary.income.quanta == 5000 &&
      jpySummary.expense.quanta == 1200 &&
      jpySummary.result.quanta == 3800)
    "Income & Expense presentation changed the established JPY display convention"

  let some usdSummary := report.measures.find? (fun row => decide (row.measure = usd))
    | throw (IO.userError "Income & Expense presentation lost USD")
  expect (usdSummary.income.quanta == 20 && usdSummary.expense.quanta == 0)
    "Income & Expense presentation did not keep USD separate from JPY"
  expect (report.unresolvedEffectCount == 0)
    "Income & Expense presentation changed unresolved Effect count"

  IO.println "Reports presentation: production Income & Expense summary preserved shared RoleFlow evidence."
