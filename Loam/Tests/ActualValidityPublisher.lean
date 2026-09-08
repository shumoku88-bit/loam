import Loam.ActualValidityPublisher
import Loam.ActualReview
import Loam.CorrectionPublisher
import Loam.MovementPublisher
import Loam.Persistence.ActualReversalPersistence

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def emptyHistory : ActualValidityHistory String :=
  { facts := []
    factIdNodup := by simp
    corrections := []
    correctionIdNodup := by simp }

private def emptyWorld : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? [] | throw (IO.userError "empty events")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci? [⟨"paypay"⟩, ⟨"coffee"⟩]
    | throw (IO.userError "vocabulary")
  return {
    events := events
    validity := emptyHistory
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := vocabulary }

private def effects (amount : Int) : List Effect :=
  [ Effect.ofQuantity ⟨"effect-1"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount))
  , Effect.ofQuantity ⟨"effect-2"⟩ ⟨"coffee"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
  ]

private def recordDraft : Loam.MovementAdmission.Draft := {
  validOn := "2026-09-03"
  description := some "before"
  effects := effects 640
  relations := []
  discharges := []
  total := 640 }

private def undatedWorld : IO Loam.MovementAdmission.World := do
  let some event := Event.ofEffects? ⟨"older-undated"⟩
      [Effect.ofQuantity ⟨"effect-old"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-1))]
    | throw (IO.userError "undated event")
  let some events := EventMemory.ofEvents? [event]
    | throw (IO.userError "undated event memory")
  return {
    events := events
    validity := emptyHistory
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := LocusAdmissionVocabulary.empty }

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  let root := dataDir / "movement-authority"
  let correctionFile := dataDir / "corrections.loam"
  let reversalFile := dataDir / "actual-reversals.loam"
  let initial ← emptyWorld
  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root initial
    | throw (IO.userError "initialize manifest fixture")
  expect (← Loam.Persistence.saveActualReversalMemory? reversalFile .empty)
    "initialize explicit empty reversal authority"
  let .ok recorded ← Loam.MovementPublisher.publishManifestDraft root.toString recordDraft
    | throw (IO.userError "record target fixture")

  let beforeInvalid ← IO.FS.readFile (root / "CURRENT")
  let invalid ← Loam.ActualValidityPublisher.publishManifestDate
    root.toString correctionFile.toString { target := recorded.eventId, validOn := "2026-02-29" }
  expect (!invalid.isOk) "impossible date was admitted"
  expect ((← IO.FS.readFile (root / "CURRENT")) == beforeInvalid)
    "invalid date changed selected manifest authority"

  let beforeNoop ← IO.FS.readFile (root / "CURRENT")
  let .ok noop ← Loam.ActualValidityPublisher.publishManifestDate
      root.toString correctionFile.toString { target := recorded.eventId, validOn := "2026-09-03" }
    | throw (IO.userError "same-date no-op was refused")
  expect (!noop.changed && !noop.firstDate && noop.previous == some "2026-09-03")
    "same-date publication did not report an exact no-op"
  expect ((← IO.FS.readFile (root / "CURRENT")) == beforeNoop)
    "same-date no-op changed manifest authority"

  let .ok corrected ← Loam.ActualValidityPublisher.publishManifestDate
      root.toString correctionFile.toString { target := recorded.eventId, validOn := "2026-09-02" }
    | throw (IO.userError "first date correction was refused")
  expect (corrected.changed && !corrected.firstDate && corrected.previous == some "2026-09-03")
    "first date correction receipt lost the prior current date"

  let .ok once ← Loam.ActualReview.loadRecordsFromManifest root (some correctionFile.toString)
    | throw (IO.userError "reload corrected Actual review")
  expect ((Loam.ActualReview.select once (.day "2026-09-03")).isEmpty)
    "superseded occurrence date remained current"
  let currentOnce := Loam.ActualReview.select once (.day "2026-09-02")
  expect (currentOnce.length == 1 && currentOnce.any fun item => item.event.id == recorded.eventId)
    "fresh Actual review did not expose the corrected date"

  let .ok twice ← Loam.ActualValidityPublisher.publishManifestDate
      root.toString correctionFile.toString { target := recorded.eventId, validOn := "2026-09-01" }
    | throw (IO.userError "repeated date correction was refused")
  expect (twice.previous == some "2026-09-02" && twice.validOn == "2026-09-01")
    "repeated date correction did not follow the explicit current frontier"

  let .ok replacement ← Loam.CorrectionPublisher.publishManifestCorrection
      root.toString correctionFile.toString {
        target := recorded.eventId
        effects := effects 650
        description := some "replacement" }
    | throw (IO.userError "movement correction fixture")
  let beforeStale ← IO.FS.readFile (root / "CURRENT")
  let stale ← Loam.ActualValidityPublisher.publishManifestDate
    root.toString correctionFile.toString { target := recorded.eventId, validOn := "2026-08-31" }
  expect (!stale.isOk) "superseded Event accepted a stale date intent"
  expect ((← IO.FS.readFile (root / "CURRENT")) == beforeStale)
    "stale target refusal changed manifest authority"

  let correctionsBefore ← IO.FS.readFile correctionFile
  let .ok replacementDate ← Loam.ActualValidityPublisher.publishManifestDate
      root.toString correctionFile.toString { target := replacement.replacement, validOn := "2026-08-31" }
    | throw (IO.userError "current replacement date correction was refused")
  expect (replacementDate.previous == some "2026-09-01")
    "replacement did not inherit the current carried date before explicit date correction"
  expect ((← IO.FS.readFile correctionFile) == correctionsBefore)
    "date publisher rewrote Movement correction evidence"

  let .ok fresh ← Loam.ActualReview.loadRecordsFromManifest root (some correctionFile.toString)
    | throw (IO.userError "reload replacement Actual review")
  let currentReplacement := Loam.ActualReview.select fresh (.day "2026-08-31")
  expect (currentReplacement.length == 1 && currentReplacement.any fun item =>
      item.event.id == replacement.replacement && item.description == "replacement")
    "fresh review did not expose the current replacement at its corrected date"

  let undatedRoot := dataDir / "undated-authority"
  let undatedCorrections := dataDir / "undated-corrections.loam"
  let older ← undatedWorld
  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? undatedRoot older
    | throw (IO.userError "initialize undated fixture")
  let .ok firstDate ← Loam.ActualValidityPublisher.publishManifestDate
      undatedRoot.toString undatedCorrections.toString {
        target := ⟨"older-undated"⟩, validOn := "2026-09-02" }
    | throw (IO.userError "first date publication was refused")
  expect (firstDate.changed && firstDate.firstDate && firstDate.previous.isNone)
    "older undated Event did not receive one first-date receipt"
  let .ok undatedSelected ← Loam.MovementManifestAuthority.loadSelectedWorld? undatedRoot
    | throw (IO.userError "reload undated world")
  let some undatedFacts := Loam.Application.admittedActualValidityFacts? undatedSelected.validity
    | throw (IO.userError "first-date frontier failed closed")
  expect (undatedFacts.any fun fact =>
      fact.event == ⟨"older-undated"⟩ && fact.validOn == "2026-09-02")
    "first date did not become current in selected manifest authority"

  IO.println "ActualValidity Publisher: manifest ownership, no-op, repeated correction, stale target, replacement and first date passed."
