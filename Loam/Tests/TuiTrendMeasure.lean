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
  let trendStep := Loam.Tui.Reports.openReport .locusTrendCompare initial
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
  let draft : Loam.Tui.LocusTrendComparePane.OverlayDraft := {
    month := "2026-09",
    name := "日本語の観測",
    daysText := "3 4 6 8 9",
    editingDays := false
  }
  let overlay := { report with trendCompare := { report.trendCompare with
    overlayDraft := some draft } }
  let days := (Loam.Tui.Reports.update overlay .tab).state
  let backspaced := (Loam.Tui.Reports.update days .backspace).state
  let pasted := (Loam.Tui.Reports.update backspaced (.paste "12")).state
  expect (pasted.trendCompare.overlayDraft == backspaced.trendCompare.overlayDraft &&
      backspaced.trendCompare.overlayDraft.any (fun draft => draft.daysText == "3 4 6 8 "))
    "Trend caret migration changed historical paste/Backspace input semantics"
  let cancelled := (Loam.Tui.Reports.update backspaced .escape).state
  expect (cancelled.measure == usd && cancelled.trendCompare.snapshot == report.trendCompare.snapshot &&
      cancelled.trendCompare.selected == report.trendCompare.selected &&
      cancelled.trendCompare.overlayDraft.isNone)
    "Trend overlay return changed the read-only configured Measure context"
  for terminal in ([{ width := 32, height := 9 }, { width := 48, height := 14 },
      { width := 80, height := 24 }, { width := 120, height := 40 }] : List Bounds) do
    for editing in [overlay, days, backspaced] do
      let frame := Loam.Tui.Reports.viewForBounds terminal editing
      expect ((frame.lines.flatten.filter Cell.caret).length == 1 &&
          (Loam.Tui.Terminal.textCaretPosition? terminal 0 0
            (Loam.Tui.Layout.contentWidth terminal) (Loam.Tui.Runtime.compileWidget frame)).isSome)
        "configured-Measure Trend overlay lost its live insertion anchor"
    expect (!(Loam.Tui.Reports.viewForBounds terminal cancelled).lines.flatten.any Cell.caret)
      "Trend chart retained a stale overlay insertion anchor"
    let picker := { report with trendCompare := { report.trendCompare with pickerOpen := true } }
    expect (!(Loam.Tui.Reports.viewForBounds terminal picker).lines.flatten.any Cell.caret)
      "navigation-only Trend series picker advertised text entry"

  IO.println "TUI Trend Measure: configured USD identity and decimal presentation passed."
