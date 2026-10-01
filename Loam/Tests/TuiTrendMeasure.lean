import Loam.Tui.Reports

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

def main : IO Unit := do
  let usd : MeasureId := ⟨"usd"⟩
  let initial := Loam.Tui.Reports.initialForDateForMeasure usd "2026-09-07"
  expect (initial.measure == usd)
    "Reports did not retain the configured USD Measure in workspace state"
  let trendStep := Loam.Tui.Reports.update initial (.input 'v')
  match trendStep.query with
  | some (.locusTrendCompare _ _ _ series) =>
      expect (series.all fun spec => decide (spec.coordinate.measure = usd))
        "Reports did not seed Trend from the configured USD Measure"
  | _ =>
      throw (IO.userError "USD Reports Trend did not emit its query")

  let point : Loam.LocusTrendReview.OverviewPoint := {
    start := "2026-04-15"
    endExclusive := "2026-06-15"
    throughExclusive := "2026-06-15"
    total := Quantity.ofQuanta 464
    observedDays := 1
    dailyAverageQuanta := 464
    complete := true
  }
  let spec : Loam.LocusTrendCompareReview.SeriesSpec := {
    label := "Coffee USD"
    coordinate := ⟨⟨"coffee"⟩, usd⟩
  }
  let series : Loam.LocusTrendCompareReview.Series := {
    spec := spec
    points := [point]
    undatedMatchingCurrentRecords := 0
  }
  let snapshot : Loam.LocusTrendCompareReview.Snapshot := {
    measure := usd
    source := "Pension"
    observedAt := "2026-09-07"
    scopeStart := "2026-04-15"
    scopeEndExclusive := "2026-09-08"
    series := [series]
  }
  let report :=
    Loam.Tui.Reports.withLocusTrendCompareSnapshot trendStep.state snapshot
      [{ measure := usd, scale := 2 }]
  let bounds : Bounds := { width := 120, height := 40 }
  let text := widgetText (Loam.Tui.Reports.viewForBounds bounds report)

  expect (contains "usd" text && contains "$4.64/day" text)
    "Trend did not apply USD Measure identity, symbol, and decimal presentation"
  expect (!(contains "¥" text) && !(contains " jpy" text))
    "USD Trend leaked the historical JPY presentation"

  IO.println "TUI Trend Measure: configured USD identity and decimal presentation passed."
