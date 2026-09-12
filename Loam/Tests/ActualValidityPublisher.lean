import Loam.Tests.ActualWorldFixture
import Loam.ActualAuthority
import Loam.ActualValidityPublisher
import Loam.ActualReview
import Loam.CorrectionPublisher
import Loam.MovementPublisher

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def emptyHistory : ActualValidityHistory String :=
  { facts := []
    factRefNodup := by simp
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

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let root := System.FilePath.mk dataPath
  let initial ← emptyWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root initial
    | throw (IO.userError "initialize Actual fixture")
  let .ok recorded ← Loam.MovementPublisher.publishDraft root.toString recordDraft
    | throw (IO.userError "record target fixture")

  let beforeInvalid ← IO.FS.readFile (root / "actual.loam")
  let invalid ← Loam.ActualValidityPublisher.publishDate
    root.toString { target := recorded.eventId, validOn := "2026-02-29" }
  expect (!invalid.isOk) "impossible date was admitted"
  expect ((← IO.FS.readFile (root / "actual.loam")) == beforeInvalid)
    "invalid date changed Actual authority"

  let beforeNoop ← IO.FS.readFile (root / "actual.loam")
  let .ok noop ← Loam.ActualValidityPublisher.publishDate
      root.toString { target := recorded.eventId, validOn := "2026-09-03" }
    | throw (IO.userError "same-date no-op was refused")
  expect (!noop.changed) "same-date publication did not report an exact no-op"
  expect ((← IO.FS.readFile (root / "actual.loam")) == beforeNoop)
    "same-date no-op changed Actual authority"

  let .ok corrected ← Loam.ActualValidityPublisher.publishDate
      root.toString { target := recorded.eventId, validOn := "2026-09-02" }
    | throw (IO.userError "first date correction was refused")
  expect corrected.changed "first date correction did not report a change"

  let .ok once ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "reload corrected Actual review")
  expect ((Loam.ActualReview.select once (.day "2026-09-03")).isEmpty)
    "superseded occurrence date remained current"
  let currentOnce := Loam.ActualReview.select once (.day "2026-09-02")
  expect (currentOnce.length == 1 && currentOnce.any fun item => item.event.id == recorded.eventId)
    "fresh Actual review did not expose the corrected date"

  let .ok twice ← Loam.ActualValidityPublisher.publishDate
      root.toString { target := recorded.eventId, validOn := "2026-09-01" }
    | throw (IO.userError "repeated date correction was refused")
  expect twice.changed "repeated date correction did not report a change"
  let .ok twiceReview ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "reload repeatedly corrected Actual review")
  expect ((Loam.ActualReview.select twiceReview (.day "2026-09-02")).isEmpty)
    "prior corrected date remained current after a second correction"
  expect ((Loam.ActualReview.select twiceReview (.day "2026-09-01")).any fun item =>
      item.event.id == recorded.eventId)
    "second date correction did not follow the explicit current frontier"

  let .ok replacement ← Loam.CorrectionPublisher.publishCorrection
      root.toString {
        target := recorded.eventId
        effects := effects 650
        description := some "replacement" }
    | throw (IO.userError "movement correction fixture")
  let beforeStale ← IO.FS.readFile (root / "actual.loam")
  let stale ← Loam.ActualValidityPublisher.publishDate
    root.toString { target := recorded.eventId, validOn := "2026-08-31" }
  expect (!stale.isOk) "superseded Event accepted a stale date intent"
  expect ((← IO.FS.readFile (root / "actual.loam")) == beforeStale)
    "stale target refusal changed Actual authority"

  let .ok carried ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "reload replacement before date correction")
  expect ((Loam.ActualReview.select carried (.day "2026-09-01")).any fun item =>
      item.event.id == replacement.replacement && item.isCurrent)
    "replacement did not inherit the current carried date"

  let .ok replacementDate ← Loam.ActualValidityPublisher.publishDate
      root.toString { target := replacement.replacement, validOn := "2026-08-31" }
    | throw (IO.userError "current replacement date correction was refused")
  expect replacementDate.changed "replacement date correction did not report a change"

  let .ok fresh ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "reload replacement Actual review")
  let currentReplacement := Loam.ActualReview.select fresh (.day "2026-08-31")
  expect (currentReplacement.length == 1 && currentReplacement.any fun item =>
      item.event.id == replacement.replacement && item.description == "replacement")
    "fresh review did not expose the current replacement at its corrected date"

  IO.println "ActualValidity Publisher: ownership, no-op, repeated correction, stale target and replacement passed."
