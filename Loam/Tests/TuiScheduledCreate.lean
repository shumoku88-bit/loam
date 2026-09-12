import Loam.ActualAuthority
import Loam.ActualReview
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.ScheduledCreationPublisher
import Loam.ScheduledReview
import Loam.Tui.ScheduledCreation
import Loam.Tui.SelectedDay
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

private def emptyScheduledLifecycle : IO Loam.Persistence.ScheduledLifecycleImage := do
  let some scheduled := ScheduledMemory.ofOccurrences? []
    | throw (IO.userError "empty Scheduled memory")
  let some terminals := ScheduledTerminalMemory.ofTerminals? []
    | throw (IO.userError "empty Scheduled terminal memory")
  return { scheduled, terminals }

private def loadSnapshot
    (scheduledFile root : System.FilePath) : IO Loam.Tui.Main.Snapshot := do
  let .ok actualRecords ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "load Actual review")
  let .ok scheduled ← Loam.ScheduledReview.loadEvidenceFromManifest scheduledFile root
    | throw (IO.userError "load Scheduled evidence")
  let actual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-08"
    allRecords := actualRecords
    undatedCount := (Loam.ActualReview.select actualRecords .undated).length }
  return { actual := actual, scheduled := .ok scheduled }

private def hasScheduled
    (records : List (ScheduledOccurrence String)) (id : ScheduledId) : Bool :=
  records.any fun record => decide (record.id = id)

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let root := dataDir
  let scheduledFile := dataDir / "scheduled.loam"

  let initialWorld ← emptyWorld
  let .ok _ ← Loam.ActualAuthority.publishWorld? root initialWorld
    | throw (IO.userError "initialize Actual fixture")
  let lifecycle ← emptyScheduledLifecycle
  expect (← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile lifecycle)
    "initialize explicit Scheduled lifecycle fixture"

  let snapshot ← loadSnapshot scheduledFile root
  let actualState := Loam.Tui.SelectedDay.initial "2026-09-12"
  let scheduledState :=
    (Loam.Tui.SelectedDay.update snapshot actualState .focusRight).state
  expect ((Loam.Tui.SelectedDay.scheduledRecords snapshot scheduledState).isEmpty)
    "empty-day Scheduled fixture unexpectedly had an explicit due occurrence"

  let createCommand :=
    Loam.Tui.SelectedDay.update snapshot scheduledState .createScheduled
  expect (createCommand.command == .createScheduled)
    "Scheduled pane did not emit new-Scheduled intent without an existing selected row"
  let refusedActual :=
    Loam.Tui.SelectedDay.update snapshot actualState .createScheduled
  expect (refusedActual.command == .stay)
    "Actual pane emitted a Scheduled creation intent"
  let refusedNewActual :=
    Loam.Tui.SelectedDay.update snapshot scheduledState .recordNew
  expect (refusedNewActual.command == .stay)
    "Scheduled pane emitted a new-Actual intent"

  let editor := Loam.Tui.ScheduledCreation.initial scheduledState.focusDate
  expect (editor.form.date == "2026-09-12" && editor.form.rows.size == 2)
    "new Scheduled editor did not seed the focused date and two neutral posting rows"
  let rows : Array Loam.Tui.Record.Row :=
    #[ { locus := "paypay", amount := "-700" }
     , { locus := "food", amount := "700" } ]
  let edited : Loam.Tui.ScheduledCreation.State := {
    editor with form := { editor.form with rows := rows } }
  let .ok draft := Loam.Tui.ScheduledCreation.draft? edited
    | throw (IO.userError "build new Scheduled draft")
  expect (draft.scheduledOn == "2026-09-12" && draft.total == 700)
    "new Scheduled editor changed the explicit date or balanced total"

  let previewState : Loam.Tui.ScheduledCreation.State := {
    edited with mode := .preview draft ⟨0, by omega⟩ }
  let publishStep := Loam.Tui.ScheduledCreation.update
    ["paypay", "rent", "food"] previewState .enter
  let intent ← requireSome publishStep.publish
    "new Scheduled preview did not emit shared publisher intent"
  let .ok receipt ← Loam.ScheduledCreationPublisher.publishCreation
      scheduledFile.toString root.toString intent
    | throw (IO.userError "publish new Scheduled from TUI intent")

  let fresh ← loadSnapshot scheduledFile root
  let freshScheduled ←
    match fresh.scheduled with
    | .error message => throw (IO.userError message)
    | .ok scheduled => pure scheduled
  let due := Loam.ScheduledReview.explicitDueRecords
    (Loam.ScheduledReview.dayEvidence freshScheduled "2026-09-12")
  expect (hasScheduled due receipt.scheduled)
    "fresh Scheduled read did not expose the newly created occurrence on its explicit day"
  expect (fresh.actual.allRecords.isEmpty)
    "Scheduled creation also created Actual evidence"

  let createdRecord ← requireSome due.head?
    "fresh Scheduled read did not expose a seed candidate"
  let .ok nextEditor := Loam.Tui.ScheduledCreation.initialFromScheduled? createdRecord
    | throw (IO.userError "seed next Scheduled from completed expectation")
  expect nextEditor.form.date.isEmpty
    "next Scheduled seed inferred a due date without recurrence evidence"
  expect (nextEditor.form.rows == rows)
    "next Scheduled seed did not preserve the original expected signed postings"
  expect (!nextEditor.notice.isEmpty)
    "next Scheduled seed did not explain that completion is already durable"

  let refreshed := Loam.Tui.SelectedDay.refreshed fresh scheduledState
  expect (refreshed.focusDate == "2026-09-12" && refreshed.pane == .scheduled)
    "new Scheduled publication moved the selected-day coordinate or active pane"
  expect ((Loam.Tui.SelectedDay.scheduledRecords fresh refreshed).length == 1)
    "fresh selected-day Scheduled pane did not expose the created occurrence"

  let unbalanced : Loam.Tui.ScheduledCreation.State := {
    editor with form := { editor.form with rows :=
      #[ { locus := "paypay", amount := "-700" }
       , { locus := "food", amount := "600" } ] } }
  expect (!(Loam.Tui.ScheduledCreation.draft? unbalanced).isOk)
    "new Scheduled editor previewed an unbalanced movement"
  let cancelled := Loam.Tui.ScheduledCreation.update ["paypay", "food"] editor .escape
  expect (cancelled.cancel && cancelled.publish.isNone)
    "Esc from new Scheduled editor emitted publication"

  IO.println "TUI Scheduled create: pane-local intent, explicit next seed, shared publication, fresh Due read and Actual independence passed."
