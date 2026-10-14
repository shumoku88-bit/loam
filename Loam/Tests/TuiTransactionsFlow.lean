import Loam.Tui.Layout
import Loam.Tui.Reports

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def isTransactionsFlow (state : Loam.Tui.Reports.State) : Bool :=
  match state.mode with
  | .transactionsFlow => true
  | _ => false

private def jpy : MeasureId := ⟨"jpy"⟩

private def effect (key locus : String) (quantity : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ ⟨locus⟩ jpy (Quantity.ofQuanta quantity)

private def event? (id : String) (effects : List Effect) : Option Event :=
  Event.ofEffects? ⟨id⟩ effects

private def record
    (event : Event) (date description : String) : Loam.ActualReview.Record :=
  {
    event := event
    date := some date
    description := description
    replacement := none
  }

private def snapshot? : Option Loam.TransactionsFlowReview.Snapshot := do
  let lesson ← event? "lesson"
    [ effect "lesson-cash" "cash" 30000
    , effect "lesson-source" "lesson-income" (-30000)
    ]
  let deposit ← event? "deposit"
    [ effect "deposit-cash" "cash" (-30000)
    , effect "deposit-smbc" "smbc" 30000
    ]
  let book ← event? "book"
    [ effect "book-smbc" "smbc" (-1915)
    , effect "book-book" "book" 1915
    ]
  match Loam.TransactionsFlowReview.project
      [ record book "2026-09-05" "book purchase"
      , record deposit "2026-09-06" "cash -> smbc"
      , record lesson "2026-09-01" "lesson income"
      ]
      "2026-09-01" "2026-09-10" with
  | .error _ => none
  | .ok snapshot => some snapshot


def main : IO Unit := do
  let initial := Loam.Tui.Reports.initialForDate "2026-09-07"
  let direct := (Loam.Tui.Reports.openReport .transactionsFlow initial).state
  expect (isTransactionsFlow direct)
    "typed Transactions Flow entrance did not enter the report"
  expect (direct.window.form.start == "2026-09-01" && direct.window.form.endExclusive == "2026-10-01")
    "Transactions Flow did not reuse the shared explicit report window"

  match (Loam.Tui.Reports.update direct .enter).query with
  | some (.transactionsFlow start endExclusive) =>
      expect (start == "2026-09-01") "Transactions Flow query changed the shared start"
      expect (endExclusive == "2026-10-01") "Transactions Flow query changed the shared end"
  | _ => throw (IO.userError "Transactions Flow Run did not emit an explicit window query")

  let some snapshot := snapshot?
    | throw (IO.userError "Transactions Flow fixture was rejected")
  let report := Loam.Tui.Reports.withTransactionsFlowSnapshot direct snapshot
  let summaryText := widgetText (Loam.Tui.Reports.view report)
  expect (contains "Reports / Transactions Flow" summaryText)
    "Transactions Flow heading was not rendered"
  expect (contains "Coordinate" summaryText && contains "Net" summaryText && contains "Gross" summaryText)
    "Transactions Flow table header was not rendered"
  expect (contains "+In" summaryText && contains "-Out" summaryText && contains "Events" summaryText)
    "Transactions Flow table columns were not rendered"
  expect (contains "cash/jpy" summaryText)
    "Transactions Flow summary lost the cash coordinate"
  expect (contains "60000" summaryText)
    "Transactions Flow summary lost gross activity"
  expect (contains "+30000" summaryText)
    "Transactions Flow summary lost positive cash witness"
  expect (contains "-30000" summaryText)
    "Transactions Flow summary lost negative cash witness"
  expect (!contains "0-cell matrix" summaryText)
    "Transactions Flow rendered the rejected dense matrix language"

  -- UI-25 compact query form: date focus and the selected result row are
  -- separate presentation priorities, not new query or selection authority.
  for bounds in ([{ width := 32, height := 9 }, { width := 48, height := 14 }] : List Bounds) do
    let opening := widgetText (Loam.Tui.Reports.viewForBounds bounds direct)
    expect (contains "Reports / Transactions Flow" opening &&
        contains "Window: Calendar Month" opening &&
        contains "> [Run]" opening)
      "Transactions Flow compact entry lost its source or Run focus"
    let startFocused := (Loam.Tui.Reports.updateForBounds bounds direct .tab).state
    expect (startFocused.window.form.focus.val == 0 &&
        contains "Start:" (widgetText (Loam.Tui.Reports.viewForBounds bounds startFocused)))
      "Transactions Flow compact entry lost its focused Start date"
    let longDate := "2026-01-01" ++ String.ofList (List.replicate 80 '8')
    let longState := { startFocused with
      window := { startFocused.window with
        form := { startFocused.window.form with start := longDate } } }
    expect (contains "…8888" (widgetText (Loam.Tui.Reports.viewForBounds bounds longState)))
      "Transactions Flow compact input lost the edited date tail"
    let endFocused := (Loam.Tui.Reports.updateForBounds bounds startFocused .tab).state
    expect (endFocused.window.form.focus.val == 1 &&
        contains "End (exclusive):"
          (widgetText (Loam.Tui.Reports.viewForBounds bounds endFocused)))
      "Transactions Flow compact entry lost its focused End date"
    let runFocused := (Loam.Tui.Reports.updateForBounds bounds endFocused .tab).state
    expect (runFocused.window.form.focus.val == 2 &&
        contains "> [Run]" (widgetText (Loam.Tui.Reports.viewForBounds bounds runFocused)))
      "Transactions Flow compact Run disappeared after Tab cycle"
    match (Loam.Tui.Reports.updateForBounds bounds runFocused .enter).query with
    | some (.transactionsFlow startDate endExclusive) =>
        expect (startDate == "2026-09-01" && endExclusive == "2026-10-01")
          "Transactions Flow compact Run changed window semantics"
    | _ => throw (IO.userError "Transactions Flow compact Run did not emit its query")

    let firstSummary := widgetText (Loam.Tui.Reports.viewForBounds bounds report)
    expect (contains "> cash/jpy" firstSummary)
      "Transactions Flow compact table did not follow its selected first coordinate"
    let next := (Loam.Tui.Reports.updateForBounds bounds report .down).state
    let nextSummary := widgetText (Loam.Tui.Reports.viewForBounds bounds next)
    expect (contains "> smbc/jpy" nextSummary)
      "Transactions Flow compact table did not follow the second coordinate"
    let detail := (Loam.Tui.Reports.updateForBounds bounds next .enter).state
    let detailVisible := widgetText (Loam.Tui.Reports.viewForBounds bounds detail)
    expect (detail.transactions.detail &&
        contains "Focused coordinate: smbc/jpy" detailVisible &&
        contains "Net " detailVisible && contains "q / Esc summary" detailVisible)
      "Transactions Flow compact detail lost coordinate, quantities or correct exit key"
    let restored := (Loam.Tui.Reports.updateForBounds bounds detail .escape).state
    expect (!restored.transactions.detail &&
        restored.transactions.selectedIndex == next.transactions.selectedIndex &&
        contains "> smbc/jpy"
          (widgetText (Loam.Tui.Reports.viewForBounds bounds restored)))
      "Transactions Flow compact detail did not restore the selected summary row"
    let dateEditor := (Loam.Tui.Reports.updateForBounds bounds restored .tab).state
    expect (dateEditor.window.form.focus.val == 0 &&
        contains "Start:" (widgetText (Loam.Tui.Reports.viewForBounds bounds dateEditor)))
      "Transactions Flow compact row-following obscured active date editing"
  let narrowBounds : Bounds := ⟨54, 24⟩
  let narrowSummaryWidget := Loam.Tui.Reports.viewForBounds narrowBounds report
  let narrowSummaryLines := narrowSummaryWidget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)
  for l in narrowSummaryLines do
    let width := Loam.Tui.Layout.displayWidth l
    expect (width ≤ 53)
      s!"Transactions Flow narrow summary row exceeded 53 columns: {l} ({width} cols)"
  let narrowSummaryText := String.intercalate "\n" narrowSummaryLines
  expect (contains "cash/jpy" narrowSummaryText)
    "Transactions Flow narrow view lost cash coordinate"
  expect (contains "60000" narrowSummaryText)
    "Transactions Flow narrow view lost gross activity"

  let second := (Loam.Tui.Reports.update report .down).state
  let secondText := widgetText (Loam.Tui.Reports.view second)
  expect (contains "> smbc/jpy" secondText)
    "Transactions Flow Down did not move the coordinate selection"

  let detailState := (Loam.Tui.Reports.update report .enter).state
  expect detailState.transactions.detail
    "Transactions Flow Enter did not open focused contributors"
  let detailText := widgetText (Loam.Tui.Reports.view detailState)
  expect (contains "Focused coordinate: cash/jpy" detailText)
    "Transactions Flow detail lost the selected coordinate"
  expect (contains "+30000 jpy" detailText)
    "Transactions Flow detail lost the positive cash witness"
  expect (contains "-30000 jpy" detailText)
    "Transactions Flow detail lost the negative cash witness"
  expect (contains "lesson income" detailText)
    "Transactions Flow detail lost the first contributing Event"
  expect (contains "cash -> smbc" detailText)
    "Transactions Flow detail lost the second contributing Event"
  expect (!contains "book purchase" detailText)
    "Transactions Flow detail leaked an unrelated zero-cell Event"

  let narrowDetailWidget := Loam.Tui.Reports.viewForBounds narrowBounds detailState
  let narrowDetailLines := narrowDetailWidget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)
  for l in narrowDetailLines do
    let width := Loam.Tui.Layout.displayWidth l
    expect (width ≤ 53)
      s!"Transactions Flow narrow detail row exceeded 53 columns: {l} ({width} cols)"

  let summaryAgain := (Loam.Tui.Reports.update detailState .escape).state
  expect (!summaryAgain.transactions.detail && isTransactionsFlow summaryAgain)
    "Transactions Flow detail Escape did not return to summary"
  expect (Loam.Tui.Reports.update summaryAgain .escape).back
    "Transactions Flow summary Escape did not return Home"

  let editStart := (Loam.Tui.Reports.update report .tab).state
  expect (editStart.window.form.focus.val == 0)
    "Transactions Flow did not reuse the shared window focus cycle"
  let edited := (Loam.Tui.Reports.update editStart (.input '9')).state
  expect edited.transactions.snapshot.isNone
    "editing Transactions Flow coordinates left a stale snapshot visible"
  expect (Loam.Tui.Reports.windowSourceLabel edited == "Custom")
    "editing Transactions Flow coordinates did not become Custom window state"

  IO.println "Transactions Flow TUI: shared window, sparse zero-net summary, focused contributors, and stale-result clearing passed."
