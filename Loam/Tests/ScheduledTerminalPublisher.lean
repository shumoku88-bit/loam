import Loam.Tests.ActualWorldFixture
import Loam.Authority.ActualAuthority
import Loam.MovementWorldLoader
import Loam.Review.ActualReview
import Loam.Review.ScheduledReview
import Loam.Publisher.ScheduledTerminalPublisher
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Authority.ScheduledLifecycleAuthority
import Loam.Authority.HouseholdAuthority

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
      factRefNodup := by simp
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
  let some terminals := ScheduledTerminalMemory.ofTerminals? []
    | throw (IO.userError "empty terminal memory")
  return { scheduled, terminals }

private def publishLifecycle
    (root : System.FilePath)
    (lifecycle : Loam.Persistence.ScheduledLifecycleImage) : IO Unit := do
  let some body := Loam.Persistence.encodeScheduledLifecycleImage? lifecycle
    | throw (IO.userError "encode Household Scheduled lifecycle fixture")
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "Scheduled" body
    | throw (IO.userError "publish Household Scheduled lifecycle fixture")
  pure ()

private def effects (fromLocus toLocus : String) (amount : Int) : List Effect :=
  [ Effect.ofQuantity ⟨"collector-temp"⟩ ⟨fromLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount))
  , Effect.ofQuantity ⟨"collector-temp"⟩ ⟨toLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
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

private def completionCount (memory : ScheduledTerminalMemory) : Nat :=
  (memory.terminals.filterMap fun terminal =>
    match terminal.target with
    | some (.actual event) => some (terminal.source, event)
    | _ => none).length

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let root := dataDir

  let initial ← emptyWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root initial
    | throw (IO.userError "initialize Actual fixture")

  let s1 ← occurrence "scheduled-1" "2026-09-10" "paypay" "rent" 1000
  let s2 ← occurrence "scheduled-2" "2026-09-10" "paypay" "food" 200
  let s3 ← occurrence "scheduled-3" "2026-09-11" "smbc" "rent" 3000
  let s4 ← occurrence "scheduled-4" "2026-09-12" "paypay" "food" 400
  let s5 ← occurrence "scheduled-5" "2026-09-13" "paypay" "rent" 500
  let some scheduledMemory := ScheduledMemory.ofOccurrences? [s1, s2, s3, s4, s5]
    | throw (IO.userError "scheduled memory")
  let lifecycle0 ← lifecycleFromScheduled scheduledMemory
  publishLifecycle root lifecycle0

  let .ok () ← Loam.ScheduledTerminalPublisher.publishHouseholdCompletion
      root
      (completionDraft "scheduled-1" "2026-09-08" "paypay" "rent" 1100)
    | throw (IO.userError "publish scheduled completion")

  let .ok retainedLifecycle ←
      Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? root
    | throw (IO.userError "reload lifecycle after completion")
  expect (completionCount retainedLifecycle.terminals == 1)
    "completion relation was not retained exactly once"
  let completionActual ←
    match retainedLifecycle.terminals.completionActualFor? ⟨"scheduled-1"⟩ with
    | some actual => pure actual
    | none => throw (IO.userError "canonical completion relation lost its Actual endpoint")
  let .ok completedEvidence ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload Actual authority after completion")
  let some completionEvent := EventMemory.findById? completedEvidence.events completionActual
    | throw (IO.userError "completion Actual Event is missing")
  expect (completionEvent.effects.all fun effect => effect.key.isNone)
    "Scheduled completion retained collector-local Effect identity"

  let .ok actualRecords ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "load Actual review")
  let actualDay := Loam.ActualReview.select actualRecords (.day "2026-09-08")
  expect (actualDay.any fun record =>
      record.event.id == completionActual &&
        record.description == "actual-scheduled-1" &&
        record.event.effects.map (fun effect => effect.quantity.quanta) == [-1100, 1100])
    "completion Actual did not enter fresh Actual review"

  let .ok afterCompletion ← Loam.ScheduledReview.loadHouseholdEvidence root root
    | throw (IO.userError "load scheduled review after completion")
  let .ok due10Evidence := Loam.ScheduledReview.dayEvidence afterCompletion "2026-09-10"
    | throw (IO.userError "Scheduled day evidence refused valid completion frontier")
  let due10 := Loam.ScheduledReview.explicitDueRecords due10Evidence
  expect (!hasScheduled due10 "scheduled-1") "completed Scheduled stayed current-open"
  expect (hasScheduled due10 "scheduled-2") "unrelated Scheduled disappeared after completion"

  let .ok () ← Loam.ScheduledTerminalPublisher.publishHouseholdCancellation
      root { scheduled := ⟨"scheduled-2"⟩ }
    | throw (IO.userError "publish Scheduled cancellation")
  let .ok afterCancellation ← Loam.ScheduledReview.loadHouseholdEvidence root root
    | throw (IO.userError "load scheduled review after cancellation")
  let .ok due10AfterEvidence := Loam.ScheduledReview.dayEvidence afterCancellation "2026-09-10"
    | throw (IO.userError "Scheduled day evidence refused valid cancellation frontier")
  let due10After := Loam.ScheduledReview.explicitDueRecords due10AfterEvidence
  expect (!hasScheduled due10After "scheduled-2") "cancelled Scheduled stayed current-open"
  let staleCompletion ← Loam.ScheduledTerminalPublisher.publishHouseholdCompletion
    root
    (completionDraft "scheduled-2" "2026-09-08" "paypay" "food" 200)
  expect (!staleCompletion.isOk) "cancelled Scheduled accepted a stale completion"

  let .ok currentLifecycle ← Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? root
    | throw (IO.userError "reload lifecycle for recovery fixture")
  let recoveredEndpoint : EventId := ⟨"recovered-actual-3"⟩
  let interrupted : ScheduledTerminal := {
    source := ⟨"scheduled-3"⟩
    target := some (.actual recoveredEndpoint) }
  let some withInterrupted := currentLifecycle.terminals.add? interrupted
    | throw (IO.userError "append interrupted completion relation")
  publishLifecycle root { currentLifecycle with terminals := withInterrupted }
  let .ok () ← Loam.ScheduledTerminalPublisher.publishHouseholdCompletion
      root
      (completionDraft "scheduled-3" "2026-09-09" "smbc" "rent" 3100)
    | throw (IO.userError "resume relation-first completion")
  let .ok recoveredEvidence ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload Actual authority after recovery")
  let some recoveredEvent := EventMemory.findById? recoveredEvidence.events recoveredEndpoint
    | throw (IO.userError "recovery did not honor the canonical retained Actual endpoint")
  expect (recoveredEvent.effects.all fun effect => effect.key.isNone)
    "Scheduled completion recovery retained collector-local Effect identity"
  let .ok afterRecoveryLifecycle ←
      Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? root
    | throw (IO.userError "reload lifecycle after recovery")
  expect (afterRecoveryLifecycle.terminals.completionActualFor? ⟨"scheduled-3"⟩ == some recoveredEndpoint)
    "recovery lost the canonical retained completion Actual endpoint"
  expect (completionCount afterRecoveryLifecycle.terminals == 2)
    "recovery duplicated or lost completion relations"

  let .ok recoveryLifecycle ← Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? root
    | throw (IO.userError "reload lifecycle for cancellation guard")
  let interruptedCancel : ScheduledTerminal := {
    source := ⟨"scheduled-4"⟩
    target := some (.actual ⟨"scheduled-completion:scheduled-4"⟩) }
  let some withInterruptedCancel := recoveryLifecycle.terminals.add? interruptedCancel
    | throw (IO.userError "append cancellation guard relation")
  publishLifecycle root { recoveryLifecycle with terminals := withInterruptedCancel }
  let refusedCancel ← Loam.ScheduledTerminalPublisher.publishHouseholdCancellation
    root { scheduled := ⟨"scheduled-4"⟩ }
  expect (!refusedCancel.isOk) "cancellation competed with an interrupted completion"

  let .ok selected ← Loam.MovementWorldLoader.loadSelectedWorld? root
    | throw (IO.userError "load selected world for policy refusal")
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root
      { selected with locusAdmission := LocusAdmissionVocabulary.empty }
    | throw (IO.userError "publish closed Locus policy")
  let beforePolicyRefusal ← IO.FS.readFile (Loam.HouseholdAuthority.path root)
  let refusedPolicy ← Loam.ScheduledTerminalPublisher.publishHouseholdCompletion
    root
    (completionDraft "scheduled-5" "2026-09-09" "paypay" "rent" 500)
  expect (!refusedPolicy.isOk) "Scheduled completion bypassed current Locus policy"
  expect ((← IO.FS.readFile (Loam.HouseholdAuthority.path root)) == beforePolicyRefusal)
    "Locus-policy refusal changed selected Movement authority"
  let .ok afterPolicyLifecycle ← Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? root
    | throw (IO.userError "reload lifecycle after policy refusal")
  expect ((ScheduledTerminalMemory.completionActualFor?
      afterPolicyLifecycle.terminals ⟨"scheduled-5"⟩).isNone)
    "Locus-policy refusal retained a completion relation"

  IO.println "Scheduled Terminal Publisher: sparse completion identity, canonical endpoint, cancellation, relation-first recovery, stale refusal and current Locus policy passed."
