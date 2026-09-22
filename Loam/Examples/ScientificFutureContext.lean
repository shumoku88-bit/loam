import Loam.Application.CorrectionFrontier
import Loam.Core.EventCorrectionMemory
import Loam.Observations.Observation192

namespace Loam.Examples.ScientificFutureContext

open Loam.Core

set_option autoImplicit false

/-!
# Non-household future-context probe: scalar scientific evidence

This probe asks whether the future-context distinction from Observations 192-194
depends on household accounting.

It deliberately removes:

- accounts and accounting roles;
- debit / credit vocabulary;
- transfers and source/destination movement;
- balancing and conservation laws.

Each retained Event below contains exactly one positive scalar Effect at one
scientific observation coordinate. The two worlds retain exactly the same Event
evidence and currently return the same scalar answer. They differ only in
Correction topology.

The same future Correction then creates a cycle in one world but not the other.
The existing fail-closed CorrectionFrontier therefore returns `none` in one
world and a defined scalar result in the other.

The purpose is not to claim a new mathematical theorem. It is a second concrete
domain witness that current observational equality can be strictly weaker than
future-context equivalence.
-/

def plantA : LocusId := ⟨"science:plant-a"⟩
def sampleCount : MeasureId := ⟨"science:sample-count"⟩

private def scalarEvent (idToken : String) (quanta : Int) : Event :=
  { id := ⟨idToken⟩
    effects :=
      [Effect.ofAnonymousQuantity plantA sampleCount (Quantity.ofQuanta quanta)]
    keyNodup := by
      simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

private def eventA : Event := scalarEvent "science:a" 7
private def eventB : Event := scalarEvent "science:b" 8
private def eventC : Event := scalarEvent "science:c" 7
private def eventD : Event := scalarEvent "science:d" 2

/-- All retained facts are single positive scalar observations, not balanced movements. -/
theorem events_are_single_scalar_observations :
    eventA.effects.length = 1 ∧
    eventB.effects.length = 1 ∧
    eventC.effects.length = 1 ∧
    eventD.effects.length = 1 := by
  native_decide

private def sharedEvents : EventMemory :=
  { events := [eventA, eventB, eventC, eventD]
    idNodup := by native_decide }

private def leftBaseCorrection : EventCorrection :=
  { target := eventA.id
    replacement := eventB.id }

private def rightBaseCorrection : EventCorrection :=
  { target := eventC.id
    replacement := eventD.id }

private def leftCorrections : EventCorrectionMemory :=
  { corrections := [leftBaseCorrection]
    idNodup := by simp [leftBaseCorrection, eventA, eventB, scalarEvent] }

private def rightCorrections : EventCorrectionMemory :=
  { corrections := [rightBaseCorrection]
    idNodup := by simp [rightBaseCorrection, eventC, eventD, scalarEvent] }

structure State where
  events : EventMemory
  corrections : EventCorrectionMemory

inductive Operation where
  | publish : EventCorrection → Operation
  deriving Repr, DecidableEq

inductive Question where
  | observedScalar
  deriving Repr, DecidableEq

def step (state : State) : Operation → State
  | .publish correction =>
      match EventCorrectionMemory.add? state.corrections correction with
      | some updated => { state with corrections := updated }
      | none => state

/-- Correction publication changes only correction evidence, never retained Events. -/
theorem step_preserves_events
    (state : State) (correction : EventCorrection) :
    (step state (.publish correction)).events = state.events := by
  unfold step
  cases hAdd : EventCorrectionMemory.add? state.corrections correction <;> simp [hAdd]

/-- The selected observation is the existing fail-closed correction-frontier quantity. -/
def answer (state : State) : Question → Option Int
  | .observedScalar =>
      (Loam.Application.quantityAtCorrectionFrontier?
        state.events state.corrections plantA sampleCount).map Quantity.quanta

def Vocabulary : Loam.Observation029.Vocabulary Question :=
  fun _ => True

private def leftState : State :=
  { events := sharedEvents
    corrections := leftCorrections }

private def rightState : State :=
  { events := sharedEvents
    corrections := rightCorrections }

/-- Both worlds retain exactly the same scientific Event evidence. -/
theorem retained_event_evidence_is_identical :
    leftState.events = rightState.events := by
  rfl

/--
The left frontier removes A and retains B, C, D: 8 + 7 + 2 = 17.
The right frontier removes C and retains A, B, D: 7 + 8 + 2 = 17.
-/
theorem left_current_answer :
    answer leftState .observedScalar = some 17 := by
  native_decide

theorem right_current_answer :
    answer rightState .observedScalar = some 17 := by
  native_decide

/-- The selected current scientific observation cannot distinguish the worlds. -/
theorem states_are_currently_equivalent :
    Loam.Observation029.Equivalent
      answer Vocabulary leftState rightState := by
  intro question _
  cases question
  rw [left_current_answer, right_current_answer]

private def futureCorrection : EventCorrection :=
  { target := eventB.id
    replacement := eventA.id }

private def publishFuture : Operation :=
  .publish futureCorrection

/-!
After publishing the same future edge B -> A:

left:
  A -> B -> A
  cycle, therefore fail closed

right:
  C -> D
  B -> A
  disjoint finite paths

The retained Event evidence remains unchanged in both worlds.
-/

theorem left_after_future_is_inadmissible :
    Loam.Application.correctionFrontierAdmissible
      (step leftState publishFuture).events
      (step leftState publishFuture).corrections = false := by
  native_decide

theorem right_after_future_is_admissible :
    Loam.Application.correctionFrontierAdmissible
      (step rightState publishFuture).events
      (step rightState publishFuture).corrections = true := by
  native_decide

theorem left_after_future_answer :
    answer (step leftState publishFuture) .observedScalar = none := by
  native_decide

/--
On the right, B and C are superseded, leaving A and D:
7 + 2 = 9.
-/
theorem right_after_future_answer :
    answer (step rightState publishFuture) .observedScalar = some 9 := by
  native_decide

/--
Current equality is strictly weaker than future-context equality in this
non-accounting scalar-observation domain.
-/
theorem states_are_not_futureEquivalent :
    ¬ Loam.Observation192.FutureEquivalent
      answer step Vocabulary leftState rightState := by
  intro hFuture
  have hAfter :=
    hFuture [publishFuture] .observedScalar (by simp [Vocabulary])
  change
    answer
        (Loam.Observation192.run step leftState [publishFuture])
        .observedScalar =
      answer
        (Loam.Observation192.run step rightState [publishFuture])
        .observedScalar
    at hAfter
  simp [Loam.Observation192.run] at hAfter
  rw [left_after_future_answer, right_after_future_answer] at hAfter
  simp at hAfter

/-- Publishing the distinguishing Correction still does not mutate Event evidence. -/
theorem retained_event_evidence_remains_identical_after_future :
    (step leftState publishFuture).events =
      (step rightState publishFuture).events := by
  rw [step_preserves_events, step_preserves_events]
  exact retained_event_evidence_is_identical

/--
Therefore a summary that keeps only the current scalar answer cannot be sufficient
for the future vocabulary that permits Correction publication.
-/
def encodeCurrentScalar (state : State) : Option Int :=
  answer state .observedScalar

theorem current_scalar_summary_is_not_future_sufficient :
    ¬ Loam.Observation192.FutureSufficient
      answer step Vocabulary encodeCurrentScalar := by
  intro hSufficient
  have hEquivalent :
      Loam.Observation192.FutureEquivalent
        answer step Vocabulary leftState rightState :=
    Loam.Observation192.equalFutureSummaryInvisible
      answer step Vocabulary hSufficient (by
        rw [encodeCurrentScalar, encodeCurrentScalar,
          left_current_answer, right_current_answer])
  exact states_are_not_futureEquivalent hEquivalent

end Loam.Examples.ScientificFutureContext
