import Loam.Tests.ActualWorldFixture
import Loam.Review.ActualReview
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Authority.ScheduledLifecycleAuthority
import Loam.Review.ScheduledReview
import Loam.Publisher.ScheduledReplacementPublisher
import Loam.Publisher.ScheduledTerminalPublisher
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
    (root : System.FilePath) : IO Loam.Tui.Main.Snapshot := do
  let .ok actualRecords ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "load Actual review")
  let .ok scheduled ← Loam.ScheduledReview.loadHouseholdEvidence root root
    | throw (IO.userError "load Scheduled evidence")
  let actual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-08"
    allRecords := actualRecords }
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
  let initialLifecycle : Loam.Persistence.ScheduledLifecycleImage := {
    scheduled := scheduledMemory
    terminals := terminals
  }
  let lifecycleBody ← requireSome
    (Loam.Persistence.encodeScheduledLifecycleImage? initialLifecycle)
    "encode Household Scheduled lifecycle fixture"
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "Scheduled" lifecycleBody
    | throw (IO.userError "save Household Scheduled lifecycle fixture")

  let snapshot ← loadSnapshot root
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
  let .ok editor := Loam.Tui.ScheduledCompletion.initialWithPresentation? [] selected snapshot.actual.today
    | throw (IO.userError "initialize Scheduled completion editor")
  expect
    (editor.editor.form.rows.size == 2 &&
      editor.editor.form.rows[0]!.locus == "paypay" &&
      editor.editor.form.rows[0]!.amount == "-1000" &&
      editor.editor.form.rows[1]!.locus == "rent" &&
      editor.editor.form.rows[1]!.amount == "1000")
    "Scheduled expectation did not seed the shared signed-posting editor"

  let originalSuppressed := Loam.Tui.ScheduledCompletion.update
    initialWorld ["paypay", "rent", "food"] editor (.ctrl 'o')
  expect originalSuppressed.publish.isNone
    "Scheduled completion leaked an original-amount publication intent"
  match originalSuppressed.state.editor.mode with
  | .editing => pure ()
  | _ => throw (IO.userError "Scheduled completion entered the new-Actual original amount editor")

  let amountForm := { editor.editor.form with focus := ⟨4, by omega⟩ }
  let amountState := { editor with editor := { editor.editor with form := amountForm } }
  let edited := Loam.Tui.ScheduledCompletion.update
    initialWorld ["paypay", "rent", "food"] amountState .backspace
  expect (edited.state.editor.form.rows[0]!.amount == "-100")
    "Scheduled completion seed was not editable presentation state"

  let unresolvedPromptForm : Loam.Tui.Record.Form :=
    Loam.Tui.Record.replaceRows editor.editor.form #[
      { locus := "paypay", amount := "-1000" },
      { locus := "rent", amount := "700" }]
  let unresolvedPromptState : Loam.Tui.ScheduledCompletion.State := {
    editor with editor := { editor.editor with form := unresolvedPromptForm } }
  let unresolvedPrompt := Loam.Tui.ScheduledCompletion.update
    initialWorld ["paypay", "rent", "food"] unresolvedPromptState (.ctrl 'u')
  expect (!unresolvedPrompt.enableUnresolved)
    "Scheduled completion requested unresolved policy before confirmation"
  match unresolvedPrompt.state.editor.mode with
  | .enableUnresolved => pure ()
  | _ => throw (IO.userError "Scheduled completion did not open unresolved activation confirmation")
  let unresolvedEnable := Loam.Tui.ScheduledCompletion.update
    initialWorld ["paypay", "rent", "food"] unresolvedPrompt.state .enter
  expect unresolvedEnable.enableUnresolved
    "Scheduled completion did not forward explicit unresolved activation intent"
  expect (unresolvedEnable.publish.isNone)
    "Scheduled completion unresolved activation also emitted completion publication"

  let .ok movementDraft := Loam.Tui.Record.draft? editor.editor.form
    | throw (IO.userError "build seeded Actual draft")
  let previewState : Loam.Tui.ScheduledCompletion.State := {
    editor with
    editor := { editor.editor with
      mode := .preview movementDraft ⟨0, by omega⟩ } }
  -- UI-17: editing is an Actual draft, anchored to an unchanged Plan target.
  let knownLoci := ["paypay", "rent", "food"]
  let mut movedFocus := editor
  for _ in [:9] do
    movedFocus := (Loam.Tui.ScheduledCompletion.update
      initialWorld knownLoci movedFocus .tab).state
  let compact : Loam.Tui.Kernel.Bounds := { width := 32, height := 9 }
  let editingWidget := Loam.Tui.ScheduledCompletion.view compact knownLoci movedFocus
  let editingText := String.ofList
    (editingWidget.lines.flatten.map Loam.Tui.Kernel.Cell.glyph)
  expect ((editingText.splitOn "Actual draft").length > 1 &&
      (editingText.splitOn "Preview").length > 1)
    "completion editor lost focused Actual action in compact viewport"
  expect (editingWidget.lines.any fun row => row.any fun cell => cell.style == .selected)
    "completion editor did not highlight the selected action"
  let refused := Loam.Tui.ScheduledCompletion.updateForBounds compact
    initialWorld knownLoci previewState .enter
  expect (refused.publish.isNone &&
      (refused.state.editor.notice.splitOn "Enlarge terminal").length > 1)
    "Scheduled completion published Actual without enough review rows"
  for bounds in
      ([ { width := 32, height := 9 },
         { width := 48, height := 14 },
         { width := 80, height := 24 } ] : List Loam.Tui.Kernel.Bounds) do
    let widget := Loam.Tui.ScheduledCompletion.view bounds knownLoci previewState
    let glyphs := String.ofList
      (widget.lines.flatten.map Loam.Tui.Kernel.Cell.glyph)
    expect (widget.lines.length <= bounds.height - 1 &&
        (glyphs.splitOn "Complete / Actual").length > 1 &&
        (glyphs.splitOn "Publish").length > 1)
      "completion preview lost Plan/Actual distinction or action bar"
    for row in widget.lines do
      expect (Loam.Tui.Layout.displayWidth
        (String.ofList (row.map Loam.Tui.Kernel.Cell.glyph)) <=
        Loam.Tui.Layout.contentWidth bounds)
        "completion preview exceeded terminal columns"
  let roomy : Loam.Tui.Kernel.Bounds := { width := 80, height := 24 }
  let readable := String.ofList
    ((Loam.Tui.ScheduledCompletion.view roomy knownLoci previewState).lines.flatten.map
      Loam.Tui.Kernel.Cell.glyph)
  expect ((readable.splitOn "Plan due:").length > 1 &&
      (readable.splitOn "Actual date:").length > 1 &&
      (readable.splitOn "Actual effects").length > 1)
    "completion confirmation did not distinguish scheduled date from Actual date"
  let longDraft := { movementDraft with
    effects := movementDraft.effects ++ movementDraft.effects ++ movementDraft.effects }
  let longPreview : Loam.Tui.ScheduledCompletion.State := {
    previewState with editor := { previewState.editor with
      mode := .preview longDraft ⟨0, by omega⟩ } }
  let scrolled := (Loam.Tui.ScheduledCompletion.updateForBounds
    ({ width := 48, height := 14 } : Loam.Tui.Kernel.Bounds)
    initialWorld knownLoci longPreview .«end»).state
  let scrollText := String.ofList
    ((Loam.Tui.ScheduledCompletion.view
      ({ width := 48, height := 14 } : Loam.Tui.Kernel.Bounds)
      knownLoci scrolled).lines.flatten.map Loam.Tui.Kernel.Cell.glyph)
  expect ((scrollText.splitOn "Plan reference").length > 1)
    "completion Actual review could not scroll to its unchanged Plan reference"
  let allowed := Loam.Tui.ScheduledCompletion.updateForBounds roomy
    initialWorld knownLoci refused.state .enter
  expect (allowed.publish.isSome && allowed.state.target == editor.target)
    "completion resize lost the exact Scheduled target or allowed Actual draft"
  let intentStep := Loam.Tui.ScheduledCompletion.update
    initialWorld ["paypay", "rent", "food"] previewState .enter
  let completionIntent ← requireSome intentStep.publish
    "completion preview did not emit shared publisher intent"
  expect (completionIntent.scheduled.token == "scheduled-1")
    "completion editor lost selected Scheduled identity"
  let .ok () ← Loam.ScheduledTerminalPublisher.publishHouseholdCompletion
      root completionIntent
    | throw (IO.userError "publish selected Scheduled completion")
  let .ok completionLifecycle ← Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? root
    | throw (IO.userError "reload canonical Household Scheduled lifecycle after completion")
  let completionActual ← requireSome
    (completionLifecycle.terminals.completionActualFor? completionIntent.scheduled)
    "canonical Scheduled completion relation lost its Actual endpoint"

  let afterCompletion ← loadSnapshot root
  let afterCompletionScheduled ← requireScheduled afterCompletion
  let .ok dueAfterCompletionEvidence :=
      Loam.ScheduledReview.dayEvidence afterCompletionScheduled "2026-09-10"
    | throw (IO.userError "Scheduled day evidence refused valid post-completion frontier")
  let dueAfterCompletion := Loam.ScheduledReview.explicitDueRecords dueAfterCompletionEvidence
  expect (!hasScheduled dueAfterCompletion "scheduled-1" &&
      hasScheduled dueAfterCompletion "scheduled-2" &&
      hasScheduled dueAfterCompletion "scheduled-3")
    "fresh Scheduled read did not close only the completed occurrence"
  let actualDay := Loam.ActualReview.select afterCompletion.actual.allRecords (.day "2026-09-08")
  expect (actualDay.any fun record =>
      record.event.id == completionActual &&
        record.event.effects.map (fun effect => effect.quantity.quanta) == [-1000, 1000])
    "completion did not publish canonical Actual evidence through shared Actual authority"

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
  -- UI-18: exact retained target and effect lines must remain reviewable on
  -- compact terminals, while Keep/Cancel stay visible at the bottom.
  let reviewState : Loam.Tui.ScheduledCancellation.State :=
    { cancelEditor with expected :=
        cancelEditor.expected ++ [String.ofList (List.replicate 90 'x'), "last-locus  +999 jpy"] }
  for bounds in
      ([ { width := 32, height := 9 },
         { width := 48, height := 14 },
         { width := 80, height := 24 } ] : List Loam.Tui.Kernel.Bounds) do
    let widget := Loam.Tui.ScheduledCancellation.view bounds reviewState
    let glyphs := String.ofList (widget.lines.flatten.map Loam.Tui.Kernel.Cell.glyph)
    expect (widget.lines.length <= bounds.height - 1 &&
        (glyphs.splitOn "Expected effects").length > 1 &&
        (glyphs.splitOn "Keep").length > 1)
      "Scheduled cancellation lost review panel or protective action"
    expect (widget.lines.any fun row => row.any fun cell => cell.style == .selected)
      "Scheduled cancellation no longer highlights protective Keep"
    for row in widget.lines do
      expect (Loam.Tui.Layout.displayWidth
        (String.ofList (row.map Loam.Tui.Kernel.Cell.glyph)) <=
        Loam.Tui.Layout.contentWidth bounds)
        "Scheduled cancellation review overflowed physical terminal width"
    let endState := (Loam.Tui.ScheduledCancellation.updateForBounds
      bounds reviewState .«end»).state
    let endText := String.ofList
      ((Loam.Tui.ScheduledCancellation.view bounds endState).lines.flatten.map
        Loam.Tui.Kernel.Cell.glyph)
    expect ((endText.splitOn "last-locus").length > 1)
      "Scheduled cancellation could not scroll to its final expected posting"
  let tinyBounds : Loam.Tui.Kernel.Bounds := { width := 32, height := 6 }
  let armedForTiny := (Loam.Tui.ScheduledCancellation.update cancelEditor .tab).state
  let unsafeEnter := Loam.Tui.ScheduledCancellation.updateForBounds
    tinyBounds armedForTiny .enter
  expect (unsafeEnter.publish.isNone &&
      (unsafeEnter.state.notice.splitOn "Enlarge terminal").length > 1)
    "Scheduled cancellation published without room to inspect expected effects"
  let recoveredEnter := Loam.Tui.ScheduledCancellation.updateForBounds
    ({ width := 48, height := 14 } : Loam.Tui.Kernel.Bounds)
    unsafeEnter.state .enter
  expect (recoveredEnter.publish.isSome &&
      recoveredEnter.state.target == cancelEditor.target)
    "resized cancellation review lost its exact target or confirmation action"
  let kept := Loam.Tui.ScheduledCancellation.update cancelEditor .enter
  expect (kept.cancel && kept.publish.isNone)
    "default cancellation confirmation retired the occurrence"
  let armed := Loam.Tui.ScheduledCancellation.update cancelEditor .tab
  expect (armed.state.choice.val == 0)
    "cancellation confirmation could not select explicit retirement"
  let cancelIntentStep := Loam.Tui.ScheduledCancellation.update armed.state .enter
  let cancelIntent ← requireSome cancelIntentStep.publish
    "explicit cancellation confirmation did not emit publisher intent"
  let .ok () ← Loam.ScheduledTerminalPublisher.publishHouseholdCancellation
      root cancelIntent
    | throw (IO.userError "publish selected Scheduled cancellation")

  let afterCancellation ← loadSnapshot root
  let afterCancellationScheduled ← requireScheduled afterCancellation
  let .ok afterCancellationDayEvidence :=
      Loam.ScheduledReview.dayEvidence afterCancellationScheduled "2026-09-10"
    | throw (IO.userError "Scheduled day evidence refused valid post-cancellation frontier")
  let explicitAfterCancellation :=
    Loam.ScheduledReview.explicitDueRecords afterCancellationDayEvidence
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

  -- The replacement editor now uses the same *admitted-token* picker as
  -- Record and Scheduled creation, with its own focus and publisher state.
  let replacementKnown := ["paypay", "rent", "food"]
  let emptyLocus : Loam.Tui.ScheduledReplacement.State := {
    replacementEditor with
    form := { replacementEditor.form with
      focus := 1
      rows := #[{ locus := "", amount := "-300" },
                { locus := "rent", amount := "300" }] } }
  let highlighted := (Loam.Tui.ScheduledReplacement.update
    replacementKnown emptyLocus .down).state
  expect (highlighted.candidateIndex == 1 &&
    highlighted.form.rows[0]!.locus.isEmpty)
    "highlighting replacement candidate unexpectedly changed input"
  let picked := (Loam.Tui.ScheduledReplacement.update
    replacementKnown highlighted .enter).state
  expect (picked.form.rows[0]!.locus == "rent" && picked.form.focus == 2 &&
    picked.candidateIndex == 0)
    "replacement Enter failed to commit highlighted Locus and move to Amount"
  let pickedText := String.ofList
    ((Loam.Tui.ScheduledReplacement.view replacementKnown picked).lines.flatten.map
      Loam.Tui.Kernel.Cell.glyph)
  expect ((pickedText.splitOn "Posting 1: rent").length > 1)
    "replacement selected Locus was not rendered in the Posting field"
  let right := (Loam.Tui.ScheduledReplacement.update
    replacementKnown highlighted .right).state
  expect (right.form.rows[0]!.locus == "rent" && right.form.focus == 1)
    "replacement Right should commit candidate without changing focus"
  let tabbed := (Loam.Tui.ScheduledReplacement.update
    replacementKnown highlighted .tab).state
  expect (tabbed.form.rows[0]!.locus.isEmpty && tabbed.form.focus == 2)
    "replacement Tab unexpectedly committed a selected candidate"
  let partialLocus : Loam.Tui.ScheduledReplacement.State := {
    emptyLocus with form := { emptyLocus.form with rows := #[
      { locus := "fo", amount := "-300" }, { locus := "rent", amount := "300" }] } }
  let completed := (Loam.Tui.ScheduledReplacement.update
    replacementKnown partialLocus .enter).state
  expect (completed.form.rows[0]!.locus == "food" && completed.form.focus == 2)
    "replacement Enter failed to accept filtered candidate"
  let exact : Loam.Tui.ScheduledReplacement.State := {
    emptyLocus with form := { emptyLocus.form with rows := #[
      { locus := "paypay", amount := "-300" }, { locus := "rent", amount := "300" }] } }
  let exactEntered := (Loam.Tui.ScheduledReplacement.update
    replacementKnown exact .enter).state
  expect (exactEntered.form.rows[0]!.locus == "paypay" &&
    exactEntered.form.focus == 2)
    "replacement Enter rewrote an exact admitted Locus"
  let unknown : Loam.Tui.ScheduledReplacement.State := {
    emptyLocus with form := { emptyLocus.form with rows := #[
      { locus := "historical-only", amount := "-300" },
      { locus := "rent", amount := "300" }] } }
  let unknownEntered := (Loam.Tui.ScheduledReplacement.update
    replacementKnown unknown .enter).state
  expect (unknownEntered.form.rows[0]!.locus == "historical-only" &&
    unknownEntered.form.focus == 2)
    "replacement completion silently rewrote a historical-only Locus"
  let cancelled := Loam.Tui.ScheduledReplacement.update
    replacementKnown picked .escape
  expect (cancelled.cancel && cancelled.publish.isNone)
    "replacement chooser cancellation requested a publication"

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
      Loam.ScheduledOccurrenceConstruction.positiveTotalQuanta
        replacementIntent.movement == 300)
    "replacement editor lost selected source or edited content"
  let .ok () ← Loam.ScheduledReplacementPublisher.publishHousehold
      root replacementIntent
    | throw (IO.userError "publish selected Scheduled replacement")

  let .ok lifecycle ←
      Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? root
    | throw (IO.userError "reload Household lifecycle after replacement")
  let some replacementId :=
      ScheduledTerminalMemory.replacementFor? lifecycle.terminals replacementIntent.source
    | throw (IO.userError "find replacement endpoint from canonical lifecycle relation")

  let afterReplacement ← loadSnapshot root
  let afterReplacementScheduled ← requireScheduled afterReplacement
  let .ok oldDayEvidence :=
      Loam.ScheduledReview.dayEvidence afterReplacementScheduled "2026-09-10"
    | throw (IO.userError "Scheduled day evidence refused valid old replacement day")
  let .ok newDayEvidence :=
      Loam.ScheduledReview.dayEvidence afterReplacementScheduled "2026-09-12"
    | throw (IO.userError "Scheduled day evidence refused valid new replacement day")
  let oldDay := Loam.ScheduledReview.explicitDueRecords oldDayEvidence
  let newDay := Loam.ScheduledReview.explicitDueRecords newDayEvidence
  expect oldDay.isEmpty
    "fresh Scheduled read retained completed, cancelled, or superseded sources on the old day"
  expect
    (newDay.length == 1 &&
      hasScheduled newDay replacementId.token &&
      !hasScheduled newDay "scheduled-3")
    "fresh Scheduled read did not expose only the replacement endpoint on its edited day"
  let refreshed := Loam.Tui.SelectedDay.refreshed afterReplacement replacementState
  expect (refreshed.focusDate == "2026-09-10" && refreshed.scheduledRow == 0)
    "Scheduled write moved the selected-day coordinate instead of only clamping local selection"

  let some usdReplacementMovement := BalancedMovement.ofChanges? ⟨"usd"⟩
      [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-40) }
      , { coordinate := ⟨"food"⟩, quantity := Quantity.ofQuanta 40 } ]
    | throw (IO.userError "USD replacement fixture")
  let usdReplacementSource : ScheduledOccurrence String := {
    id := ⟨"scheduled-usd"⟩
    scheduledOn := "2026-09-20"
    movement := usdReplacementMovement }
  let .ok usdReplacementEditor := Loam.Tui.ScheduledReplacement.initial? usdReplacementSource
    | throw (IO.userError "initialize USD Scheduled replacement editor")
  let .ok usdReplacementDraft := Loam.Tui.ScheduledReplacement.draft? usdReplacementEditor
    | throw (IO.userError "build USD Scheduled replacement draft")
  expect
    (usdReplacementEditor.measure == ⟨"usd"⟩ &&
      usdReplacementDraft.movement.measure == ⟨"usd"⟩)
    "Scheduled replacement did not preserve a non-JPY Measure"

  IO.println "TUI Scheduled terminal: canonical completion endpoint, safe cancellation, editable supersede, shared publication and fresh reads passed."
