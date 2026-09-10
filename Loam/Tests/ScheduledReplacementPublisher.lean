import Loam.ScheduledReplacementPublisher
import Loam.ScheduledReview
import Loam.ScheduledTerminalPublisher
import Loam.Persistence.ScheduledLifecyclePersistence

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

private def lifecycleFromScheduled
    (scheduled : ScheduledMemory String) : IO Loam.Persistence.ScheduledLifecycleImage := do
  let some terminals := ScheduledTerminalMemory.ofTerminals? []
    | throw (IO.userError "empty terminal memory")
  return { scheduled, terminals }

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

private def replacementCount (memory : ScheduledTerminalMemory) : Nat :=
  (memory.terminals.filterMap fun terminal =>
    match terminal.target with
    | some (.scheduled successor) => some (terminal.source, successor)
    | _ => none).length

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let root := dataDir / "movement-authority"
  let scheduledFile := dataDir / "scheduled.loam"

  let initial ← emptyWorld
  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root initial
    | throw (IO.userError "initialize manifest fixture")

  let s1 ← occurrence "scheduled-1" "2026-09-10" "paypay" "rent" 1000
  let s2 ← occurrence "scheduled-2" "2026-09-11" "smbc" "rent" 3000
  let s3 ← occurrence "scheduled-3" "2026-09-12" "paypay" "food" 400
  let some scheduledMemory := ScheduledMemory.ofOccurrences? [s1, s2, s3]
    | throw (IO.userError "scheduled memory")
  let lifecycle0 ← lifecycleFromScheduled scheduledMemory
  expect (← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile lifecycle0)
    "save complete Scheduled lifecycle fixture"

  let beforeInvalid ← IO.FS.readFile scheduledFile
  let invalid ← Loam.ScheduledReplacementPublisher.publishManifestReplacement
    scheduledFile.toString root.toString
    (replacementDraft "scheduled-1" "2026-02-29" "paypay" "rent" 1000)
  expect (!invalid.isOk) "impossible replacement date was admitted"
  expect ((← IO.FS.readFile scheduledFile) == beforeInvalid)
    "refused replacement changed the lifecycle authority"

  let .ok fresh ← Loam.ScheduledReplacementPublisher.publishManifestReplacement
      scheduledFile.toString root.toString
      (replacementDraft "scheduled-1" "2026-09-13" "paypay" "rent" 1100)
    | throw (IO.userError "publish fresh Scheduled replacement")
  expect (fresh.source.token == "scheduled-1")
    "fresh replacement receipt changed source identity"

  let some retained ← Loam.Persistence.loadScheduledLifecycleImage? scheduledFile
    | throw (IO.userError "reload lifecycle after replacement")
  expect (replacementCount retained.terminals == 1)
    "fresh replacement relation was not retained exactly once"
  expect (ScheduledTerminalMemory.replacementFor?
      retained.terminals ⟨"scheduled-1"⟩ == some fresh.replacement)
    "fresh replacement relation lost its endpoints"
  expect ((ScheduledMemory.findById? retained.scheduled fresh.replacement).isSome)
    "replacement endpoint was not published in the same lifecycle image"

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

  let beforeStale ← IO.FS.readFile scheduledFile
  let stale ← Loam.ScheduledReplacementPublisher.publishManifestReplacement
    scheduledFile.toString root.toString
    (replacementDraft "scheduled-1" "2026-09-14" "paypay" "rent" 1200)
  expect (!stale.isOk) "already-replaced source accepted another replacement"
  expect ((← IO.FS.readFile scheduledFile) == beforeStale)
    "stale replacement changed the complete lifecycle image"

  let brokenRelation : ScheduledTerminal := {
    source := ⟨"scheduled-2"⟩
    target := some (.scheduled ⟨"missing-endpoint"⟩) }
  let some brokenRelations := retained.terminals.add? brokenRelation
    | throw (IO.userError "construct malformed replacement graph fixture")
  let brokenLifecycle := { retained with terminals := brokenRelations }
  expect (← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile brokenLifecycle)
    "save structurally inconsistent complete lifecycle fixture"
  let brokenRead ← Loam.ScheduledReview.loadEvidenceFromManifest scheduledFile root
  expect (!brokenRead.isOk)
    "missing replacement endpoint did not make complete lifecycle read fail closed"
  let noAutoHeal ← Loam.ScheduledReplacementPublisher.publishManifestReplacement
    scheduledFile.toString root.toString
    (replacementDraft "scheduled-2" "2026-09-14" "smbc" "rent" 3100)
  expect (!noAutoHeal.isOk)
    "replacement publisher auto-healed an externally malformed lifecycle image"
  expect (← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile retained)
    "restore admitted lifecycle after negative fixture"

  let .ok _ ← Loam.ScheduledTerminalPublisher.publishManifestCancellation
      scheduledFile.toString root.toString { scheduled := ⟨"scheduled-3"⟩ }
    | throw (IO.userError "cancel stale-source fixture")
  let cancelledReplacement ← Loam.ScheduledReplacementPublisher.publishManifestReplacement
    scheduledFile.toString root.toString
    (replacementDraft "scheduled-3" "2026-09-15" "paypay" "food" 400)
  expect (!cancelledReplacement.isOk)
    "cancelled Scheduled identity accepted a replacement"

  let some finalLifecycle ← Loam.Persistence.loadScheduledLifecycleImage? scheduledFile
    | throw (IO.userError "reload final lifecycle")
  expect (replacementCount finalLifecycle.terminals == 1)
    "stale or malformed refusal changed replacement relation count"

  IO.println "Scheduled Replacement Publisher: one-image publication, append-only provenance, malformed-world refusal and terminal refusal passed."
