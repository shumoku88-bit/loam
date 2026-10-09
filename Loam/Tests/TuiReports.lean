import Loam.Tui.Reports
import Loam.Tui.ReportsSession
import Loam.Tui.PlainTextPrint
import Loam.Tui.Balances

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def widgetLineTexts (widget : Widget) : List String :=
  widget.lines.map fun cells =>
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


private def expectRefusal {α : Type} (result : Except String α)
    (message : String) : IO Unit := do
  match result with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError message)

private def testBoundedPrint : IO Unit := do
  let exactLimit := List.replicate Loam.Tui.PlainTextPrint.maxLines "x"
  match Loam.Tui.PlainTextPrint.prepare exactLimit with
  | .error message => throw (IO.userError ("within-limit print refused: " ++ message))
  | .ok prepared =>
      expect (prepared.lineCount == 200 && prepared.byteCount == 400 &&
        prepared.lines.length == 200)
        "bounded print lost exact line/byte accounting"
  expectRefusal (Loam.Tui.PlainTextPrint.prepare (exactLimit ++ ["extra"]))
    "bounded print admitted one extra line"
  expectRefusal (Loam.Tui.PlainTextPrint.prepare
    [String.ofList (List.replicate (Loam.Tui.PlainTextPrint.maxBytes + 1) 'x')])
    "bounded print admitted an oversized single line"
  match Loam.Tui.PlainTextPrint.prepare ["a", "日本", "b\\t\\x01c"] with
  | .error message => throw (IO.userError message)
  | .ok prepared =>
      expect (prepared.byteCount == 12 && prepared.lineCount == 3 &&
        prepared.lines[2]? == some "bc")
        "bounded print lost UTF-8 byte accounting or control-byte sanitation"
  let selectedBalances : Loam.Tui.Balances.State := {
    rows := [.unsupported ⟨⟨"unknown-wallet"⟩, ⟨"jpy"⟩⟩]
  }
  match Loam.Tui.Balances.preparePrint selectedBalances with
  | .error message => throw (IO.userError message)
  | .ok prepared =>
      expect (contains "unsupported" (String.intercalate "\\n" prepared.lines))
        "selected balance printing turned unsupported state into an amount"
  expectRefusal (Loam.Tui.Balances.preparePrint {
      rows := List.replicate 250 (.unsupported ⟨⟨"unknown-wallet"⟩, ⟨"jpy"⟩⟩)
    })
    "selected balance printing expanded an oversized row selection"

private def testReportsBalancesPrint (state : Loam.Tui.Reports.State) : IO Unit := do
  expect (contains "[p] print view"
      (widgetText (Loam.Tui.Reports.viewForBounds { width := 100, height := 24 } state)))
    "Reports/Balances did not advertise bounded terminal printing"
  match Loam.Tui.Reports.prepareBalancesPrint state with
  | .error message => throw (IO.userError ("bounded Reports/Balances refused fixture: " ++ message))
  | .ok prepared =>
      let printed := String.intercalate "\\n" prepared.lines
      expect (contains "Qualified Net Worth: UNKNOWN" printed &&
        contains "liability-unsupported" printed && contains "balance unsupported" printed)
        "Reports/Balances print omitted evidence qualifiers or unknown amounts"

def main : IO Unit := do
  expect (Loam.Tui.Terminal.plainTerminalText "a\n\r\x1b\tb" == "ab")
    "presentation text retained terminal control characters"
  let reportHelp := widgetText (Loam.Tui.Reports.viewForBounds
    { width := 120, height := 24 } Loam.Tui.Reports.initial)
  expect (!contains "[y] copy screen" reportHelp && !contains "Shift+drag" reportHelp)
    "Reports retained the retired screen-copy or terminal-selection hint"

  testBoundedPrint

  let styledCells : List Cell :=
    [ { glyph := 'a', style := .normal }
    , { glyph := 'b', style := .normal }
    , { glyph := '日', style := .muted }
    , { glyph := '本', style := .muted }
    , { glyph := 'c', style := .normal }
    ]
  expect
    (Loam.Tui.Terminal.cellsToStyleRuns styledCells ==
      [ span "ab" .normal
      , span "日本" .muted
      , span "c" .normal
      ])
    "terminal style-run coalescing changed glyph order or style boundaries"
  expect
    (Loam.Tui.Terminal.renderCellsAnsi styledCells ==
      "\x1b[0mab\x1b[0;2m日本\x1b[0mc")
    "terminal style-run rendering emitted per-cell or reordered ANSI output"

  let directWidget : Widget :=
    .column
      [ .row [span "ab" .normal, span "日本" .muted]
      , .row [span "tail" .normal]
      ]
  expect
    (Loam.Tui.Terminal.widgetSpanLines directWidget ==
      [ [span "ab" .normal, span "日本" .muted]
      , [span "tail" .normal]
      ])
    "direct terminal renderer lowered Widget spans before row recovery"
  expect
    (Loam.Tui.Terminal.directFrameAnsi { width := 6, height := 2 } directWidget ==
      "\x1b[1;1H\x1b[0mab\x1b[0;2m日\x1b[0m\x1b[K" ++
      "\x1b[2;1H\x1b[0mtail\x1b[0m\x1b[K")
    "direct terminal renderer changed row order, clipping, style, or clearing"

  let viewportSource :=
    Loam.Tui.Viewport.concat
      [ Loam.Tui.Viewport.ofList ([1, 2] : List Nat)
      , Loam.Tui.Viewport.ofList [3, 4]
      ]
  expect
    (viewportSource.extent == 4 && viewportSource.slice 1 2 == [2, 3])
    "lazy viewport source did not preserve cross-source slicing"

  let initial := Loam.Tui.Reports.initialForDate "2026-09-07"
  let menuText := widgetText (Loam.Tui.Reports.view initial)
  expect (contains "Reports" menuText) "Reports menu heading was not rendered"
  expect (contains "Stock–Flow" menuText) "Reports menu lost Stock–Flow"
  expect (contains "Income & Expense" menuText) "Reports menu lost Income & Expense"
  expect (contains "Balances" menuText) "Reports menu lost evidence-aware Balances"
  expect (contains "Liquidity" menuText) "Reports menu lost Liquidity"
  expect (contains "Budget Window" menuText) "Reports menu lost Budget Window"
  expect (!(contains "Scheduled Coverage" menuText))
    "Reports menu still exposed Scheduled Coverage after it moved to Scheduled"
  expect (contains "Multicurrency Spend" menuText) "Reports menu lost Multicurrency Spend"
  expect (contains "Trend" menuText) "Reports menu lost unified Trend"
  expect (!(contains "Locus Trend" menuText)) "Reports menu still exposed retired Locus Trend"
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
    "Reports direct Trend key did not enter the comparison surface"
  match compareStep.query with
  | some (.locusTrendCompare observedAt granularity scope series) =>
      expect (observedAt == "2026-09-07")
        "Trend lost the selected Home observation date"
      expect (granularity == .cycle && scope == .allHistory)
        "Trend did not open at Cycle / All history"
      expect (series.map (·.label) == ["Tobacco", "Coffee", "Food"])
        "Trend default series labels changed"
      expect
        (series.map (fun item => item.coordinate.locus.token) ==
          ["tobacco", "coffee", "food"])
        "Trend stopped using exact Locus identities"
  | _ => throw (IO.userError "Trend did not emit its multi-series query")

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
    "Trend did not select the current cycle initially"

  let trendCatalog : Loam.LocusCatalog.Catalog :=
    [ { locus := ⟨"tobacco"⟩, label := "Tobacco", help := "" }
    , { locus := ⟨"coffee"⟩, label := "Coffee", help := "" }
    , { locus := ⟨"food"⟩, label := "Food", help := "" }
    , { locus := ⟨"books"⟩, label := "Books", help := "" }
    , { locus := ⟨"travel"⟩, label := "Travel", help := "" }
    , { locus := ⟨"medical"⟩, label := "Medical", help := "" }
    ]
  let rackReport : Loam.Tui.Reports.State := {
    compareReport with
      trendCompare :=
        Loam.Tui.LocusTrendComparePane.withCatalog
          compareReport.trendCompare trendCatalog
  }
  let rackText := widgetText
    (Loam.Tui.Reports.viewForBounds { width := 100, height := 30 } rackReport)
  expect (contains "[1 ● Tobacco]" rackText &&
      contains "[2 ◆ Coffee]" rackText &&
      contains "[3 ▲ Food]" rackText &&
      contains "[4 + Add]" rackText &&
      contains "[5 + Add]" rackText &&
      contains "a series" rackText)
    "Trend did not expose the five-slot Series rack"

  let addFourthOpen := (Loam.Tui.Reports.update rackReport (.input 'a')).state
  expect (Loam.Tui.LocusTrendComparePane.isPickerOpen addFourthOpen.trendCompare &&
      addFourthOpen.trendCompare.pickerSlot == 3)
    "Trend series picker did not target slot 4 after the default three series"
  let pickerAtBooks :=
    (List.range 3).foldl
      (fun state _ => (Loam.Tui.Reports.update state .down).state)
      addFourthOpen
  let addBooks := Loam.Tui.Reports.update pickerAtBooks .enter
  match addBooks.query with
  | some (.locusTrendCompare _ _ _ series) =>
      expect (series.map (·.label) == ["Tobacco", "Coffee", "Food", "Books"])
        "Trend series picker did not append Books as series 4"
  | _ => throw (IO.userError "Trend series 4 addition did not rerun the Trend query")
  expect (addBooks.state.trendCompareSeries.length == 4 &&
      !Loam.Tui.LocusTrendComparePane.isPickerOpen addBooks.state.trendCompare)
    "Trend series 4 addition changed the rack contract or left the picker open"

  let addFifthOpen := (Loam.Tui.Reports.update addBooks.state (.input 'a')).state
  expect (addFifthOpen.trendCompare.pickerSlot == 4)
    "Trend with four series did not target slot 5"
  let pickerAtTravel :=
    (List.range 4).foldl
      (fun state _ => (Loam.Tui.Reports.update state .down).state)
      addFifthOpen
  let addTravel := Loam.Tui.Reports.update pickerAtTravel .enter
  match addTravel.query with
  | some (.locusTrendCompare _ _ _ series) =>
      expect
        (series.map (·.label) == ["Tobacco", "Coffee", "Food", "Books", "Travel"] &&
          series.length == Loam.Tui.LocusTrendComparePane.maxSeries)
        "Trend did not fill exactly five active series"
  | _ => throw (IO.userError "Trend series 5 addition did not rerun the Trend query")

  let booksSpec : Loam.LocusTrendCompareReview.SeriesSpec := {
    label := "Books"
    coordinate := ⟨⟨"books"⟩, ⟨"jpy"⟩⟩
  }
  let travelSpec : Loam.LocusTrendCompareReview.SeriesSpec := {
    label := "Travel"
    coordinate := ⟨⟨"travel"⟩, ⟨"jpy"⟩⟩
  }
  let booksSeries : Loam.LocusTrendCompareReview.Series := {
    spec := booksSpec
    points := tobaccoPoints
    undatedMatchingCurrentRecords := 0
  }
  let travelSeries : Loam.LocusTrendCompareReview.Series := {
    spec := travelSpec
    points := coffeePoints
    undatedMatchingCurrentRecords := 0
  }
  let fiveSnapshot : Loam.LocusTrendCompareReview.Snapshot := {
    compareSnapshot with
      series := [tobaccoSeries, coffeeSeries, foodSeries, booksSeries, travelSeries]
  }
  let fiveReport :=
    Loam.Tui.Reports.withLocusTrendCompareSnapshot addTravel.state fiveSnapshot
  let fiveText := widgetText
    (Loam.Tui.Reports.viewForBounds { width := 100, height := 34 } fiveReport)
  expect (contains "[4 ■ Books]" fiveText && contains "[5 □ Travel]" fiveText)
    "Trend rack lost the fourth or fifth marker identity"

  let fullPickerOpen := (Loam.Tui.Reports.update addTravel.state (.input 'a')).state
  expect (fullPickerOpen.trendCompare.pickerSlot == 0)
    "full five-series Trend did not reopen on an explicit replacement slot"
  let fifthSlot := (Loam.Tui.Reports.update fullPickerOpen (.input '5')).state
  let pickerAtMedical :=
    (List.range 5).foldl
      (fun state _ => (Loam.Tui.Reports.update state .down).state)
      fifthSlot
  let replaceMedical := Loam.Tui.Reports.update pickerAtMedical .enter
  match replaceMedical.query with
  | some (.locusTrendCompare _ _ _ series) =>
      expect
        (series.map (·.label) == ["Tobacco", "Coffee", "Food", "Books", "Medical"] &&
          series.length == 5)
        "Trend did not replace slot 5 while preserving the five-series ceiling"
  | _ => throw (IO.userError "Trend slot 5 replacement did not rerun the query")

  let removeFifthOpen := (Loam.Tui.Reports.update replaceMedical.state (.input 'a')).state
  let removeFifthSlot := (Loam.Tui.Reports.update removeFifthOpen (.input '5')).state
  let removeFifth := Loam.Tui.Reports.update removeFifthSlot (.input 'x')
  expect (removeFifth.state.trendCompareSeries.map (·.label) ==
      ["Tobacco", "Coffee", "Food", "Books"])
    "Trend series picker did not remove slot 5"

  let removeFourthOpen := (Loam.Tui.Reports.update removeFifth.state (.input 'a')).state
  let removeFourthSlot := (Loam.Tui.Reports.update removeFourthOpen (.input '4')).state
  let removeFourth := Loam.Tui.Reports.update removeFourthSlot (.input 'x')
  expect (removeFourth.state.trendCompareSeries.map (·.label) ==
      ["Tobacco", "Coffee", "Food"])
    "Trend series picker did not remove slot 4"

  let removeThirdOpen := (Loam.Tui.Reports.update removeFourth.state (.input 'a')).state
  let removeThirdSlot := (Loam.Tui.Reports.update removeThirdOpen (.input '3')).state
  let removeThird := Loam.Tui.Reports.update removeThirdSlot (.input 'x')
  expect (removeThird.state.trendCompareSeries.map (·.label) == ["Tobacco", "Coffee"])
    "Trend series picker did not remove slot 3"

  let removeSecondOpen := (Loam.Tui.Reports.update removeThird.state (.input 'a')).state
  let removeSecondSlot := (Loam.Tui.Reports.update removeSecondOpen (.input '2')).state
  let removeSecond := Loam.Tui.Reports.update removeSecondSlot (.input 'x')
  expect (removeSecond.state.trendCompareSeries.map (·.label) == ["Tobacco"])
    "Trend series picker did not reduce to a valid one-series Trend"

  let keepOneOpen := (Loam.Tui.Reports.update removeSecond.state (.input 'a')).state
  let keepOneSlot := (Loam.Tui.Reports.update keepOneOpen (.input '1')).state
  let keepOne := Loam.Tui.Reports.update keepOneSlot (.input 'x')
  expect (keepOne.query.isNone &&
      keepOne.state.trendCompareSeries.map (·.label) == ["Tobacco"] &&
      contains "at least one active series" keepOne.state.notice)
    "Trend allowed its final active series to be removed"

  let addSecondOpen := (Loam.Tui.Reports.update removeSecond.state (.input 'a')).state
  expect (addSecondOpen.trendCompare.pickerSlot == 1)
    "Trend with one series did not target the next empty slot"
  let duplicateSecond := Loam.Tui.Reports.update addSecondOpen .enter
  expect (duplicateSecond.query.isNone &&
      duplicateSecond.state.trendCompareSeries.length == 1 &&
      contains "already active" duplicateSecond.state.notice)
    "Trend accepted the same exact Locus twice"
  let chooseCoffee := (Loam.Tui.Reports.update duplicateSecond.state .down).state
  let addSecond := Loam.Tui.Reports.update chooseCoffee .enter
  expect (addSecond.query.isSome &&
      addSecond.state.trendCompareSeries.map (·.label) == ["Tobacco", "Coffee"])
    "Trend did not add a second distinct series after duplicate rejection"

  let monthRequest := Loam.Tui.Reports.update compareReport (.input ']')
  match monthRequest.query with
  | some (.locusTrendCompare observedAt granularity scope series) =>
      expect (observedAt == "2026-09-07" && granularity == .month &&
          scope == .allHistory &&
          series.map (·.label) == ["Tobacco", "Coffee", "Food"])
        "Trend ] did not request the same exact series at month granularity"
  | _ => throw (IO.userError "Trend ] did not request month granularity")

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
    "Trend did not preserve the selected Aug 14 period when zooming to months"
  let monthText := widgetText
    (Loam.Tui.Reports.viewForBounds { width := 100, height := 30 } monthReport)
  expect (contains "Trend   month average / day" monthText &&
      contains "Aug 1 → Sep 1" monthText &&
      contains "Grain Month" monthText &&
      contains "[ / ] grain" monthText &&
      !(contains "Range " monthText) && !(contains "s/S range" monthText))
    "Trend Month did not stay all-history without Day range controls"

  let dayRequest := Loam.Tui.Reports.update monthReport (.input ']')
  match dayRequest.query with
  | some (.locusTrendCompare observedAt granularity scope _) =>
      expect (observedAt == "2026-09-07" && granularity == .day &&
          scope == .allHistory)
        "Trend second ] did not request day granularity"
  | _ => throw (IO.userError "Trend second ] did not request day granularity")

  let cycleRequest := Loam.Tui.Reports.update monthReport (.input '[')
  match cycleRequest.query with
  | some (.locusTrendCompare _ granularity scope _) =>
      expect (granularity == .cycle && scope == .allHistory)
        "Trend [ did not return from month to cycle granularity"
  | _ => throw (IO.userError "Trend [ did not request cycle granularity")

  let ignoredCycleRange := Loam.Tui.Reports.update compareReport (.input 's')
  expect (ignoredCycleRange.query.isNone &&
      ignoredCycleRange.state.trendCompare.scope == .allHistory)
    "Trend exposed Range changes while Cycle grain was active"

  let currentCycleRequest := Loam.Tui.Reports.update dayRequest.state (.input 's')
  match currentCycleRequest.query with
  | some (.locusTrendCompare observedAt granularity scope series) =>
      expect (observedAt == "2026-09-07" && granularity == .day &&
          scope == .currentCycle &&
          series.map (·.label) == ["Tobacco", "Coffee", "Food"])
        "Trend Day s did not request Current cycle with the same exact series"
  | _ => throw (IO.userError "Trend Day s did not request Current cycle")

  let currentMonthRequest := Loam.Tui.Reports.update currentCycleRequest.state (.input 's')
  match currentMonthRequest.query with
  | some (.locusTrendCompare _ granularity scope _) =>
      expect (granularity == .day && scope == .currentMonth)
        "Trend Day second s did not request This month"
  | _ => throw (IO.userError "Trend Day second s did not request This month")

  let scopeBackRequest := Loam.Tui.Reports.update currentCycleRequest.state (.input 'S')
  match scopeBackRequest.query with
  | some (.locusTrendCompare _ granularity scope _) =>
      expect (granularity == .day && scope == .allHistory)
        "Trend Day S did not return to All history"
  | _ => throw (IO.userError "Trend Day S did not request All history")

  let monthFromScopedDay := Loam.Tui.Reports.update currentCycleRequest.state (.input '[')
  match monthFromScopedDay.query with
  | some (.locusTrendCompare _ granularity scope _) =>
      expect (granularity == .month && scope == .allHistory)
        "Trend Month did not force All history after leaving a scoped Day view"
  | _ => throw (IO.userError "Trend scoped Day did not request Month")
  expect (monthFromScopedDay.state.trendCompare.scope == .currentCycle)
    "Trend forgot the preferred Day Range while Month was active"
  let loadedMonthFromScopedDay :=
    Loam.Tui.Reports.withLocusTrendCompareSnapshot monthFromScopedDay.state monthSnapshot
  expect (loadedMonthFromScopedDay.trendCompare.scope == .currentCycle)
    "Trend Month snapshot overwrote the remembered Day Range"
  let dayAgain := Loam.Tui.Reports.update loadedMonthFromScopedDay (.input ']')
  match dayAgain.query with
  | some (.locusTrendCompare _ granularity scope _) =>
      expect (granularity == .day && scope == .currentCycle)
        "Trend did not restore the remembered Range when returning to Day"
  | _ => throw (IO.userError "Trend did not return from Month to scoped Day")

  let compareLeft := (Loam.Tui.Reports.update compareReport .left).state
  expect (compareLeft.trendCompare.selected == 1)
    "Trend left arrow did not move one shared cycle"

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
    "Trend Day did not open on the trailing 31-day viewport"

  let viewportOneLeft :=
    Loam.Tui.LocusTrendComparePane.moveSelection viewportState true
  expect (viewportOneLeft.selected == 38 &&
      Loam.Tui.LocusTrendComparePane.visibleStart viewportOneLeft == 9)
    "Trend Day moved the viewport before selection reached its edge"

  let viewportAtLeft :=
    (List.range 30).foldl
      (fun state _ => Loam.Tui.LocusTrendComparePane.moveSelection state true)
      viewportState
  expect (viewportAtLeft.selected == 9 &&
      Loam.Tui.LocusTrendComparePane.visibleStart viewportAtLeft == 9)
    "Trend Day did not keep the selected day at the left viewport edge"
  let viewportPastLeft :=
    Loam.Tui.LocusTrendComparePane.moveSelection viewportAtLeft true
  expect (viewportPastLeft.selected == 8 &&
      Loam.Tui.LocusTrendComparePane.visibleStart viewportPastLeft == 8)
    "Trend Day did not scroll exactly one day past the viewport edge"

  let viewportReport : Loam.Tui.Reports.State := {
    compareReport with trendCompare := viewportState
  }
  let viewportPress :=
    (Loam.Tui.Reports.updateForBounds compareBounds viewportReport
      (.pointer Loam.Tui.LocusTrendComparePane.plotLeft
        (Loam.Tui.LocusTrendComparePane.plotTop viewportState + 1))).state
  expect (viewportPress.trendCompare.selected == 9)
    "Trend click did not select inside the visible Day viewport"

  let viewportDrag :=
    (Loam.Tui.Reports.updateForBounds compareBounds viewportReport
      (.pointerDrag Loam.Tui.LocusTrendComparePane.plotLeft
        (Loam.Tui.LocusTrendComparePane.plotTop viewportState + 1))).state
  expect (viewportDrag.trendCompare.selected == 9)
    "Trend drag did not scrub inside the visible Day viewport"

  let viewportMotion :=
    (Loam.Tui.Reports.updateForBounds compareBounds viewportReport
      (.pointerMotion Loam.Tui.LocusTrendComparePane.plotLeft
        (Loam.Tui.LocusTrendComparePane.plotTop viewportState + 1))).state
  expect (viewportMotion.trendCompare.selected == viewportState.selected)
    "Trend still followed passive pointer motion"

  let viewportWheelBack := (Loam.Tui.Reports.update viewportReport .up).state
  expect (viewportWheelBack.trendCompare.selected == 38)
    "Trend wheel-up did not move one Day period backward"
  let viewportWheelForward := (Loam.Tui.Reports.update viewportWheelBack .down).state
  expect (viewportWheelForward.trendCompare.selected == 39)
    "Trend wheel-down did not move one Day period forward"

  let viewportText := widgetText
    (Loam.Tui.Reports.viewForBounds compareBounds viewportReport)
  expect (contains "31-day viewport" viewportText &&
      contains "Range All history" viewportText &&
      contains "s/S range" viewportText &&
      contains "wheel select period" viewportText &&
      contains "mouse click/drag scrub" viewportText &&
      contains "Aug 10" viewportText && contains "As of Sep 9" viewportText)
    "Trend Day did not expose the visible 31-day window and mouse controls"
  expect (!(contains "¥8,000" viewportText))
    "Trend Day scale still included an outlier outside the visible viewport"
  expect (contains "o overlay" viewportText)
    "Trend Day did not expose the session-overlay entrance"

  let overlayStarted := (Loam.Tui.Reports.update viewportReport (.input 'o')).state
  let overlayStartText := widgetText
    (Loam.Tui.Reports.viewForBounds compareBounds overlayStarted)
  expect (Loam.Tui.LocusTrendComparePane.isOverlayEditing overlayStarted.trendCompare &&
      contains "Overlay   session only" overlayStartText &&
      contains "Sep 2026" overlayStartText)
    "Trend overlay did not open on the selected Day month as session-only presentation"

  let typeChars := fun (state : Loam.Tui.Reports.State) (text : String) =>
    text.toList.foldl
      (fun current char => (Loam.Tui.Reports.update current (.input char)).state)
      state
  let overlayNamed := typeChars overlayStarted "Mother off"
  let overlayDaysFocus := (Loam.Tui.Reports.update overlayNamed .enter).state
  let overlayDaysTyped := typeChars overlayDaysFocus "3 4 6 8 9"
  let overlayApplied := (Loam.Tui.Reports.update overlayDaysTyped .enter).state
  expect (!Loam.Tui.LocusTrendComparePane.isOverlayEditing overlayApplied.trendCompare &&
      overlayApplied.trendCompare.overlays.length == 1 &&
      !overlayApplied.trendCompare.overlayGuides)
    "Trend overlay did not apply the custom month/day observation with guides initially off"
  let overlayText := widgetText
    (Loam.Tui.Reports.viewForBounds compareBounds overlayApplied)
  expect (contains "A Mother off (Sep 2026: 3 4 6 8 9)" overlayText &&
      contains "guides off" overlayText &&
      contains "v guides on" overlayText &&
      !(contains "┊" overlayText) &&
      contains "O clear overlays" overlayText &&
      contains "not saved" overlayText)
    "Trend overlay did not start with its quiet marker-only presentation"

  let guidesOn := (Loam.Tui.Reports.update overlayApplied (.input 'v')).state
  let guidesOnText := widgetText
    (Loam.Tui.Reports.viewForBounds compareBounds guidesOn)
  expect (guidesOn.trendCompare.overlayGuides &&
      contains "guides on" guidesOnText &&
      contains "v guides off" guidesOnText &&
      contains "┊" guidesOnText)
    "Trend overlay one-key guide toggle did not add vertical guides after observation"

  let guidesOff := (Loam.Tui.Reports.update guidesOn (.input 'v')).state
  let guidesOffText := widgetText
    (Loam.Tui.Reports.viewForBounds compareBounds guidesOff)
  expect (!guidesOff.trendCompare.overlayGuides &&
      contains "guides off" guidesOffText &&
      !(contains "┊" guidesOffText))
    "Trend overlay one-key guide toggle did not remove vertical guides"

  let invalidStarted := (Loam.Tui.Reports.update guidesOff (.input 'o')).state
  let invalidNamed := typeChars invalidStarted "Friend house"
  let invalidDaysFocus := (Loam.Tui.Reports.update invalidNamed .enter).state
  let invalidDaysTyped := typeChars invalidDaysFocus "31"
  let invalidApplied := Loam.Tui.Reports.update invalidDaysTyped .enter
  expect (Loam.Tui.LocusTrendComparePane.isOverlayEditing invalidApplied.state.trendCompare &&
      contains "Day 31 is not in 2026-09" invalidApplied.state.notice)
    "Trend overlay accepted an impossible day for the selected month"
  let invalidCancelled := (Loam.Tui.Reports.update invalidApplied.state .escape).state
  let overlaysCleared := (Loam.Tui.Reports.update invalidCancelled (.input 'O')).state
  expect (overlaysCleared.trendCompare.overlays.isEmpty &&
      !(contains "Mother off"
        (widgetText (Loam.Tui.Reports.viewForBounds compareBounds overlaysCleared))))
    "Trend did not clear its session-only overlays"

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
    "Trend scoped Day view incorrectly retained the All-history 31-day viewport"
  let scopedViewportReport : Loam.Tui.Reports.State := {
    compareReport with trendCompare := scopedViewportState
  }
  let scopedViewportText := widgetText
    (Loam.Tui.Reports.viewForBounds compareBounds scopedViewportReport)
  expect (contains "Range Current cycle" scopedViewportText &&
      contains "s/S range" scopedViewportText &&
      !(contains "31-day viewport" scopedViewportText))
    "Trend did not expose the scoped Day range as a whole"

  let comparePointer :=
    (Loam.Tui.Reports.updateForBounds compareBounds compareLeft
      (.pointer Loam.Tui.LocusTrendComparePane.plotLeft
        (Loam.Tui.LocusTrendComparePane.plotTop compareLeft.trendCompare + 1))).state
  expect (comparePointer.trendCompare.selected == 0)
    "Trend pointer did not select the nearest shared cycle"

  let compareText := widgetText
    (Loam.Tui.Reports.viewForBounds compareBounds comparePointer)
  expect (contains "Trend   cycle average / day" compareText &&
      contains "Selected   Apr 15 → Jun 15" compareText &&
      contains "Tobacco" compareText && contains "¥464/day" compareText &&
      contains "Coffee" compareText && contains "¥131/day" compareText &&
      contains "Food" compareText && contains "¥477/day" compareText)
    "Trend did not show all selected-cycle series values together"
  expect (!(contains "Range " compareText) && !(contains "s/S range" compareText))
    "Trend Cycle exposed Day-only Range controls"
  expect (contains "Exact Locus series" compareText)
    "Trend lost its no-reclassification boundary"
  expect ((Loam.Tui.Reports.viewForBounds compareBounds comparePointer).lines.length <=
      compareBounds.height)
    "Trend exceeded the terminal height"

  let ignoredTrendRendererKey := Loam.Tui.Reports.update comparePointer (.input 'r')
  expect (ignoredTrendRendererKey.query.isNone &&
      ignoredTrendRendererKey.state.trendCompare.selected ==
        comparePointer.trendCompare.selected)
    "retired Trend renderer key still changed the Trend interaction state"
  expect (isMenu (Loam.Tui.Reports.update comparePointer .escape).state)
    "Trend escape did not return to Reports menu"

  let retiredTrendKey := Loam.Tui.Reports.update initial (.input 'g')
  expect (isMenu retiredTrendKey.state && retiredTrendKey.query.isNone)
    "retired Locus Trend direct key still opened a second Trend surface"

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
  expect (contains "Balance Sheet support: INCOMPLETE" balancesText)
    "Balances surface hid missing stock-role support"
  expect (contains "Known Net Worth subtotal: 12000 jpy" balancesText)
    "Balances surface lost the supported Asset subtotal"
  expect (contains "Qualified Net Worth: UNKNOWN" balancesText)
    "Balances surface promoted an incomplete Net Worth to knowledge"
  expect (contains "liability-unsupported" balancesText && contains "balance unsupported" balancesText)
    "Balances surface hid the unsupported liability witness"
  testReportsBalancesPrint balancesReport
  expectRefusal (Loam.Tui.Reports.prepareBalancesPrint balancesStep.state)
    "Reports/Balances printed without a current RoleBalance answer"

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
    daily := {
      start := "2026-09-01"
      endExclusive := "2026-10-01"
      dates := ["2026-09-01", "2026-09-02", "2026-09-03"]
      rows :=
        [ { coordinate := pensionCoordinate
          , role := .income
          , cells :=
              [ { date := "2026-09-01", quantity := Quantity.ofQuanta (-240000) }
              , { date := "2026-09-02", quantity := Quantity.ofQuanta 0 }
              , { date := "2026-09-03", quantity := Quantity.ofQuanta 0 }
              ] }
        , { coordinate := foodCoordinate
          , role := .expense
          , cells :=
              [ { date := "2026-09-01", quantity := Quantity.ofQuanta 20000 }
              , { date := "2026-09-02", quantity := Quantity.ofQuanta 30000 }
              , { date := "2026-09-03", quantity := Quantity.ofQuanta 0 }
              ] }
        , { coordinate := consultingCoordinate
          , role := .income
          , cells :=
              [ { date := "2026-09-01", quantity := Quantity.ofQuanta 0 }
              , { date := "2026-09-02", quantity := Quantity.ofQuanta 0 }
              , { date := "2026-09-03", quantity := Quantity.ofQuanta (-20) }
              ] }
        ]
      unresolvedEffects := []
    }
    monthly := {
      start := "2026-09-01"
      endExclusive := "2026-10-01"
      months := ["2026-09"]
      rows :=
        [ { coordinate := pensionCoordinate
          , role := .income
          , cells :=
              [ { month := "2026-09", quantity := Quantity.ofQuanta (-240000) } ] }
        , { coordinate := foodCoordinate
          , role := .expense
          , cells :=
              [ { month := "2026-09", quantity := Quantity.ofQuanta 50000 } ] }
        , { coordinate := consultingCoordinate
          , role := .income
          , cells :=
              [ { month := "2026-09", quantity := Quantity.ofQuanta (-20) } ] }
        ]
      unresolvedEffects := []
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

  let monthlyIncomeExpense : Loam.Tui.Reports.State := {
    (Loam.Tui.Reports.update incomeExpenseReport (.input 'g')).state with
      multimeasurePresentation :=
        [ { measure := ⟨"usd"⟩, scale := 2 } ]
  }
  expect (monthlyIncomeExpense.incomeExpenseDisplay == .monthly)
    "Income & Expense g did not switch to Monthly Accounts"
  let monthlyIncomeExpenseText :=
    widgetText (Loam.Tui.Reports.view monthlyIncomeExpense)
  expect (contains "View: Monthly" monthlyIncomeExpenseText &&
      contains "Monthly Accounts" monthlyIncomeExpenseText &&
      contains "2026-09" monthlyIncomeExpenseText)
    "Monthly Accounts view did not expose its month axis"
  expect (contains "pension" monthlyIncomeExpenseText &&
      contains "food" monthlyIncomeExpenseText &&
      contains "Total Income" monthlyIncomeExpenseText &&
      contains "Total Expense" monthlyIncomeExpenseText &&
      contains "Net" monthlyIncomeExpenseText &&
      contains "240,000" monthlyIncomeExpenseText &&
      contains "50,000" monthlyIncomeExpenseText &&
      contains "190,000" monthlyIncomeExpenseText)
    "Monthly Accounts view lost grouped account rows or Income/Expense/Net totals"
  expect (contains "consulting" monthlyIncomeExpenseText &&
      contains "0.20" monthlyIncomeExpenseText)
    "Monthly Accounts view bypassed Measure decimal presentation"
  expect (!(contains "block 1/1" monthlyIncomeExpenseText) &&
      !(contains "Period total" monthlyIncomeExpenseText))
    "single-month Monthly Accounts retained redundant block or period-total chrome"
  expect (contains "not a forecast" monthlyIncomeExpenseText)
    "Monthly Accounts view lost the explicit future-zero boundary"

  let multiMonthIncomeExpense ←
    match monthlyIncomeExpense.incomeExpenseSnapshot with
    | none => throw (IO.userError "Monthly Accounts fixture lost its loaded snapshot")
    | some snapshot =>
        let monthly : Loam.MonthlyRoleFlowReview.Snapshot := {
          snapshot.monthly with
            start := "2026-05-01"
            endExclusive := "2026-10-01"
            months := ["2026-05", "2026-06", "2026-07", "2026-08", "2026-09"]
            rows :=
              [ { coordinate := pensionCoordinate
                , role := .income
                , cells :=
                    [ { month := "2026-05", quantity := Quantity.ofQuanta (-100000) }
                    , { month := "2026-06", quantity := Quantity.ofQuanta 0 }
                    , { month := "2026-07", quantity := Quantity.ofQuanta (-100000) }
                    , { month := "2026-08", quantity := Quantity.ofQuanta 0 }
                    , { month := "2026-09", quantity := Quantity.ofQuanta (-240000) }
                    ] }
              , { coordinate := foodCoordinate
                , role := .expense
                , cells :=
                    [ { month := "2026-05", quantity := Quantity.ofQuanta 10000 }
                    , { month := "2026-06", quantity := Quantity.ofQuanta 11000 }
                    , { month := "2026-07", quantity := Quantity.ofQuanta 12000 }
                    , { month := "2026-08", quantity := Quantity.ofQuanta 13000 }
                    , { month := "2026-09", quantity := Quantity.ofQuanta 14000 }
                    ] }
              ]
        }
        pure {
          monthlyIncomeExpense with
            incomeExpenseSnapshot := some { snapshot with monthly := monthly }
        }
  let wideMonthlyText :=
    widgetText
      (Loam.Tui.Reports.viewForBounds
        { width := 120, height := 200 } multiMonthIncomeExpense)
  expect
    (contains "2026-05" wideMonthlyText &&
      contains "2026-06" wideMonthlyText &&
      contains "2026-07" wideMonthlyText &&
      contains "2026-08" wideMonthlyText &&
      contains "2026-09" wideMonthlyText &&
      !(contains "block 1/" wideMonthlyText))
    "120-column Monthly Accounts did not keep five months in one table"
  expect
    (contains "Window total" wideMonthlyText && !(contains "Period total" wideMonthlyText))
    "multi-month Monthly Accounts did not name the whole-window total precisely"

  let narrowMonthlyText :=
    widgetText
      (Loam.Tui.Reports.viewForBounds
        { width := 80, height := 200 } multiMonthIncomeExpense)
  expect
    (contains "block 1/3" narrowMonthlyText &&
      contains "block 2/3" narrowMonthlyText &&
      contains "block 3/3" narrowMonthlyText)
    "80-column Monthly Accounts did not split five months into width-safe blocks"
  expect (contains "Window total" narrowMonthlyText)
    "split Monthly Accounts lost the whole-window total label"
  let dailyIncomeExpense :=
    (Loam.Tui.Reports.update monthlyIncomeExpense (.input 'g')).state
  expect (dailyIncomeExpense.incomeExpenseDisplay == .daily)
    "Income & Expense g did not switch from Monthly Accounts to Daily Flow"
  let dailyIncomeExpenseText :=
    widgetText (Loam.Tui.Reports.view dailyIncomeExpense)
  expect
    (contains "View: Daily" dailyIncomeExpenseText &&
      contains "Daily Flow" dailyIncomeExpenseText &&
      contains "09-01" dailyIncomeExpenseText &&
      contains "09-02" dailyIncomeExpenseText &&
      contains "09-03" dailyIncomeExpenseText)
    "Daily Flow view did not expose its sparse activity-date axis"
  expect
    (contains "Income" dailyIncomeExpenseText &&
      contains "food" dailyIncomeExpenseText &&
      contains "Net" dailyIncomeExpenseText &&
      contains "240,000" dailyIncomeExpenseText &&
      contains "50,000" dailyIncomeExpenseText &&
      contains "190,000" dailyIncomeExpenseText)
    "Daily Flow view lost aggregate Income, Expense detail, or Net totals"
  expect (!(contains "pension" dailyIncomeExpenseText))
    "Daily Flow expanded Income accounts instead of retaining the aggregate Income row"
  expect
    (contains "0.20" dailyIncomeExpenseText &&
      contains "Window total" dailyIncomeExpenseText)
    "Daily Flow bypassed Measure presentation or whole-window totals"
  expect (contains "omitted dates are not asserted zero" dailyIncomeExpenseText)
    "Daily Flow turned sparse date omission into a zero claim"

  let dailyBounds : Bounds := { width := 100, height := 16 }
  let fullDailyLines := widgetLineTexts (Loam.Tui.Reports.view dailyIncomeExpense)
  let dailyBodySize := fullDailyLines.length - 4
  let fullDailyBody := fullDailyLines.take dailyBodySize
  let fullDailyFooter := fullDailyLines.drop dailyBodySize
  let dailyPage := dailyBounds.height - (fullDailyFooter.length + 1)
  expect
    (Loam.Tui.Reports.scrollLimit dailyBounds dailyIncomeExpense ==
      dailyBodySize - dailyPage)
    "virtual Daily body extent diverged from the full compatibility view"
  let topDailyLines :=
    widgetLineTexts (Loam.Tui.Reports.viewForBounds dailyBounds dailyIncomeExpense)
  expect
    (topDailyLines.take dailyPage == fullDailyBody.take dailyPage &&
      topDailyLines.drop (dailyPage + 1) == fullDailyFooter)
    "virtual Daily top viewport diverged from the full report rows"
  let scrolledDaily := { dailyIncomeExpense with scroll := 7 }
  let scrolledDailyLines :=
    widgetLineTexts (Loam.Tui.Reports.viewForBounds dailyBounds scrolledDaily)
  expect
    (scrolledDailyLines.take dailyPage == (fullDailyBody.drop 7).take dailyPage)
    "virtual Daily scrolled viewport diverged from the full report rows"

  let preparedDaily ←
    match Loam.Tui.Reports.prepareScrollView? dailyBounds dailyIncomeExpense with
    | some prepared => pure prepared
    | none => throw (IO.userError "Daily Flow did not prepare its scroll cache")
  expect
    (widgetLineTexts
        (Loam.Tui.Reports.viewPreparedScroll dailyBounds dailyIncomeExpense preparedDaily) ==
      topDailyLines)
    "prepared Daily top view diverged from the ordinary bounded view"
  expect
    (widgetLineTexts
        (Loam.Tui.Reports.viewPreparedScroll dailyBounds scrolledDaily preparedDaily) ==
      scrolledDailyLines)
    "prepared Daily scrolled view diverged from the ordinary bounded view"
  let preparedDown :=
    Loam.Tui.Reports.scrollPrepared dailyIncomeExpense preparedDaily true
  let preparedUp :=
    Loam.Tui.Reports.scrollPrepared preparedDown preparedDaily false
  expect (preparedDown.scroll == 1 && preparedUp.scroll == 0)
    "prepared Daily scroll did not preserve one-line navigation semantics"
  let batchedDaily := Loam.Tui.Reports.scrollPrepared dailyIncomeExpense preparedDaily true 7
  expect (batchedDaily.scroll == scrolledDaily.scroll)
    "coalesced Daily wheel did not preserve the number of navigation steps"
  let resizedDaily := Loam.Tui.Reports.prepareScrollView?
    { width := 48, height := 10 } scrolledDaily
  expect (resizedDaily.any fun prepared => prepared.page == 10 - (prepared.footer.length + 1))
    "Daily cache did not rebuild its page geometry after resize"

  let summaryAgain :=
    (Loam.Tui.Reports.update dailyIncomeExpense (.input 'g')).state
  expect (summaryAgain.incomeExpenseDisplay == .summary)
    "Income & Expense g did not return from Daily Flow to Summary"

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
  let usdBudgetReport := Loam.Tui.Reports.withBudgetSnapshot budget {
    measure := ⟨"usd"⟩
    start := "2026-08-17"
    endExclusive := "2026-10-15"
    rows := [food]
  }
  let usdBudgetText := widgetText (Loam.Tui.Reports.view usdBudgetReport)
  expect (contains "70 usd" usdBudgetText && !(contains "70 jpy" usdBudgetText))
    "Budget Window rendering rewrote the snapshot Measure as JPY"

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
