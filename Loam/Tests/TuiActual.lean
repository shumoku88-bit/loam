import Loam.Tui.Main

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

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

  IO.println "TUI Actual: full-day navigation and derived ten-row window passed."
