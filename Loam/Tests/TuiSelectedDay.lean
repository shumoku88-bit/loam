import Loam.Tui.SelectedDay

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
private def paypay : LocusId := ⟨"paypay"⟩
private def food : LocusId := ⟨"food"⟩

private def actualRecord? : Option Loam.Tui.Main.ReviewRecord := do
  let event ← Event.ofEffects? ⟨"event-day"⟩
    [ Effect.ofQuantity ⟨"effect-from"⟩ paypay yen (Quantity.ofQuanta (-640))
    , Effect.ofQuantity ⟨"effect-to"⟩ food yen (Quantity.ofQuanta 640)
    ]
  pure {
    event
    date := some "2026-09-07"
    description := "コンビニ"
    replacement := none
    isCurrent := true
  }

private def scheduledRecord? : Option (ScheduledOccurrence String) := do
  let movement ← BalancedMovement.ofChanges? yen
    [ { coordinate := paypay, quantity := Quantity.ofQuanta (-1000) }
    , { coordinate := food, quantity := Quantity.ofQuanta 1000 }
    ]
  pure {
    id := ⟨"scheduled-day"⟩
    scheduledOn := "2026-09-07"
    movement := movement
  }

private def fixture : IO Loam.Tui.Main.Snapshot := do
  let actualRecord ← requireSome actualRecord? "Actual day fixture was not admitted"
  let scheduledRecord ← requireSome scheduledRecord? "Scheduled day fixture was not admitted"
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? [scheduledRecord])
    "Scheduled memory fixture was not admitted"
  let terminals ← requireSome (ScheduledTerminalMemory.ofTerminals? [])
    "empty terminal memory was not admitted"
  let events ← requireSome (EventMemory.ofEvents? [])
    "empty Event memory was not admitted"
  let actual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-07"
    allRecords := [actualRecord]
    undatedCount := 0
  }
  let scheduledSnapshot : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled, terminals, events
  }
  pure { actual, scheduled := .ok scheduledSnapshot }

def main : IO Unit := do
  let snapshot ← fixture
  let state := Loam.Tui.SelectedDay.initial "2026-09-07"
  expect ((Loam.Tui.SelectedDay.actualRecords snapshot state).length == 1)
    "Selected-day workspace did not reuse the shared Actual day answer"
  expect ((Loam.Tui.SelectedDay.scheduledRecords snapshot state).length == 1)
    "Selected-day workspace did not reuse the shared Scheduled day answer"

  let actualText := widgetText (Loam.Tui.SelectedDay.view { width := 100, height := 30 } snapshot state)
  expect (contains "Household Day Workspace" actualText)
    "Selected-day workspace heading disappeared"
  expect (contains "コンビニ" actualText && contains "Selected Actual:" actualText)
    "Selected-day workspace did not keep Actual evidence and detail together"

  let correctionStep := Loam.Tui.SelectedDay.update snapshot state .correctActual
  expect (correctionStep.command == .correctActual)
    "Selected-day Actual selection stopped delegating Correction intent"
  let reversalStep := Loam.Tui.SelectedDay.update snapshot state .reverseActual
  expect (reversalStep.command == .reverseActual)
    "Selected-day Actual selection stopped delegating Reversal intent"
  let dateStep := Loam.Tui.SelectedDay.update snapshot state .correctDate
  expect (dateStep.command == .correctDate)
    "Selected-day Actual selection stopped delegating date-correction intent"

  let scheduledState := (Loam.Tui.SelectedDay.update snapshot state .focusRight).state
  let scheduledText := widgetText (Loam.Tui.SelectedDay.view { width := 100, height := 30 } snapshot scheduledState)
  expect (contains "scheduled-day" scheduledText && contains "Selected Scheduled:" scheduledText)
    "Selected-day workspace did not keep Scheduled evidence and detail together"
  let refusalMessage :=
    "This Scheduled occurrence uses a non-JPY measure and cannot be represented by the JPY replacement editor."
  let refusedScheduledState := { scheduledState with notice := refusalMessage }
  let refusedScheduledText := widgetText
    (Loam.Tui.SelectedDay.view { width := 100, height := 30 } snapshot refusedScheduledState)
  expect (contains refusalMessage refusedScheduledText)
    "Selected-day workspace did not render a Scheduled replacement refusal notice from its current state"
  let refusedCorrection := Loam.Tui.SelectedDay.update snapshot scheduledState .correctActual
  expect (refusedCorrection.command == .stay)
    "Scheduled pane emitted an Actual Correction intent"
  let refusedReversal := Loam.Tui.SelectedDay.update snapshot scheduledState .reverseActual
  expect (refusedReversal.command == .stay)
    "Scheduled pane emitted an Actual Reversal intent"
  let refusedDate := Loam.Tui.SelectedDay.update snapshot scheduledState .correctDate
  expect (refusedDate.command == .stay)
    "Scheduled pane emitted an Actual date-correction intent"

  let movedSnapshot : Loam.Tui.Main.Snapshot := {
    snapshot with actual := { snapshot.actual with allRecords := [] } }
  let refreshed := Loam.Tui.SelectedDay.refreshed movedSnapshot state
  expect (refreshed.focusDate == "2026-09-07" && refreshed.actualRow == 0)
    "fresh reload moved the selected-day coordinate instead of only clamping local row state"

  let newStep := Loam.Tui.SelectedDay.update snapshot state .recordNew
  expect (newStep.command == .recordNew)
    "Selected-day workspace stopped delegating new Actual to the shared Record path"
  let backStep := Loam.Tui.SelectedDay.update snapshot state .back
  expect (backStep.command == .back)
    "Selected-day workspace back command changed"

  let unknown := Loam.Tui.SelectedDay.initial "2026-09-08"
  let unknownState := (Loam.Tui.SelectedDay.update snapshot unknown .focusRight).state
  let unknownText := widgetText (Loam.Tui.SelectedDay.view { width := 100, height := 30 } snapshot unknownState)
  expect (contains "Unknown: absence of an explicit due occurrence is not NotDue." unknownText)
    "Selected-day workspace collapsed Scheduled Unknown into NotDue"

  let unavailable : Loam.Tui.Main.Snapshot :=
    { snapshot with scheduled := .error "scheduled fixture unavailable" }
  let unavailableScheduledState :=
    (Loam.Tui.SelectedDay.update unavailable state .focusRight).state
  let unavailableText := widgetText
    (Loam.Tui.SelectedDay.view { width := 100, height := 30 } unavailable unavailableScheduledState)
  expect (contains "Scheduled [Unavailable]" unavailableText &&
    contains "[Unavailable] scheduled fixture unavailable" unavailableText)
    "Selected-day workspace collapsed unavailable Scheduled evidence into an empty pane"
  let unavailableCreate :=
    Loam.Tui.SelectedDay.update unavailable unavailableScheduledState .createScheduled
  expect (unavailableCreate.command == .stay)
    "Selected-day workspace emitted a Scheduled write intent while Scheduled evidence was unavailable"

  IO.println "TUI selected day: shared composition, Record/Correction/Reversal/date delegation, refresh, Unknown and Scheduled unavailability passed."
