import Loam.Tests.ActualWorldFixture
import Loam.Authority.ActualAuthority
import Loam.MovementWorldLoader
import Loam.Tui.Correction
import Loam.Tui.RecordSession
import Loam.Publisher.MovementPublisher
import Loam.Review.ActualReview
import Lean.Elab.Tactic.Omega

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def emptyWorld : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? [] | throw (IO.userError "empty events")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci?
      [⟨"paypay"⟩, ⟨"coffee"⟩, ⟨"receivable:counterparty"⟩]
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

private def recordDraft : Loam.MovementAdmission.Draft := {
  validOn := "2026-09-07"
  description := some "before"
  effects :=
    [ Effect.ofQuantity ⟨"effect-1"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-640))
    , Effect.ofQuantity ⟨"effect-2"⟩ ⟨"coffee"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 640)
    ]
  relations := []
  discharges := []
  total := 640 }

private def usdRecord? : Option Loam.Tui.Main.ReviewRecord := do
  let event ← Event.ofEffects? ⟨"non-jpy"⟩
    [ Effect.ofQuantity ⟨"effect-1"⟩ ⟨"paypay"⟩ ⟨"usd"⟩ (Quantity.ofQuanta (-1234))
    , Effect.ofQuantity ⟨"effect-2"⟩ ⟨"coffee"⟩ ⟨"usd"⟩ (Quantity.ofQuanta 1234)
    ]
  pure {
    event
    date := some "2026-09-07"
    description := "usd"
    replacement := none }

private def checkBoundedSurface (world : Loam.MovementAdmission.World)
    (editor : Loam.Tui.Correction.State) : IO Unit := do
  let bounds : Bounds := { width := 80, height := 24 }
  let opened := Loam.Tui.Correction.view bounds [] editor
  expect (contains "Correction / Edit" (widgetText opened) &&
    contains "Date (kept)" (widgetText opened) && !contains "C-o" (widgetText opened))
    "Correction shared input lost its fixed-date or Original suppression labels"
  let japanese := { editor with editor := { editor.editor with form :=
    { editor.editor.form with description := "修正" } } }
  expect (Loam.Tui.RecordSession.focusedCursorPosition? 0 0
    (Loam.Tui.Runtime.compileWidget (Loam.Tui.Correction.view bounds [] japanese)) == some (3, 18))
    "Correction did not place its CJK Description caret at the active field"
  let six : Loam.Tui.Record.Form := { editor.editor.form with
    rows := Array.replicate 6 {}, focus := ⟨1, by simp⟩ }
  for width in [48, 80, 120] do
    for height in [14, 24, 40] do
      let active : Bounds := { width, height }
      for index in (List.range (3 + six.rows.size * 2 + 4)).drop 1 do
        have count : 0 < 3 + six.rows.size * 2 + 4 := by omega
        let form := { six with focus := ⟨index % _, Nat.mod_lt _ count⟩ }
        let state := { editor with editor := { editor.editor with form := form } }
        let widget := Loam.Tui.Correction.view active [] state
        expect (widget.lines.length == height - 1 && widget.lines.all (fun cells =>
          Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <= width - 1))
          "Correction input escaped terminal bounds"
        let some (row, col) := Loam.Tui.RecordSession.focusedCursorPosition? 0 0
            (Loam.Tui.Runtime.compileWidget widget)
          | throw (IO.userError "Correction hid its active field/action")
        expect (row < height - 1 && col < width - 1) "Correction caret escaped terminal bounds"
  let form : Loam.Tui.Record.Form := { editor.editor.form with
    description := "after", rows := #[{ locus := "paypay", amount := "-650" },
                                     { locus := "coffee", amount := "650" }], focus := ⟨1, by omega⟩ }
  let replacementEditor := Loam.Tui.Record.preview world { editor.editor with form := form }
  let replacement := { editor with editor := replacementEditor }
  let text := widgetText (Loam.Tui.Correction.view bounds [] replacement)
  expect (contains "Before / selected snapshot" text && contains "-640 jpy  paypay" text &&
    contains "+640 jpy  coffee" text && contains "Description: before" text &&
    contains "Replacement" text && contains "-650 jpy  paypay" text &&
    contains "+650 jpy  coffee" text && contains "Description: after" text)
    "Correction confirmation did not distinguish exact before/replacement evidence"
  expect (contains "Original stays retained; date stays kept." text &&
    contains "[Publish] [Edit] [Cancel]" text)
    "Correction confirmation lost its retained-history boundary or actions"
  let longDescription := String.join (List.replicate 60 "長い変更内容") ++ "末尾"
  let longForm := { form with description := longDescription }
  let longEditor := Loam.Tui.Record.preview world { replacement.editor with form := longForm }
  let long := { replacement with editor := longEditor }
  let compact : Bounds := { width := 48, height := 14 }
  let limit := Loam.Tui.Correction.previewScrollLimit compact long
  expect (limit > 0) "long Correction preview had no review viewport"
  let some tail := Loam.Tui.Correction.scrollPreview compact long .«end»
    | throw (IO.userError "Correction End did not handle review")
  expect (tail.editor.previewScroll == limit && tail.target == editor.target &&
    tail.before.event.id == editor.before.event.id && tail.editor.form.rows == form.rows)
    "Correction review changed target, before snapshot, or replacement inputs"
  expect (contains "Replacement positive total" (widgetText (Loam.Tui.Correction.view compact [] tail)))
    "Correction End did not reach the complete replacement tail"
  expect ((Loam.Tui.Correction.view compact [] long).lines.drop 7 ==
    (Loam.Tui.Correction.view compact [] tail).lines.drop 7)
    "Correction preview scrolling moved the fixed footer"
  let some atEnd := Loam.Tui.Correction.scrollPreview compact tail .down
    | throw (IO.userError "Correction Down did not handle review")
  expect (atEnd.editor.previewScroll == limit) "Correction review overshot its bounds"
  let expanded := Loam.Tui.Correction.normalizedForBounds { width := 160, height := 80 } tail
  expect (expanded.editor.previewScroll <=
    Loam.Tui.Correction.previewScrollLimit { width := 160, height := 80 } expanded)
    "Correction resize did not clamp review scrolling"
  let some home := Loam.Tui.Correction.scrollPreview compact tail .home
    | throw (IO.userError "Correction Home did not handle review")
  expect (home.editor.previewScroll == 0) "Correction Home did not reach review start"
  expect ((Loam.Tui.Correction.update world [] tail .enter).publish.isSome &&
    (Loam.Tui.Correction.update world [] tail .escape).publish.isNone)
    "Correction review altered explicit publication or cancellation"
  let hugeForm : Loam.Tui.Record.Form := { form with rows := #[
    { locus := "paypay", amount := "-12345678901234567890" },
    { locus := "coffee", amount := "12345678901234567890" }], focus := ⟨1, by omega⟩ }
  let hugeEditor := Loam.Tui.Record.preview world { replacement.editor with form := hugeForm }
  let huge := { replacement with editor := hugeEditor }
  let hugeText := widgetText (Loam.Tui.Correction.view { width := 120, height := 40 } [] huge)
  expect (contains "12,345,678,901,234,567,890" hugeText)
    "Correction confirmation clipped exact replacement digits"
  let usdForm : Loam.Tui.Record.Form := {
    form with
    measure := "usd"
    rows := #[{ locus := "paypay", amount := "-12.34" }, { locus := "coffee", amount := "12.34" }]
    focus := ⟨1, by omega⟩ }
  let usdBase : Loam.Tui.Record.State := {
    editor.editor with
    form := usdForm
    measurePresentation := [{ measure := ⟨"usd"⟩, scale := 2 }] }
  let usdEditor := Loam.Tui.Record.preview world usdBase
  let usd := { editor with editor := usdEditor }
  let usdText := widgetText (Loam.Tui.Correction.view { width := 120, height := 40 } [] usd)
  expect (contains "+640 jpy" usdText && contains "+12.34 usd" usdText)
    "Correction before/replacement display collapsed distinct Measures"
  let longTarget := String.join (List.replicate 30 "target-") ++ "identity-tail"
  let identified := { long with target := ⟨longTarget⟩ }
  let identifiedText := widgetText (Loam.Tui.Correction.view { width := 48, height := 80 } [] identified)
  expect (contains "identity-tail" identifiedText)
    "Correction confirmation hid the end of an oversized target identity"

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
  let current := Loam.ActualReview.select records (.day "2026-09-07")
  let record ← requireSome current.head? "current Actual fixture disappeared"
  let .ok editor := Loam.Tui.Correction.initialWithPresentation? [] record
    | throw (IO.userError "Correction editor did not accept current JPY Actual")
  expect (editor.target == recorded) "Correction editor lost selected target identity"
  expect (editor.editor.form.date == "2026-09-07") "Correction editor lost fixed occurrence date"
  expect (editor.editor.form.description == "before") "Correction editor did not prefill description"
  expect (editor.editor.form.measure == "jpy") "Correction editor did not prefill Measure"
  expect (editor.editor.form.rows.map (fun row => row.amount) == #["-640", "640"])
    "Correction editor did not prefill signed Effects"

  let usd ← requireSome usdRecord? "USD fixture was not admitted"
  let usdPresentation : List Loam.MeasurePresentation.Metadata :=
    [{ measure := ⟨"usd"⟩, scale := 2 }]
  let .ok usdEditor := Loam.Tui.Correction.initialWithPresentation? usdPresentation usd
    | throw (IO.userError "Correction editor refused balanced decimal USD Actual")
  expect (usdEditor.editor.form.measure == "usd")
    "Correction editor did not preserve the selected Actual Measure"
  expect (usdEditor.editor.form.rows.map (fun row => row.amount) == #["-12.34", "12.34"])
    "Correction editor exposed stored USD quanta instead of the configured decimal presentation"

  let .ok world ← Loam.MovementWorldLoader.loadSelectedWorld? root
    | throw (IO.userError "reload selected world")
  checkBoundedSurface world editor
  let known := ["paypay", "coffee", "receivable:counterparty"]
  let forcedForm : Loam.Tui.Record.Form := {
    editor.editor.form with focus := ⟨0, by omega⟩ }
  let forced : Loam.Tui.Correction.State := {
    editor with editor := { editor.editor with form := forcedForm } }
  let typed := Loam.Tui.Correction.update world known forced (.input 'X')
  expect (typed.state.editor.form.date == "2026-09-07")
    "Correction input changed the fixed occurrence date"
  expect (typed.state.editor.form.description == "beforeX")
    "Date-focus suppression did not redirect editing to the first editable field"
  let shifted := Loam.Tui.Correction.update world known editor .shiftTab
  expect (shifted.state.editor.form.focus.val != 0)
    "Correction focus reached the fixed Date field"

  let some catalogMetadata := Loam.LocusCatalog.decode?
      ("paypay\tPayPay\tPayPay残高\n" ++
       "coffee\tコーヒー\tコーヒー支出\n" ++
       "receivable:counterparty\t立替金\t未回収立替残高\n")
    | throw (IO.userError "Correction catalog metadata fixture")
  let catalog := Loam.LocusCatalog.forVocabulary world.locusAdmission catalogMetadata
  let filteredForm : Loam.Tui.Record.Form := {
    date := editor.editor.form.date
    description := editor.editor.form.description
    measure := editor.editor.form.measure
    rows := #[
      { locus := "rece", amount := "-640" },
      { locus := "coffee", amount := "640" }]
    focus := ⟨3, by decide⟩
  }
  let filteredEditor :=
    Loam.Tui.Record.withCatalog
      { editor.editor with form := filteredForm } catalog
  let filteredState : Loam.Tui.Correction.State := {
    editor with editor := filteredEditor
  }
  let filteredText := widgetText (Loam.Tui.Correction.view { width := 120, height := 40 } known filteredState)
  expect (contains "[Preview] [Add row] [Drop row] [Cancel]" filteredText)
    "Correction action labels drifted from Record action semantics"
  expect (contains "receivable:counterparty" filteredText && contains "立替金" filteredText)
    "Correction did not expose filtered human-facing Locus candidates"
  expect (!contains "coffee  コーヒー" filteredText)
    "Correction candidate list ignored the typed Locus filter"

  let amountFocusForm : Loam.Tui.Record.Form :=
    Loam.Tui.Record.moveFocus filteredForm false
  let amountFocusState : Loam.Tui.Correction.State := {
    filteredState with editor := { filteredState.editor with form := amountFocusForm }
  }
  let amountFocusText := widgetText (Loam.Tui.Correction.view { width := 120, height := 40 } known amountFocusState)
  expect (contains "focus a Locus field" amountFocusText)
    "Correction amount focus still pretended the Locus search had no matches"
  expect (!contains "(no matching admitted Locus)" amountFocusText)
    "Correction amount focus still showed a false no-matching-Locus warning"

  let originalSuppressed := Loam.Tui.Correction.update world known editor (.ctrl 'o')
  expect originalSuppressed.publish.isNone
    "Correction leaked an original-amount publication intent"
  match originalSuppressed.state.editor.mode with
  | .editing => pure ()
  | _ => throw (IO.userError "Correction entered the new-Actual original amount editor")

  let unresolvedPromptForm : Loam.Tui.Record.Form :=
    Loam.Tui.Record.replaceRows editor.editor.form #[
      { locus := "paypay", amount := "-640" },
      { locus := "coffee", amount := "400" }]
  let unresolvedPromptState : Loam.Tui.Correction.State := {
    editor with editor := { editor.editor with form := unresolvedPromptForm } }
  let unresolvedPrompt :=
    Loam.Tui.Correction.update world known unresolvedPromptState (.ctrl 'u')
  expect (!unresolvedPrompt.enableUnresolved)
    "Correction requested unresolved policy before confirmation"
  expect (contains "[Esc] cancel Correction"
    (widgetText (Loam.Tui.Correction.view { width := 48, height := 14 } known unresolvedPrompt.state)))
    "Correction unresolved confirmation claimed to cancel a new Record"
  match unresolvedPrompt.state.editor.mode with
  | .enableUnresolved => pure ()
  | _ => throw (IO.userError "Correction did not open unresolved activation confirmation")
  let unresolvedEnable :=
    Loam.Tui.Correction.update world known unresolvedPrompt.state .enter
  expect unresolvedEnable.enableUnresolved
    "Correction did not forward explicit unresolved activation intent"
  expect (unresolvedEnable.publish.isNone)
    "Correction unresolved activation also emitted replacement publication"

  let some unresolvedVocabulary := LocusAdmissionVocabulary.ofLoci?
      [⟨"paypay"⟩, ⟨"coffee"⟩, Loam.Tui.Record.unresolvedLocus]
    | throw (IO.userError "Correction unresolved vocabulary")
  let unresolvedWorld : Loam.MovementAdmission.World := {
    world with locusAdmission := unresolvedVocabulary }
  let unresolvedForm : Loam.Tui.Record.Form :=
    Loam.Tui.Record.replaceRows editor.editor.form #[
      { locus := "paypay", amount := "-640" },
      { locus := "coffee", amount := "400" }]
  let unresolvedState : Loam.Tui.Correction.State := {
    editor with editor := { editor.editor with form := unresolvedForm } }
  let unresolvedStep :=
    Loam.Tui.Correction.update unresolvedWorld known unresolvedState (.ctrl 'u')
  expect (unresolvedStep.state.editor.form.rows == #[
      { locus := "paypay", amount := "-640" },
      { locus := "coffee", amount := "400" },
      { locus := "suspense", amount := "240" }])
    "Correction editor did not reuse unresolved remainder assistance"

  let correctedRows : Array Loam.Tui.Record.Row := #[
    { locus := "paypay", amount := "-650" },
    { locus := "coffee", amount := "650" }]
  let correctedForm : Loam.Tui.Record.Form := {
    date := editor.editor.form.date
    description := "after"
    measure := editor.editor.form.measure
    rows := correctedRows
    focus := ⟨1, by omega⟩ }
  let .ok replacementDraft := Loam.Tui.Record.draft? correctedForm
    | throw (IO.userError "corrected form did not parse")
  let previewEditor : Loam.Tui.Record.State := {
    editor.editor with mode := .preview replacementDraft ⟨0, by omega⟩ }
  let previewState : Loam.Tui.Correction.State := { editor with editor := previewEditor }
  let publishStep := Loam.Tui.Correction.update world known previewState .enter
  let correctionDraft ← requireSome publishStep.publish "Correction preview did not emit publication intent"
  expect (correctionDraft.target == recorded) "Correction intent changed the selected target"
  expect (correctionDraft.description == some "after") "Correction intent lost explicit replacement description"
  expect (correctionDraft.effects.map (fun effect => effect.quantity.quanta) == [-650, 650])
    "Correction intent lost edited signed postings"

  let .ok () ← Loam.CorrectionPublisher.publishCorrection
      root.toString correctionDraft
    | throw (IO.userError "shared CorrectionPublisher refused TUI intent")
  let .ok actualEvidence ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload actual authority")
  let some correction := actualEvidence.corrections.corrections.find?
      (fun correction => correction.target == recorded)
    | throw (IO.userError "find correction relation for target")
  let replacementId := correction.replacement
  let .ok freshRecords ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "fresh Actual review reload")
  let fresh := Loam.ActualReview.select freshRecords (.day "2026-09-07")
  expect (fresh.length == 1) "fresh selected day did not expose exactly one current Actual"
  expect (fresh.any fun item =>
      item.event.id == replacementId && item.description == "after" &&
      item.date == some "2026-09-07" &&
      item.event.effects.map (fun effect => effect.quantity.quanta) == [-650, 650])
    "fresh selected day did not expose the replacement evidence"
  expect (freshRecords.any fun item => item.event.id == recorded && !item.isCurrent)
    "Correction TUI path rewrote or lost the original Event"

  let stale ← Loam.CorrectionPublisher.publishCorrection root.toString correctionDraft
  expect (!stale.isOk) "stale TUI correction intent bypassed shared publisher re-checks"

  IO.println "TUI Correction: fixed date, filtered labeled Locus candidates, JPY/USD Measure prefill, representability, explicit Reversal independence, shared intent, publication and fresh reload passed."
