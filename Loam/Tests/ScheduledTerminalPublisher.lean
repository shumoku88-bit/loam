import Loam.ActualReview
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

private def occurrence (id day fromLocus toLocus : String) (amount : Int) :
    IO (ScheduledOccurrence String) := do
  let some movement := movement? fromLocus toLocus amount
    | throw (IO.userError "scheduled movement")
  return { id := ⟨id⟩, scheduledOn := day, movement := movement }

private def lifecycleFromScheduled
    (scheduled : ScheduledMemory String) : IO Loam.Persistence.ScheduledLifecycleImage := do
  let some completions := ScheduledCompletionMemory.ofCompletions? []
    | throw (IO.userError "empty completion memory")
  let some retirements := ScheduledRetirementMemory.ofRetirements? []
    | throw (IO.userError "empty retirement memory")
  let some replacements := ScheduledReplacementMemory.ofReplacements? []
    | throw (IO.userError "empty replacement memory")
  return { scheduled, completions, retirements, replacements }

private def effects (fromLocus toLocus : String) (amount : Int) : List Effect :=
  [ Effect.ofQuantity ⟨"effect-1"⟩ ⟨fromLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount))
  , Effect.ofQuantity ⟨"effect-2"⟩ ⟨toLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
  ]

private def completionDraft
    (scheduled day fromLocus toLocus : String) (amount : Int) :
    Loam.ScheduledTerminalPublisher.CompletionDraft := {
  scheduled := ⟨scheduled⟩
  movement := {
    validOn := day
    description := some ("actual-" ++ scheduled)
    effects := effects fromLocus toLocus amount
    relations := []
    discharges := []
    total := amount }
}

private def hasScheduled
    (records : List (ScheduledOccurrence String)) (token : String) : Bool :=
  records.any fun record => record.id.token == token

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
  let s2 ← occurrence "scheduled-2" "2026-09-10" "paypay" "food" 200
  let s3 ← occurrence "scheduled-3" "2026-09-11" "smbc" "rent" 3000
  let s4 ← occurrence "scheduled-4" "2026-09-12" "paypay" "food" 400
  let s5 ← occurrence "scheduled-5" "2026-09-13" "paypay" "rent" 500
  let some scheduledMemory := ScheduledMemory.ofOccurrences? [s1, s2, s3, s4, s5]
    | throw (IO.userError "scheduled memory")
  let lifecycle0 ← lifecycleFromScheduled scheduledMemory
  expect (← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile lifecycle0)
    "save complete Scheduled lifecycle fixture"

  let .ok completion ← Loam.ScheduledTerminalPublisher.publishManifestCompletion
      scheduledFile.toString root.toString
      (completionDraft "scheduled-1" "2026-09-08" "paypay" "rent" 1100)
    | throw (IO.userError "publish scheduled completion")
  expect (completion.actual.token == "scheduled-completion:scheduled-1")
    "completion endpoint identity changed"
  expect (!completion.resumed) "fresh completion reported recovery"

  let some retainedLifecycle ←
      Loam.Persistence.loadScheduledLifecycleImage? scheduledFile
    | throw (IO.userError "reload lifecycle after completion")
  expect (retainedLifecycle.completions.completions.length == 1)
    "completion relation was not retained exactly once"

  let .ok actualRecords ← Loam.ActualReview.loadRecordsFromManifest root none
    | throw (IO.userError "load manifest Actual review")
  let actualDay := Loam.ActualReview.select actualRecords (.day "2026-09-08")
  expect (actualDay.any fun record =>
      record.event.id == completion.actual &&
        record.description == "actual-scheduled-1" &&
        record.event.effects.map (fun effect => effect.quantity.quanta) == [-1100, 1100])
    "completion Actual did not enter fresh manifest review"

  let .ok afterCompletion ← Loam.ScheduledReview.loadEvidenceFromManifest scheduledFile root
    | throw (IO.userError "load scheduled review after completion")
  let due10 := Loam.ScheduledReview.explicitDueRecords
    (Loam.ScheduledReview.dayEvidence afterCompletion "2026-09-10")
  expect (!hasScheduled due10 "scheduled-1") "completed Scheduled stayed current-open"
  expect (hasScheduled due10 "scheduled-2") "unrelated Scheduled disappeared after completion"

  let .ok cancelled ← Loam.ScheduledTerminalPublisher.publishManifestCancellation
      scheduledFile.toString root.toString { scheduled := ⟨"scheduled-2"⟩ }
    | throw (IO.userError "publish Scheduled cancellation")
  expect (cancelled.scheduled.token == "scheduled-2") "cancellation receipt changed identity"
  let .ok afterCancellation ← Loam.ScheduledReview.loadEvidenceFromManifest scheduledFile root
    | throw (IO.userError "load scheduled review after cancellation")
  let due10After := Loam.ScheduledReview.explicitDueRecords
    (Loam.ScheduledReview.dayEvidence afterCancellation "2026-09-10")
  expect (!hasScheduled due10After "scheduled-2") "cancelled Scheduled stayed current-open"
  let staleCompletion ← Loam.ScheduledTerminalPublisher.publishManifestCompletion
    scheduledFile.toString root.toString
    (completionDraft "scheduled-2" "2026-09-08" "paypay" "food" 200)
  expect (!staleCompletion.isOk) "cancelled Scheduled accepted a stale completion"

  let some currentLifecycle ← Loam.Persistence.loadScheduledLifecycleImage? scheduledFile
    | throw (IO.userError "reload lifecycle for recovery fixture")
  let interrupted : ScheduledCompletion := {
    scheduled := ⟨"scheduled-3"⟩
    actual := ⟨"scheduled-completion:scheduled-3"⟩ }
  let some withInterrupted := currentLifecycle.completions.add? interrupted
    | throw (IO.userError "append interrupted completion relation")
  expect (← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile
      { currentLifecycle with completions := withInterrupted })
    "save lifecycle with interrupted completion relation"
  let .ok resumed ← Loam.ScheduledTerminalPublisher.publishManifestCompletion
      scheduledFile.toString root.toString
      (completionDraft "scheduled-3" "2026-09-09" "smbc" "rent" 3100)
    | throw (IO.userError "resume relation-first completion")
  expect resumed.resumed "retained inert completion relation was not recovered"
  expect (resumed.actual == interrupted.actual) "recovery changed retained Actual endpoint"

  let some recoveryLifecycle ← Loam.Persistence.loadScheduledLifecycleImage? scheduledFile
    | throw (IO.userError "reload lifecycle for cancellation guard")
  let interruptedCancel : ScheduledCompletion := {
    scheduled := ⟨"scheduled-4"⟩
    actual := ⟨"scheduled-completion:scheduled-4"⟩ }
  let some withInterruptedCancel := recoveryLifecycle.completions.add? interruptedCancel
    | throw (IO.userError "append cancellation guard relation")
  expect (← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile
      { recoveryLifecycle with completions := withInterruptedCancel })
    "save lifecycle with cancellation guard relation"
  let refusedCancel ← Loam.ScheduledTerminalPublisher.publishManifestCancellation
    scheduledFile.toString root.toString { scheduled := ⟨"scheduled-4"⟩ }
  expect (!refusedCancel.isOk) "cancellation competed with an interrupted completion"

  let .ok selected ← Loam.MovementManifestAuthority.loadSelectedWorld? root
    | throw (IO.userError "load selected world for policy refusal")
  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root
      { selected with locusAdmission := LocusAdmissionVocabulary.empty }
    | throw (IO.userError "publish closed Locus policy")
  let beforePolicyRefusal ← IO.FS.readFile (root / "CURRENT")
  let refusedPolicy ← Loam.ScheduledTerminalPublisher.publishManifestCompletion
    scheduledFile.toString root.toString
    (completionDraft "scheduled-5" "2026-09-09" "paypay" "rent" 500)
  expect (!refusedPolicy.isOk) "Scheduled completion bypassed current Locus policy"
  expect ((← IO.FS.readFile (root / "CURRENT")) == beforePolicyRefusal)
    "Locus-policy refusal changed selected Movement authority"
  let some afterPolicyLifecycle ← Loam.Persistence.loadScheduledLifecycleImage? scheduledFile
    | throw (IO.userError "reload lifecycle after policy refusal")
  expect ((ScheduledCompletionMemory.findByScheduled?
      afterPolicyLifecycle.completions ⟨"scheduled-5"⟩).isNone)
    "Locus-policy refusal retained a completion relation"

  IO.println "Scheduled Terminal Publisher: lifecycle completion, cancellation, relation-first cross-authority recovery, stale refusal and current Locus policy passed."
