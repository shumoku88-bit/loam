import Loam.Tests.ActualWorldFixture
import Loam.ActualAuthority
import Loam.MovementWorldLoader
import Loam.Tui.Correction
import Loam.MovementPublisher
import Loam.ActualReview
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
  let .ok editor := Loam.Tui.Correction.initial? record
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
  let known := ["paypay", "coffee"]
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

  IO.println "TUI Correction: fixed date, JPY/USD Measure prefill, representability, explicit Reversal independence, shared intent, publication and fresh reload passed."
