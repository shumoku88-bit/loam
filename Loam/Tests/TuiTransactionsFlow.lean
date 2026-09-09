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
    isCurrent := true
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
  let menuText := widgetText (Loam.Tui.Reports.view initial)
  expect (contains "Transactions Flow" menuText)
    "Reports menu did not expose Transactions Flow"

  let direct := (Loam.Tui.Reports.update initial (.input 't')).state
  expect (isTransactionsFlow direct)
    "Transactions Flow direct key did not enter the report"
  expect (direct.form.start == "2026-09-01" && direct.form.endExclusive == "2026-10-01")
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
  expect (contains "cash/jpy" summaryText)
    "Transactions Flow summary lost the cash coordinate"
  expect (contains "net 0" summaryText)
    "Transactions Flow summary erased zero-net circulation"
  expect (contains "gross 60000" summaryText)
    "Transactions Flow summary lost gross activity"
  expect (contains "2 events" summaryText)
    "Transactions Flow summary lost active Event count"
  expect (!contains "0-cell matrix" summaryText)
    "Transactions Flow rendered the rejected dense matrix language"

  let second := (Loam.Tui.Reports.update report .down).state
  let secondText := widgetText (Loam.Tui.Reports.view second)
  expect (contains "> smbc/jpy" secondText)
    "Transactions Flow Down did not move the coordinate selection"

  let detailState := (Loam.Tui.Reports.update report .enter).state
  expect detailState.transactionsDetail
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

  let summaryAgain := (Loam.Tui.Reports.update detailState .escape).state
  expect (!summaryAgain.transactionsDetail && isTransactionsFlow summaryAgain)
    "Transactions Flow detail Escape did not return to summary"
  let menuAgain := (Loam.Tui.Reports.update summaryAgain .escape).state
  expect (match menuAgain.mode with | .menu => true | _ => false)
    "Transactions Flow summary Escape did not return to Reports menu"

  let editStart := (Loam.Tui.Reports.update report .tab).state
  expect (editStart.form.focus.val == 0)
    "Transactions Flow did not reuse the shared window focus cycle"
  let edited := (Loam.Tui.Reports.update editStart (.input '9')).state
  expect edited.transactionsSnapshot.isNone
    "editing Transactions Flow coordinates left a stale snapshot visible"
  expect (Loam.Tui.Reports.windowSourceLabel edited == "Custom")
    "editing Transactions Flow coordinates did not become Custom window state"

  IO.println "Transactions Flow TUI: shared window, sparse zero-net summary, focused contributors, and stale-result clearing passed."
