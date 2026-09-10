import Loam.Tui.Main
import Loam.Tui.HraScheduled

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

private def yen : MeasureId := ⟨"jpy"⟩

private def change (locus : String) (quanta : Int) : MovementChange LocusId :=
  { coordinate := ⟨locus⟩, quantity := Quantity.ofQuanta quanta }

private def scheduledRecord?
    (id date fromLocus toLocus : String) (quanta : Int) : Option (ScheduledOccurrence String) := do
  let movement ← BalancedMovement.ofChanges? yen
    [change fromLocus (-quanta), change toLocus quanta]
  pure {
    id := ⟨id⟩
    scheduledOn := date
    movement := movement
  }

private def hraScheduledSnapshot : IO Loam.Tui.Main.Snapshot := do
  let first ← requireSome (scheduledRecord? "scheduled-0" "2026-09-07" "paypay" "food" 100)
    "first Scheduled fixture was not admitted"
  let second ← requireSome (scheduledRecord? "scheduled-1" "2026-09-07" "smbc" "paypay" 200)
    "second Scheduled fixture was not admitted"
  let future ← requireSome (scheduledRecord? "scheduled-2" "2026-09-08" "paypay" "books" 300)
    "future-day Scheduled fixture was not admitted"
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? [first, second, future])
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
  let snapshot ← hraScheduledSnapshot
  let start := Loam.Tui.HraScheduled.initial "2026-09-07"

  -- 1. Focus Day scope shows only today's Scheduled occurrences
  expect ((Loam.Tui.HraScheduled.recordsForScope snapshot start).length == 2)
    "HRA Scheduled Focus Day did not return the two scheduled occurrences on 2026-09-07"

  -- 2. Scheduled opens on occurrences so j/k browses records before any explicit Locus filtering.
  expect (start.pane == .occurrences)
    "HRA Scheduled did not open on the Scheduled occurrences pane"
  let second := (Loam.Tui.HraScheduled.update snapshot start .next).state
  match Loam.Tui.HraScheduled.selectedRecord? snapshot second with
  | none => throw (IO.userError "HRA Scheduled occurrence selection disappeared")
  | some record =>
      expect (record.id.token == "scheduled-1")
        "HRA Scheduled j/down selection did not move to the second occurrence"

  -- 3. Rendering check
  let viewWidget := Loam.Tui.HraScheduled.view { width := 100, height := 30 } snapshot second
  let viewText := widgetText viewWidget
  expect (contains "Household Scheduled Workspace" viewText)
    "HRA Scheduled heading was not rendered"
  expect (contains "Selected Scheduled Details:" viewText && contains "scheduled-1" viewText)
    "HRA Scheduled details did not render selected occurrence information"
  let refusalMessage :=
    "This Scheduled occurrence uses a non-JPY measure and cannot be represented by the JPY replacement editor."
  let refusedState := { second with notice := refusalMessage }
  let refusedText := widgetText
    (Loam.Tui.HraScheduled.view { width := 100, height := 30 } snapshot refusedState)
  expect (contains refusalMessage refusedText)
    "HRA Scheduled did not render a Scheduled replacement refusal notice from its current state"

  -- 4. Cycle Filter expands to allCurrent
  let allCurrent := (Loam.Tui.HraScheduled.update snapshot second .cycleFilter).state
  expect ((Loam.Tui.HraScheduled.recordsForScope snapshot allCurrent).length == 3)
    "HRA Scheduled filter cycle did not expand to all current-open Scheduled occurrences"
  expect (allCurrent.pane == .occurrences)
    "HRA Scheduled scope change moved focus into the Locus filter pane"

  let allCurrentText := widgetText (Loam.Tui.HraScheduled.view { width := 100, height := 30 } snapshot allCurrent)
  expect (contains "All Current-Open" allCurrentText)
    "HRA Scheduled heading did not reflect All Current-Open scope"

  -- 5. Loci navigation and filtering
  let toLoci := (Loam.Tui.HraScheduled.update snapshot allCurrent .focusLeft).state
  expect (toLoci.pane == .loci)
    "HRA Scheduled focusLeft did not switch to loci pane"

  -- 6. Object-local command emission from occurrences pane
  let occPane := (Loam.Tui.HraScheduled.update snapshot allCurrent .focusRight).state

  let completeStep := Loam.Tui.HraScheduled.update snapshot occPane .completeScheduled
  expect (completeStep.command == .completeScheduled)
    "HRA Scheduled completeScheduled event did not emit completeScheduled command"

  let replaceStep := Loam.Tui.HraScheduled.update snapshot occPane .replaceScheduled
  expect (replaceStep.command == .replaceScheduled)
    "HRA Scheduled replaceScheduled event did not emit replaceScheduled command"

  let cancelStep := Loam.Tui.HraScheduled.update snapshot occPane .cancelScheduled
  expect (cancelStep.command == .cancelScheduled)
    "HRA Scheduled cancelScheduled event did not emit cancelScheduled command"

  let createStep := Loam.Tui.HraScheduled.update snapshot occPane .createScheduled
  expect (createStep.command == .createScheduled)
    "HRA Scheduled createScheduled event did not emit createScheduled command"

  let backStep := Loam.Tui.HraScheduled.update snapshot occPane .back
  expect (backStep.command == .back)
    "HRA Scheduled back event did not emit back command"

  -- 7. From loci pane, complete/replace/cancel are refused and emit .stay with notice
  let lociCompleteStep := Loam.Tui.HraScheduled.update snapshot toLoci .completeScheduled
  expect (lociCompleteStep.command == .stay)
    "HRA Scheduled completeScheduled from loci pane unexpectedly emitted a non-stay command"
  expect (contains "Scheduled pane" lociCompleteStep.state.notice)
    "HRA Scheduled complete notice from loci pane was missing guidance"

  -- 8. Startup refusal remains explicit and blocks Scheduled writes.
  let unavailable : Loam.Tui.Main.Snapshot :=
    { snapshot with scheduled := .error "scheduled fixture unavailable" }
  let unavailableText := widgetText
    (Loam.Tui.HraScheduled.view { width := 100, height := 30 } unavailable start)
  expect (contains "Scheduled [Unavailable]" unavailableText &&
    contains "[Unavailable] scheduled fixture unavailable" unavailableText)
    "HRA Scheduled collapsed startup refusal into an empty Scheduled workspace"
  let unavailableCreate := Loam.Tui.HraScheduled.update unavailable start .createScheduled
  expect (unavailableCreate.command == .stay &&
    contains "[Unavailable] Scheduled" unavailableCreate.state.notice)
    "HRA Scheduled emitted a write intent while Scheduled evidence was unavailable"

  IO.println "TUI Scheduled: HRA Scheduled workspace mechanics and startup unavailability passed."
