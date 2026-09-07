import Loam.ActualReview
import Loam.ScheduledReview
import Loam.ScheduledTerminalPublisher
import Loam.Tui.SelectedDay
import Loam.Tui.ScheduledCancellation
import Loam.Tui.ScheduledCompletion
import Lean.Elab.Tactic.Omega

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def emptyWorld : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? [] | throw (IO.userError "empty events")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci?
      [⟨"paypay"⟩, ⟨"rent"⟩, ⟨"food"⟩]
    | throw (IO.userError "vocabulary")
  return {
    events := events
    validity := {
      facts := []
      factIdNodup := by simp
      corrections := []
      correctionIdNodup := by simp }
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := vocabulary }

private def movement? (toLocus : String) (amount : Int) : Option (BalancedMovement LocusId) :=
  BalancedMovement.ofChanges? ⟨"jpy"⟩
    [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-amount) }
    , { coordinate := ⟨toLocus⟩, quantity := Quantity.ofQuanta amount }
    ]

private def occurrence (id toLocus : String) (amount : Int) : IO (ScheduledOccurrence String) := do
  let some movement := movement? toLocus amount
    | throw (IO.userError "scheduled movement")
  return {
    id := ⟨id⟩
    scheduledOn := "2026-09-10"
    movement := movement }

private def loadSnapshot
    (scheduledFile root : System.FilePath) : IO Loam.Tui.Main.Snapshot := do
  let .ok actualRecords ← Loam.ActualReview.loadRecordsFromManifest root none
    | throw (IO.userError "load manifest Actual review")
  let .ok scheduled ← Loam.ScheduledReview.loadEvidenceFromManifest scheduledFile root
    | throw (IO.userError "load Scheduled evidence")
  let actual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-08"
    allRecords := actualRecords
    undatedCount := (Loam.ActualReview.select actualRecords .undated).length }
  return { actual := actual, scheduled := scheduled }

private def hasScheduled
    (records : List (ScheduledOccurrence String)) (token : String) : Bool :=
  records.any fun record => record.id.token == token

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let root := dataDir / "movement-authority"
  let scheduledFile := dataDir / "scheduled.loam"

  let initialWorld ← emptyWorld
  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root initialWorld
    | throw (IO.userError "initialize manifest fixture")
  let first ← occurrence "scheduled-1" "rent" 1000
  let second ← occurrence "scheduled-2" "food" 200
  let some scheduledMemory := ScheduledMemory.ofOccurrences? [first, second]
    | throw (IO.userError "scheduled memory")
  expect (← Loam.Persistence.saveScheduledMemory? scheduledFile scheduledMemory)
    "save Scheduled fixture"

  let snapshot ← loadSnapshot scheduledFile root
  let actualState := Loam.Tui.SelectedDay.initial "2026-09-10"
  let scheduledState :=
    (Loam.Tui.SelectedDay.update snapshot actualState .focusRight).state
  let completeStep :=
    Loam.Tui.SelectedDay.update snapshot scheduledState .completeScheduled
  expect (completeStep.command == .completeScheduled)
    "Scheduled pane did not emit selected completion intent"

  let selected ← requireSome
    (Loam.Tui.SelectedDay.selectedScheduled? snapshot scheduledState)
    "selected Scheduled fixture disappeared"
  let .ok editor := Loam.Tui.ScheduledCompletion.initial? selected snapshot.actual.today
    | throw (IO.userError "initialize Scheduled completion editor")
  expect
    (editor.editor.form.rows.size == 2 &&
      editor.editor.form.rows[0]!.locus == "paypay" &&
      editor.editor.form.rows[0]!.amount == "-1000" &&
      editor.editor.form.rows[1]!.locus == "rent" &&
      editor.editor.form.rows[1]!.amount == "1000")
    "Scheduled expectation did not seed the shared signed-posting editor"

  let amountForm := { editor.editor.form with focus := ⟨3, by omega⟩ }
  let amountState := { editor with editor := { editor.editor with form := amountForm } }
  let edited := Loam.Tui.ScheduledCompletion.update
    initialWorld ["paypay", "rent", "food"] amountState .backspace
  expect (edited.state.editor.form.rows[0]!.amount == "-100")
    "Scheduled completion seed was not editable presentation state"

  let .ok movementDraft := Loam.Tui.Record.draft? editor.editor.form
    | throw (IO.userError "build seeded Actual draft")
  let previewState : Loam.Tui.ScheduledCompletion.State := {
    editor with
    editor := { editor.editor with
      mode := .preview movementDraft ⟨0, by omega⟩ } }
  let intentStep := Loam.Tui.ScheduledCompletion.update
    initialWorld ["paypay", "rent", "food"] previewState .enter
  let completionIntent ← requireSome intentStep.publish
    "completion preview did not emit shared publisher intent"
  expect (completionIntent.scheduled.token == "scheduled-1")
    "completion editor lost selected Scheduled identity"
  let .ok completion ← Loam.ScheduledTerminalPublisher.publishManifestCompletion
      scheduledFile.toString root.toString completionIntent
    | throw (IO.userError "publish selected Scheduled completion")
  expect (completion.scheduled.token == "scheduled-1")
    "shared completion receipt changed selected Scheduled identity"

  let afterCompletion ← loadSnapshot scheduledFile root
  let dueAfterCompletion := Loam.ScheduledReview.explicitDueRecords
    (Loam.ScheduledReview.dayEvidence afterCompletion.scheduled "2026-09-10")
  expect (!hasScheduled dueAfterCompletion "scheduled-1" &&
      hasScheduled dueAfterCompletion "scheduled-2")
    "fresh Scheduled read did not close only the completed occurrence"
  let actualDay := Loam.ActualReview.select afterCompletion.actual.allRecords (.day "2026-09-08")
  expect (actualDay.any fun record =>
      record.event.id == completion.actual &&
        record.event.effects.map (fun effect => effect.quantity.quanta) == [-1000, 1000])
    "completion did not publish independent Actual evidence through shared manifest authority"

  let afterState := Loam.Tui.SelectedDay.refreshed afterCompletion scheduledState
  let cancelCommand := Loam.Tui.SelectedDay.update afterCompletion afterState .cancelScheduled
  expect (cancelCommand.command == .cancelScheduled)
    "Scheduled pane did not emit selected cancellation intent"
  let cancelTarget ← requireSome
    (Loam.Tui.SelectedDay.selectedScheduled? afterCompletion afterState)
    "remaining Scheduled occurrence was not selected"
  expect (cancelTarget.id.token == "scheduled-2")
    "fresh selected-day clamp did not select the remaining Scheduled occurrence"

  let cancelEditor := Loam.Tui.ScheduledCancellation.initial cancelTarget
  expect (cancelEditor.choice.val == 1)
    "Scheduled cancellation did not default to Keep"
  let kept := Loam.Tui.ScheduledCancellation.update cancelEditor .enter
  expect (kept.cancel && kept.publish.isNone)
    "default cancellation confirmation retired the occurrence"
  let armed := Loam.Tui.ScheduledCancellation.update cancelEditor .tab
  expect (armed.state.choice.val == 0)
    "cancellation confirmation could not select explicit retirement"
  let cancelIntentStep := Loam.Tui.ScheduledCancellation.update armed.state .enter
  let cancelIntent ← requireSome cancelIntentStep.publish
    "explicit cancellation confirmation did not emit publisher intent"
  let .ok cancelled ← Loam.ScheduledTerminalPublisher.publishManifestCancellation
      scheduledFile.toString root.toString cancelIntent
    | throw (IO.userError "publish selected Scheduled cancellation")
  expect (cancelled.scheduled.token == "scheduled-2")
    "shared cancellation receipt changed selected Scheduled identity"

  let afterCancellation ← loadSnapshot scheduledFile root
  let explicitAfterCancellation := Loam.ScheduledReview.explicitDueRecords
    (Loam.ScheduledReview.dayEvidence afterCancellation.scheduled "2026-09-10")
  expect explicitAfterCancellation.isEmpty
    "fresh Scheduled read retained a completed or cancelled occurrence"
  let refreshed := Loam.Tui.SelectedDay.refreshed afterCancellation afterState
  expect (refreshed.focusDate == "2026-09-10" && refreshed.scheduledRow == 0)
    "Scheduled terminal write moved the day coordinate instead of only clamping local selection"

  IO.println "TUI Scheduled terminal: editable completion seed, shared completion/cancel publication, safe confirmation and fresh reads passed."
