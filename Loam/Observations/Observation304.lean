import Loam.Core.ActualReversal
import Loam.Observations.Observation298

namespace Loam.Observation304

open Loam.Core

set_option autoImplicit false

/-!
# Observation 304 — a positive retention certificate over Actual reversal memory

Observations 300–303 developed the negative side of the retention verifier:
find two states collapsed by a candidate summary, discover one common future
context that distinguishes them, and check the payload into
`¬ FutureSufficient`.

This observation exercises the positive side against an existing LOAM Core
relation family.

The declared future vocabulary is intentionally narrow:

- the only allowed operation is publication of one fixed reversal relation
  `A -> B`;
- the only selected question is whether `A` already has an explicit reversal.

For that vocabulary, the complete retained reversal history is more information
than future answering needs. It is enough to retain:

- whether A is already used as any reversal endpoint;
- whether B is already used as any reversal endpoint;
- whether A is already used specifically as a reversal target.

Those three bits determine both the selected current answer and whether the one
allowed future publication will be admitted.

The result is deliberately vocabulary-relative. It does not claim that three
bits are sufficient for arbitrary ActualReversal publications or for production
reversal admission.
-/

private def eventA : EventId := ⟨"positive-reversal:a"⟩
private def eventB : EventId := ⟨"positive-reversal:b"⟩
private def eventC : EventId := ⟨"positive-reversal:c"⟩
private def eventD : EventId := ⟨"positive-reversal:d"⟩
private def eventE : EventId := ⟨"positive-reversal:e"⟩

private def publishAB : ActualReversal :=
  { target := eventA
    reversal := eventB }

structure State where
  reversals : ActualReversalMemory

inductive Operation where
  | publishAB
  deriving Repr, DecidableEq

inductive Question where
  | aIsReversed
  deriving Repr, DecidableEq

/-- Execute the one declared future publication through the real Core memory admission. -/
def step (state : State) : Operation → State
  | .publishAB =>
      match state.reversals.add? publishAB with
      | some updated => { reversals := updated }
      | none => state

/-- Selected observation: has A already been named as an explicit reversal target? -/
def answer (state : State) : Question → Bool
  | .aIsReversed =>
      (state.reversals.findByTarget? eventA).isSome

def Vocabulary : Loam.Observation029.Vocabulary Question :=
  fun _ => True

/-- Whether one identity is already consumed by either role in reversal memory. -/
def endpointUsed
    (memory : ActualReversalMemory)
    (event : EventId) : Bool :=
  decide (event ∈ ActualReversal.endpointIds memory.reversals)

/--
Three retained bits are enough for the declared question / operation vocabulary.

The complete reversal pairing and every unrelated endpoint identity are omitted.
-/
structure Summary where
  aUsed : Bool
  bUsed : Bool
  aIsReversed : Bool
  deriving Repr, DecidableEq

def encode (state : State) : Summary :=
  { aUsed := endpointUsed state.reversals eventA
    bUsed := endpointUsed state.reversals eventB
    aIsReversed := answer state .aIsReversed }

/-- The selected current answer is read directly from the retained summary. -/
def decodeCurrent (summary : Summary) : Question → Bool
  | .aIsReversed => summary.aIsReversed

theorem encode_is_currently_sufficient :
    Loam.Observation029.SufficientFor
      answer Vocabulary encode := by
  refine ⟨decodeCurrent, ?_⟩
  intro state question _
  cases question
  rfl

/--
Maintain the summary without consulting discarded reversal history.

If either A or B is already consumed, Core admission rejects `A -> B` and the
summary is unchanged. Otherwise the publication is admitted and all three bits
become true.
-/
def summaryStep (summary : Summary) : Operation → Summary
  | .publishAB =>
      if summary.aUsed || summary.bUsed then
        summary
      else
        { aUsed := true
          bUsed := true
          aIsReversed := true }

private theorem eventA_ne_eventB : eventA ≠ eventB := by
  native_decide

/--
The concrete three-bit summary transition commutes with the retained Core state
transition.
-/
theorem summaryStep_commutes
    (state : State)
    (operation : Operation) :
    summaryStep (encode state) operation =
      encode (step state operation) := by
  cases operation
  by_cases hA :
      eventA ∈ ActualReversal.endpointIds state.reversals.reversals
  · simp [summaryStep, encode, endpointUsed, step,
      ActualReversalMemory.add?, publishAB, eventA_ne_eventB, hA]
  · by_cases hB :
        eventB ∈ ActualReversal.endpointIds state.reversals.reversals
    · simp [summaryStep, encode, endpointUsed, step,
        ActualReversalMemory.add?, publishAB, eventA_ne_eventB, hA, hB]
    · have hAFlat := hA
      have hBFlat := hB
      simp [ActualReversal.endpointIds] at hAFlat hBFlat
      have hANone :
          ¬ ∃ relation,
              relation ∈ state.reversals.reversals ∧
                (eventA = relation.target ∨ eventA = relation.reversal) := by
        intro hExists
        rcases hExists with ⟨relation, hMem, hEndpoint⟩
        have hFresh := hAFlat relation hMem
        rcases hEndpoint with hTarget | hReversal
        · exact hFresh.1 hTarget
        · exact hFresh.2 hReversal
      have hBNone :
          ¬ ∃ relation,
              relation ∈ state.reversals.reversals ∧
                (eventB = relation.target ∨ eventB = relation.reversal) := by
        intro hExists
        rcases hExists with ⟨relation, hMem, hEndpoint⟩
        have hFresh := hBFlat relation hMem
        rcases hEndpoint with hTarget | hReversal
        · exact hFresh.1 hTarget
        · exact hFresh.2 hReversal
      simp [summaryStep, encode, endpointUsed, step,
        ActualReversalMemory.add?, publishAB, eventA_ne_eventB,
        hANone, hBNone, answer, ActualReversalMemory.findByTarget?,
        ActualReversal.endpointIds]

/--
The three-bit summary is exactly locally maintainable under the declared future
operation.
-/
theorem encode_is_updateIndependent :
    Loam.Observation297.UpdateIndependent step encode :=
  ⟨summaryStep, summaryStep_commutes⟩

/-- A proof-directed positive certificate over existing Core relation semantics. -/
theorem retentionCertificate :
    Loam.Observation298.MaintainedCertificate
      answer step Vocabulary encode :=
  { current := encode_is_currently_sufficient
    update := encode_is_updateIndependent }

/-- The candidate summary really is sufficient for every declared finite future. -/
theorem encode_is_futureSufficient :
    Loam.Observation192.FutureSufficient
      answer step Vocabulary encode :=
  retentionCertificate.futureSufficient

/-- The verifier's positive branch can carry the real reversal certificate. -/
def retentionVerdict :
    Loam.Observation298.RetentionVerdict
      answer step Vocabulary encode :=
  .preserved encode_is_futureSufficient

/-! ## Canonical behavioural witness states -/

/-- No retained reversal endpoint currently blocks the declared A -> B publication. -/
def availableWitnessState : State :=
  { reversals := ActualReversalMemory.empty }

/--
A is already consumed as a reversal endpoint but is not itself a reversal
target, so the declared A -> B publication is blocked while the selected current
answer remains false.
-/
def blockedWitnessState : State :=
  { reversals :=
      { reversals :=
          [ { target := eventC
              reversal := eventA } ]
        endpointNodup := by native_decide } }

/-- Publishing A -> B from the available state yields the already-reversed class. -/
def alreadyReversedWitnessState : State :=
  step availableWitnessState .publishAB

theorem availableWitness_encode :
    encode availableWitnessState =
      { aUsed := false, bUsed := false, aIsReversed := false } := by
  native_decide

theorem blockedWitness_encode :
    encode blockedWitnessState =
      { aUsed := true, bUsed := false, aIsReversed := false } := by
  native_decide

theorem alreadyReversedWitness_encode :
    encode alreadyReversedWitnessState =
      { aUsed := true, bUsed := true, aIsReversed := true } := by
  native_decide

/-! ## The certificate is genuinely lossy -/

private def leftMemory : ActualReversalMemory :=
  { reversals :=
      [ { target := eventC
          reversal := eventD } ]
    endpointNodup := by native_decide }

private def rightMemory : ActualReversalMemory :=
  { reversals :=
      [ { target := eventC
          reversal := eventE } ]
    endpointNodup := by native_decide }

private def leftState : State :=
  { reversals := leftMemory }

private def rightState : State :=
  { reversals := rightMemory }

/--
The two retained histories differ, but neither history mentions A or B and
neither currently reverses A. The three-bit summary therefore identifies them.
-/
theorem witness_summaries_equal :
    encode leftState = encode rightState := by
  native_decide

private theorem witness_histories_differ :
    leftState.reversals.reversals ≠ rightState.reversals.reversals := by
  native_decide

theorem witness_states_differ :
    leftState ≠ rightState := by
  intro hState
  apply witness_histories_differ
  exact congrArg (fun state => state.reversals.reversals) hState

/-- Future sufficiency here does not come from retaining the whole source state. -/
theorem encode_is_not_injective :
    ¬ Function.Injective encode := by
  intro hInjective
  exact witness_states_differ (hInjective witness_summaries_equal)

/-!
## Finding

The retention verifier now has one existing-LOAM positive case as well as the
counterexample-driven negative cases.

For the declared vocabulary:

    complete ActualReversalMemory
              |
              v
        three-bit summary
      A used? / B used?
       / A reversed?
              |
      +-------+-------+
      |               |
 current answer   local update
      |               |
      +-------+-------+
              |
              v
   MaintainedCertificate
              |
              v
      FutureSufficient

The summary is non-injective: unrelated reversal-history details are genuinely
discarded.

The result is intentionally conditional on the declared future vocabulary. If
arbitrary future reversal identities, exact physical-inverse questions, or the
full production publisher are admitted, more retained information may be
required.

That vocabulary dependence is the point of the positive example: safe
compression means retaining enough information for the futures one commits to
answering, not reconstructing every discarded historical detail.
-/

end Loam.Observation304
