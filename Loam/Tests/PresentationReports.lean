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
  let snapshot : Loam.Presentation.HouseholdSnapshot := {
    observedAt := "2026-09-24"
    actual := .ok []
    scheduled := .ok []
    attention := .ok .unavailable
    budget := budget
    capacity := .error "capacity unavailable"
    stockFlow := .ok stockFlow
    purposeMetadata := []
  }

  let reports := Loam.Presentation.Reports.fromSnapshot snapshot
  match reports.stockFlow with
  | .error message =>
      throw (IO.userError ("Reports unexpectedly lost Stock-Flow evidence: " ++ message))
  | .ok report =>
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

  IO.println "Reports presentation: Stock-Flow roles preserve shared Review arithmetic."
