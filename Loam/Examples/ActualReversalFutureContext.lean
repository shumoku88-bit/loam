import Loam.Core.ActualReversal
import Loam.Observations.Observation192

namespace Loam.Examples.ActualReversalFutureContext

open Loam.Core

set_option autoImplicit false

/-!
# Future-context probe: retained Actual reversal provenance

This probe isolates one existing LOAM relation family whose meaning differs from
both EventCorrection and document derivation.

An `ActualReversal` does not supersede its target. It records that one retained
Event is the explicit inverse of another retained Event. Both endpoint Events
remain historical facts. At the Core memory boundary, every endpoint identity is
globally unique across both roles.

The probe intentionally studies that retained relation-memory law only. It does
not model the complete practical reversal publisher, referential closure, or the
exact physical-inverse admission performed at the production boundary.

Question:

> Can two reversal memories that currently give the same selected provenance
> answer react differently to the same future reversal publication because one
> memory has already consumed an endpoint identity?

That distinction is neither Correction supersession nor unrestricted document
provenance.
-/

private def eventA : EventId := ⟨"reversal:a"⟩
private def eventB : EventId := ⟨"reversal:b"⟩
private def eventC : EventId := ⟨"reversal:c"⟩
private def eventD : EventId := ⟨"reversal:d"⟩

private def leftBase : ActualReversal :=
  { target := eventC
    reversal := eventB }

private def rightBase : ActualReversal :=
  { target := eventC
    reversal := eventD }

private def leftMemory : ActualReversalMemory :=
  { reversals := [leftBase]
    endpointNodup := by native_decide }

private def rightMemory : ActualReversalMemory :=
  { reversals := [rightBase]
    endpointNodup := by native_decide }

structure State where
  reversals : ActualReversalMemory

inductive Operation where
  | publish : ActualReversal → Operation
  deriving Repr, DecidableEq

inductive Question where
  | aIsReversed
  deriving Repr, DecidableEq

/--
Publish one reversal relation when its two endpoint identities remain globally
fresh. Rejected publication leaves the retained memory unchanged.
-/
def step (state : State) : Operation → State
  | .publish reversal =>
      match state.reversals.add? reversal with
      | some updated => { reversals := updated }
      | none => state

/-- Selected provenance observation: does A already have an explicit reversal? -/
def answer (state : State) : Question → Bool
  | .aIsReversed =>
      (state.reversals.findByTarget? eventA).isSome

def Vocabulary : Loam.Observation029.Vocabulary Question :=
  fun _ => True

private def leftState : State :=
  { reversals := leftMemory }

private def rightState : State :=
  { reversals := rightMemory }

theorem left_current_answer :
    answer leftState .aIsReversed = false := by
  native_decide

theorem right_current_answer :
    answer rightState .aIsReversed = false := by
  native_decide

theorem states_are_currently_equivalent :
    Loam.Observation029.Equivalent
      answer Vocabulary leftState rightState := by
  intro question _
  cases question
  rw [left_current_answer, right_current_answer]

private def futureReversal : ActualReversal :=
  { target := eventA
    reversal := eventB }

private def publishFuture : Operation :=
  .publish futureReversal

/-!
The same future relation A -> B behaves differently:

left:
  C -> B already consumes B
  A -> B is rejected

right:
  C -> D leaves A and B fresh
  A -> B is admitted
-/

theorem left_after_future_answer :
    answer (step leftState publishFuture) .aIsReversed = false := by
  native_decide

theorem right_after_future_answer :
    answer (step rightState publishFuture) .aIsReversed = true := by
  native_decide

theorem states_are_not_futureEquivalent :
    ¬ Loam.Observation192.FutureEquivalent
      answer step Vocabulary leftState rightState := by
  intro hFuture
  have hAfter :=
    hFuture [publishFuture] .aIsReversed (by simp [Vocabulary])
  change
    answer
        (Loam.Observation192.run step leftState [publishFuture])
        .aIsReversed =
      answer
        (Loam.Observation192.run step rightState [publishFuture])
        .aIsReversed
    at hAfter
  simp [Loam.Observation192.run] at hAfter
  rw [left_after_future_answer, right_after_future_answer] at hAfter
  simp at hAfter

/-- Current selected provenance answer alone is the candidate lossy summary. -/
def encodeCurrentAnswer (state : State) : Bool :=
  answer state .aIsReversed

theorem current_answer_summary_is_not_future_sufficient :
    ¬ Loam.Observation192.FutureSufficient
      answer step Vocabulary encodeCurrentAnswer := by
  intro hSufficient
  have hEquivalent :
      Loam.Observation192.FutureEquivalent
        answer step Vocabulary leftState rightState :=
    Loam.Observation192.equalFutureSummaryInvisible
      answer step Vocabulary hSufficient (by
        rw [encodeCurrentAnswer, encodeCurrentAnswer,
          left_current_answer, right_current_answer])
  exact states_are_not_futureEquivalent hEquivalent

end Loam.Examples.ActualReversalFutureContext
