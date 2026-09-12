import Loam.Tests.ActualWorldFixture
import Loam.ActualAuthority
import Loam.ActualReview
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.ScheduledReview
import Loam.ScheduledReplacementPublisher
import Loam.ScheduledTerminalPublisher
import Loam.Tui.SelectedDay
import Loam.Tui.ScheduledCancellation
import Loam.Tui.ScheduledCompletion
import Loam.Tui.ScheduledReplacement
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
      factRefNodup := by simp
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
  let .ok actualRecords ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "load Actual review")
  let .ok scheduled ← Loam.ScheduledReview.loadEvidenceFromActual scheduledFile root
    | throw (IO.userError "load Scheduled evidence")
  let actual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-08"
    allRecords := actualRecords
    undatedCount := (Loam.ActualReview.select actualRecords .undated).length }
  return { actual := actual, scheduled := .ok scheduled }

private def requireScheduled
    (snapshot : Loam.Tui.Main.Snapshot) : IO Loam.ScheduledReview.EvidenceSnapshot := do
  match snapshot.scheduled with
  | .error message => throw (IO.userError message)
  | .ok scheduled => pure scheduled

private def hasScheduled
    (records : List (ScheduledOccurrence String)) (token : String) : Bool :=
  records.any fun record => record.id.token == token

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let root := dataDir
  let scheduledFile := dataDir / "scheduled.loam"

  let initialWorld ← emptyWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root initialWorld
    | throw (IO.userError "initialize Actual fixture")
  let first ← occurrence "scheduled-1" "rent" 1000
  let second ← occurrence "scheduled-2" "food" 200
  let third ← occurrence "scheduled-3" "rent" 300
  let some scheduledMemory := ScheduledMemory.ofOccurrences? [first, second, third]
    | throw (IO.userError "scheduled memory")
  let some terminals := ScheduledTerminalMemory.ofTerminals? []
    | throw (IO.userError "empty terminal memory")
  expect (← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile {
      scheduled := scheduledMemory
      terminals := terminals })
    "save Scheduled lifecycle fixture"

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
  let .ok completion ← Loam.ScheduledTerminalPublisher.publishCompletion
      scheduledFile.toString root.toString completionIntent
    | throw (IO.userError "publish selected Scheduled completion")
  expect (completion.scheduled.token == "scheduled-1")
    "shared completion receipt changed selected Scheduled identity"

  let afterCompletion ← loadSnapshot scheduledFile root
  let afterCompletionScheduled ← requireScheduled afterCompletion
  let dueAfterCompletion := Loam.ScheduledReview.explicitDueRecords
    (Loam.ScheduledReview.dayEvidence afterCompletionScheduled "2026-09-10")
  expect (!hasScheduled dueAfterCompletion "scheduled-1" &&
      hasScheduled dueAfterCompletion "scheduled-2" &&
      hasScheduled dueAfterCompletion "scheduled-3")
    "fresh Scheduled read did not close only the completed occurrence"
  let actualDay := Loam.ActualReview.select afterCompletion.actual.allRecords (.day "2026-09-08")
  expect (actualDay.any fun record =>
      record.event.id == completion.actual &&
        record.event.effects.map (fun effect => effect.quantity.quanta) == [-1000, 1000])
    "completion did not publish independent Actual evidence through shared Actual authority"

  let afterState := Loam.Tui.SelectedDay.refreshed afterCompletion scheduledState
  let cancelCommand := Loam.Tui.SelectedDay.update afterCompletion afterState .cancelScheduled
  expect (cancelCommand.command == .cancelScheduled)
    "Scheduled pane did not emit selected cancellation intent"
  let cancelTarget ← requireSome
    (Loam.Tui.SelectedDay.selectedScheduled? afterCompletion afterState)
    "remaining Scheduled occurrence was not selected"
  expect (cancelTarget.id.token == "scheduled-2")
    "fresh selected-day clamp did not select the next Scheduled occurrence"

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
  let .ok cancelled ← Loam.ScheduledTerminalPublisher.publishCancellation
      scheduledFile.toString root.toString cancelIntent
    | throw (IO.userError "publish selected Scheduled cancellation")
  expect (cancelled.scheduled.token == "scheduled-2")
    "shared cancellation receipt changed selected Scheduled identity"

  let afterCancellation ← loadSnapshot scheduledFile root
  let afterCancellationScheduled ← requireScheduled afterCancellation
  let explicitAfterCancellation := Loam.ScheduledReview.explicitDueRecords
    (Loam.ScheduledReview.dayEvidence afterCancellationScheduled "2026-09-10")
  expect (explicitAfterCancellation.length == 1 && hasScheduled explicitAfterCancellation "scheduled-3")
    "fresh Scheduled read did not leave only the untouched third occurrence"
  let replacementState := Loam.Tui.SelectedDay.refreshed afterCancellation afterState
  let replaceCommand := Loam.Tui.SelectedDay.update
    afterCancellation replacementState .replaceScheduled
  expect (replaceCommand.command == .replaceScheduled)
    "Scheduled pane did not emit selected supersede intent"
  let replaceTarget ← requireSome
    (Loam.Tui.SelectedDay.selectedScheduled? afterCancellation replacementState)
    "Scheduled supersede target disappeared"
  expect (replaceTarget.id.token == "scheduled-3")
    "selected-day clamp did not select the remaining replacement source"

  let .ok replacementEditor := Loam.Tui.ScheduledReplacement.initial? replaceTarget
    | throw (IO.userError "initialize Scheduled replacement editor")
  expect
    (replacementEditor.form.date == "2026-09-10" &&
      replacementEditor.form.rows.size == 2 &&
      replacementEditor.form.rows[0]!.locus == "paypay" &&
      replacementEditor.form.rows[0]!.amount == "-300" &&
      replacementEditor.form.rows[1]!.locus == "rent" &&
      replacementEditor.form.rows[1]!.amount == "300")
    "Scheduled replacement did not seed date plus signed postings exactly"

  let amountReplacement := { replacementEditor with
    form := { replacementEditor.form with focus := 2 } }
  let amountEdited := Loam.Tui.ScheduledReplacement.update
    ["paypay", "rent", "food"] amountReplacement .backspace
  expect (amountEdited.state.form.rows[0]!.amount == "-30")
    "Scheduled replacement posting seed was not editable local state"

  let movedEditor := { replacementEditor with
    form := { replacementEditor.form with date := "2026-09-12" } }
  let .ok replacementDraft := Loam.Tui.ScheduledReplacement.draft? movedEditor
    | throw (IO.userError "build Scheduled replacement draft")
  let replacementPreview : Loam.Tui.ScheduledReplacement.State := {
    movedEditor with mode := .preview replacementDraft ⟨0, by omega⟩ }
  let replacementIntentStep := Loam.Tui.ScheduledReplacement.update
    ["paypay", "rent", "food"] replacementPreview .enter
  let replacementIntent ← requireSome replacementIntentStep.publish
    "replacement preview did not emit shared publisher intent"
  expect
    (replacementIntent.source.token == "scheduled-3" &&
      replacementIntent.scheduledOn == "2026-09-12" &&
      replacementIntent.total == 300)
    "replacement editor lost selected source or edited content"
  let .ok replacement ← Loam.ScheduledReplacementPublisher.publishReplacement
      scheduledFile.toString root.toString replacementIntent
    | throw (IO.userError "publish selected Scheduled replacement")
  expect (replacement.source.token == "scheduled-3")
    "shared replacement receipt changed selected source identity"

  let afterReplacement ← loadSnapshot scheduledFile root
  let afterReplacementScheduled ← requireScheduled afterReplacement
  let oldDay := Loam.ScheduledReview.explicitDueRecords
    (Loam.ScheduledReview.dayEvidence afterReplacementScheduled "2026-09-10")
  let newDay := Loam.ScheduledReview.explicitDueRecords
    (Loam.ScheduledReview.dayEvidence afterReplacementScheduled "2026-09-12")
  expect oldDay.isEmpty
    "fresh Scheduled read retained completed, cancelled, or superseded sources on the old day"
  expect
    (newDay.length == 1 &&
      hasScheduled newDay replacement.replacement.token &&
      !hasScheduled newDay "scheduled-3")
    "fresh Scheduled read did not expose only the replacement endpoint on its edited day"
  let refreshed := Loam.Tui.SelectedDay.refreshed afterReplacement replacementState
  expect (refreshed.focusDate == "2026-09-10" && refreshed.scheduledRow == 0)
    "Scheduled write moved the selected-day coordinate instead of only clamping local selection"

  IO.println "TUI Scheduled terminal: completion, safe cancellation, editable supersede, shared publication and fresh reads passed."
