import Loam.Core.EventMemory
import Loam.Core.ActualValidity
import Loam.Core.ScheduledCompletion

namespace Loam.Observation129

open Loam.Core

set_option autoImplicit false

/-!
# Observation 129 — Can one-time historical admission publish fresh LOAM identity atomically across evidence streams?

This observation studies the multi-stream publication protocol for a one-time
historical admission:
- Fresh destination-side EventId / EffectKey values are issued by LOAM
- Several physically separate streams (EventMemory, ActualValidity, ScheduledCompletion)
  share the same newly issued identities
- A durable Prepared Admission state acts as a temporary recovery aid across crashes
  and is retired once the receipt is committed (following Observation 076)
- The protocol guarantees:
  1. auxiliary-first publication leaves candidate facts inert prior to event commit
  2. committing EventMemory makes all candidate evidence live simultaneously
  3. crash after event commit recovers using the exact prepared candidate without reissuing fresh IDs
  4. receipt commit guarantees complete persistent facts
  5. inconsistent destination state fails closed
  6. temporary prepared state is safely retired after receipt commit
-/

/--
A multi-stream candidate prepared entirely in memory before publication.
All cross-stream references are validated closed within the candidate bundle.
-/
structure AdmissionCandidate (Time : Type) where
  events : EventMemory
  validities : ActualValidityMemory Time
  completions : ScheduledCompletionMemory
  validity_closed : ∀ fact ∈ validities.entries,
    (EventMemory.findById? events fact.event).isSome = true
  completion_closed : ∀ comp ∈ completions.completions,
    (EventMemory.findById? events comp.actual).isSome = true

/--
Durable staging state retained across process crashes.
Holds the source snapshot fingerprint, the base destination state, and the exact candidate bundle.
This is a temporary recovery aid, not a permanent sidecar.
-/
structure PreparedAdmission (Time : Type) where
  snapshotHash : String
  baseEvents : EventMemory
  candidate : AdmissionCandidate Time

/--
The observable physical persistent state across all participating streams and staging files.
-/
structure PersistentWorld (Time : Type) where
  events : EventMemory
  validities : ActualValidityMemory Time
  completions : ScheduledCompletionMemory
  prepared : Option (PreparedAdmission Time)
  receiptCommitted : Bool

/--
Live validity facts recognized by an Event-first reader.
A validity fact is live only if its referenced Event exists in EventMemory.
-/
def liveValidities {Time : Type} (world : PersistentWorld Time) : List (ActualValidity Time) :=
  world.validities.entries.filter fun fact =>
    (EventMemory.findById? world.events fact.event).isSome

/--
Live completions recognized by an Event-first reader.
A completion is live only if its referenced actual Event exists in EventMemory.
-/
def liveCompletions {Time : Type} (world : PersistentWorld Time) : List ScheduledCompletion :=
  world.completions.completions.filter fun comp =>
    (EventMemory.findById? world.events comp.actual).isSome

/--
Phases of exclusive historical admission publication.
-/
inductive PublicationPhase
  | Initial
  | PreparedRetained
  | AuxiliaryReplaced
  | EventMemoryCommitted
  | ReceiptCommitted
  | Retired
deriving DecidableEq

/--
Step-by-step publication sequence.
-/
def publishStep {Time : Type}
    (snapshotHash : String)
    (candidate : AdmissionCandidate Time) :
    PublicationPhase → PersistentWorld Time → PersistentWorld Time × PublicationPhase
  | .Initial, world =>
      -- Step 1: Durably retain PREPARED admission state
      ({ world with
         prepared := some {
           snapshotHash := snapshotHash,
           baseEvents := world.events,
           candidate := candidate
         } },
       .PreparedRetained)
  | .PreparedRetained, world =>
      -- Step 2: Publish auxiliary streams (validities, completions)
      -- EventMemory is still base state.
      ({ world with
         validities := candidate.validities,
         completions := candidate.completions },
       .AuxiliaryReplaced)
  | .AuxiliaryReplaced, world =>
      -- Step 3: Publish EventMemory (Canonical Commit Point)
      ({ world with events := candidate.events },
       .EventMemoryCommitted)
  | .EventMemoryCommitted, world =>
      -- Step 4: Publish Admission Receipt (Idempotency Commit Point)
      ({ world with receiptCommitted := true },
       .ReceiptCommitted)
  | .ReceiptCommitted, world =>
      -- Step 5: Retire temporary PREPARED admission state
      ({ world with prepared := none },
       .Retired)
  | .Retired, world =>
      (world, .Retired)

/--
Decide equality of EventMemory identities.
-/
def eventIdsEqual (m1 m2 : EventMemory) : Bool :=
  decide (m1.events.map Event.id = m2.events.map Event.id)

/--
Restart recovery actions on process reboot.
-/
inductive RestartAction
  | StartFresh
  | ResumePreparedAuxiliary
  | RecoverReceiptOnly
  | CleanupLeftoverPrepared
  | FailClosedInconsistent
deriving DecidableEq

/--
Restart planner inspecting only durable persistent state.
Does NOT require in-memory parameters from the pre-crash process.
-/
def planRestart {Time : Type}
    (world : PersistentWorld Time)
    (currentSnapshotHash : String) : RestartAction :=
  match world.receiptCommitted, world.prepared with
  | true, none =>
      .StartFresh
  | true, some _ =>
      -- Case 5: Receipt committed, clean up leftover prepared aid
      .CleanupLeftoverPrepared
  | false, none =>
      -- Case 1: No prepared state, start fresh
      .StartFresh
  | false, some prep =>
      if prep.snapshotHash != currentSnapshotHash then
        .FailClosedInconsistent
      else if eventIdsEqual world.events prep.candidate.events then
        -- Case 4: EventMemory already committed, recover receipt using exact prepared candidate
        .RecoverReceiptOnly
      else if eventIdsEqual world.events prep.baseEvents then
        -- Cases 2 & 3: EventMemory still base, resume auxiliary/event publication from prepared candidate
        .ResumePreparedAuxiliary
      else
        -- Case 6: Inconsistent destination state, fail closed
        .FailClosedInconsistent

/--
Theorem 1 (Auxiliary-First Crash Inertness):
If a crash occurs after auxiliary streams are replaced but before EventMemory is committed,
no newly introduced candidate event is present in the reader-visible live validities,
because its EventId does not yet exist in the unmodified EventMemory.
-/
theorem auxiliary_crash_inert
    {Time : Type}
    (initialWorld : PersistentWorld Time)
    (snapshotHash : String)
    (candidate : AdmissionCandidate Time)
    (hDisjoint : ∀ fact ∈ candidate.validities.entries,
      (EventMemory.findById? initialWorld.events fact.event).isSome = false) :
    let step1 := publishStep snapshotHash candidate .Initial initialWorld
    let step2 := publishStep snapshotHash candidate step1.2 step1.1
    step2.2 = .AuxiliaryReplaced ∧
    ∀ fact ∈ candidate.validities.entries,
      fact ∉ liveValidities step2.1 := by
  dsimp [publishStep, liveValidities]
  constructor
  · rfl
  · intro fact hFactIn
    simp only [List.mem_filter]
    intro ⟨_, hSome⟩
    have hNone := hDisjoint fact hFactIn
    rw [hNone] at hSome
    contradiction

/--
Theorem 2 (Event Commit Completeness):
The moment EventMemory is committed, every newly admitted Event already has its
validity evidence and completion evidence present on disk.
-/
theorem event_commit_complete
    {Time : Type}
    (initialWorld : PersistentWorld Time)
    (snapshotHash : String)
    (candidate : AdmissionCandidate Time) :
    let step1 := publishStep snapshotHash candidate .Initial initialWorld
    let step2 := publishStep snapshotHash candidate step1.2 step1.1
    let step3 := publishStep snapshotHash candidate step2.2 step2.1
    (∀ fact ∈ candidate.validities.entries, fact ∈ liveValidities step3.1) ∧
    (∀ comp ∈ candidate.completions.completions, comp ∈ liveCompletions step3.1) := by
  dsimp [publishStep, liveValidities, liveCompletions]
  constructor
  · intro fact hFact
    simp only [List.mem_filter]
    exact ⟨hFact, candidate.validity_closed fact hFact⟩
  · intro comp hComp
    simp only [List.mem_filter]
    exact ⟨hComp, candidate.completion_closed comp hComp⟩

/--
Theorem 3 (Restart Case 4 Recovers Exact Prepared Candidate Without Reissuing IDs):
If a crash occurs after EventMemory is committed but before receipt publication,
restart inspects durable state, finds the exact prepared candidate matching current EventMemory,
and chooses RecoverReceiptOnly.
-/
theorem restart_case4_recovers_exact_candidate
    {Time : Type}
    (initialWorld : PersistentWorld Time)
    (hInitialUncommitted : initialWorld.receiptCommitted = false)
    (snapshotHash : String)
    (candidate : AdmissionCandidate Time) :
    let step1 := publishStep snapshotHash candidate .Initial initialWorld
    let step2 := publishStep snapshotHash candidate step1.2 step1.1
    let step3 := publishStep snapshotHash candidate step2.2 step2.1
    planRestart step3.1 snapshotHash = .RecoverReceiptOnly := by
  dsimp [publishStep, planRestart, eventIdsEqual]
  rw [hInitialUncommitted]
  simp

/--
Theorem 4 (Restart Case 2/3 Resumes from Prepared Candidate):
If a crash occurs during auxiliary publication or before EventMemory commit,
restart detects that EventMemory matches the base state and resumes from the prepared candidate.
-/
theorem restart_case2_resumes_prepared_candidate
    {Time : Type}
    (initialWorld : PersistentWorld Time)
    (hInitialUncommitted : initialWorld.receiptCommitted = false)
    (snapshotHash : String)
    (candidate : AdmissionCandidate Time)
    (hCandidateFresh : eventIdsEqual initialWorld.events candidate.events = false) :
    let step1 := publishStep snapshotHash candidate .Initial initialWorld
    let step2 := publishStep snapshotHash candidate step1.2 step1.1
    planRestart step2.1 snapshotHash = .ResumePreparedAuxiliary := by
  dsimp [publishStep, planRestart]
  rw [hInitialUncommitted]
  dsimp [eventIdsEqual] at hCandidateFresh
  simp [eventIdsEqual, hCandidateFresh]

/--
Theorem 5 (Restart Case 5 Cleans Up Leftover Prepared Aid):
If a crash occurs after receipt commit but before retirement,
restart recognizes receipt completion and chooses CleanupLeftoverPrepared.
-/
theorem restart_case5_cleans_up_leftover_aid
    {Time : Type}
    (initialWorld : PersistentWorld Time)
    (snapshotHash : String)
    (candidate : AdmissionCandidate Time) :
    let step1 := publishStep snapshotHash candidate .Initial initialWorld
    let step2 := publishStep snapshotHash candidate step1.2 step1.1
    let step3 := publishStep snapshotHash candidate step2.2 step2.1
    let step4 := publishStep snapshotHash candidate step3.2 step3.1
    planRestart step4.1 snapshotHash = .CleanupLeftoverPrepared := by
  dsimp [publishStep, planRestart]

/--
Theorem 6 (Restart Case 6 Fails Closed on Unknown Destination State):
If current EventMemory matches neither base state nor candidate state,
restart refuses automatic repair and fails closed.
-/
theorem restart_case6_fails_closed
    {Time : Type}
    (world : PersistentWorld Time)
    (hUncommitted : world.receiptCommitted = false)
    (prep : PreparedAdmission Time)
    (hPrep : world.prepared = some prep)
    (hNotCandidate : eventIdsEqual world.events prep.candidate.events = false)
    (hNotBase : eventIdsEqual world.events prep.baseEvents = false) :
    planRestart world prep.snapshotHash = .FailClosedInconsistent := by
  dsimp [planRestart]
  rw [hUncommitted, hPrep]
  simp [hNotCandidate, hNotBase]

/--
Theorem 7 (Receipt Guarantees Full Canonical Publication):
Whenever the admission receipt is committed through the protocol,
the persistent world holds the complete candidate events, validities, and completions.
-/
theorem receipt_guarantees_completeness
    {Time : Type}
    (initialWorld : PersistentWorld Time)
    (snapshotHash : String)
    (candidate : AdmissionCandidate Time) :
    let step1 := publishStep snapshotHash candidate .Initial initialWorld
    let step2 := publishStep snapshotHash candidate step1.2 step1.1
    let step3 := publishStep snapshotHash candidate step2.2 step2.1
    let step4 := publishStep snapshotHash candidate step3.2 step3.1
    step4.1.receiptCommitted = true ∧
    step4.1.events = candidate.events ∧
    step4.1.validities = candidate.validities ∧
    step4.1.completions = candidate.completions := by
  dsimp [publishStep]
  exact ⟨rfl, rfl, rfl, rfl⟩

end Loam.Observation129
