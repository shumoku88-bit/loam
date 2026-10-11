import Loam.Tests.ActualWorldFixture
import Loam.Review.ActualReview
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Publisher.ScheduledCreationPublisher
import Loam.Review.ScheduledReview
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
    (root : System.FilePath) : IO Loam.Tui.Main.Snapshot := do
  let .ok actualRecords ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "load Actual review")
  let .ok scheduled ← Loam.ScheduledReview.loadHouseholdEvidence root root
    | throw (IO.userError "load Scheduled evidence")
  let actual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-08"
    allRecords := actualRecords }
  return { actual := actual, scheduled := .ok scheduled }

private def hasScheduled
    (records : List (ScheduledOccurrence String)) (id : ScheduledId) : Bool :=
  records.any fun record => decide (record.id = id)

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let root := dataDir

  let initialWorld ← emptyWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root initialWorld
    | throw (IO.userError "initialize Actual fixture")
  let lifecycle ← emptyScheduledLifecycle
  let lifecycleBody ← requireSome
    (Loam.Persistence.encodeScheduledLifecycleImage? lifecycle)
    "encode Household Scheduled lifecycle fixture"
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "Scheduled" lifecycleBody
    | throw (IO.userError "initialize Household Scheduled lifecycle fixture")

  let snapshot ← loadSnapshot root
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
  expect (draft.scheduledOn == "2026-09-12" &&
    Loam.ScheduledOccurrenceConstruction.positiveTotalQuanta draft.movement == 700)
    "new Scheduled editor changed the explicit date or balanced total"

  let previewState : Loam.Tui.ScheduledCreation.State := {
    edited with mode := .preview draft ⟨0, by omega⟩ }
  -- UI-16: a compact confirmation must retain the signed meaning, due date,
  -- selected publication action and enough room to inspect its postings.
  let compact : Loam.Tui.Kernel.Bounds := { width := 48, height := 14 }
  let previewWidget := Loam.Tui.ScheduledCreation.view compact [] previewState
  let previewText := String.ofList
    (previewWidget.lines.flatten.map Loam.Tui.Kernel.Cell.glyph)
  expect (previewText.includes "Scheduled / New / Preview" &&
    previewText.includes "Expected postings" &&
    previewText.includes "2026-09-12" &&
    previewText.includes "-700 jpy" && previewText.includes "+700 jpy" &&
    previewText.includes "Publish Scheduled")
    "compact Scheduled confirmation lost due date, signed postings or selected action"
  expect (previewWidget.lines.length <= compact.height - 1)
    "Scheduled confirmation exceeded compact terminal height"
  for cells in previewWidget.lines do
    expect (Loam.Tui.Layout.displayWidth
      (String.ofList (cells.map Loam.Tui.Kernel.Cell.glyph)) <=
      Loam.Tui.Layout.contentWidth compact)
      "Scheduled confirmation exceeded compact terminal width"

  let tiny : Loam.Tui.Kernel.Bounds := { width := 32, height := 9 }
  let blocked := Loam.Tui.ScheduledCreation.updateForBounds
    tiny ["paypay", "food"] previewState .enter
  expect (blocked.publish.isNone && blocked.state.notice.includes "Enlarge terminal")
    "Scheduled review published without room to inspect its postings"
  let allowed := Loam.Tui.ScheduledCreation.updateForBounds
    compact ["paypay", "food"] previewState .enter
  expect allowed.publish.isSome
    "Scheduled review blocked publication despite sufficient viewport"

  let large := "123456789012345678901234567890"
  let longLocus := "long" ++ String.ofList (List.replicate 70 'x')
  let longEditor : Loam.Tui.ScheduledCreation.State := {
    edited with form := { edited.form with rows :=
      #[ { locus := "paypay", amount := "-" ++ large }
       , { locus := longLocus, amount := large } ] } }
  let .ok longDraft := Loam.Tui.ScheduledCreation.draft? longEditor
    | throw (IO.userError "build long Scheduled preview fixture")
  let longPreview : Loam.Tui.ScheduledCreation.State := {
    longEditor with mode := .preview longDraft ⟨0, by omega⟩ }
  let limit := Loam.Tui.ScheduledCreation.previewScrollLimit compact longPreview
  expect (limit > 0) "long Scheduled confirmation did not offer scrolling"
  let last := (Loam.Tui.ScheduledCreation.updateForBounds
    compact [] longPreview .«end»).state
  expect (last.previewScroll == limit)
    "Scheduled review End failed to expose trailing postings"
  let endText := String.ofList
    ((Loam.Tui.ScheduledCreation.view compact [] last).lines.flatten.map
      Loam.Tui.Kernel.Cell.glyph)
  expect (endText.includes "Balanced total")
    "Scheduled review scrolling could not reach exact total"
  let reset := (Loam.Tui.ScheduledCreation.updateForBounds
    compact [] last .home).state
  expect (reset.previewScroll == 0)
    "Scheduled review Home failed to return to the first posting"
  let selectedEdit := (Loam.Tui.ScheduledCreation.updateForBounds
    compact [] longPreview .tab).state
  let editStep := Loam.Tui.ScheduledCreation.updateForBounds
    compact [] selectedEdit .enter
  expect (editStep.publish.isNone)
    "Scheduled preview Edit choice unexpectedly published"

  let publishStep := Loam.Tui.ScheduledCreation.update
    ["paypay", "rent", "food"] previewState .enter
  let intent ← requireSome publishStep.publish
    "new Scheduled preview did not emit shared publisher intent"
  let .ok scheduledId ← Loam.ScheduledCreationPublisher.publishHousehold root intent
    | throw (IO.userError "publish new Scheduled from TUI intent")

  let fresh ← loadSnapshot root
  let freshScheduled ←
    match fresh.scheduled with
    | .error message => throw (IO.userError message)
    | .ok scheduled => pure scheduled
  let .ok dayEvidence := Loam.ScheduledReview.dayEvidence freshScheduled "2026-09-12"
    | throw (IO.userError "fresh Scheduled day evidence refused valid lifecycle")
  let due := Loam.ScheduledReview.explicitDueRecords dayEvidence
  expect (hasScheduled due scheduledId)
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

  let usdRows : Array Loam.Tui.Record.Row :=
    #[ { locus := "paypay", amount := "-25" }
     , { locus := "food", amount := "25" } ]
  let usdEditor := Loam.Tui.ScheduledCreation.initialWithMeasure ⟨"usd"⟩ "2026-09-13"
  let usdEdited : Loam.Tui.ScheduledCreation.State := {
    usdEditor with form := { usdEditor.form with rows := usdRows } }
  let .ok usdDraft := Loam.Tui.ScheduledCreation.draft? usdEdited
    | throw (IO.userError "build USD Scheduled draft")
  expect (usdDraft.movement.measure == ⟨"usd"⟩)
    "new Scheduled editor replaced the explicitly selected Measure"
  let usdRecord : ScheduledOccurrence String := {
    id := ⟨"scheduled-usd"⟩
    scheduledOn := usdDraft.scheduledOn
    movement := usdDraft.movement }
  let .ok usdNext := Loam.Tui.ScheduledCreation.initialFromScheduled? usdRecord
    | throw (IO.userError "seed next USD Scheduled occurrence")
  expect (usdNext.measure == ⟨"usd"⟩ && usdNext.form.rows == usdRows)
    "next Scheduled seed did not preserve a non-JPY Measure and postings"

  IO.println "TUI Scheduled create: pane-local intent, explicit next seed, shared publication, fresh Due read and Actual independence passed."
