import Loam.Application.CorrectionFrontier
import Loam.Core.EventCorrectionMemory
import Loam.Observations.Observation192

namespace Loam.Observation193

open Loam.Core

set_option autoImplicit false

/-!
# Observation 193 — Correction as a real future context

Observation 192 proved a generic Nerode-style result using a synthetic `reveal`
operation. This observation asks whether the same future-context distinction
appears when the operation and observation are taken directly from existing
LOAM semantics.

The selected operation is deliberately narrow: append one raw `EventCorrection`
fact through `EventCorrectionMemory.add?`. The selected observation is the
existing fail-closed `CorrectionFrontier` quantity projection.

This does not model the physical multi-stream Correction writer, publication
order, retry protocol, or crash residue. It isolates the semantic question:

> Can two retained Event worlds that answer the same current quantity question
> become distinguishable after the same explicit Correction relation is added?
-/

structure CorrectionState where
  events : EventMemory
  corrections : EventCorrectionMemory

inductive CorrectionOperation where
  | publish : EventCorrection → CorrectionOperation
  deriving Repr, DecidableEq

inductive CorrectionQuestion where
  | walletQuantity
  deriving Repr, DecidableEq

/--
Append one raw Correction fact. Repeated correction identity leaves the state
unchanged in this total transition wrapper. Semantic frontier admission remains
separate and fail-closed in `CorrectionFrontier`.
-/
def correctionStep
    (state : CorrectionState) : CorrectionOperation → CorrectionState
  | .publish correction =>
      match EventCorrectionMemory.add? state.corrections correction with
      | some updated => { state with corrections := updated }
      | none => state

/-- Publishing a raw Correction fact does not mutate retained Event evidence. -/
theorem correctionStep_preserves_events
    (state : CorrectionState)
    (correction : EventCorrection) :
    (correctionStep state (.publish correction)).events = state.events := by
  unfold correctionStep
  cases hAdd : EventCorrectionMemory.add? state.corrections correction <;> simp [hAdd]

private def wallet : LocusId := ⟨"wallet"⟩
private def jpy : MeasureId := ⟨"jpy"⟩

/-- The selected question uses LOAM's real fail-closed correction frontier. -/
def correctionAnswer
    (state : CorrectionState) : CorrectionQuestion → Option Int
  | .walletQuantity =>
      (Loam.Application.quantityAtCorrectionFrontier?
        state.events state.corrections wallet jpy).map Quantity.quanta

def CorrectionVocabulary :
    Loam.Observation029.Vocabulary CorrectionQuestion :=
  fun _ => True

private def oneEffectEvent
    (idToken effectToken : String)
    (quanta : Int) : Event :=
  { id := ⟨idToken⟩
    effects :=
      [Effect.ofQuantity
        ⟨effectToken⟩ wallet jpy (Quantity.ofQuanta quanta)]
    keyNodup := by simp }

private def targetId : EventId := ⟨"target"⟩
private def replacementId : EventId := ⟨"replacement"⟩

private def leftEvents : EventMemory :=
  { events :=
      [ oneEffectEvent "target" "target-effect" (-100)
      , oneEffectEvent "replacement" "replacement-effect" (-80)
      , oneEffectEvent "buffer" "buffer-effect" 180
      ]
    idNodup := by native_decide }

private def rightEvents : EventMemory :=
  { events :=
      [ oneEffectEvent "target" "target-effect" (-120)
      , oneEffectEvent "replacement" "replacement-effect" (-80)
      , oneEffectEvent "buffer" "buffer-effect" 200
      ]
    idNodup := by native_decide }

private def emptyCorrections : EventCorrectionMemory :=
  { corrections := [], idNodup := by simp }

private def leftState : CorrectionState :=
  { events := leftEvents, corrections := emptyCorrections }

private def rightState : CorrectionState :=
  { events := rightEvents, corrections := emptyCorrections }

private def targetCorrection : EventCorrection :=
  { id := ⟨"correction-1"⟩
    target := targetId
    replacement := replacementId }

private def publishTarget : CorrectionOperation :=
  .publish targetCorrection

/-- Both retained Event worlds currently aggregate to the same raw quantity. -/
theorem raw_recorded_quantities_agree_now :
    EventMemory.quantityAtRecorded leftEvents wallet jpy =
      EventMemory.quantityAtRecorded rightEvents wallet jpy := by
  native_decide

/-- With no Correction facts, the real correction-frontier question agrees too. -/
theorem left_current_answer :
    correctionAnswer leftState .walletQuantity = some 0 := by
  native_decide

theorem right_current_answer :
    correctionAnswer rightState .walletQuantity = some 0 := by
  native_decide

/-- Observation 029 therefore identifies the two worlds at the current boundary. -/
theorem states_are_currently_equivalent :
    Loam.Observation029.Equivalent
      correctionAnswer CorrectionVocabulary leftState rightState := by
  intro question _
  cases question
  rw [left_current_answer, right_current_answer]

/--
After the same explicit Correction relation is appended, the target Event is
removed from the admitted effective frontier in each world. Because the hidden
target contribution differed, the effective answers now differ.
-/
theorem left_after_correction_answer :
    correctionAnswer
      (correctionStep leftState publishTarget)
      .walletQuantity = some 100 := by
  native_decide

theorem right_after_correction_answer :
    correctionAnswer
      (correctionStep rightState publishTarget)
      .walletQuantity = some 120 := by
  native_decide

/--
The two currently equivalent worlds are not future-context equivalent under the
real Correction operation and CorrectionFrontier observation.
-/
theorem states_are_not_futureEquivalent :
    ¬ Loam.Observation192.FutureEquivalent
      correctionAnswer correctionStep CorrectionVocabulary
      leftState rightState := by
  intro hFuture
  have hAfter :=
    hFuture [publishTarget] .walletQuantity (by simp [CorrectionVocabulary])
  change
    correctionAnswer (correctionStep leftState publishTarget) .walletQuantity =
      correctionAnswer (correctionStep rightState publishTarget) .walletQuantity
    at hAfter
  rw [left_after_correction_answer, right_after_correction_answer] at hAfter
  simp at hAfter

/--
The distinction is relation-driven rather than a new physical quantity Event:
the Correction operation leaves both Event memories unchanged.
-/
theorem raw_event_evidence_is_unchanged_by_the_distinguishing_step :
    (correctionStep leftState publishTarget).events = leftState.events ∧
    (correctionStep rightState publishTarget).events = rightState.events := by
  exact ⟨correctionStep_preserves_events _ _, correctionStep_preserves_events _ _⟩

/-! ## Current sufficiency is again weaker than future-context sufficiency -/

/-- Retain only today's correction-effective wallet quantity. -/
def encodeCurrentQuantity (state : CorrectionState) : Option Int :=
  correctionAnswer state .walletQuantity

private def decodeCurrentQuantity
    (summary : Option Int) : CorrectionQuestion → Option Int
  | .walletQuantity => summary

/-- For the one-question current vocabulary, the current answer is sufficient. -/
theorem current_quantity_summary_is_currently_sufficient :
    Loam.Observation029.SufficientFor
      correctionAnswer CorrectionVocabulary encodeCurrentQuantity := by
  refine ⟨decodeCurrentQuantity, ?_⟩
  intro state question _
  cases question
  rfl

/-- But equal current quantities do not suffice once Correction is an allowed future context. -/
theorem current_quantity_summary_is_not_future_sufficient :
    ¬ Loam.Observation192.FutureSufficient
      correctionAnswer correctionStep CorrectionVocabulary encodeCurrentQuantity := by
  intro hSufficient
  have hEncode : encodeCurrentQuantity leftState = encodeCurrentQuantity rightState := by
    unfold encodeCurrentQuantity
    rw [left_current_answer, right_current_answer]
  have hEquivalent :
      Loam.Observation192.FutureEquivalent
        correctionAnswer correctionStep CorrectionVocabulary
        leftState rightState :=
    Loam.Observation192.equalFutureSummaryInvisible
      correctionAnswer correctionStep CorrectionVocabulary hSufficient hEncode
  exact states_are_not_futureEquivalent hEquivalent

/-!
## Finding

The synthetic `reveal` witness from Observation 192 was not an artifact of the
toy model. Existing LOAM Correction semantics produce the same strict dynamic
refinement:

```text
same current CorrectionFrontier quantity
    does not imply
same answer after every allowed Correction continuation
```

The witness uses existing LOAM types and operations:

- retained `EventMemory`;
- raw `EventCorrectionMemory.add?`;
- explicit `EventCorrection` identity and endpoints;
- fail-closed `CorrectionFrontier` admission;
- existing correction-effective quantity projection.

The important mechanism is not additive mutation. The distinguishing operation
leaves `EventMemory` unchanged. It changes which retained Event evidence is
selected into the effective frontier by adding explicit relation authority.

Observation 192 therefore reaches one genuine LOAM semantic boundary:

```text
retained evidence
  + allowed future relation facts
  + effective-frontier questions
      -> future-context observational quotient
```

This remains narrower than a whole-LOAM behavioural semantics. The observation
does not include branching Resolution, ActualValidity correction, routing,
time, publication order, writer failure, or authority migration. It also does
not claim a new mathematical theorem or that every LOAM operation belongs in
one transition algebra.
-/

end Loam.Observation193
