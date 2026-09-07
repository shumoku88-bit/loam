import Loam.ScheduledReplacementPublisher
import Loam.ScheduledReview
import Loam.ScheduledTerminalPublisher

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

private def movement? (fromLocus toLocus : String) (amount : Int) :
    Option (BalancedMovement LocusId) :=
  BalancedMovement.ofChanges? ⟨"jpy"⟩
    [ { coordinate := ⟨fromLocus⟩, quantity := Quantity.ofQuanta (-amount) }
    , { coordinate := ⟨toLocus⟩, quantity := Quantity.ofQuanta amount }
    ]

private def occurrence
    (id day fromLocus toLocus : String) (amount : Int) : IO (ScheduledOccurrence String) := do
  let some movement := movement? fromLocus toLocus amount
    | throw (IO.userError "scheduled movement")
  return { id := ⟨id⟩, scheduledOn := day, movement := movement }

private def effects (fromLocus toLocus : String) (amount : Int) : List Effect :=
  [ Effect.ofQuantity ⟨"effect-1"⟩ ⟨fromLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount))
  , Effect.ofQuantity ⟨"effect-2"⟩ ⟨toLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
  ]

private def replacementDraft
    (source day fromLocus toLocus : String) (amount : Int) :
    Loam.ScheduledReplacementPublisher.Draft := {
  source := ⟨source⟩
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
  let replacementFile :=
    Loam.Persistence.scheduledReplacementPathForScheduledMemory scheduledFile

  let initial ← emptyWorld
  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root initial
    | throw (IO.userError "initialize manifest fixture")

  let s1 ← occurrence "scheduled-1" "2026-09-10" "paypay" "rent" 1000
  let s2 ← occurrence "scheduled-2" "2026-09-11" "smbc" "rent" 3000
  let s3 ← occurrence "scheduled-3" "2026-09-12" "paypay" "food" 400
  let some scheduledMemory := ScheduledMemory.ofOccurrences? [s1, s2, s3]
    | throw (IO.userError "scheduled memory")
  expect (← Loam.Persistence.saveScheduledMemory? scheduledFile scheduledMemory)
    "save scheduled fixture"

  let invalid ← Loam.ScheduledReplacementPublisher.publishManifestReplacement
    scheduledFile.toString root.toString
    (replacementDraft "scheduled-1" "2026-02-29" "paypay" "rent" 1000)
  expect (!invalid.isOk) "impossible replacement date was admitted"
  expect (!(← replacementFile.pathExists)) "refused replacement published provenance"

  let .ok fresh ← Loam.ScheduledReplacementPublisher.publishManifestReplacement
      scheduledFile.toString root.toString
      (replacementDraft "scheduled-1" "2026-09-13" "paypay" "rent" 1100)
    | throw (IO.userError "publish fresh Scheduled replacement")
  expect (!fresh.resumed && fresh.source.token == "scheduled-1")
    "fresh replacement receipt changed source or recovery state"

  let some retained ← Loam.Persistence.loadScheduledReplacementMemoryOrEmpty? replacementFile
    | throw (IO.userError "reload replacement memory")
  expect (retained.replacements.length == 1)
    "fresh replacement relation was not retained exactly once"
  expect (retained.replacements.any fun relation =>
      relation.source.token == "scheduled-1" && relation.replacement == fresh.replacement)
    "fresh replacement relation lost its endpoints"

  let .ok afterFresh ← Loam.ScheduledReview.loadEvidenceFromManifest scheduledFile root
    | throw (IO.userError "reload replacement-aware Scheduled review")
  let oldDay := Loam.ScheduledReview.explicitDueRecords
    (Loam.ScheduledReview.dayEvidence afterFresh "2026-09-10")
  let newDay := Loam.ScheduledReview.explicitDueRecords
    (Loam.ScheduledReview.dayEvidence afterFresh "2026-09-13")
  expect (!hasScheduled oldDay ⟨"scheduled-1"⟩)
    "replaced source stayed current-open"
  expect (hasScheduled newDay fresh.replacement)
    "replacement occurrence did not become current-open"
  expect ((ScheduledMemory.findById? afterFresh.scheduled ⟨"scheduled-1"⟩).isSome)
    "append-only replacement rewrote the source occurrence"

  let stale ← Loam.ScheduledReplacementPublisher.publishManifestReplacement
    scheduledFile.toString root.toString
    (replacementDraft "scheduled-1" "2026-09-14" "paypay" "rent" 1200)
  expect (!stale.isOk) "already-replaced source accepted another replacement"

  let interrupted : ScheduledReplacement := {
    source := ⟨"scheduled-2"⟩
    replacement := ⟨"scheduled-recovery"⟩ }
  let some withInterrupted := retained.add? interrupted
    | throw (IO.userError "append interrupted replacement relation")
  expect (← Loam.Persistence.saveScheduledReplacementMemory? replacementFile withInterrupted)
    "save interrupted replacement relation"
  let brokenRead ← Loam.ScheduledReview.loadEvidenceFromManifest scheduledFile root
  expect (!brokenRead.isOk)
    "missing replacement endpoint did not make replacement-aware read fail closed"

  let .ok resumed ← Loam.ScheduledReplacementPublisher.publishManifestReplacement
      scheduledFile.toString root.toString
      (replacementDraft "scheduled-2" "2026-09-14" "smbc" "rent" 3100)
    | throw (IO.userError "resume relation-first Scheduled replacement")
  expect resumed.resumed "interrupted replacement was not reported as resumed"
  expect (resumed.replacement == interrupted.replacement)
    "recovery changed the retained replacement endpoint"
  let .ok afterResume ← Loam.ScheduledReview.loadEvidenceFromManifest scheduledFile root
    | throw (IO.userError "reload Scheduled review after recovery")
  let resumedDay := Loam.ScheduledReview.explicitDueRecords
    (Loam.ScheduledReview.dayEvidence afterResume "2026-09-14")
  expect (hasScheduled resumedDay interrupted.replacement)
    "recovered replacement did not become current-open"
  let oldSecondDay := Loam.ScheduledReview.explicitDueRecords
    (Loam.ScheduledReview.dayEvidence afterResume "2026-09-11")
  expect (!hasScheduled oldSecondDay ⟨"scheduled-2"⟩)
    "recovered source stayed current-open"

  let .ok _ ← Loam.ScheduledTerminalPublisher.publishManifestCancellation
      scheduledFile.toString root.toString { scheduled := ⟨"scheduled-3"⟩ }
    | throw (IO.userError "cancel stale-source fixture")
  let cancelledReplacement ← Loam.ScheduledReplacementPublisher.publishManifestReplacement
    scheduledFile.toString root.toString
    (replacementDraft "scheduled-3" "2026-09-15" "paypay" "food" 400)
  expect (!cancelledReplacement.isOk)
    "cancelled Scheduled identity accepted a replacement"

  let some finalRelations ← Loam.Persistence.loadScheduledReplacementMemoryOrEmpty? replacementFile
    | throw (IO.userError "reload final replacement memory")
  expect (finalRelations.replacements.length == 2)
    "recovery or stale refusal changed replacement relation count"

  IO.println "Scheduled Replacement Publisher: manifest currentness, relation-first publication/recovery, append-only provenance and terminal refusal passed."
