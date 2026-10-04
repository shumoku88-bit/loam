import Loam.HouseholdCommand
import Loam.Authority.LocusAdmissionAuthority
import Loam.Authority.HouseholdAuthority
import Loam.Review.ScheduledReview
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Tests.DeterministicScenarioSupport

namespace Loam.Tests.DeterministicScheduledRecoveryScenario

open Loam
open Loam.Core
open Loam.Persistence
open Loam.Tests.DeterministicScenarioSupport

set_option autoImplicit false

private structure Stats where
  freshCompletions : Nat := 0
  cancellations : Nat := 0
  interruptedClaims : Nat := 0
  blockedRetries : Nat := 0
  recoveredCompletions : Nat := 0
  refusals : Nat := 0
deriving Repr, DecidableEq

private def movement?
    (fromLocus toLocus : String)
    (amount : Int) : Option (BalancedMovement LocusId) :=
  BalancedMovement.ofChanges? ⟨"jpy"⟩ [
    {
      coordinate := ⟨fromLocus⟩
      quantity := Quantity.ofQuanta (-amount)
    },
    {
      coordinate := ⟨toLocus⟩
      quantity := Quantity.ofQuanta amount
    }
  ]

private def occurrence
    (id day fromLocus toLocus : String)
    (amount : Int) : IO (ScheduledOccurrence String) := do
  let movement ← requireSome
    (movement? fromLocus toLocus amount)
    s!"Scheduled fixture movement '{id}' was not balanced"
  pure {
    id := ⟨id⟩
    scheduledOn := day
    movement := movement
  }

private def completionDraft
    (scheduled day fromLocus toLocus : String)
    (amount : Int) :
    Loam.ScheduledTerminalPublisher.CompletionDraft := {
  scheduled := ⟨scheduled⟩
  movement := {
    validOn := day
    description := some ("actual-" ++ scheduled)
    effects := [
      Effect.ofAnonymousQuantity
        ⟨fromLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount)),
      Effect.ofAnonymousQuantity
        ⟨toLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
    ]
    relations := []
    discharges := []
    total := amount
  }
}

private def scheduledPath (root : System.FilePath) : System.FilePath :=
  Loam.HouseholdPaths.scheduled root

private def scheduledBytes (root : System.FilePath) : IO String :=
  IO.FS.readFile (scheduledPath root)

private def policyBytes (root : System.FilePath) : IO String := do
  let generation ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "load HouseholdImage for deterministic Locus policy bytes"
  requireSome
    (Loam.Persistence.HouseholdImage.body?
      generation.image "LocusAdmission")
    "deterministic HouseholdImage Locus policy section missing"

private def loadScheduled
    (root : System.FilePath)
    (context : String) : IO ScheduledLifecycleImage := do
  requireSome
    (← loadScheduledLifecycleImage? (scheduledPath root))
    s!"{context}: Scheduled lifecycle reload failed"

private def checkScheduledCanonical
    (root : System.FilePath)
    (context : String) : IO String := do
  let lifecycle ← loadScheduled root context
  let encoded ← requireSome
    (encodeScheduledLifecycleImage? lifecycle)
    s!"{context}: Scheduled lifecycle failed canonical encoding"
  let decoded ← requireSome
    (decodeScheduledLifecycleImage? encoded)
    s!"{context}: canonical Scheduled bytes failed typed decoding"
  let reencoded ← requireSome
    (encodeScheduledLifecycleImage? decoded)
    s!"{context}: decoded Scheduled lifecycle failed canonical re-encoding"
  expect (encoded == reencoded)
    s!"{context}: Scheduled encode/decode was not canonical"
  let disk ← scheduledBytes root
  expect (disk == encoded)
    s!"{context}: scheduled.loam diverged from canonical lifecycle encoding"
  pure disk

private def checkAuthorityPair
    (root : System.FilePath)
    (context : String) : IO (String × String) := do
  let actual ← checkCanonical root context
  let scheduled ← checkScheduledCanonical root context
  pure (actual, scheduled)

private def expectPairRefusal {α : Type}
    (root : System.FilePath)
    (context : String)
    (action : IO (Except String α)) : IO Unit := do
  let beforeActual ← authorityBytes root
  let beforeScheduled ← scheduledBytes root
  match ← action with
  | .ok _ =>
      throw <| IO.userError s!"{context}: operation unexpectedly succeeded"
  | .error _ => pure ()
  let afterActual ← authorityBytes root
  let afterScheduled ← scheduledBytes root
  expect (afterActual == beforeActual)
    s!"{context}: refused operation changed actual.loam"
  expect (afterScheduled == beforeScheduled)
    s!"{context}: refused operation changed scheduled.loam"
  let _ ← checkAuthorityPair root context
  pure ()

private def completionCount (memory : ScheduledTerminalMemory) : Nat :=
  (memory.terminals.filterMap fun terminal =>
    match terminal.target with
    | some (.actual event) => some (terminal.source, event)
    | _ => none).length

private def hasOpen
    (records : List (ScheduledOccurrence String))
    (token : String) : Bool :=
  records.any fun record => record.id.token == token

private def approvedLoci : IO LocusAdmissionVocabulary :=
  requireSome
    (LocusAdmissionVocabulary.ofLoci? [
      ⟨"paypay"⟩,
      ⟨"smbc"⟩,
      ⟨"rent"⟩,
      ⟨"food"⟩
    ])
    "Scheduled recovery Locus vocabulary was not unique"

private def prepareRoot
    (root : System.FilePath) : IO LocusAdmissionVocabulary := do
  cleanupDir root
  IO.FS.createDirAll root

  let _ ← requireOk
    (← Loam.ActualAuthority.publishActual? root ActualEvidence.empty)
    "initialize empty Actual authority"

  let loci ← approvedLoci
  let _ ← requireOk
    (← Loam.LocusAdmissionAuthority.publishCurrent? root loci)
    "publish Scheduled recovery Locus policy"

  let s1 ← occurrence "scheduled-1" "2026-09-10" "paypay" "rent" 1000
  let s2 ← occurrence "scheduled-2" "2026-09-10" "paypay" "food" 200
  let s3 ← occurrence "scheduled-3" "2026-09-11" "smbc" "rent" 3000
  let scheduled ← requireSome
    (ScheduledMemory.ofOccurrences? [s1, s2, s3])
    "Scheduled recovery memory construction failed"
  let terminals ← requireSome
    (ScheduledTerminalMemory.ofTerminals? [])
    "Scheduled recovery terminal memory construction failed"

  expect
    (← saveScheduledLifecycleImage? (scheduledPath root) {
      scheduled := scheduled
      terminals := terminals
    })
    "publish Scheduled recovery lifecycle fixture"

  let _ ← checkAuthorityPair root "initial Scheduled recovery fixture"
  pure loci

private def runScenario
    (root : System.FilePath) : IO (Stats × String × String × String) := do
  let loci ← prepareRoot root
  let mut stats : Stats := {}

  -- Fresh two-authority completion.
  let _ ← requireOk
    (← Loam.HouseholdCommand.completeScheduled root
      (completionDraft "scheduled-1" "2026-09-08" "paypay" "rent" 1100))
    "step 1 fresh Scheduled completion failed"
  stats := { stats with freshCompletions := stats.freshCompletions + 1 }

  let afterFresh ← loadScheduled root "step 1 fresh completion"
  let freshEndpoint ← requireSome
    (afterFresh.terminals.completionActualFor? ⟨"scheduled-1"⟩)
    "step 1 completion endpoint missing"
  let freshActual ← loadActual root "step 1 fresh completion"
  let freshEvent ← requireSome
    (freshActual.events.findById? freshEndpoint)
    "step 1 completion Actual Event missing"
  expect (freshEvent.effects.all fun effect => effect.key.isNone)
    "step 1 Scheduled completion retained collector-local Effect identity"
  let _ ← checkAuthorityPair root "step 1 fresh completion"

  -- Independent cancellation remains Scheduled-only.
  let actualBeforeCancel ← authorityBytes root
  let _ ← requireOk
    (← Loam.HouseholdCommand.cancelScheduled root {
      scheduled := ⟨"scheduled-2"⟩
    })
    "step 2 Scheduled cancellation failed"
  stats := { stats with cancellations := stats.cancellations + 1 }
  let actualAfterCancel ← authorityBytes root
  expect (actualAfterCancel == actualBeforeCancel)
    "step 2 Scheduled-only cancellation changed actual.loam"
  let afterCancel ← loadScheduled root "step 2 cancellation"
  expect
    (afterCancel.terminals.terminals.any fun terminal =>
      terminal.source == ⟨"scheduled-2"⟩ && terminal.target.isNone)
    "step 2 cancellation terminal missing"
  let _ ← checkAuthorityPair root "step 2 cancellation"

  -- Controlled interruption at the documented relation-first boundary:
  -- retain the Scheduled completion claim but do not publish its Actual Event.
  let beforeInterruptedActual ← authorityBytes root
  let lifecycle ← loadScheduled root "step 3 before interrupted claim"
  let recoveredEndpoint : EventId := ⟨"recovered-actual-3"⟩
  let interrupted : ScheduledTerminal := {
    source := ⟨"scheduled-3"⟩
    target := some (.actual recoveredEndpoint)
  }
  let terminals ← requireSome
    (lifecycle.terminals.add? interrupted)
    "step 3 interrupted completion relation was not admissible"
  expect
    (← saveScheduledLifecycleImage? (scheduledPath root) {
      lifecycle with terminals := terminals
    })
    "step 3 interrupted completion claim could not be retained"
  stats := { stats with interruptedClaims := stats.interruptedClaims + 1 }
  expect ((← authorityBytes root) == beforeInterruptedActual)
    "step 3 interrupted Scheduled claim changed actual.loam"

  let interruptedActual ← loadActual root "step 3 interrupted claim"
  expect ((interruptedActual.events.findById? recoveredEndpoint).isNone)
    "step 3 interruption unexpectedly published the Actual endpoint"

  let snapshot ← requireOk
    (← Loam.ScheduledReview.loadHouseholdEvidence root root)
    "step 3 Scheduled review rejected inert interrupted completion"
  let openRecords ← requireOk
    (Loam.ScheduledReview.currentOpenRecords snapshot)
    "step 3 current-open Scheduled projection failed"
  expect (hasOpen openRecords "scheduled-3")
    "step 3 inert interrupted completion incorrectly closed Scheduled source"
  let _ ← checkAuthorityPair root "step 3 interrupted claim"

  -- Cancellation may not compete with the retained completion claim.
  expectPairRefusal root "step 4 cancellation against interrupted completion"
    (Loam.HouseholdCommand.cancelScheduled root {
      scheduled := ⟨"scheduled-3"⟩
    })
  stats := { stats with refusals := stats.refusals + 1 }

  -- Make the retry temporarily inadmissible by changing only current new-write
  -- policy. The retained Scheduled claim must remain intact.
  let _ ← requireOk
    (← Loam.LocusAdmissionAuthority.publishCurrent?
      root LocusAdmissionVocabulary.empty)
    "step 5 publish closed Locus policy"
  let scheduledBeforeBlockedRetry ← scheduledBytes root
  expectPairRefusal root "step 5 blocked recovery retry"
    (Loam.HouseholdCommand.completeScheduled root
      (completionDraft "scheduled-3" "2026-09-09" "smbc" "rent" 3100))
  stats := {
    stats with
    blockedRetries := stats.blockedRetries + 1
    refusals := stats.refusals + 1
  }
  expect ((← scheduledBytes root) == scheduledBeforeBlockedRetry)
    "step 5 blocked retry changed retained completion claim"

  -- Restore policy, then retry through the ordinary production entrance.
  let _ ← requireOk
    (← Loam.LocusAdmissionAuthority.publishCurrent? root loci)
    "step 6 restore Scheduled recovery Locus policy"

  let scheduledBeforeRecovery ← scheduledBytes root
  let _ ← requireOk
    (← Loam.HouseholdCommand.completeScheduled root
      (completionDraft "scheduled-3" "2026-09-09" "smbc" "rent" 3100))
    "step 6 interrupted Scheduled completion did not recover"
  stats := {
    stats with
    recoveredCompletions := stats.recoveredCompletions + 1
  }

  let scheduledAfterRecovery ← scheduledBytes root
  expect (scheduledAfterRecovery == scheduledBeforeRecovery)
    "step 6 recovery rewrote an already-retained Scheduled completion claim"

  let recoveredActual ← loadActual root "step 6 recovered completion"
  let recoveredEvent ← requireSome
    (recoveredActual.events.findById? recoveredEndpoint)
    "step 6 recovery did not honor retained Actual endpoint"
  expect (recoveredEvent.effects.all fun effect => effect.key.isNone)
    "step 6 recovered completion retained collector-local Effect identity"

  let recoveredLifecycle ← loadScheduled root "step 6 recovered completion"
  expect
    (recoveredLifecycle.terminals.completionActualFor? ⟨"scheduled-3"⟩ ==
      some recoveredEndpoint)
    "step 6 recovery changed canonical retained endpoint"
  expect (completionCount recoveredLifecycle.terminals == 2)
    "step 6 recovery duplicated or lost completion claims"
  let _ ← checkAuthorityPair root "step 6 recovered completion"

  -- Completed endpoint is now terminal. A further completion attempt must be a
  -- pure refusal across both authorities.
  expectPairRefusal root "step 7 duplicate completion after recovery"
    (Loam.HouseholdCommand.completeScheduled root
      (completionDraft "scheduled-3" "2026-09-09" "smbc" "rent" 3100))
  stats := { stats with refusals := stats.refusals + 1 }

  let finalSnapshot ← requireOk
    (← Loam.ScheduledReview.loadHouseholdEvidence root root)
    "final Scheduled review failed"
  let finalOpen ← requireOk
    (Loam.ScheduledReview.currentOpenRecords finalSnapshot)
    "final current-open Scheduled projection failed"
  expect (!hasOpen finalOpen "scheduled-1")
    "final fresh completion remained current-open"
  expect (!hasOpen finalOpen "scheduled-2")
    "final cancellation remained current-open"
  expect (!hasOpen finalOpen "scheduled-3")
    "final recovered completion remained current-open"

  let (actualFinal, scheduledFinal) ←
    checkAuthorityPair root "final Scheduled recovery scenario"
  let policyFinal ← policyBytes root
  pure (stats, actualFinal, scheduledFinal, policyFinal)

def runTests : IO Unit := do
  let rootA := System.FilePath.mk "scratch/test-deterministic-scheduled-recovery-a"
  let rootB := System.FilePath.mk "scratch/test-deterministic-scheduled-recovery-b"

  let (statsA, actualA, scheduledA, policyA) ← runScenario rootA
  let (statsB, actualB, scheduledB, policyB) ← runScenario rootB

  expect (statsA == statsB)
    "deterministic Scheduled recovery replay changed scenario counters"
  expect (actualA == actualB)
    "deterministic Scheduled recovery replay changed final actual.loam bytes"
  expect (scheduledA == scheduledB)
    "deterministic Scheduled recovery replay changed final scheduled.loam bytes"
  expect (policyA == policyB)
    "deterministic Scheduled recovery replay changed final HouseholdImage Locus policy bytes"

  expect (statsA.freshCompletions == 1)
    "Scheduled recovery scenario missed fresh completion"
  expect (statsA.cancellations == 1)
    "Scheduled recovery scenario missed cancellation"
  expect (statsA.interruptedClaims == 1)
    "Scheduled recovery scenario missed controlled interrupted claim"
  expect (statsA.blockedRetries == 1)
    "Scheduled recovery scenario missed policy-blocked retry"
  expect (statsA.recoveredCompletions == 1)
    "Scheduled recovery scenario missed recovery completion"
  expect (statsA.refusals == 3)
    "Scheduled recovery scenario missed expected refusal branches"

  cleanupDir rootA
  cleanupDir rootB

  IO.println
    s!"Deterministic Scheduled recovery scenario passed: freshCompletions={statsA.freshCompletions}, cancellations={statsA.cancellations}, interruptedClaims={statsA.interruptedClaims}, blockedRetries={statsA.blockedRetries}, recoveredCompletions={statsA.recoveredCompletions}, refusals={statsA.refusals}."

end Loam.Tests.DeterministicScheduledRecoveryScenario

def main : IO Unit :=
  Loam.Tests.DeterministicScheduledRecoveryScenario.runTests
