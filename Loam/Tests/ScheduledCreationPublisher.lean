import Loam.ScheduledCreationPublisher
import Loam.ScheduledReview
import Loam.Persistence.ScheduledRetirementPersistence

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def emptyWorld : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? [] | throw (IO.userError "empty events")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci?
      [⟨"paypay"⟩, ⟨"smbc"⟩, ⟨"rent"⟩, ⟨"food"⟩]
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

private def effects (fromLocus toLocus : String) (amount : Int) : List Effect :=
  [ Effect.ofQuantity ⟨"effect-1"⟩ ⟨fromLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount))
  , Effect.ofQuantity ⟨"effect-2"⟩ ⟨toLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
  ]

private def draft
    (day fromLocus toLocus : String) (amount : Int) :
    Loam.ScheduledCreationPublisher.Draft := {
  scheduledOn := day
  effects := effects fromLocus toLocus amount
  total := amount }

private def hasScheduled
    (records : List (ScheduledOccurrence String)) (id : ScheduledId) : Bool :=
  records.any fun record => decide (record.id = id)

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let root := dataDir / "movement-authority"
  let scheduledFile := dataDir / "scheduled.loam"
  let retirementFile :=
    Loam.Persistence.scheduledRetirementPathForScheduledMemory scheduledFile

  let initial ← emptyWorld
  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root initial
    | throw (IO.userError "initialize manifest fixture")

  expect (!(← scheduledFile.pathExists))
    "Scheduled fixture unexpectedly existed before first creation"

  let .ok first ← Loam.ScheduledCreationPublisher.publishManifestCreation
      scheduledFile.toString root.toString
      (draft "2026-09-10" "paypay" "rent" 1000)
    | throw (IO.userError "publish first Scheduled creation")
  expect (first.scheduled.token == "scheduled-1")
    "first Scheduled creation did not choose the first fresh identity"

  let .ok afterFirst ← Loam.ScheduledReview.loadEvidenceFromManifest scheduledFile root
    | throw (IO.userError "reload Scheduled review after first creation")
  let firstDay := Loam.ScheduledReview.explicitDueRecords
    (Loam.ScheduledReview.dayEvidence afterFirst "2026-09-10")
  expect (hasScheduled firstDay first.scheduled)
    "fresh Scheduled creation did not become current-open on its explicit date"

  let invalid ← Loam.ScheduledCreationPublisher.publishManifestCreation
    scheduledFile.toString root.toString
    (draft "2026-02-29" "paypay" "food" 200)
  expect (!invalid.isOk) "impossible Scheduled date was admitted"
  let some afterInvalid ← Loam.Persistence.loadScheduledMemory? scheduledFile
    | throw (IO.userError "reload Scheduled memory after invalid draft")
  expect (afterInvalid.occurrences.length == 1)
    "refused Scheduled creation changed retained occurrence count"

  let .ok second ← Loam.ScheduledCreationPublisher.publishManifestCreation
      scheduledFile.toString root.toString
      (draft "2026-09-11" "smbc" "food" 300)
    | throw (IO.userError "publish second Scheduled creation")
  expect (second.scheduled.token == "scheduled-2")
    "second Scheduled creation did not advance fresh identity"

  let orphan : ScheduledRetirement := { scheduled := ⟨"scheduled-3"⟩ }
  let some orphanMemory := ScheduledRetirementMemory.ofRetirements? [orphan]
    | throw (IO.userError "orphan retirement fixture")
  expect (← Loam.Persistence.saveScheduledRetirementMemory? retirementFile orphanMemory)
    "save orphan retirement fixture"

  let brokenRead ← Loam.ScheduledReview.loadEvidenceFromManifest scheduledFile root
  expect (!brokenRead.isOk)
    "unknown retirement identity did not make Scheduled read fail closed"

  let refused ← Loam.ScheduledCreationPublisher.publishManifestCreation
    scheduledFile.toString root.toString
    (draft "2026-09-12" "paypay" "food" 400)
  expect (!refused.isOk)
    "Scheduled creation silently healed orphan lifecycle evidence by recycling its identity"
  let some afterRefusal ← Loam.Persistence.loadScheduledMemory? scheduledFile
    | throw (IO.userError "reload Scheduled memory after lifecycle refusal")
  expect (afterRefusal.occurrences.length == 2 &&
      (ScheduledMemory.findById? afterRefusal ⟨"scheduled-3"⟩).isNone)
    "lifecycle refusal still retained the candidate Scheduled identity"

  IO.println "Scheduled Creation Publisher: fresh append, explicit date validation, current-open review and orphan-evidence fail-closed admission passed."
