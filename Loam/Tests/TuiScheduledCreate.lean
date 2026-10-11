import Loam.Tests.ActualWorldFixture
import Loam.Review.ActualReview
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Publisher.ScheduledCreationPublisher
import Loam.Review.ScheduledReview
import Loam.Tui.ScheduledCreation
import Loam.Tui.ScheduledCoverageSetup
import Loam.Tui.SelectedDay
import Lean.Elab.Tactic.Omega

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

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
  -- UI-16 input: every focused posting remains visible, including the sixth
  -- row on compact terminals. Field selection never mutates household evidence.
  let many : Array Loam.Tui.Record.Row :=
    #[ { locus := "paypay", amount := "-1" },
       { locus := "food", amount := "1" },
       { locus := "paypay", amount := "-2" },
       { locus := "food", amount := "2" },
       { locus := "paypay", amount := "-3" },
       { locus := "last-locus", amount := "987654321" } ]
  let manyEditor : Loam.Tui.ScheduledCreation.State := {
    editor with form := { editor.form with rows := many, focus := 12 } }
  for bounds in
      ([ { width := 32, height := 10 },
         { width := 48, height := 14 },
         { width := 80, height := 24 },
         { width := 140, height := 40 } ] : List Loam.Tui.Kernel.Bounds) do
    let image := Loam.Tui.ScheduledCreation.view bounds [] manyEditor
    let glyphs := String.ofList (image.lines.flatten.map Loam.Tui.Kernel.Cell.glyph)
    expect (image.lines.length <= bounds.height - 1)
      "Scheduled input editor exceeded terminal height"
    for cells in image.lines do
      expect (Loam.Tui.Layout.displayWidth
        (String.ofList (cells.map Loam.Tui.Kernel.Cell.glyph)) <=
        Loam.Tui.Layout.contentWidth bounds)
        "Scheduled input editor exceeded terminal width"
    expect (contains "987654321" glyphs)
      "Scheduled input did not keep the last focused posting amount visible"
    expect (contains "[Preview]" glyphs && contains "[Cancel]" glyphs)
      "Scheduled input clipped its fixed action choices"

  let catalog : Loam.LocusCatalog.Catalog :=
    [ { locus := ⟨"paypay"⟩, label := "電子マネー", help := "支払元" },
      { locus := ⟨"food"⟩, label := "食費", help := "食料品" } ]
  let locusEditor := Loam.Tui.ScheduledCreation.withCatalog
    { editor with form := { editor.form with focus := 1 } } catalog
  let regular : Loam.Tui.Kernel.Bounds := { width := 80, height := 24 }
  let firstImage := Loam.Tui.ScheduledCreation.view regular [] locusEditor
  let firstText := String.ofList
    (firstImage.lines.flatten.map Loam.Tui.Kernel.Cell.glyph)
  expect (contains "Locus candidates" firstText &&
    contains "paypay" firstText && contains "food" firstText)
    "regular Scheduled input did not expose admitted candidates"
  let moved := (Loam.Tui.ScheduledCreation.update [] locusEditor .down).state
  let movedImage := Loam.Tui.ScheduledCreation.view regular [] moved
  expect (firstImage.lines.length == movedImage.lines.length)
    "candidate selection caused the Scheduled editor to jump vertically"
  -- UI-16: Enter commits the highlighted Locus before advancing to Amount,
  -- matching ordinary Record. Candidate movement alone and Tab do not commit.
  let highlighted ← requireSome
    (Loam.Tui.LocusPicker.selected? catalog "" moved.candidateIndex)
    "Scheduled editor had no selected Locus candidate"
  let entered := (Loam.Tui.ScheduledCreation.update [] moved .enter).state
  expect (entered.form.rows[0]!.locus == highlighted.locus.token &&
    entered.form.focus == 2 && entered.candidateIndex == 0)
    "Enter skipped highlighted Scheduled Locus without writing it to Posting"
  let enteredImage := Loam.Tui.ScheduledCreation.view regular [] entered
  let enteredText := String.ofList
    (enteredImage.lines.flatten.map Loam.Tui.Kernel.Cell.glyph)
  expect (contains ("Posting 1" ++
    Loam.Tui.Layout.padRight 15 "Posting 1: " ++
    highlighted.locus.token) enteredText)
    "chosen Scheduled Locus was not visible in the Posting field"
  let tabbed := (Loam.Tui.ScheduledCreation.update [] moved .tab).state
  expect (tabbed.form.rows[0]!.locus.isEmpty && tabbed.form.focus == 2)
    "Tab unexpectedly committed the highlighted Scheduled candidate"
  let rightAccepted := (Loam.Tui.ScheduledCreation.update [] moved .right).state
  expect (rightAccepted.form.rows[0]!.locus == highlighted.locus.token &&
    rightAccepted.form.focus == 1)
    "Right no longer accepts the Scheduled candidate in place"
  let partiallyTyped : Loam.Tui.ScheduledCreation.State := {
    locusEditor with form := { locusEditor.form with rows :=
      #[{ locus := "fo", amount := "" }, {}] } }
  let completed := (Loam.Tui.ScheduledCreation.update [] partiallyTyped .enter).state
  expect (completed.form.rows[0]!.locus == "food" && completed.form.focus == 2)
    "Enter did not complete the filtered Scheduled Locus"
  let exact : Loam.Tui.ScheduledCreation.State := {
    locusEditor with form := { locusEditor.form with rows :=
      #[{ locus := "paypay", amount := "" }, {}] } }
  let exactResult := (Loam.Tui.ScheduledCreation.update [] exact .enter).state
  expect (exactResult.form.rows[0]!.locus == "paypay" &&
    exactResult.form.focus == 2)
    "Enter replaced an already exact Scheduled Locus"
  let unknown : Loam.Tui.ScheduledCreation.State := {
    locusEditor with form := { locusEditor.form with rows :=
      #[{ locus := "not-in-catalog", amount := "" }, {}] } }
  let unknownResult := (Loam.Tui.ScheduledCreation.update [] unknown .enter).state
  expect (unknownResult.form.rows[0]!.locus == "not-in-catalog" &&
    unknownResult.form.focus == 2)
    "Enter erased a Scheduled Locus when no candidate was available"
  let editedAction : Loam.Tui.ScheduledCreation.State := {
    manyEditor with form := { manyEditor.form with focus := 15 } }
  let actionText := String.ofList
    ((Loam.Tui.ScheduledCreation.view
      ({ width := 48, height := 14 } : Loam.Tui.Kernel.Bounds)
      [] editedAction).lines.flatten.map Loam.Tui.Kernel.Cell.glyph)
  expect (contains "[Preview]" actionText)
    "Scheduled input hid the Preview action after six rows"

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
  expect (contains "Scheduled / New / Preview" previewText &&
    contains "Expected postings" previewText &&
    contains "2026-09-12" previewText &&
    contains "-700 jpy" previewText && contains "+700 jpy" previewText &&
    contains "Publish Scheduled" previewText)
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
  expect (blocked.publish.isNone && contains "Enlarge terminal" blocked.state.notice)
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
  expect (contains "Balanced total" endText)
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
  -- Optional pace selection after creation changes only the monitoring
  -- intention. It cannot publish a second Scheduled or infer recurrence.
  let pace : Loam.Tui.ScheduledCoverageSetup.CreatedPaceState := {
    source := createdRecord }
  let onceStep := Loam.Tui.ScheduledCoverageSetup.updateCreatedPace
    pace .enter
  match onceStep.action with
  | some .keepOne => pure ()
  | _ => throw (IO.userError "new Scheduled pace was not one-off by default")
  let skipped := Loam.Tui.ScheduledCoverageSetup.updateCreatedPace pace .escape
  match skipped.action with
  | some .keepOne => pure ()
  | _ => throw (IO.userError "Esc did not preserve existing monitoring")
  for (index, months) in
      ([(1, 1), (2, 2), (3, 3), (4, 6), (5, 12)] : List (Nat × Nat)) do
    let selected := { pace with selection := index }
    match (Loam.Tui.ScheduledCoverageSetup.updateCreatedPace
      selected .enter).action with
    | some (.save value) =>
        expect (value == months) "new Scheduled pace selected wrong cadence"
    | _ => throw (IO.userError "new Scheduled pace did not offer monitoring")
  let undecided := { pace with selection := 6 }
  match (Loam.Tui.ScheduledCoverageSetup.updateCreatedPace
    undecided .enter).action with
  | some .undecided => pure ()
  | _ => throw (IO.userError "new Scheduled pace could not remain undecided")
  for bounds in
      ([ { width := 32, height := 9 },
         { width := 48, height := 14 },
         { width := 80, height := 24 } ] : List Loam.Tui.Kernel.Bounds) do
    let widget := Loam.Tui.ScheduledCoverageSetup.viewCreatedPace bounds undecided
    let glyphs := String.ofList
      (widget.lines.flatten.map Loam.Tui.Kernel.Cell.glyph)
    expect (widget.lines.length <= bounds.height - 1 &&
      contains "Expected pace" glyphs)
      "post-creation pace chooser was clipped on a short terminal"
    for cells in widget.lines do
      expect (Loam.Tui.Layout.displayWidth
        (String.ofList (cells.map Loam.Tui.Kernel.Cell.glyph)) <=
        Loam.Tui.Layout.contentWidth bounds)
        "post-creation pace chooser exceeded terminal width"
  let .ok twoMonthRule :=
    Loam.Tui.ScheduledCoverageSetup.ruleFor? createdRecord 2
    | throw (IO.userError "post-creation pace could not build rule")
  expect (twoMonthRule.everyMonths == 2 &&
    twoMonthRule.anchor == createdRecord.scheduledOn &&
    twoMonthRule.negativeLoci == ["paypay"] &&
    twoMonthRule.positiveLoci == ["food"])
    "post-creation monitoring changed source or signed-Locus shape"

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
