import Loam.Tui.ActualDateCorrection
import Loam.ActualReview
import Loam.CorrectionPublisher
import Loam.MovementPublisher

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
      factIdNodup := by simp
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
  let dataDir := System.FilePath.mk dataPath
  let root := dataDir / "movement-authority"
  let correctionFile := dataDir / "corrections.loam"
  let initial ← emptyWorld
  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root initial
    | throw (IO.userError "initialize manifest fixture")
  let .ok recorded ← Loam.MovementPublisher.publishManifestDraft root.toString recordDraft
    | throw (IO.userError "record target fixture")

  let .ok records ← Loam.ActualReview.loadRecordsFromManifest root none
    | throw (IO.userError "load initial Actual review")
  let record ← requireSome (Loam.ActualReview.select records (.day "2026-09-07")).head?
    "selected Actual fixture disappeared"
  let .ok editor := Loam.Tui.ActualDateCorrection.initial? record
    | throw (IO.userError "date editor did not accept dated current Actual")
  expect (editor.target == recorded.eventId && editor.input == "2026-09-07")
    "date editor lost target or visible current date"

  let erased := (Loam.Tui.ActualDateCorrection.update editor .backspace).state
  let typed := (Loam.Tui.ActualDateCorrection.update erased (.input '6')).state
  expect (typed.input == "2026-09-06")
    "date editor did not keep editing presentation-local"
  let preview := Loam.Tui.ActualDateCorrection.update typed .enter
  expect (preview.state.mode == .preview && preview.publish.isNone)
    "valid date did not require a separate preview before publication"
  let publish := Loam.Tui.ActualDateCorrection.update preview.state .enter
  let dateDraft ← requireSome publish.publish "date preview did not emit publication intent"
  expect (dateDraft.target == recorded.eventId && dateDraft.validOn == "2026-09-06")
    "date editor intent changed target or date"

  let .ok receipt ← Loam.ActualValidityPublisher.publishManifestDate
      root.toString correctionFile.toString dateDraft
    | throw (IO.userError "shared date publisher refused TUI intent")
  expect (receipt.changed && receipt.previous == some "2026-09-07")
    "shared date publisher receipt lost prior date"

  let .ok fresh ← Loam.ActualReview.loadRecordsFromManifest root (some correctionFile.toString)
    | throw (IO.userError "fresh Actual review reload")
  expect ((Loam.ActualReview.select fresh (.day "2026-09-07")).isEmpty)
    "old selected day still exposed the moved Actual"
  let moved := Loam.ActualReview.select fresh (.day "2026-09-06")
  expect (moved.length == 1 && moved.any fun item => item.event.id == recorded.eventId)
    "new date did not expose the moved Actual"

  let .ok worldAfterDate ← Loam.MovementManifestAuthority.loadSelectedWorld? root
    | throw (IO.userError "reload world after date correction")
  expect ((EventMemory.findById? worldAfterDate.events recorded.eventId).isSome)
    "date correction rewrote or removed Event payload"

  let staleIntent : Loam.ActualValidityPublisher.Draft := {
    target := recorded.eventId
    validOn := "2026-09-05" }
  let .ok replacement ← Loam.CorrectionPublisher.publishManifestCorrection
      root.toString correctionFile.toString {
        target := recorded.eventId
        effects := effects 650
        description := some "corrected coffee" }
    | throw (IO.userError "movement correction fixture")
  let stale ← Loam.ActualValidityPublisher.publishManifestDate
    root.toString correctionFile.toString staleIntent
  expect (!stale.isOk) "stale TUI date intent bypassed publisher currentness re-check"

  let .ok replacementRecords ← Loam.ActualReview.loadRecordsFromManifest root (some correctionFile.toString)
    | throw (IO.userError "reload replacement review")
  expect (replacementRecords.any fun item =>
      item.event.id == replacement.replacement && item.date == some "2026-09-06" && item.isCurrent)
    "Movement correction stopped carrying the current date after TUI date correction"

  IO.println "TUI Actual date: local edit/preview, shared publication, fresh move and stale-intent rejection passed."
