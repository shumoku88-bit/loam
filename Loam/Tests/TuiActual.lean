import Loam.Tui.Main
import Loam.Tui.HraActual

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def testRecord (index : Nat) : Loam.Tui.Main.ReviewRecord :=
  { event :=
      { id := ⟨"event-" ++ toString index⟩
        effects := []
        keyNodup := by simp }
    date := some "2026-09-07"
    description := "row-" ++ toString index
    replacement := none
    isCurrent := true }

private def actualRecord?
    (id date description fromLocus toLocus : String) (quanta : Int) : Option Loam.Tui.Main.ReviewRecord := do
  let event ← Event.ofEffects? ⟨id⟩
    [ Effect.ofQuantity ⟨id ++ "-from"⟩ ⟨fromLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-quanta))
    , Effect.ofQuantity ⟨id ++ "-to"⟩ ⟨toLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quanta)
    ]
  pure { event, date := some date, description, replacement := none, isCurrent := true }

private def emptyScheduledSnapshot : IO Loam.ScheduledReview.EvidenceSnapshot := do
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? []) "empty Scheduled memory was not admitted"
  let completions ← requireSome (ScheduledCompletionMemory.ofCompletions? []) "empty completion memory was not admitted"
  let retirements ← requireSome (ScheduledRetirementMemory.ofRetirements? []) "empty retirement memory was not admitted"
  let replacements ← requireSome (ScheduledReplacementMemory.ofReplacements? []) "empty replacement memory was not admitted"
  let events ← requireSome (EventMemory.ofEvents? []) "empty Event memory was not admitted"
  pure { scheduled, completions, retirements, replacements, events }

private def hraSnapshot : IO Loam.Tui.Main.Snapshot := do
  let first ← requireSome (actualRecord? "event-0" "2026-09-07" "alpha" "paypay" "food" 100)
    "first HRA Actual fixture was not admitted"
  let second ← requireSome (actualRecord? "event-1" "2026-09-07" "beta" "smbc" "paypay" 200)
    "second HRA Actual fixture was not admitted"
  let previous ← requireSome (actualRecord? "event-2" "2026-09-06" "gamma" "paypay" "books" 300)
    "previous-day HRA Actual fixture was not admitted"
  let scheduled ← emptyScheduledSnapshot
  let actual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-07"
    allRecords := [previous, second, first]
    undatedCount := 0
  }
  pure { actual, scheduled }

private def initialCursor : Loam.Tui.Main.ReviewCursor :=
  let displayed := ((List.range 12).map testRecord).toArray
  let selected : Option (Fin displayed.size) :=
    if h : 0 < displayed.size then some ⟨0, h⟩ else none
  { date := "2026-09-07"
    totalCount := displayed.size
    displayed := displayed
    selected := selected }

private def moveNextN : Nat → Loam.Tui.Main.ReviewCursor → Loam.Tui.Main.ReviewCursor
  | 0, cursor => cursor
  | count + 1, cursor =>
      let (next, _) := Loam.Tui.Main.moveReviewNext cursor
      moveNextN count next

def main : IO Unit := do
  let snapshot ← hraSnapshot
  let hraStart := Loam.Tui.HraActual.initial "2026-09-07"
  expect ((Loam.Tui.HraActual.visibleRecords snapshot hraStart).length == 2)
    "HRA Actual Focus Day did not use the shared selected-day Actual answer"
  let right := (Loam.Tui.HraActual.update snapshot hraStart .focusRight).state
  let second := (Loam.Tui.HraActual.update snapshot right .next).state
  match Loam.Tui.HraActual.selectedRecord? snapshot second with
  | none => throw (IO.userError "HRA Actual transaction selection disappeared")
  | some record =>
      expect (record.description == "beta")
        "HRA Actual j/down-style selection did not move to the second transaction"
  let hraText := widgetText (Loam.Tui.HraActual.view { width := 100, height := 30 } snapshot second)
  expect (contains "Household Actuals Workspace" hraText)
    "HRA Actual shell heading disappeared"
  expect (contains "Selected Actual Details:" hraText && contains "beta" hraText)
    "HRA Actual did not keep selected transaction details visible without a detail transition"
  let allCurrent := (Loam.Tui.HraActual.update snapshot second .cycleFilter).state
  expect ((Loam.Tui.HraActual.visibleRecords snapshot allCurrent).length == 3)
    "HRA Actual filter did not expand from Focus Day to all current Actual evidence"
  expect (allCurrent.order == .asc)
    "HRA Actual initial order was not ascending"

  -- Focus left pane (loci) and select locus 1 (paypay)
  let allCurrentLoci := (Loam.Tui.HraActual.update snapshot allCurrent .focusLeft).state
  let paypayLocus := (Loam.Tui.HraActual.update snapshot allCurrentLoci .next).state
  expect (Loam.Tui.HraActual.selectedLocus? snapshot paypayLocus == some "paypay")
    "HRA Actual next did not select the paypay locus"
  let paypayAsc := Loam.Tui.HraActual.visibleRecords snapshot paypayLocus
  expect (paypayAsc.map (·.description) == ["gamma", "beta", "alpha"])
    "HRA Actual paypay records in ascending order did not list oldest first"
  match Loam.Tui.HraActual.selectedRecord? snapshot paypayLocus with
  | none => throw (IO.userError "HRA Actual paypay record selection disappeared")
  | some record =>
      expect (record.description == "gamma")
        "HRA Actual ascending paypay record was not oldest first (gamma)"

  -- Toggle order to descending (newest first)
  let paypayDesc := (Loam.Tui.HraActual.update snapshot paypayLocus .cycleOrder).state
  expect (paypayDesc.order == .desc)
    "HRA Actual cycleOrder did not change order to descending"
  let paypayDescRecords := Loam.Tui.HraActual.visibleRecords snapshot paypayDesc
  expect (paypayDescRecords.map (·.description) == ["alpha", "beta", "gamma"])
    "HRA Actual paypay records in descending order did not list newest first"
  match Loam.Tui.HraActual.selectedRecord? snapshot paypayDesc with
  | none => throw (IO.userError "HRA Actual descending paypay record selection disappeared")
  | some record =>
      expect (record.description == "alpha")
        "HRA Actual descending paypay record at row 0 was not newest (alpha)"

  -- Move down in descending order
  let paypayDescRight := (Loam.Tui.HraActual.update snapshot paypayDesc .focusRight).state
  let paypayDescSecond := (Loam.Tui.HraActual.update snapshot paypayDescRight .next).state
  match Loam.Tui.HraActual.selectedRecord? snapshot paypayDescSecond with
  | none => throw (IO.userError "HRA Actual descending second record disappeared")
  | some record =>
      expect (record.description == "beta")
        "HRA Actual descending second record was not beta"

  -- Toggle back to ascending
  let paypayAscAgain := (Loam.Tui.HraActual.update snapshot paypayDescSecond .cycleOrder).state
  expect (paypayAscAgain.order == .asc)
    "HRA Actual cycleOrder did not toggle back to ascending"
  match Loam.Tui.HraActual.selectedRecord? snapshot paypayAscAgain with
  | none => throw (IO.userError "HRA Actual toggled-back record disappeared")
  | some record =>
      expect (record.description == "gamma")
        "HRA Actual toggled-back record at row 0 was not oldest (gamma)"

  -- View check
  let descViewText := widgetText (Loam.Tui.HraActual.view { width := 100, height := 30 } snapshot paypayDesc)
  expect (contains "desc" descViewText && contains "newest first" descViewText)
    "HRA Actual view did not display descending order indication"
  expect (contains "[o] order" descViewText)
    "HRA Actual view footer did not expose [o] order"

  let recent := Loam.Tui.Main.recentActualPreview ((List.range 5).map testRecord)
  expect (recent.map (·.description) == ["row-4", "row-3", "row-2"])
    "Home Actual preview did not show the three most recent selected-day records first"

  let start := initialCursor
  expect (start.displayed.size == 12)
    "Actual cursor still truncated a 12-record day"

  let shifted := moveNextN 10 start
  match shifted.selected with
  | none => throw (IO.userError "Actual selection disappeared after navigating past row 10")
  | some selected =>
      expect (selected.val == 10)
        "Actual selection could not reach the eleventh record"

  expect (Loam.Tui.Main.reviewWindowStart shifted == 1)
    "Actual browse window did not follow the eleventh selected record"
  let rows := Loam.Tui.Main.visibleReviewRows shifted
  expect (rows.length == 10)
    "Actual browse rendered more or fewer than ten local rows"
  match rows with
  | [] => throw (IO.userError "Actual browse window unexpectedly became empty")
  | (firstIndex, _) :: _ =>
      expect (firstIndex == 1)
        "Actual browse window did not advance by one row"

  match Loam.Tui.Main.selectedRecord? shifted with
  | none => throw (IO.userError "Actual selected record disappeared after window shift")
  | some record =>
      expect (record.description == "row-10")
        "Actual detail selection no longer follows the global browse selection"

  let state : Loam.Tui.Main.State :=
    { selectedDate := "2026-09-07"
      surface := .actual shifted .browse }
  let text := widgetText (Loam.Tui.Main.actualBrowseView shifted state)
  expect (contains "row-10" text)
    "Actual browse window did not render the selected eleventh record"
  expect (!contains "row-0" text)
    "Actual browse window failed to drop the row above its ten-line window"
  expect (contains "12 current record(s)" text)
    "Actual browse lost the full day record count"

  let last := moveNextN 11 start
  let (blocked, notice) := Loam.Tui.Main.moveReviewNext last
  expect (notice == "No next row in this day view.")
    "Actual end-of-list refusal changed"
  match blocked.selected, last.selected with
  | some blockedIndex, some lastIndex =>
      expect (blockedIndex.val == lastIndex.val)
        "Actual end-of-list refusal moved the selection"
  | _, _ => throw (IO.userError "Actual end-of-list selection became unavailable")

  IO.println "TUI Actual: HRA workspace mechanics and retained legacy navigation checks passed."