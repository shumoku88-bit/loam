import Loam.Tui.HraHome
import Loam.Tui.Terminal

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

/-- Inspect structured glyph/style cells rather than terminal escape output. -/
private def hasStyledText (widget : Widget) (text : String) (style : Style) : Bool :=
  widget.lines.any fun cells =>
    (List.range (cells.length + 1)).any fun start =>
      let segment := (cells.drop start).take text.length
      String.ofList (segment.map Cell.glyph) == text &&
        segment.all (fun cell => cell.style == style)

private def yen : MeasureId := ⟨"jpy"⟩
private def paypay : LocusId := ⟨"paypay"⟩
private def groceries : LocusId := ⟨"groceries"⟩

private def change (locus : LocusId) (quanta : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := Quantity.ofQuanta quanta }

private def scheduled? (index : Nat) : Option (ScheduledOccurrence String) := do
  let movement ← BalancedMovement.ofChanges? yen
    [change paypay (-100), change groceries 100]
  pure {
    id := ⟨"scheduled-" ++ toString index⟩
    scheduledOn := "2026-09-07"
    movement := movement
  }

private def moveNextN : Nat → Loam.Tui.Main.ScheduledCursor → Loam.Tui.Main.ScheduledCursor
  | 0, cursor => cursor
  | count + 1, cursor =>
      let (next, _) := Loam.Tui.Main.moveScheduledNext cursor
      moveNextN count next

private def fixtureSnapshot : IO Loam.Tui.Main.Snapshot := do
  let records ← requireSome ((List.range 12).mapM scheduled?)
    "Scheduled fixtures were not admitted"
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? records)
    "Scheduled memory fixture was not admitted"
  let completions ← requireSome (ScheduledCompletionMemory.ofCompletions? [])
    "empty completion memory was not admitted"
  let retirements ← requireSome (ScheduledRetirementMemory.ofRetirements? [])
    "empty retirement memory was not admitted"
  let replacements ← requireSome (ScheduledReplacementMemory.ofReplacements? [])
    "empty replacement memory was not admitted"
  let events ← requireSome (EventMemory.ofEvents? [])
    "empty Event memory was not admitted"
  let scheduledSnapshot : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := scheduled
    completions := completions
    retirements := retirements
    replacements := replacements
    events := events
  }
  let actual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-07"
    allRecords := []
    undatedCount := 0
  }
  pure { actual := actual, scheduled := .ok scheduledSnapshot }

def main : IO Unit := do
  let snapshot ← fixtureSnapshot
  let home := Loam.Tui.Main.initialState "2026-09-07"
  let opened := (Loam.Tui.Main.update snapshot home .tab).state
  let cursor ←
    match opened.surface with
    | .scheduled _ cursor .browse => pure cursor
    | _ => throw (IO.userError "Tab did not open Scheduled browse")

  expect (cursor.displayed.size == 12)
    "Scheduled cursor still truncated a 12-occurrence day"
  let shifted := moveNextN 10 cursor
  match shifted.selected with
  | none => throw (IO.userError "Scheduled selection disappeared after row 10")
  | some selected =>
      expect (selected.val == 10)
        "Scheduled selection could not reach the eleventh occurrence"

  expect (Loam.Tui.Main.scheduledWindowStart shifted == 1)
    "Scheduled browse window did not follow the eleventh selected occurrence"
  let rows := Loam.Tui.Main.visibleScheduledRows shifted
  expect (rows.length == 10)
    "Scheduled browse did not retain a ten-row local window"
  match rows with
  | [] => throw (IO.userError "Scheduled browse window unexpectedly became empty")
  | (firstIndex, _) :: _ =>
      expect (firstIndex == 1)
        "Scheduled browse window did not advance by one row"

  let selected ←
    match Loam.Tui.Main.selectedScheduledRecord? shifted with
    | some record => pure record
    | none => throw (IO.userError "Scheduled selected occurrence disappeared")
  let browseState : Loam.Tui.Main.State := {
    selectedDate := "2026-09-07"
    surface := .scheduled none shifted .browse
  }
  let browseText := widgetText (Loam.Tui.Main.view snapshot browseState)
  expect (contains "12 explicit current-open occurrence(s)" browseText)
    "Scheduled browse lost the full-day occurrence count"
  expect (contains "↑/↓ select/scroll" browseText)
    "Scheduled browse did not publish its local navigation affordance"

  let detailState := (Loam.Tui.Main.update snapshot browseState .enter).state
  let detailText := widgetText (Loam.Tui.Main.view snapshot detailState)
  expect (contains ("id: " ++ selected.id.token) detailText)
    "Scheduled detail does not follow the global selection"
  expect (contains "Expectation evidence, not Actual evidence." detailText)
    "Scheduled detail lost its expectation/Actual distinction"

  let backState := (Loam.Tui.Main.update snapshot detailState .back).state
  match backState.surface with
  | .scheduled _ backCursor .browse =>
      match backCursor.selected, shifted.selected with
      | some actualIndex, some expectedIndex =>
          expect (actualIndex.val == expectedIndex.val)
            "Scheduled detail back-navigation lost the selected occurrence"
      | _, _ => throw (IO.userError "Scheduled selection became unavailable after detail back")
  | _ => throw (IO.userError "Scheduled detail did not return to browse")

  let unknownHome := Loam.Tui.Main.initialState "2026-09-08"
  let unknownState := (Loam.Tui.Main.update snapshot unknownHome .tab).state
  let unknownText := widgetText (Loam.Tui.Main.view snapshot unknownState)
  expect (contains "Scheduled / Unknown" unknownText)
    "Scheduled missing evidence stopped publishing Unknown"
  expect (contains "Unknown is not NotDue" unknownText)
    "Scheduled workspace collapsed open-world Unknown into NotDue"

  let pendingActual : Loam.Tui.Main.ActualSnapshot := {
    snapshot.actual with today := "2026-09-08"
  }
  let pendingSnapshot : Loam.Tui.Main.Snapshot := {
    snapshot with actual := pendingActual
  }
  let pendingScheduled ←
    match pendingSnapshot.scheduled with
    | .error message => throw (IO.userError message)
    | .ok scheduled => pure scheduled
  match Loam.ScheduledReview.currentOpenBeforeDate pendingScheduled "2026-09-08" with
  | .error message => throw (IO.userError message)
  | .ok pending =>
      expect (pending.length == 12)
        "past-date current-open Scheduled projection lost retained occurrences"
  match Loam.ScheduledReview.currentOpenBeforeDate pendingScheduled "2026-09-07" with
  | .error message => throw (IO.userError message)
  | .ok pending =>
      expect pending.isEmpty
        "Scheduled due on the boundary was incorrectly classified as past-date pending"

  let pendingHome := Loam.Tui.Main.initialState "2026-09-08"
  let bounds : Bounds := { width := 140, height := 42 }
  let pendingText := widgetText (Loam.Tui.HraHome.view bounds pendingSnapshot pendingHome)
  expect (contains "Pending: 12" pendingText)
    "Home status did not expose the past-date current-open Scheduled count"
  expect (contains "Pending Scheduled:" pendingText)
    "Home did not expose its pending Scheduled section"
  expect (contains "2026-09-07  [Still open]" pendingText)
    "Home pending section lost the original expected date"
  expect (contains "07!" pendingText)
    "Home calendar did not mark the original date of a past-date current-open Scheduled"
  expect (contains "expected date passed; Scheduled is still current-open" pendingText)
    "Home calendar marker lost its non-rescheduling explanation"

  let sameDayView := Loam.Tui.HraHome.view bounds pendingSnapshot pendingHome
  expect (hasStyledText sameDayView "[08 ]" .selectedUnderlined)
    "Today + focus lost its combined presentation"
  expect (hasStyledText sameDayView " 07! " .normal)
    "Pending-only calendar cell changed"
  let moved := (Loam.Tui.Main.update pendingSnapshot pendingHome .right).state
  expect (moved.selectedDate == "2026-09-09") "Home focus did not advance"
  let movedView := Loam.Tui.HraHome.view bounds pendingSnapshot moved
  expect (hasStyledText movedView " 08  " .underlined)
    "Today indication followed focus instead of the snapshot date"
  expect (hasStyledText movedView "[09 ]" .selected)
    "Focus-only cell lost the existing selected style"
  let movedAgain := (Loam.Tui.Main.update pendingSnapshot moved .right).state
  let movedAgainView := Loam.Tui.HraHome.view bounds pendingSnapshot movedAgain
  expect (hasStyledText movedAgainView " 08  " .underlined &&
    hasStyledText movedAgainView "[10 ]" .selected &&
    hasStyledText movedAgainView " 09  " .normal)
    "Moving focus left stale emphasis or moved Today"
  let dueTodayView := Loam.Tui.HraHome.view bounds snapshot home
  expect (hasStyledText dueTodayView "[07 ]" .selectedUnderlined)
    "Scheduled on Today was incorrectly marked Pending"

  -- SGR attributes accumulate: each style must clear the previous underline,
  -- background and dim attributes before setting its own (including dirty redraw).
  for style in [Style.normal, .selected, .muted, .underlined, .selectedUnderlined] do
    let sgr := Loam.Tui.Terminal.ansiStyle style
    expect (sgr.startsWith "\x1b[0;" || sgr == "\x1b[0m")
      "Terminal style can leak attributes into the next calendar cell"

  IO.println "TUI Scheduled: browse/detail, Unknown, Pending and independent Today/focus presentation passed."
