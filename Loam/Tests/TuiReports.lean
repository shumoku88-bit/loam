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

private def isMultimeasureSpend (state : Loam.Tui.Reports.State) : Bool :=
  match state.mode with
  | .multimeasureSpend => true
  | _ => false

private def isLocusTrend (state : Loam.Tui.Reports.State) : Bool :=
  match state.mode with
  | .locusTrend => true
  | _ => false

private def isLocusTrendCompare (state : Loam.Tui.Reports.State) : Bool :=
  match state.mode with
  | .locusTrendCompare => true
  | _ => false

private def reportEffect
    (key locus measure : String) (quanta : Int) : Effect :=
  Effect.ofQuantity
    ⟨key⟩ ⟨locus⟩ ⟨measure⟩ (Quantity.ofQuanta quanta)

private def dayPoints
    (start : String) (count : Nat) (firstValue regularValue : Int) :
    List Loam.LocusTrendReview.OverviewPoint :=
  (List.range count).map fun index =>
    let date :=
      (Loam.ActualDate.shiftDays? start (Int.ofNat index)).getD start
    let endExclusive :=
      (Loam.ActualDate.shiftDays? date 1).getD date
    let value := if index == 0 then firstValue else regularValue
    {
      start := date
      endExclusive := endExclusive
      throughExclusive := endExclusive
      total := Quantity.ofQuanta value
      observedDays := 1
      dailyAverageQuanta := value
      complete := decide (index + 1 < count)
    }


def main : IO Unit := do
  let initial := Loam.Tui.Reports.initialForDate "2026-09-07"
  let menuText := widgetText (Loam.Tui.Reports.view initial)
  expect (contains "Reports" menuText) "Reports menu heading was not rendered"
  expect (contains "Stock–Flow" menuText) "Reports menu lost Stock–Flow"
  expect (contains "Income & Expense" menuText) "Reports menu lost Income & Expense"
  expect (contains "Balances" menuText) "Reports menu lost evidence-aware Balances"
  expect (contains "Liquidity" menuText) "Reports menu lost Liquidity"
  expect (contains "Budget Window" menuText) "Reports menu lost Budget Window"
  expect (contains "Scheduled Coverage" menuText) "Reports menu lost Scheduled Coverage"
  expect (contains "Multicurrency Spend" menuText) "Reports menu lost Multicurrency Spend"
  expect (contains "Trend Compare" menuText) "Reports menu lost Trend Compare"
  expect (contains "Locus Trend" menuText) "Reports menu lost Locus Trend"
  expect (contains "Fava Projection" menuText) "Reports menu lost Fava Projection"
  let favaStep := Loam.Tui.Reports.update initial (.input 'f')
  expect (favaStep.query == some .favaProjection)
    "Reports direct Fava key 'f' did not trigger favaProjection query"
  expect (initial.window.form.start == "2026-09-01")
    "Reports did not seed the selected-day calendar month start"
  expect (initial.window.form.endExclusive == "2026-10-01")
    "Reports did not seed the selected-day calendar month end"
  expect (initial.window.form.focus.val == 2) "calendar-month prefill did not focus Run"
  expect (initial.liquidityForm.assumedCompleteThrough == "2026-09-30")
    "conditional outlook did not prefill the selected-day calendar month end"
  expect (initial.liquidityForm.focus.val == 1)
    "conditional outlook prefill did not focus explicit Run"
  expect ((Loam.Tui.Reports.update initial (.input 'q')).back)
    "Reports menu q did not return Home"
  expect (!(Loam.Tui.Reports.update initial (.input 'b')).back)
    "retired Reports b Home alias survived"

  let compareStep := Loam.Tui.Reports.update initial (.input 'v')
  expect (isLocusTrendCompare compareStep.state)
    "Reports direct Trend Compare key did not enter the comparison surface"
  match compareStep.query with
  | some (.locusTrendCompare observedAt granularity scope series) =>
      expect (observedAt == "2026-09-07")
        "Trend Compare lost the selected Home observation date"
      expect (granularity == .cycle && scope == .allHistory)
        "Trend Compare did not open at Cycle / All history"
      expect (series.map (·.label) == ["Tobacco", "Coffee", "Food"])
        "Trend Compare default series labels changed"
      expect
        (series.map (fun item => item.coordinate.locus.token) ==
          ["tobacco", "coffee", "food"])
        "Trend Compare stopped using exact Locus identities"
  | _ => throw (IO.userError "Trend Compare did not emit its multi-series query")

  let tobaccoPoints : List Loam.LocusTrendReview.OverviewPoint :=
    [ { start := "2026-04-15", endExclusive := "2026-06-15",
        throughExclusive := "2026-06-15", total := Quantity.ofQuanta 28304,
        observedDays := 61, dailyAverageQuanta := 464, complete := true }
    , { start := "2026-06-15", endExclusive := "2026-08-14",
        throughExclusive := "2026-08-14", total := Quantity.ofQuanta 30480,
        observedDays := 60, dailyAverageQuanta := 508, complete := true }
    , { start := "2026-08-14", endExclusive := "2026-10-15",
        throughExclusive := "2026-09-08", total := Quantity.ofQuanta 12500,
        observedDays := 25, dailyAverageQuanta := 500, complete := false }
    ]
  let coffeePoints : List Loam.LocusTrendReview.OverviewPoint :=
    [ { start := "2026-04-15", endExclusive := "2026-06-15",
        throughExclusive := "2026-06-15", total := Quantity.ofQuanta 7991,
        observedDays := 61, dailyAverageQuanta := 131, complete := true }
    , { start := "2026-06-15", endExclusive := "2026-08-14",
        throughExclusive := "2026-08-14", total := Quantity.ofQuanta 9480,
        observedDays := 60, dailyAverageQuanta := 158, complete := true }
    , { start := "2026-08-14", endExclusive := "2026-10-15",
        throughExclusive := "2026-09-08", total := Quantity.ofQuanta 6100,
        observedDays := 25, dailyAverageQuanta := 244, complete := false }
    ]
  let foodPoints : List Loam.LocusTrendReview.OverviewPoint :=
    [ { start := "2026-04-15", endExclusive := "2026-06-15",
        throughExclusive := "2026-06-15", total := Quantity.ofQuanta 29097,
        observedDays := 61, dailyAverageQuanta := 477, complete := true }
    , { start := "2026-06-15", endExclusive := "2026-08-14",
        throughExclusive := "2026-08-14", total := Quantity.ofQuanta 31440,
        observedDays := 60, dailyAverageQuanta := 524, complete := true }
    , { start := "2026-08-14", endExclusive := "2026-10-15",
        throughExclusive := "2026-09-08", total := Quantity.ofQuanta 15700,
        observedDays := 25, dailyAverageQuanta := 628, complete := false }
    ]
  let tobaccoSpec : Loam.LocusTrendCompareReview.SeriesSpec := {
    label := "Tobacco"
    coordinate := ⟨⟨"tobacco"⟩, ⟨"jpy"⟩⟩
  }
  let coffeeSpec : Loam.LocusTrendCompareReview.SeriesSpec := {
    label := "Coffee"
    coordinate := ⟨⟨"coffee"⟩, ⟨"jpy"⟩⟩
  }
  let foodSpec : Loam.LocusTrendCompareReview.SeriesSpec := {
    label := "Food"
    coordinate := ⟨⟨"food"⟩, ⟨"jpy"⟩⟩
  }
  let tobaccoSeries : Loam.LocusTrendCompareReview.Series := {
    spec := tobaccoSpec
    points := tobaccoPoints
    undatedMatchingCurrentRecords := 0
  }
  let coffeeSeries : Loam.LocusTrendCompareReview.Series := {
    spec := coffeeSpec
    points := coffeePoints
    undatedMatchingCurrentRecords := 0
  }
  let foodSeries : Loam.LocusTrendCompareReview.Series := {
    spec := foodSpec
    points := foodPoints
    undatedMatchingCurrentRecords := 0
  }
  let compareSnapshot : Loam.LocusTrendCompareReview.Snapshot := {
    source := "Pension"
    observedAt := "2026-09-07"
    scopeStart := "2026-04-15"
    scopeEndExclusive := "2026-09-08"
    series := [tobaccoSeries, coffeeSeries, foodSeries]
  }
  let compareReport :=
    Loam.Tui.Reports.withLocusTrendCompareSnapshot compareStep.state compareSnapshot
  expect (compareReport.trendCompare.selected == 2)
    "Trend Compare did not select the current cycle initially"

  let monthRequest := Loam.Tui.Reports.update compareReport (.input ']')
  match monthRequest.query with
  | some (.locusTrendCompare observedAt granularity scope series) =>
      expect (observedAt == "2026-09-07" && granularity == .month &&
          scope == .allHistory &&
          series.map (·.label) == ["Tobacco", "Coffee", "Food"])
        "Trend Compare ] did not request the same exact series at month granularity"
  | _ => throw (IO.userError "Trend Compare ] did not request month granularity")

  let monthPoints : List Loam.LocusTrendReview.OverviewPoint :=
    [ { start := "2026-04-15", endExclusive := "2026-05-01",
        throughExclusive := "2026-05-01", total := Quantity.ofQuanta 7000,
        observedDays := 16, dailyAverageQuanta := 437, complete := false }
    , { start := "2026-05-01", endExclusive := "2026-06-01",
        throughExclusive := "2026-06-01", total := Quantity.ofQuanta 14500,
        observedDays := 31, dailyAverageQuanta := 467, complete := true }
    , { start := "2026-06-01", endExclusive := "2026-07-01",
        throughExclusive := "2026-07-01", total := Quantity.ofQuanta 15000,
        observedDays := 30, dailyAverageQuanta := 500, complete := true }
    , { start := "2026-07-01", endExclusive := "2026-08-01",
        throughExclusive := "2026-08-01", total := Quantity.ofQuanta 15810,
        observedDays := 31, dailyAverageQuanta := 510, complete := true }
    , { start := "2026-08-01", endExclusive := "2026-09-01",
        throughExclusive := "2026-09-01", total := Quantity.ofQuanta 15500,
        observedDays := 31, dailyAverageQuanta := 500, complete := true }
    , { start := "2026-09-01", endExclusive := "2026-09-08",
        throughExclusive := "2026-09-08", total := Quantity.ofQuanta 3500,
        observedDays := 7, dailyAverageQuanta := 500, complete := false }
    ]
  let monthTobacco : Loam.LocusTrendCompareReview.Series := {
    spec := tobaccoSpec, points := monthPoints, undatedMatchingCurrentRecords := 0
  }
  let monthCoffee : Loam.LocusTrendCompareReview.Series := {
    spec := coffeeSpec, points := monthPoints, undatedMatchingCurrentRecords := 0
  }
  let monthFood : Loam.LocusTrendCompareReview.Series := {
    spec := foodSpec, points := monthPoints, undatedMatchingCurrentRecords := 0
  }
  let monthSnapshot : Loam.LocusTrendCompareReview.Snapshot := {
    source := "Pension"
    observedAt := "2026-09-07"
    granularity := .month
    scopeStart := "2026-04-15"
    scopeEndExclusive := "2026-09-08"
    series := [monthTobacco, monthCoffee, monthFood]
  }
  let monthReport :=
    Loam.Tui.Reports.withLocusTrendCompareSnapshot monthRequest.state monthSnapshot
  expect (monthReport.trendCompare.granularity == .month &&
      monthReport.trendCompare.selected == 4)
    "Trend Compare did not preserve the selected Aug 14 period when zooming to months"
  let monthText := widgetText
    (Loam.Tui.Reports.viewForBounds { width := 100, height := 30 } monthReport)
  expect (contains "Trend Compare   month average / day" monthText &&
      contains "Aug 1 → Sep 1" monthText &&
      contains "Scope All history" monthText &&
      contains "[ / ] grain" monthText && contains "s/S scope" monthText)
    "Trend Compare month view did not expose its granularity and selected month"

  let dayRequest := Loam.Tui.Reports.update monthReport (.input ']')
  match dayRequest.query with
  | some (.locusTrendCompare observedAt granularity scope _) =>
      expect (observedAt == "2026-09-07" && granularity == .day &&
          scope == .allHistory)
        "Trend Compare second ] did not request day granularity"
  | _ => throw (IO.userError "Trend Compare second ] did not request day granularity")

  let cycleRequest := Loam.Tui.Reports.update monthReport (.input '[')
  match cycleRequest.query with
  | some (.locusTrendCompare _ granularity scope _) =>
      expect (granularity == .cycle && scope == .allHistory)
        "Trend Compare [ did not return from month to cycle granularity"
  | _ => throw (IO.userError "Trend Compare [ did not request cycle granularity")

  let currentCycleRequest := Loam.Tui.Reports.update compareReport (.input 's')
  match currentCycleRequest.query with
  | some (.locusTrendCompare observedAt granularity scope series) =>
      expect (observedAt == "2026-09-07" && granularity == .cycle &&
          scope == .currentCycle &&
          series.map (·.label) == ["Tobacco", "Coffee", "Food"])
        "Trend Compare s did not request Current cycle with the same exact series"
  | _ => throw (IO.userError "Trend Compare s did not request Current cycle")

  let currentMonthRequest := Loam.Tui.Reports.update currentCycleRequest.state (.input 's')
  match currentMonthRequest.query with
  | some (.locusTrendCompare _ _ scope _) =>
      expect (scope == .currentMonth)
        "Trend Compare second s did not request This month"
  | _ => throw (IO.userError "Trend Compare second s did not request This month")

  let scopeBackRequest := Loam.Tui.Reports.update currentCycleRequest.state (.input 'S')
  match scopeBackRequest.query with
  | some (.locusTrendCompare _ _ scope _) =>
      expect (scope == .allHistory)
        "Trend Compare S did not return to All history"
  | _ => throw (IO.userError "Trend Compare S did not request All history")

  let compareLeft := (Loam.Tui.Reports.update compareReport .left).state
  expect (compareLeft.trendCompare.selected == 1)
    "Trend Compare left arrow did not move one shared cycle"

  let compareBounds : Bounds := { width := 100, height := 30 }

  let viewportTobacco : Loam.LocusTrendCompareReview.Series := {
    spec := tobaccoSpec
    points := dayPoints "2026-08-01" 40 500 500
    undatedMatchingCurrentRecords := 0
  }
  let viewportCoffee : Loam.LocusTrendCompareReview.Series := {
    spec := coffeeSpec
    points := dayPoints "2026-08-01" 40 100 100
    undatedMatchingCurrentRecords := 0
  }
  let viewportFood : Loam.LocusTrendCompareReview.Series := {
    spec := foodSpec
    points := dayPoints "2026-08-01" 40 8000 400
    undatedMatchingCurrentRecords := 0
  }
  let viewportSnapshot : Loam.LocusTrendCompareReview.Snapshot := {
    source := "Pension"
    observedAt := "2026-09-09"
    granularity := .day
    scopeStart := "2026-08-01"
    scopeEndExclusive := "2026-09-10"
    series := [viewportTobacco, viewportCoffee, viewportFood]
  }
  let viewportState :=
    Loam.Tui.LocusTrendComparePane.withSnapshot
      Loam.Tui.LocusTrendComparePane.initial viewportSnapshot
  expect (viewportState.selected == 39 &&
      Loam.Tui.LocusTrendComparePane.visibleStart viewportState == 9 &&
      Loam.Tui.LocusTrendComparePane.visibleCount viewportState == 31)
    "Trend Compare Day did not open on the trailing 31-day viewport"

  let viewportOneLeft :=
    Loam.Tui.LocusTrendComparePane.moveSelection viewportState true
  expect (viewportOneLeft.selected == 38 &&
      Loam.Tui.LocusTrendComparePane.visibleStart viewportOneLeft == 9)
    "Trend Compare Day moved the viewport before selection reached its edge"

  let viewportAtLeft :=
    (List.range 30).foldl
      (fun state _ => Loam.Tui.LocusTrendComparePane.moveSelection state true)
      viewportState
  expect (viewportAtLeft.selected == 9 &&
      Loam.Tui.LocusTrendComparePane.visibleStart viewportAtLeft == 9)
    "Trend Compare Day did not keep the selected day at the left viewport edge"
  let viewportPastLeft :=
    Loam.Tui.LocusTrendComparePane.moveSelection viewportAtLeft true
  expect (viewportPastLeft.selected == 8 &&
      Loam.Tui.LocusTrendComparePane.visibleStart viewportPastLeft == 8)
    "Trend Compare Day did not scroll exactly one day past the viewport edge"

  let viewportReport : Loam.Tui.Reports.State := {
    compareReport with trendCompare := viewportState
  }
  let viewportPress :=
    (Loam.Tui.Reports.updateForBounds compareBounds viewportReport
      (.pointer Loam.Tui.LocusTrendComparePane.plotLeft
        (Loam.Tui.LocusTrendComparePane.plotTop viewportState + 1))).state
  expect (viewportPress.trendCompare.selected == 9)
    "Trend Compare click did not select inside the visible Day viewport"

  let viewportDrag :=
    (Loam.Tui.Reports.updateForBounds compareBounds viewportReport
      (.pointerDrag Loam.Tui.LocusTrendComparePane.plotLeft
        (Loam.Tui.LocusTrendComparePane.plotTop viewportState + 1))).state
  expect (viewportDrag.trendCompare.selected == 9)
    "Trend Compare drag did not scrub inside the visible Day viewport"

  let viewportMotion :=
    (Loam.Tui.Reports.updateForBounds compareBounds viewportReport
      (.pointerMotion Loam.Tui.LocusTrendComparePane.plotLeft
        (Loam.Tui.LocusTrendComparePane.plotTop viewportState + 1))).state
  expect (viewportMotion.trendCompare.selected == viewportState.selected)
    "Trend Compare still followed passive pointer motion"

  let viewportWheelBack := (Loam.Tui.Reports.update viewportReport .up).state
  expect (viewportWheelBack.trendCompare.selected == 38)
    "Trend Compare wheel-up did not move one Day period backward"
  let viewportWheelForward := (Loam.Tui.Reports.update viewportWheelBack .down).state
  expect (viewportWheelForward.trendCompare.selected == 39)
    "Trend Compare wheel-down did not move one Day period forward"

  let viewportText := widgetText
    (Loam.Tui.Reports.viewForBounds compareBounds viewportReport)
  expect (contains "31-day viewport" viewportText &&
      contains "wheel select period" viewportText &&
      contains "mouse click/drag scrub" viewportText &&
      contains "Aug 10" viewportText && contains "Sep 9" viewportText)
    "Trend Compare Day did not expose the visible 31-day window and mouse controls"
  expect (!(contains "¥8,000" viewportText))
    "Trend Compare Day scale still included an outlier outside the visible viewport"

  let scopedViewportSnapshot : Loam.LocusTrendCompareReview.Snapshot := {
    viewportSnapshot with
      scope := .currentCycle
      scopeStart := "2026-08-01"
      scopeEndExclusive := "2026-09-10"
  }
  let scopedViewportState :=
    Loam.Tui.LocusTrendComparePane.withSnapshot
      viewportState scopedViewportSnapshot
  expect (scopedViewportState.scope == .currentCycle &&
      Loam.Tui.LocusTrendComparePane.visibleStart scopedViewportState == 0 &&
      Loam.Tui.LocusTrendComparePane.visibleCount scopedViewportState == 40)
    "Trend Compare scoped Day view incorrectly retained the All-history 31-day viewport"
  let scopedViewportText := widgetText
    (Loam.Tui.LocusTrendComparePane.viewForBounds compareBounds scopedViewportState)
  expect (contains "Scope Current cycle" scopedViewportText &&
      !(contains "31-day viewport" scopedViewportText))
    "Trend Compare did not expose the scoped Day range as a whole"

  let comparePointer :=
    (Loam.Tui.Reports.updateForBounds compareBounds compareLeft
      (.pointer Loam.Tui.LocusTrendComparePane.plotLeft
        (Loam.Tui.LocusTrendComparePane.plotTop compareLeft.trendCompare + 1))).state
  expect (comparePointer.trendCompare.selected == 0)
    "Trend Compare pointer did not select the nearest shared cycle"

  let compareText := widgetText
    (Loam.Tui.Reports.viewForBounds compareBounds comparePointer)
  expect (contains "Trend Compare   cycle average / day" compareText &&
      contains "Selected   Apr 15 → Jun 15" compareText &&
      contains "Tobacco" compareText && contains "¥464/day" compareText &&
      contains "Coffee" compareText && contains "¥131/day" compareText &&
      contains "Food" compareText && contains "¥477/day" compareText)
    "Trend Compare did not show all selected-cycle series values together"
  expect (contains "Scope All history" compareText)
    "Trend Compare did not expose its active scope"
  expect (contains "Exact Locus series" compareText)
    "Trend Compare lost its no-reclassification boundary"
  expect ((Loam.Tui.Reports.viewForBounds compareBounds comparePointer).lines.length <=
      compareBounds.height)
    "Trend Compare exceeded the terminal height"

  let compareBlock := (Loam.Tui.Reports.update comparePointer (.input 'r')).state
  expect (compareBlock.trendCompare.renderer == .block)
    "Trend Compare renderer fallback did not move from Braille to block"
  expect (isMenu (Loam.Tui.Reports.update comparePointer .escape).state)
    "Trend Compare escape did not return to Reports menu"

  let trendStep := Loam.Tui.Reports.update initial (.input 'g')
  expect (isLocusTrend trendStep.state)
    "Reports direct Locus Trend key did not enter the trend surface"
  match trendStep.query with
  | some (.locusTrendOverview observedAt coordinate) =>
      expect (observedAt == "2026-09-07")
        "Locus Trend overview lost the selected Home observation date"
      expect (coordinate == (⟨⟨"tobacco"⟩, ⟨"jpy"⟩⟩ : EffectCoordinate))
        "Locus Trend default did not preserve the exact tobacco/jpy coordinate"
  | _ => throw (IO.userError "Locus Trend did not request its long-history overview")

  let trendOverview :=
    Loam.Tui.Reports.withLocusTrendOverview trendStep.state {
      source := "Pension"
      observedAt := "2026-09-07"
      coordinate := ⟨⟨"tobacco"⟩, ⟨"jpy"⟩⟩
      points :=
        [ { start := "2026-04-15"
          , endExclusive := "2026-06-15"
          , throughExclusive := "2026-06-15"
          , total := Quantity.ofQuanta 28000
          , observedDays := 61
          , dailyAverageQuanta := 459
          , complete := true }
        , { start := "2026-06-15"
          , endExclusive := "2026-08-14"
          , throughExclusive := "2026-08-14"
          , total := Quantity.ofQuanta 30500
          , observedDays := 60
          , dailyAverageQuanta := 508
          , complete := true }
        , { start := "2026-08-14"
          , endExclusive := "2026-10-15"
          , throughExclusive := "2026-09-08"
          , total := Quantity.ofQuanta 12500
          , observedDays := 25
          , dailyAverageQuanta := 500
          , complete := false }
        ]
      undatedMatchingCurrentRecords := 0
    }
  expect (trendOverview.trend.selected == 2)
    "fresh Locus Trend overview did not select the latest configured cycle"

  let trendLeft := (Loam.Tui.Reports.update trendOverview .left).state
  expect (trendLeft.trend.selected == 1)
    "Locus Trend left arrow did not move the overview cycle selection backward"

  let trendBounds : Bounds := { width := 80, height := 24 }
  let trendPointer :=
    (Loam.Tui.Reports.updateForBounds trendBounds trendLeft
      (.pointer Loam.Tui.LocusTrendPane.plotLeft
        (Loam.Tui.LocusTrendPane.plotTop + 1))).state
  expect (trendPointer.trend.selected == 0)
    "Locus Trend pointer did not select the nearest overview cycle"

  let trendText := widgetText
    (Loam.Tui.Reports.viewForBounds trendBounds trendPointer)
  expect (contains "Locus Trend   tobacco / jpy" trendText &&
      contains "Pension cycles" trendText &&
      contains "through Sep 7, 2026" trendText &&
      contains "Selected   Apr 15 → Jun 15   ● complete" trendText &&
      contains "¥459/day" trendText &&
      contains "● completed cycle" trendText &&
      contains "◇ current partial" trendText)
    "Locus Trend did not render the polished long-history overview"
  expect ((Loam.Tui.Reports.viewForBounds trendBounds trendPointer).lines.length <= trendBounds.height)
    "full-screen Locus Trend exceeded the terminal height"
  let narrowTrendBounds : Bounds := { width := 48, height := 20 }
  let narrowTrendText := widgetText
    (Loam.Tui.Reports.viewForBounds narrowTrendBounds trendPointer)
  expect ((Loam.Tui.Reports.viewForBounds narrowTrendBounds trendPointer).lines.length <=
      narrowTrendBounds.height)
    "polished Locus Trend exceeded a narrow terminal height"
  expect (contains "q/Esc reports" narrowTrendText)
    "polished Locus Trend footer wrapping lost the back navigation"
  expect (contains "braille" trendText)
    "Locus Trend did not default to the high-resolution portable renderer"

  let trendBlock := (Loam.Tui.Reports.update trendPointer (.input 'r')).state
  expect (trendBlock.trend.renderer == .block)
    "Locus Trend renderer fallback did not move from Braille to block"
  let trendBlockText := widgetText
    (Loam.Tui.Reports.viewForBounds trendBounds trendBlock)
  expect (contains "block" trendBlockText)
    "Locus Trend did not surface the active fallback renderer"

  let trendAscii := (Loam.Tui.Reports.update trendBlock (.input 'r')).state
  expect (trendAscii.trend.renderer == .ascii)
    "Locus Trend renderer fallback did not move from block to ASCII"

  let historyRequest := Loam.Tui.Reports.update trendPointer (.input 'd')
  match historyRequest.query with
  | some (.locusTrendHistory observedAt coordinate) =>
      expect (observedAt == "2026-09-07")
        "Locus Trend daily history changed the selected observation date"
      expect (coordinate == (⟨⟨"tobacco"⟩, ⟨"jpy"⟩⟩ : EffectCoordinate))
        "Locus Trend daily history changed the exact coordinate"
  | _ =>
      throw (IO.userError "Locus Trend d did not request configured all-days history")

  let trendHistory :=
    Loam.Tui.Reports.withLocusTrendHistory historyRequest.state {
      start := "2026-04-15"
      endExclusive := "2026-09-08"
      coordinate := ⟨⟨"tobacco"⟩, ⟨"jpy"⟩⟩
      points :=
        [ { date := "2026-04-15"
          , daily := Quantity.ofQuanta 500
          , cumulative := Quantity.ofQuanta 500
          , runningDailyAverageQuanta := 500 }
        , { date := "2026-04-16"
          , daily := Quantity.ofQuanta 0
          , cumulative := Quantity.ofQuanta 500
          , runningDailyAverageQuanta := 250 }
        , { date := "2026-04-17"
          , daily := Quantity.ofQuanta 500
          , cumulative := Quantity.ofQuanta 1000
          , runningDailyAverageQuanta := 333 }
        , { date := "2026-04-18"
          , daily := Quantity.ofQuanta 500
          , cumulative := Quantity.ofQuanta 1500
          , runningDailyAverageQuanta := 375 }
        ]
      undatedMatchingCurrentRecords := 0
    }
  expect (Loam.Tui.LocusTrendPane.isHistory trendHistory.trend &&
      trendHistory.trend.selected == 3)
    "all-days Trend did not open on its latest calendar day"

  let historyLeft := (Loam.Tui.Reports.update trendHistory .left).state
  expect (historyLeft.trend.selected == 2)
    "all-days Trend left arrow did not move exactly one calendar day"
  let historyText := widgetText
    (Loam.Tui.Reports.viewForBounds trendBounds historyLeft)
  expect (contains "Locus Trend / Daily History   tobacco / jpy" historyText &&
      contains "Selected   Apr 17" historyText &&
      contains "One point per calendar day" historyText)
    "all-days Trend did not render its selected calendar-day evidence"

  let historyPointer :=
    (Loam.Tui.Reports.updateForBounds trendBounds historyLeft
      (.pointer Loam.Tui.LocusTrendPane.plotLeft
        (Loam.Tui.LocusTrendPane.plotTop + 1))).state
  expect (historyPointer.trend.selected == 0)
    "all-days Trend pointer did not select the nearest calendar day"

  let overviewAgain := (Loam.Tui.Reports.update historyLeft (.input 'd')).state
  expect (Loam.Tui.LocusTrendPane.isOverview overviewAgain.trend)
    "d did not return all-days history to cycle overview"
  let cachedHistory := Loam.Tui.Reports.update overviewAgain (.input 'd')
  expect (cachedHistory.query.isNone &&
      Loam.Tui.LocusTrendPane.isHistory cachedHistory.state.trend &&
      cachedHistory.state.trend.selected == 2)
    "d did not reuse the cached daily history and prior selected day"

  match (Loam.Tui.Reports.update trendPointer .enter).query with
  | some (.locusTrend start endExclusive coordinate) =>
      expect (start == "2026-04-15" && endExclusive == "2026-06-15")
        "Locus Trend Enter did not drill into the selected configured cycle"
      expect (coordinate == (⟨⟨"tobacco"⟩, ⟨"jpy"⟩⟩ : EffectCoordinate))
        "Locus Trend drill-down changed the exact coordinate"
  | _ => throw (IO.userError "Locus Trend overview Enter did not request daily detail")

  let trendDaily :=
    Loam.Tui.Reports.withLocusTrendSnapshot trendPointer {
      start := "2026-04-15"
      endExclusive := "2026-04-18"
      coordinate := ⟨⟨"tobacco"⟩, ⟨"jpy"⟩⟩
      points :=
        [ { date := "2026-04-15"
          , daily := Quantity.ofQuanta 500
          , cumulative := Quantity.ofQuanta 500
          , runningDailyAverageQuanta := 500 }
        , { date := "2026-04-16"
          , daily := Quantity.ofQuanta 0
          , cumulative := Quantity.ofQuanta 500
          , runningDailyAverageQuanta := 250 }
        , { date := "2026-04-17"
          , daily := Quantity.ofQuanta 500
          , cumulative := Quantity.ofQuanta 1000
          , runningDailyAverageQuanta := 333 }
        ]
      undatedMatchingCurrentRecords := 0
    }
  let trendDailyText := widgetText
    (Loam.Tui.Reports.viewForBounds trendBounds trendDaily)
  expect (contains "Locus Trend / Daily   tobacco / jpy" trendDailyText &&
      contains "Selected   Apr 17" trendDailyText)
    "Locus Trend daily drill-down did not render the selected day"

  let trendBack := (Loam.Tui.Reports.update trendDaily (.input 'q')).state
  expect (isLocusTrend trendBack && Loam.Tui.LocusTrendPane.isOverview trendBack.trend)
    "Locus Trend q did not return from daily detail to long history"

  let multicurrencyStep := Loam.Tui.Reports.update initial (.input 'x')
  expect (isMultimeasureSpend multicurrencyStep.state)
    "Reports direct Multicurrency Spend key did not enter the report surface"
  let multicurrencyText := widgetText (Loam.Tui.Reports.view multicurrencyStep.state)
  expect (contains "Reports / Multicurrency Spend" multicurrencyText)
    "Multicurrency Spend heading was not rendered"
  expect (contains "not a Trip transaction type" multicurrencyText)
    "Multicurrency Spend surface promoted presentation into transaction semantics"
  match (Loam.Tui.Reports.update multicurrencyStep.state .enter).query with
  | some (.multimeasureSpend start endExclusive) =>
      expect (start == "2026-09-01" && endExclusive == "2026-10-01")
        "Multicurrency Spend changed the explicit calendar window"
  | _ =>
      throw (IO.userError "Multicurrency Spend did not emit its explicit window query")

  let multicurrencyReport :=
    Loam.Tui.Reports.withMultimeasureSpendSnapshot multicurrencyStep.state {
      start := "2026-09-01"
      endExclusive := "2026-10-01"
      accountingExpense := [
        { measure := ⟨"jpy"⟩, quantity := Quantity.ofQuanta 4700 },
        { measure := ⟨"usd"⟩, quantity := Quantity.ofQuanta 2500 }
      ]
      exchangeExpense := [
        { measure := ⟨"jpy"⟩, quantity := Quantity.ofQuanta 100 }
      ]
      originalPresentedExpense := [
        { measure := ⟨"usd"⟩, quantity := Quantity.ofQuanta 3000 }
      ]
      exchanges := [{
        event := ⟨"exchange-jpy-usd"⟩
        date := "2026-09-13"
        description := "cash exchange"
        source := reportEffect "source" "cash-jpy" "jpy" (-15100)
        destination := reportEffect "destination" "cash-usd" "usd" 10000
        extraEffects := [reportEffect "fee" "fx-fee" "jpy" 100]
      }]
      unresolvedExpenseEffects := []
      unresolvedExchangeEffects := []
      unresolvedOriginalAmounts := []
    } [
      { measure := ⟨"jpy"⟩, scale := 0 },
      { measure := ⟨"usd"⟩, scale := 2 }
    ]
  let multicurrencyReportText := widgetText (Loam.Tui.Reports.view multicurrencyReport)
  expect (contains "Ordinary accounting Expense" multicurrencyReportText &&
      contains "4700 jpy" multicurrencyReportText &&
      contains "25.00 usd" multicurrencyReportText)
    "Multicurrency Spend mixed or hid ordinary Measure-separated Expense"
  expect (contains "Original presented Expense" multicurrencyReportText &&
      contains "30.00 usd" multicurrencyReportText)
    "Multicurrency Spend lost OriginalAmount evidence"
  expect (contains "Exchange-associated Expense" multicurrencyReportText &&
      contains "100 jpy" multicurrencyReportText)
    "Multicurrency Spend hid exchange-associated Expense"
  expect (contains "Exchange occurrences" multicurrencyReportText &&
      contains "-15100 jpy" multicurrencyReportText &&
      contains "+100.00 usd" multicurrencyReportText)
    "Multicurrency Spend lost exact exchange source/destination evidence"
  expect (contains "No FX rate, valuation, or home currency is inferred" multicurrencyReportText)
    "Multicurrency Spend lost its no-conversion boundary"
  expect (!contains "3000 usd" multicurrencyReportText &&
      !contains "2500 usd" multicurrencyReportText)
    "Multicurrency Spend ignored configured Measure decimal presentation"

  let coverageStep := Loam.Tui.Reports.update initial (.input 'c')
  expect (match coverageStep.state.mode with | .scheduledCoverage => true | _ => false)
    "Reports direct Scheduled Coverage key did not enter the coverage surface"
  match coverageStep.query with
  | some (.scheduledCoverage observedAt) =>
      expect (observedAt == "2026-09-07")
        "Scheduled Coverage query did not retain the selected Home date as its explicit observation coordinate"
  | _ => throw (IO.userError "Scheduled Coverage surface did not request its shared read-side projection")
  let coverageText := widgetText (Loam.Tui.Reports.view coverageStep.state)
  expect (contains "Reports / Scheduled Coverage" coverageText)
    "Scheduled Coverage heading was not rendered"
  expect (contains "replaceable read-side config" coverageText)
    "Scheduled Coverage surface promoted monitoring rules into Scheduled authority"

  let balancesStep := Loam.Tui.Reports.update initial (.input 'r')
  expect (match balancesStep.state.mode with | .balances => true | _ => false)
    "Reports direct Balances key did not enter the shared RoleBalance surface"
  match balancesStep.query with
  | some .roleBalances => pure ()
  | _ => throw (IO.userError "Reports Balances surface did not request the shared RoleBalance answer")

  let cashCoordinate : EffectCoordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩
  let unsupportedDebt : EffectCoordinate := ⟨⟨"liability-unsupported"⟩, ⟨"jpy"⟩⟩
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
  expect (contains "liability-unsupported" balancesText && contains "balance unsupported" balancesText)
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

  let pensionCompare : Loam.BoundaryPresetConfig.Preset := {
    name := "Pension Cycle"
    boundaries :=
      ["2026-04-15", "2026-06-15", "2026-08-15", "2026-10-15", "2026-12-15"]
  }
  let comparePresetInitial :=
    Loam.Tui.Reports.initialForDateWithPresets "2026-09-07" [pensionCompare]
  let comparePresetStock := (Loam.Tui.Reports.update comparePresetInitial .enter).state
  let comparePresetSingle := (Loam.Tui.Reports.update comparePresetStock (.input ']')).state
  expect (Loam.Tui.Reports.windowSourceLabel comparePresetSingle == "Pension Cycle")
    "comparison fixture did not select its named preset"
  let comparePreset := (Loam.Tui.Reports.update comparePresetSingle (.input 'c')).state
  expect (Loam.Tui.Reports.comparisonSourceLabel comparePreset == "Pension Cycle")
    "comparison did not inherit the single-period named preset"
  expect (comparePreset.comparison.leftStart == "2026-06-15" &&
      comparePreset.comparison.leftEndExclusive == "2026-08-15" &&
      comparePreset.comparison.rightStart == "2026-08-15" &&
      comparePreset.comparison.rightEndExclusive == "2026-10-15")
    "named preset comparison did not seed previous/current adjacent cycles"
  let comparePresetBack := (Loam.Tui.Reports.update comparePreset .left).state
  expect (comparePresetBack.comparison.leftStart == "2026-04-15" &&
      comparePresetBack.comparison.leftEndExclusive == "2026-06-15" &&
      comparePresetBack.comparison.rightStart == "2026-06-15" &&
      comparePresetBack.comparison.rightEndExclusive == "2026-08-15")
    "left did not shift the whole named-preset comparison pair"
  let comparePresetForward := (Loam.Tui.Reports.update comparePreset .right).state
  expect (comparePresetForward.comparison.leftStart == "2026-08-15" &&
      comparePresetForward.comparison.leftEndExclusive == "2026-10-15" &&
      comparePresetForward.comparison.rightStart == "2026-10-15" &&
      comparePresetForward.comparison.rightEndExclusive == "2026-12-15")
    "right did not shift the whole named-preset comparison pair"

  let compareCalendarBase :=
    (Loam.Tui.Reports.update comparePresetInitial .enter).state
  let compareCalendar := (Loam.Tui.Reports.update compareCalendarBase (.input 'c')).state
  let compareCycledPreset := (Loam.Tui.Reports.update compareCalendar (.input ']')).state
  expect (Loam.Tui.Reports.comparisonSourceLabel compareCycledPreset == "Pension Cycle")
    "comparison [ / ] source control did not select the named preset"
  expect (compareCycledPreset.comparison.leftStart == "2026-06-15" &&
      compareCycledPreset.comparison.rightEndExclusive == "2026-10-15")
    "comparison source switch did not derive the named adjacent pair"

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
  let stockBack := Loam.Tui.Reports.update stock (.input 'q')
  expect (isMenu stockBack.state && !stockBack.back)
    "Reports detail q did not return exactly one level to the Reports menu"

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
    measure := some (⟨"usd"⟩ : MeasureId)
    reconstructedStart := Quantity.ofQuanta 100
    increasesAcrossEvents := Quantity.ofQuanta 50
    decreasesAcrossEvents := Quantity.ofQuanta (-20)
    currentTracked := Quantity.ofQuanta 140
  }
  let refusedShiftFromReport := (Loam.Tui.Reports.update stockReport .right).state
  expect refusedShiftFromReport.stockFlowSnapshot.isSome
    "refused non-calendar shift discarded the existing Stock-Flow snapshot"

  let stockReportText := widgetText (Loam.Tui.Reports.view stockReport)
  expect (contains " usd" stockReportText)
    "Stock–Flow TUI did not render the selected Measure"
  expect (contains "Reconstructed at start:" stockReportText && contains "100 usd" stockReportText)
    "Stock–Flow start reconstruction was not rendered"
  expect (contains "Reconstructed at end:" stockReportText && contains "130 usd" stockReportText)
    "Stock–Flow end reconstruction was not rendered"
  expect (contains "Tracked increases across Events:" stockReportText && contains "+50 usd" stockReportText)
    "Stock–Flow increases were not rendered"
  expect (contains "Tracked decreases across Events:" stockReportText && contains "-20 usd" stockReportText)
    "Stock–Flow decreases were not rendered"
  expect (contains "Net change:" stockReportText && contains "+30 usd" stockReportText)
    "Stock–Flow net change was not rendered"
  expect (contains "Current tracked balance now:" stockReportText && contains "140 usd" stockReportText)
    "Stock–Flow current context was not rendered separately"
  expect (contains "not income/spending" stockReportText)
    "Stock–Flow lost its sign/classification non-claim"

  let stockCompare := (Loam.Tui.Reports.update stock (.input 'c')).state
  expect (match stockCompare.mode with | .stockFlowCompare => true | _ => false)
    "Stock–Flow c did not enter two-period comparison"
  expect (Loam.Tui.Reports.comparisonSourceLabel stockCompare == "Calendar Month")
    "Stock–Flow comparison did not inherit Calendar Month source"
  expect (stockCompare.comparison.leftStart == "2026-08-01" &&
      stockCompare.comparison.leftEndExclusive == "2026-09-01")
    "Stock–Flow comparison did not seed Left from the previous calendar month"
  expect (stockCompare.comparison.rightStart == "2026-09-01" &&
      stockCompare.comparison.rightEndExclusive == "2026-10-01")
    "Stock–Flow comparison did not seed Right from the current calendar month"
  match (Loam.Tui.Reports.update stockCompare .enter).query with
  | some (.stockFlowCompare leftStart leftEnd rightStart rightEnd) =>
      expect (leftStart == "2026-08-01" && leftEnd == "2026-09-01")
        "Stock–Flow comparison changed Left coordinates"
      expect (rightStart == "2026-09-01" && rightEnd == "2026-10-01")
        "Stock–Flow comparison changed Right coordinates"
  | _ => throw (IO.userError "Stock–Flow comparison did not emit both explicit windows")

  let stockComparisonReport := Loam.Tui.Reports.withStockFlowComparison stockCompare {
    left := {
      start := "2026-08-01"
      endExclusive := "2026-09-01"
      measure := some (⟨"jpy"⟩ : MeasureId)
      reconstructedStart := Quantity.ofQuanta 1000
      increasesAcrossEvents := Quantity.ofQuanta 300
      decreasesAcrossEvents := Quantity.ofQuanta (-100)
      currentTracked := Quantity.ofQuanta 1500
    }
    right := {
      start := "2026-09-01"
      endExclusive := "2026-10-01"
      measure := some (⟨"jpy"⟩ : MeasureId)
      reconstructedStart := Quantity.ofQuanta 1200
      increasesAcrossEvents := Quantity.ofQuanta 400
      decreasesAcrossEvents := Quantity.ofQuanta (-200)
      currentTracked := Quantity.ofQuanta 1500
    }
  }
  let stockComparisonText := widgetText
    (Loam.Tui.Reports.viewForBounds { width := 140, height := 80 } stockComparisonReport)
  expect (contains "Left period" stockComparisonText && contains "Right period" stockComparisonText)
    "wide Stock–Flow comparison did not expose both panes"
  expect (contains "Compare by: Calendar Month" stockComparisonText)
    "Stock–Flow comparison did not render its automatic source"
  expect (contains "Window [2026-08-01, 2026-09-01)" stockComparisonText &&
      contains "Window [2026-09-01, 2026-10-01)" stockComparisonText)
    "Stock–Flow comparison did not render both explicit windows"
  let stockCompareForward := (Loam.Tui.Reports.update stockCompare .right).state
  expect (stockCompareForward.comparison.leftStart == "2026-09-01" &&
      stockCompareForward.comparison.leftEndExclusive == "2026-10-01" &&
      stockCompareForward.comparison.rightStart == "2026-10-01" &&
      stockCompareForward.comparison.rightEndExclusive == "2026-11-01")
    "right did not shift the whole Calendar Month comparison pair"
  let stockCompareCustom := (Loam.Tui.Reports.update stockCompare (.input 'e')).state
  expect (Loam.Tui.Reports.comparisonSourceLabel stockCompareCustom == "Custom")
    "e did not enter manual comparison editing"
  expect (stockCompareCustom.comparison.focus.val == 0)
    "e did not focus Left start for manual comparison editing"
  expect (match (Loam.Tui.Reports.update stockComparisonReport .escape).state.mode with
      | .stockFlow => true | _ => false)
    "Stock–Flow comparison escape did not return to the single-period report"

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
  let consultingCoordinate : EffectCoordinate := ⟨⟨"consulting"⟩, ⟨"usd"⟩⟩
  let incomeExpenseReport := Loam.Tui.Reports.withIncomeExpenseSnapshot incomeExpense {
    roleFlow := {
      start := "2026-09-01"
      endExclusive := "2026-10-01"
      rows :=
        [ { coordinate := pensionCoordinate
          , role := .income
          , quantity := Quantity.ofQuanta (-240000) }
        , { coordinate := foodCoordinate
          , role := .expense
          , quantity := Quantity.ofQuanta 50000 }
        , { coordinate := consultingCoordinate
          , role := .income
          , quantity := Quantity.ofQuanta (-20) }
        ]
      unresolvedEffects :=
        [ { event := ⟨"actual-unresolved"⟩
          , date := "2026-09-12"
          , effect := Effect.ofAnonymousQuantity
              ⟨"mystery"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 5) }
        ]
    }
    expenseProvenance := .available {
      scheduledLinked :=
        [ { coordinate := foodCoordinate, role := .expense
          , quantity := Quantity.ofQuanta 20000 } ]
      noScheduledLink :=
        [ { coordinate := foodCoordinate, role := .expense
          , quantity := Quantity.ofQuanta 30000 } ]
    }
  }
  let incomeExpenseReportText := widgetText (Loam.Tui.Reports.view incomeExpenseReport)
  expect (contains "Income:" incomeExpenseReportText && contains "240000 jpy" incomeExpenseReportText)
    "Income & Expense view did not present credit-normal Income"
  expect (contains "Expense:" incomeExpenseReportText && contains "50000 jpy" incomeExpenseReportText)
    "Income & Expense view did not present debit-normal Expense"
  expect (contains "Result:" incomeExpenseReportText && contains "190000 jpy" incomeExpenseReportText)
    "Income & Expense view did not derive the occurrence-time result"
  expect (contains "20 usd" incomeExpenseReportText && contains "consulting" incomeExpenseReportText)
    "Income & Expense view did not preserve the shared multi-Measure summary"
  expect (contains "Income breakdown" incomeExpenseReportText && contains "pension" incomeExpenseReportText) "Income & Expense view did not expose coordinate-preserving Income detail"
  expect (contains "Scheduled-linked expense:" incomeExpenseReportText &&
      contains "20000 jpy" incomeExpenseReportText)
    "Income & Expense view did not expose Scheduled-linked Expense"
  expect (contains "No Scheduled link:" incomeExpenseReportText &&
      contains "30000 jpy" incomeExpenseReportText && contains "food" incomeExpenseReportText)
    "Income & Expense view did not expose unlinked Expense"
  expect (contains "not a fixed/recurring-cost classification" incomeExpenseReportText)
    "Income & Expense view overstated Scheduled provenance as fixed-cost classification"
  expect (contains "Unresolved role Effects: 1" incomeExpenseReportText && contains "mystery" incomeExpenseReportText)
    "Income & Expense view hid unresolved role evidence"
  expect (contains "not accrual recognition or period closing" incomeExpenseReportText)
    "Income & Expense view overstated occurrence-time flow as a closed P/L"

  let incomeCompareBase := (Loam.Tui.Reports.update incomeExpense (.input 'c')).state
  let incomeCompare : Loam.Tui.Reports.State := {
    incomeCompareBase with
      comparison := {
        incomeCompareBase.comparison with
        leftStart := "2026-01-15"
        leftEndExclusive := "2026-03-03"
        rightStart := "2026-07-01"
        rightEndExclusive := "2026-07-20"
        focus := ⟨4, by decide⟩
        source := .custom
      }
  }
  match (Loam.Tui.Reports.update incomeCompare .enter).query with
  | some (.incomeExpenseCompare leftStart leftEnd rightStart rightEnd) =>
      expect (leftStart == "2026-01-15" && leftEnd == "2026-03-03")
        "Income & Expense comparison constrained Left to a calendar month"
      expect (rightStart == "2026-07-01" && rightEnd == "2026-07-20")
        "Income & Expense comparison constrained Right to a calendar month"
  | _ => throw (IO.userError "Income & Expense comparison did not emit arbitrary windows")

  let incomeComparisonReport := Loam.Tui.Reports.withIncomeExpenseComparison incomeCompare {
    left := {
      roleFlow := {
        start := "2026-01-15"
        endExclusive := "2026-03-03"
        rows :=
          [ { coordinate := pensionCoordinate, role := .income, quantity := Quantity.ofQuanta (-100) }
          , { coordinate := foodCoordinate, role := .expense, quantity := Quantity.ofQuanta 30 }
          ]
        unresolvedEffects := []
      }
      expenseProvenance := .available {
        scheduledLinked :=
          [ { coordinate := foodCoordinate, role := .expense, quantity := Quantity.ofQuanta 10 } ]
        noScheduledLink :=
          [ { coordinate := foodCoordinate, role := .expense, quantity := Quantity.ofQuanta 20 } ]
      }
    }
    right := {
      roleFlow := {
        start := "2026-07-01"
        endExclusive := "2026-07-20"
        rows :=
          [ { coordinate := pensionCoordinate, role := .income, quantity := Quantity.ofQuanta (-120) }
          , { coordinate := foodCoordinate, role := .expense, quantity := Quantity.ofQuanta 40 }
          ]
        unresolvedEffects := []
      }
      expenseProvenance := .available {
        scheduledLinked :=
          [ { coordinate := foodCoordinate, role := .expense, quantity := Quantity.ofQuanta 25 } ]
        noScheduledLink :=
          [ { coordinate := foodCoordinate, role := .expense, quantity := Quantity.ofQuanta 15 } ]
      }
    }
  }
  let incomeComparisonText := widgetText
    (Loam.Tui.Reports.viewForBounds { width := 140, height := 100 } incomeComparisonReport)
  expect (contains "Left period" incomeComparisonText && contains "Right period" incomeComparisonText)
    "wide Income & Expense comparison did not expose both panes"
  expect (contains "Window [2026-01-15, 2026-03-03)" incomeComparisonText &&
      contains "Window [2026-07-01, 2026-07-20)" incomeComparisonText)
    "Income & Expense comparison did not render arbitrary independent windows"
  expect (contains "No delta, percentage, equal-duration, or baseline meaning is inferred."
      incomeComparisonText)
    "Income & Expense comparison accidentally claimed comparison semantics"
  expect (contains "Scheduled-linked expense:" incomeComparisonText &&
      contains "No Scheduled link:" incomeComparisonText)
    "Income & Expense comparison did not carry Expense provenance into both period panes"

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
  expect (contains "q / Esc home" smallMenuText)
    "bounded Reports menu did not pin its navigation"

  let topBoundedText := widgetText (Loam.Tui.Reports.viewForBounds small stockReport)
  expect (contains "Reports / Stock–Flow" topBoundedText)
    "bounded Stock–Flow lost the top of its report body"
  expect (contains "Lines 1–" topBoundedText)
    "bounded report did not expose its scroll position"
  expect (contains "q / Esc Reports menu" topBoundedText)
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
  expect (contains "q / Esc Reports menu" bottomBoundedText)
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
      expect (contains "q / Esc" (widgetText rendered))
        ("Reports lost essential navigation at tiny terminal height " ++ toString tiny.height)

  IO.println
    "TUI Reports: menu, two-period Stock–Flow and Income & Expense comparison, conditional Liquidity, Budget Window and navigation passed."
