import Loam.Tests.ActualWorldFixture
import Loam.Authority.ActualAuthority
import Loam.MovementWorldLoader
import Loam.Tui.ActualDateCorrection
import Loam.Review.ActualReview
import Loam.Publisher.CorrectionPublisher
import Loam.Publisher.MovementPublisher

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
  let some vocabulary := LocusAdmissionVocabulary.ofLoci? [⟨"paypay"⟩, ⟨"coffee"⟩]
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

private def effects (amount : Int) : List Effect :=
  [ Effect.ofQuantity ⟨"effect-1"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount))
  , Effect.ofQuantity ⟨"effect-2"⟩ ⟨"coffee"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
  ]

private def recordDraft : Loam.MovementAdmission.Draft := {
  validOn := "2026-09-07"
  description := some "coffee"
  effects := effects 640
  relations := []
  discharges := []
  total := 640 }

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let root := System.FilePath.mk dataPath
  let initial ← emptyWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root initial
    | throw (IO.userError "initialize Actual fixture")
  let .ok recorded ← Loam.MovementPublisher.publishDraft root.toString recordDraft
    | throw (IO.userError "record target fixture")

  let .ok records ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "load initial Actual review")
  let record ← requireSome (Loam.ActualReview.select records (.day "2026-09-07")).head?
    "selected Actual fixture disappeared"
  let .ok editor := Loam.Tui.ActualDateCorrection.initial? record
    | throw (IO.userError "date editor did not accept dated current Actual")
  expect (editor.target == recorded && editor.input == "2026-09-07")
    "date editor lost target or visible current date"
  for bounds in [({width := 32, height := 9} : Loam.Tui.Kernel.Bounds),
      {width := 48, height := 14}, {width := 80, height := 24}, {width := 120, height := 40}] do
    let widget := Loam.Tui.ActualDateCorrection.viewForBounds bounds editor
    let markers := widget.lines.flatten.filter (·.caret)
    expect (markers.length == 1 && markers.all (fun cell => cell.glyph == ' '))
      "Actual date editing lost its insertion blank during resize"
    expect (widget.lines.any fun cells => cells.any (·.caret) &&
      contains "New date:" (String.ofList (cells.map (·.glyph))))
      "Actual date caret escaped its field"
    let preview := Loam.Tui.ActualDateCorrection.update editor .enter
    expect (preview.publish.isNone &&
      !(Loam.Tui.ActualDateCorrection.viewForBounds bounds preview.state).lines.flatten.any (·.caret))
      "Actual date preview published early or retained a text caret"
    let returned := Loam.Tui.ActualDateCorrection.update preview.state .escape
    let refused := Loam.Tui.ActualDateCorrection.withPublishError preview.state "Refused"
    for editing in [returned.state, refused] do
      expect (editing.input == editor.input &&
        ((Loam.Tui.ActualDateCorrection.viewForBounds bounds editing).lines.flatten.filter (·.caret)).length == 1)
        "Actual date review return/refusal lost draft or focused input"
    expect ((Loam.Tui.ActualDateCorrection.update editor (.paste "ignored")).state.input == editor.input)
      "Actual date changed historically unsupported paste"
    let cancel := Loam.Tui.ActualDateCorrection.update editor .escape
    expect (cancel.cancel && cancel.publish.isNone) "Actual date cancellation emitted a write"
  -- Confirm the target, both dates, focused value and bounded physical frame.
  for bounds in [({ width := 48, height := 14 } : Loam.Tui.Kernel.Bounds),
      { width := 80, height := 24 }, { width := 120, height := 40 }] do
    let widget := Loam.Tui.ActualDateCorrection.view bounds editor
    let glyphs := String.ofList (widget.lines.flatten.map Loam.Tui.Kernel.Cell.glyph)
    expect (contains "Current date" glyphs && contains "New date" glyphs &&
      contains "2026-09-07" glyphs && contains recorded.token glyphs)
      "date editor lost its original date, editable date or exact target"
    expect (widget.lines.length <= bounds.height - 1)
      "date editor exceeded the writable terminal height"
    for cells in widget.lines do
      expect (Loam.Tui.Layout.displayWidth (String.ofList
        (cells.map Loam.Tui.Kernel.Cell.glyph)) <= Loam.Tui.Layout.contentWidth bounds)
        "date editor exceeded the writable terminal width"
    expect (widget.lines.any fun cells =>
      cells.any fun cell => cell.style == .selected && cell.glyph == '2')
      "date editor lost highlighted editable date"

  -- The same editor floats only when it fits, without changing retained input.
  let roomy : Loam.Tui.Kernel.Bounds := { width := 120, height := 40 }
  let some rectangle := Loam.Tui.ActualDateCorrection.floatingGeometry? roomy
    | throw (IO.userError "date editor did not float at roomy bounds")
  expect (rectangle.width == 76 && rectangle.height == 18 &&
      rectangle.top == 11 && rectangle.left == 21)
    "date editor did not use centered shared modal geometry"
  let floating := Loam.Tui.ActualDateCorrection.viewForBounds roomy editor
  expect (floating.lines.length == rectangle.height)
    "floating date form escaped its modal height"
  let floatingText := String.ofList (floating.lines.flatten.map Loam.Tui.Kernel.Cell.glyph)
  expect (contains recorded.token floatingText && contains "Current date" floatingText &&
      contains "New date" floatingText)
    "floating date form lost its immutable target or both dates"
  for cells in floating.lines do
    expect (Loam.Tui.Layout.displayWidth (String.ofList
      (cells.map Loam.Tui.Kernel.Cell.glyph)) == rectangle.width)
      "floating date form escaped its panel width"
  for tiny in [({ width := 48, height := 14 } : Loam.Tui.Kernel.Bounds),
      { width := 32, height := 9 }, { width := 10, height := 1 }] do
    expect ((Loam.Tui.ActualDateCorrection.floatingGeometry? tiny).isNone)
      "compact date editor unexpectedly floated"
    let compact := Loam.Tui.ActualDateCorrection.viewForBounds tiny editor
    expect (compact.lines == (Loam.Tui.ActualDateCorrection.view tiny editor).lines)
      "compact date editor changed the existing visible contract"
    expect (compact.lines.length <= tiny.height - 1)
      "compact date editor exceeded writable terminal rows"

  let erased := (Loam.Tui.ActualDateCorrection.update editor .backspace).state
  let typed := (Loam.Tui.ActualDateCorrection.update erased (.input '6')).state
  expect (typed.input == "2026-09-06")
    "date editor did not keep editing presentation-local"
  let preview := Loam.Tui.ActualDateCorrection.update typed .enter
  expect (preview.state.mode == .preview && preview.publish.isNone)
    "valid date did not require a separate preview before publication"
  let review := Loam.Tui.ActualDateCorrection.view
    { width := 48, height := 14 } preview.state
  let reviewText := String.ofList (review.lines.flatten.map Loam.Tui.Kernel.Cell.glyph)
  expect (contains "Proposed date" reviewText && contains "Publish date change" reviewText &&
    contains "2026-09-06" reviewText && contains recorded.token reviewText)
    "date preview lost its date, target or explicit confirmation"
  let refused := Loam.Tui.ActualDateCorrection.withPublishError preview.state "Recheck refused"
  let refusedText := String.ofList ((Loam.Tui.ActualDateCorrection.view
    { width := 48, height := 14 } refused).lines.flatten.map Loam.Tui.Kernel.Cell.glyph)
  expect (refused.mode == .editing && contains "Recheck refused" refusedText)
    "publication refusal did not return to the edit mode with visible notice"
  -- Unreadable compact reviews must refuse Enter rather than silently publish.
  for tiny in [({ width := 32, height := 9 } : Loam.Tui.Kernel.Bounds),
      { width := 10, height := 1 }] do
    let hidden := Loam.Tui.ActualDateCorrection.updateForBounds tiny preview.state .enter
    expect (hidden.publish.isNone && hidden.state.input == "2026-09-06" &&
        hidden.state.target == recorded && hidden.state.mode == .preview &&
        contains "Enlarge terminal" hidden.state.notice)
      "compact date review emitted hidden publication or lost retained draft"
  let publish := Loam.Tui.ActualDateCorrection.updateForBounds
    { width := 120, height := 40 } preview.state .enter
  let dateDraft ← requireSome publish.publish "date preview did not emit publication intent"
  expect (dateDraft.target == recorded && dateDraft.validOn == "2026-09-06")
    "date editor intent changed target or date"

  let .ok () ← Loam.ActualValidityPublisher.publishDate root.toString dateDraft
    | throw (IO.userError "shared date publisher refused TUI intent")

  let .ok fresh ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "fresh Actual review reload")
  expect ((Loam.ActualReview.select fresh (.day "2026-09-07")).isEmpty)
    "old selected day still exposed the moved Actual"
  let moved := Loam.ActualReview.select fresh (.day "2026-09-06")
  expect (moved.length == 1 && moved.any fun item => item.event.id == recorded)
    "new date did not expose the moved Actual"

  let .ok worldAfterDate ← Loam.MovementWorldLoader.loadSelectedWorld? root
    | throw (IO.userError "reload world after date correction")
  expect ((EventMemory.findById? worldAfterDate.events recorded).isSome)
    "date correction rewrote or removed Event payload"

  let staleIntent : Loam.ActualValidityPublisher.Draft := {
    target := recorded
    validOn := "2026-09-05" }
  let .ok () ← Loam.CorrectionPublisher.publishCorrection
      root.toString {
        target := recorded
        effects := effects 650
        description := some "corrected coffee" }
    | throw (IO.userError "movement correction fixture")
  let .ok actualEvidence ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload actual authority")
  let some correction := actualEvidence.corrections.corrections.find?
      (fun correction => correction.target == recorded)
    | throw (IO.userError "find correction relation for target")
  let replacementId := correction.replacement
  let stale ← Loam.ActualValidityPublisher.publishDate root.toString staleIntent
  expect (!stale.isOk) "stale TUI date intent bypassed publisher currentness re-check"

  let .ok replacementRecords ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "reload replacement review")
  expect (replacementRecords.any fun item =>
      item.event.id == replacementId && item.date == some "2026-09-06" && item.isCurrent)
    "Movement correction stopped carrying the current date after TUI date correction"

  IO.println "TUI Actual date: local edit/preview, shared publication, fresh move and stale-intent rejection passed."
