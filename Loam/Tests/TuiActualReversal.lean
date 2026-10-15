import Loam.Tests.ActualWorldFixture
import Loam.Authority.ActualAuthority
import Loam.Review.ActualReview
import Loam.Publisher.ActualReversalPublisher
import Loam.Publisher.MovementPublisher
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Tui.ActualReversal

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

private def emptyLifecycle : IO Loam.Persistence.ScheduledLifecycleImage := do
  let some scheduled := ScheduledMemory.ofOccurrences? []
    | throw (IO.userError "empty Scheduled memory")
  let some terminals := ScheduledTerminalMemory.ofTerminals? []
    | throw (IO.userError "empty Scheduled terminal memory")
  return { scheduled, terminals }

private def recordDraft : Loam.MovementAdmission.Draft := {
  validOn := "2026-09-07"
  description := some "coffee"
  effects :=
    [ Effect.ofQuantity ⟨"effect-1"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-640))
    , Effect.ofQuantity ⟨"effect-2"⟩ ⟨"coffee"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 640) ]
  relations := []
  discharges := []
  total := 640 }

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let root := dataDir
  let initial ← emptyWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root initial
    | throw (IO.userError "initialize Actual fixture")
  let lifecycle ← emptyLifecycle
  let lifecycleBody ← requireSome
    (Loam.Persistence.encodeScheduledLifecycleImage? lifecycle)
    "encode Scheduled lifecycle"
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "Scheduled" lifecycleBody
    | throw (IO.userError "initialize Household Scheduled lifecycle")
  let .ok recorded ← Loam.MovementPublisher.publishDraft root.toString recordDraft
    | throw (IO.userError "record target fixture")

  let .ok records ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "load target Actual review")
  let record ← requireSome (Loam.ActualReview.select records (.day "2026-09-07")).head?
    "selected Actual fixture disappeared"
  let .ok editor := Loam.Tui.ActualReversal.initial? record "2026-09-08"
    | throw (IO.userError "reversal editor rejected practical Actual")
  expect (editor.target == recorded && editor.inputDate == "2026-09-08")
    "reversal editor did not keep selected target and today as independent coordinates"
  for bounds in [({width := 32, height := 9} : Loam.Tui.Kernel.Bounds),
      {width := 48, height := 14}, {width := 80, height := 24}, {width := 120, height := 40}] do
    let widget := Loam.Tui.ActualReversal.viewForBounds bounds editor
    let markers := widget.lines.flatten.filter (·.caret)
    expect (markers.length == 1 && markers.all (fun cell => cell.glyph == ' '))
      "Reversal date editing lost its insertion blank during resize"
    expect (widget.lines.any fun cells => cells.any (·.caret) &&
      contains "Reversal date:" (String.ofList (cells.map (·.glyph))))
      "Reversal caret escaped its date field"
    let preview := Loam.Tui.ActualReversal.update editor .enter
    expect (preview.publish.isNone &&
      !(Loam.Tui.ActualReversal.viewForBounds bounds preview.state).lines.flatten.any (·.caret))
      "Reversal preview published early or retained a caret"
    let returned := Loam.Tui.ActualReversal.update preview.state .escape
    let refused := Loam.Tui.ActualReversal.withPublishError preview.state "Refused"
    for editing in [returned.state, refused] do
      expect (editing.inputDate == editor.inputDate &&
        ((Loam.Tui.ActualReversal.viewForBounds bounds editing).lines.flatten.filter (·.caret)).length == 1)
        "Reversal return/refusal lost draft or focused input"
    expect ((Loam.Tui.ActualReversal.update editor (.paste "ignored")).state.inputDate == editor.inputDate)
      "Reversal changed historically unsupported paste"
    let cancel := Loam.Tui.ActualReversal.update editor .escape
    expect (cancel.cancel && cancel.publish.isNone) "Reversal cancellation emitted a write"
  for bounds in [({ width := 48, height := 14 } : Loam.Tui.Kernel.Bounds),
      { width := 80, height := 24 }, { width := 120, height := 40 }] do
    let widget := Loam.Tui.ActualReversal.view bounds editor
    let glyphs := String.ofList (widget.lines.flatten.map Loam.Tui.Kernel.Cell.glyph)
    expect (contains "Target date" glyphs && contains "Reversal date" glyphs &&
      contains recorded.token glyphs && contains "2026-09-08" glyphs)
      "reversal date editor lost target or editable date"
    expect (widget.lines.length <= bounds.height - 1)
      "reversal date editor exceeded terminal height"
    for cells in widget.lines do
      expect (Loam.Tui.Layout.displayWidth (String.ofList
        (cells.map Loam.Tui.Kernel.Cell.glyph)) <= Loam.Tui.Layout.contentWidth bounds)
        "reversal date editor exceeded terminal width"

  let some usdEvent := Event.ofEffects? ⟨"usd-actual"⟩
      [ Effect.ofQuantity ⟨"usd-effect-1"⟩ ⟨"paypay"⟩ ⟨"usd"⟩ (Quantity.ofQuanta (-25))
      , Effect.ofQuantity ⟨"usd-effect-2"⟩ ⟨"coffee"⟩ ⟨"usd"⟩ (Quantity.ofQuanta 25)
      ]
    | throw (IO.userError "USD reversal editor Event fixture")
  let usdRecord : Loam.ActualReview.Record := {
    event := usdEvent
    date := some "2026-09-07"
    description := "USD coffee"
    replacement := none
  }
  let .ok usdEditor := Loam.Tui.ActualReversal.initial? usdRecord "2026-09-08"
    | throw (IO.userError "reversal editor rejected single-Measure USD Actual")
  let usdInverse := Loam.Tui.ActualReversal.inversePreview usdEditor
  expect (usdInverse.all fun (_, _, measure) => decide (measure = ⟨"usd"⟩))
    "reversal editor rewrote USD inverse preview as another Measure"

  let some mixedEvent := Event.ofEffects? ⟨"mixed-actual"⟩
      [ Effect.ofQuantity ⟨"mixed-effect-1"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-25))
      , Effect.ofQuantity ⟨"mixed-effect-2"⟩ ⟨"coffee"⟩ ⟨"usd"⟩ (Quantity.ofQuanta 25)
      ]
    | throw (IO.userError "mixed-Measure reversal editor Event fixture")
  let mixedRecord : Loam.ActualReview.Record := {
    event := mixedEvent
    date := some "2026-09-07"
    description := "mixed"
    replacement := none
  }
  expect (!(Loam.Tui.ActualReversal.initial? mixedRecord "2026-09-08").isOk)
    "reversal editor admitted a mixed-Measure Actual"

  -- The floating frame must preserve exact identity, dates and compact view.
  let roomy : Loam.Tui.Kernel.Bounds := { width := 120, height := 40 }
  let some rectangle := Loam.Tui.ActualReversal.floatingGeometry? roomy
    | throw (IO.userError "reversal editor did not float at roomy bounds")
  expect (rectangle.width == 76 && rectangle.height == 21 &&
      rectangle.top == 9 && rectangle.left == 21)
    "reversal floating geometry changed shared centered layout"
  let floating := Loam.Tui.ActualReversal.viewForBounds roomy editor
  let floatingText := String.ofList (floating.lines.flatten.map Loam.Tui.Kernel.Cell.glyph)
  expect (floating.lines.length == rectangle.height &&
    contains recorded.token floatingText &&
    contains "Target date" floatingText && contains "Reversal date" floatingText)
    "floating reversal lost its exact target or date summary"
  for cells in floating.lines do
    expect (Loam.Tui.Layout.displayWidth (String.ofList
      (cells.map Loam.Tui.Kernel.Cell.glyph)) == rectangle.width)
      "floating reversal overflowed its frame width"
  for tiny in [({ width := 48, height := 14 } : Loam.Tui.Kernel.Bounds),
      { width := 32, height := 9 }, { width := 10, height := 1 }] do
    expect ((Loam.Tui.ActualReversal.floatingGeometry? tiny).isNone)
      "compact reversal unexpectedly floated"
    let compact := Loam.Tui.ActualReversal.viewForBounds tiny editor
    expect (compact.lines == (Loam.Tui.ActualReversal.view tiny editor).lines &&
      compact.lines.length <= tiny.height - 1)
      "compact reversal changed its original visible contract"

  let inverse := Loam.Tui.ActualReversal.inversePreview editor
  expect (inverse.length == 2)
    "reversal preview lost postings"
  expect (inverse.any fun (locus, quantity, _) => locus.token == "paypay" && quantity.quanta == 640)
    "reversal preview did not negate PayPay posting"
  expect (inverse.any fun (locus, quantity, _) => locus.token == "coffee" && quantity.quanta == -640)
    "reversal preview did not negate coffee posting"

  let preview := Loam.Tui.ActualReversal.update editor .enter
  expect (preview.state.mode == .preview && preview.publish.isNone)
    "reversal did not require explicit preview before publication"
  let smallBounds : Loam.Tui.Kernel.Bounds := { width := 48, height := 14 }
  let review := Loam.Tui.ActualReversal.view smallBounds preview.state
  let reviewText := String.ofList (review.lines.flatten.map Loam.Tui.Kernel.Cell.glyph)
  expect (contains "Actual / Reverse / Preview" reviewText &&
    contains "Inverse postings" reviewText &&
    contains "+640 jpy" reviewText && contains "-640 jpy" reviewText &&
    contains "Original retained" reviewText && contains "Publish reversal" reviewText)
    "reversal review lost exact signed inverse or retained-original warning"
  expect (review.lines.length <= smallBounds.height - 1)
    "reversal Preview exceeded small terminal height"
  let tiny : Loam.Tui.Kernel.Bounds := { width := 32, height := 6 }
  let blocked := Loam.Tui.ActualReversal.updateForBounds tiny preview.state .enter
  expect (blocked.publish.isNone && blocked.state.mode == .preview)
    "tiny terminal published a reversal without visible inverse evidence"
  let expanded := Loam.Tui.ActualReversal.updateForBounds smallBounds preview.state .enter
  expect expanded.publish.isSome "adequate review viewport lost Enter publication"
  -- A too-small preview must recover when the active terminal becomes usable
  -- again. The resize-aware session passes the new bounds into this guard.
  let restored := Loam.Tui.ActualReversal.updateForBounds smallBounds blocked.state .enter
  expect (restored.publish.isSome && restored.state.target == recorded &&
    restored.state.inputDate == preview.state.inputDate)
    "resized reversal preview did not recover the same exact publication intent"
  let shrunkAgain := Loam.Tui.ActualReversal.updateForBounds tiny blocked.state .enter
  expect shrunkAgain.publish.isNone
    "re-shrinking reversal preview bypassed the current viewport publication guard"
  let firstEffect ← requireSome record.event.effects.head?
    "long inverse-preview fixture has no Effect"
  let repeated : Loam.Tui.ActualReversal.State := {
    preview.state with targetEffects := List.replicate 18 firstEffect }
  let limit := Loam.Tui.ActualReversal.previewScrollLimit smallBounds repeated
  expect (limit > 0) "long inverse preview did not admit scrolling"
  let jumped := (Loam.Tui.ActualReversal.updateForBounds smallBounds repeated .«end»).state
  expect (jumped.previewScroll == limit)
    "reversal End did not reach all postings"
  let back := (Loam.Tui.ActualReversal.updateForBounds smallBounds jumped .pageUp).state
  expect (back.previewScroll < jumped.previewScroll)
    "reversal PageUp did not scroll inverse review"
  let last := Loam.Tui.ActualReversal.view smallBounds jumped
  expect (last.lines.length <= smallBounds.height - 1)
    "scrolled long inverse review exceeded terminal height"
  let floated := Loam.Tui.ActualReversal.updateForBounds
    (Loam.Tui.ActualReversal.editorBounds roomy) preview.state .enter
  expect (floated.publish.isSome && floated.state.target == recorded)
    "floating reversal could not confirm its exact inverse after review"
  let publish := Loam.Tui.ActualReversal.update preview.state .enter
  let draft ← requireSome publish.publish "reversal preview did not emit publication intent"
  expect (draft.target == recorded && draft.validOn == "2026-09-08")
    "reversal intent changed target or occurrence date"

  let .ok () ← Loam.ActualReversalPublisher.publishHousehold root draft
    | throw (IO.userError "shared reversal publisher refused TUI intent")

  let .ok evidence ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload Actual authority after reversal")
  let relation ← requireSome (evidence.reversals.findByTarget? draft.target)
    "canonical reversal relation missing after TUI publication"

  let .ok fresh ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "fresh Actual review after reversal")
  expect (fresh.any fun item => item.event.id == recorded)
    "reversal removed the original Actual"
  expect (fresh.any fun item => item.event.id == relation.reversal && item.date == some "2026-09-08")
    "fresh Actual review did not expose the canonical reversal occurrence"

  let .ok rawReview := Loam.ActualReview.recordsFromActualEvidence? evidence
    | throw (IO.userError "raw reversal review")
  for review in [fresh, rawReview] do
    expect ((review.find? (·.event.id == recorded)).bind (·.reversedBy) == some relation.reversal &&
      (review.find? (·.event.id == relation.reversal)).bind (·.reversalOf) == some recorded)
      "Actual detail read projection lost explicit reversal endpoints"
    expect ((review.find? (·.event.id == recorded)).any (·.isCurrent))
      "reversal presentation changed correction-frontier currentness"

  let cancelled := Loam.Tui.ActualReversal.update editor .escape
  expect (cancelled.cancel && cancelled.publish.isNone)
    "Esc from reversal editor emitted publication"

  IO.println "TUI Actual reversal: today-seeded date, exact inverse preview, shared publication and retained original passed."
