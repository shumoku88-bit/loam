import Loam.ActualAuthority
import Loam.ActualReview
import Loam.CorrectionPublisher
import Loam.MovementPublisher

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def emptyWorld : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? [] | throw (IO.userError "empty events")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci?
      [⟨"paypay"⟩, ⟨"coffee"⟩, ⟨"books"⟩]
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

private def effects (fromLocus toLocus : String) (amount : Int) : List Effect :=
  [ Effect.ofQuantity ⟨"effect-1"⟩ ⟨fromLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount))
  , Effect.ofQuantity ⟨"effect-2"⟩ ⟨toLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
  ]

private def recordDraft : Loam.MovementAdmission.Draft := {
  validOn := "2026-09-07"
  description := some "before"
  effects := effects "paypay" "coffee" 640
  relations := []
  discharges := []
  total := 640 }

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  let root := dataDir / "movement-authority"
  let correctionFile := dataDir / "corrections.loam"
  let initial ← emptyWorld
  let .ok _ ← Loam.ActualAuthority.publishWorld? root initial
    | throw (IO.userError "initialize manifest fixture")
  let .ok recorded ← Loam.MovementPublisher.publishManifestDraft root.toString recordDraft
    | throw (IO.userError "record target fixture")

  let correctionDraft : Loam.CorrectionPublisher.Draft := {
    target := recorded.eventId
    effects := effects "paypay" "coffee" 650
    description := some "after" }

  let unbalanced : Loam.CorrectionPublisher.Draft := {
    correctionDraft with effects := correctionDraft.effects.take 1 }
  let refusedUnbalanced ← Loam.CorrectionPublisher.publishManifestCorrection
    root.toString correctionFile.toString unbalanced
  expect (!refusedUnbalanced.isOk) "unbalanced correction replacement was admitted"

  let .ok selected ← Loam.ActualAuthority.loadSelectedWorld? root
    | throw (IO.userError "reload selected world")
  let .ok _ ← Loam.ActualAuthority.publishWorld? root
      { selected with locusAdmission := LocusAdmissionVocabulary.empty }
    | throw (IO.userError "publish closed Locus policy")
  let beforeRefusal ← IO.FS.readFile (root / "actual.loam")
  let refusedPolicy ← Loam.CorrectionPublisher.publishManifestCorrection
    root.toString correctionFile.toString correctionDraft
  expect (!refusedPolicy.isOk) "correction bypassed current Locus new-write policy"
  expect ((← IO.FS.readFile (root / "actual.loam")) == beforeRefusal)
    "Locus-policy refusal changed selected manifest authority"
  let .ok _ ← Loam.ActualAuthority.publishWorld? root selected
    | throw (IO.userError "restore Locus policy")

  let .ok receipt ← Loam.CorrectionPublisher.publishManifestCorrection
      root.toString correctionFile.toString correctionDraft
    | throw (IO.userError "publish correction")
  expect (receipt.target == recorded.eventId) "correction receipt changed target identity"
  expect (receipt.carriedDate) "correction did not carry explicit current target date"
  expect (receipt.publishedDescription) "explicit replacement description was not published"
  expect (!receipt.resumed) "fresh correction was reported as a resumed publication"

  let .ok actualEvidence ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload actual authority")
  expect (actualEvidence.corrections.corrections.length == 1) "correction relation count changed"
  expect (actualEvidence.corrections.corrections.any fun correction =>
      correction.target == recorded.eventId && correction.replacement == receipt.replacement)
    "published correction relation lost its endpoints"

  let .ok world ← Loam.ActualAuthority.loadSelectedWorld? root
    | throw (IO.userError "reload corrected manifest")
  expect ((EventMemory.findById? world.events recorded.eventId).isSome)
    "append-only correction rewrote the original Event"
  expect ((EventMemory.findById? world.events receipt.replacement).isSome)
    "replacement Event is absent from selected manifest"

  let .ok records ← Loam.ActualReview.loadRecordsFromManifest root (some correctionFile.toString)
    | throw (IO.userError "reload correction-aware Actual review")
  let current := Loam.ActualReview.select records (.day "2026-09-07")
  expect (current.length == 1) "corrected day did not have exactly one current Actual"
  expect (current.any fun record =>
      record.event.id == receipt.replacement && record.description == "after" &&
        record.date == some "2026-09-07" &&
        record.event.effects.map (fun effect => effect.quantity.quanta) == [-650, 650])
    "current Actual did not expose replacement quantity/date/description evidence"
  expect (records.any fun record => record.event.id == recorded.eventId && !record.isCurrent)
    "original Event disappeared instead of remaining retained and non-current"

  let staleRetry ← Loam.CorrectionPublisher.publishManifestCorrection
    root.toString correctionFile.toString correctionDraft
  expect (!staleRetry.isOk) "already-completed correction target was accepted again"

  IO.println "Correction Publisher: manifest re-read, explicit Reversal independence, fail-closed policy, append-only relation, replacement and fresh review passed."
