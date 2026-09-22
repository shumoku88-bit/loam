import Loam.Observations.Observation193
import Loam.Observations.Observation299

namespace Loam.Observation300

open Loam.Core

set_option autoImplicit false

/-!
# Observation 300 — bounded search against real Correction semantics

Observation 299 proved that its bounded searcher is sound for any supplied finite
state/operation/question space. Observation 193 supplied a hand-constructed
counterexample using LOAM's existing Correction semantics.

This observation connects the two.

The finite fixture is rebuilt here instead of importing Observation 193's private
witness terms. The semantic machinery itself is reused directly:

- `CorrectionState`;
- `EventCorrectionMemory.add?` through `correctionStep`;
- fail-closed `CorrectionFrontier` projection through `correctionAnswer`;
- the current-quantity compression `encodeCurrentQuantity`.

The question is whether the generic bounded searcher can discover a
Correction-driven witness automatically from the supplied finite candidates.
-/

private def wallet : LocusId := ⟨"wallet"⟩
private def jpy : MeasureId := ⟨"jpy"⟩

private def oneEffectEvent
    (idToken effectToken : String)
    (quanta : Int) : Event :=
  { id := ⟨idToken⟩
    effects :=
      [Effect.ofQuantity
        ⟨effectToken⟩ wallet jpy (Quantity.ofQuanta quanta)]
    keyNodup := by simp }

private def replacementQuanta : Int := -80

private def emptyCorrections : EventCorrectionMemory :=
  { corrections := [], idNodup := by simp }

/--
One target quantity is enough to generate a complete candidate world.

The buffer is derived so that the current recorded total remains zero before
the Correction is published. The future effective quantity therefore exposes
the hidden target difference instead of encoding the finished state by hand.
-/
private def correctionStateFromTarget
    (targetQuanta : Int) : Loam.Observation193.CorrectionState :=
  let bufferQuanta := -(targetQuanta + replacementQuanta)
  { events :=
      { events :=
          [ oneEffectEvent "target" "target-effect" targetQuanta
          , oneEffectEvent "replacement" "replacement-effect" replacementQuanta
          , oneEffectEvent "buffer" "buffer-effect" bufferQuanta
          ]
        idNodup := by
          simp [oneEffectEvent] }
    corrections := emptyCorrections }

private def correctionSeeds : List Int :=
  [-100, -120]

private def publishTarget : Loam.Observation193.CorrectionOperation :=
  .publish
    { target := ⟨"target"⟩
      replacement := ⟨"replacement"⟩ }

private def correctionOperations :
    List Loam.Observation193.CorrectionOperation :=
  [publishTarget]

private def correctionQuestions :
    List Loam.Observation193.CorrectionQuestion :=
  [.walletQuantity]

def decideCorrectionVocabulary :
    ∀ question : Loam.Observation193.CorrectionQuestion,
      Decidable (Loam.Observation193.CorrectionVocabulary question) :=
  fun _ => isTrue trivial

private def correctionSearchSpace (depth : Nat) :
    Loam.Observation299.SearchSpace
      Loam.Observation193.CorrectionState
      Loam.Observation193.CorrectionOperation
      Loam.Observation193.CorrectionQuestion :=
  Loam.Observation299.SearchSpace.fromSeeds
    correctionSeeds
    correctionStateFromTarget
    correctionOperations
    correctionQuestions
    depth

theorem correction_seed_count :
    (correctionSearchSpace 1).states.length = correctionSeeds.length := by
  simp [correctionSearchSpace]

/-- The generated worlds are intentionally indistinguishable by today's summary. -/
theorem correction_generated_current_summaries :
    correctionSeeds.map
        (fun seed =>
          Loam.Observation193.encodeCurrentQuantity
            (correctionStateFromTarget seed)) =
      [some 0, some 0] := by
  native_decide

def correctionSearch (depth : Nat) :=
  (correctionSearchSpace depth).search
    Loam.Observation193.correctionAnswer
    Loam.Observation193.correctionStep
    Loam.Observation193.CorrectionVocabulary
    decideCorrectionVocabulary
    Loam.Observation193.encodeCurrentQuantity

/-- The depth-one fixture enumerates exactly eight candidate payloads. -/
theorem correction_depth_one_candidate_count :
    (correctionSearchSpace 1).candidateCount = 8 := by
  native_decide


/-- Distinct unordered summary collisions reduce the same fixture to two payloads. -/
theorem correction_depth_one_distinct_collision_candidate_count :
    (correctionSearchSpace 1).distinctSummaryCollisionCandidateCount
      Loam.Observation193.encodeCurrentQuantity = 2 := by
  native_decide

def correctionDistinctCollisionSearch :=
  (correctionSearchSpace 1).searchDistinctSummaryCollisions
    Loam.Observation193.correctionAnswer
    Loam.Observation193.correctionStep
    Loam.Observation193.CorrectionVocabulary
    decideCorrectionVocabulary
    Loam.Observation193.encodeCurrentQuantity

theorem correction_distinct_collision_search_finds_counterexample :
    correctionDistinctCollisionSearch.isSome = true := by
  native_decide

/--
With no future operation available, the two candidate states are collapsed by
the current-quantity summary and remain indistinguishable.
-/
theorem correction_depth_zero_finds_no_counterexample :
    (correctionSearch 0).isNone = true := by
  native_decide

/--
At depth one the bounded searcher automatically discovers a distinguishing
Correction continuation.
-/
theorem correction_depth_one_finds_counterexample :
    (correctionSearch 1).isSome = true := by
  native_decide

/--
The discovered bounded witness is not merely an executable test result. By the
Observation-299 soundness bridge it refutes future sufficiency of retaining only
the current CorrectionFrontier quantity.
-/
theorem correction_search_refutes_current_quantity_summary :
    ¬ Loam.Observation192.FutureSufficient
      Loam.Observation193.correctionAnswer
      Loam.Observation193.correctionStep
      Loam.Observation193.CorrectionVocabulary
      Loam.Observation193.encodeCurrentQuantity := by
  have hSome : (correctionSearch 1).isSome = true :=
    correction_depth_one_finds_counterexample
  cases hSearch : correctionSearch 1 with
  | none =>
      simp [hSearch] at hSome
  | some payload =>
      exact
        (correctionSearchSpace 1).search_some_refutes_futureSufficient
          Loam.Observation193.correctionAnswer
          Loam.Observation193.correctionStep
          Loam.Observation193.CorrectionVocabulary
          decideCorrectionVocabulary
          Loam.Observation193.encodeCurrentQuantity
          payload
          (by simpa [correctionSearch] using hSearch)

/-!
## Finding

The bounded searcher now reaches a real LOAM semantic boundary rather than only
the synthetic reveal model.

Within the supplied finite model:

    two retained Event worlds
      + same current CorrectionFrontier quantity
      + one allowed EventCorrection publication
      + one selected quantity question
          |
          v
    bounded search
          |
          v
    automatically found distinguishing payload
          |
          v
    Observation-298 checker
          |
          v
    not FutureSufficient

This does not enlarge the completeness claim. The result is only complete for
the caller-supplied two states, one operation, one question, and depth one.
Its significance is narrower: the search/check split survives contact with
LOAM's existing Correction semantics and rediscovers the same kind of witness
that Observation 193 previously built by hand.
-/

end Loam.Observation300
