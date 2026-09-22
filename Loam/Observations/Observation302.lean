import Loam.Examples.ActualReversalFutureContext
import Loam.Observations.Observation299

namespace Loam.Observation302

open Loam.Core

set_option autoImplicit false

/-!
# Observation 302 — bounded search against Actual reversal provenance

Correction and document derivation already exercise the generic bounded
search/check boundary with different relation meanings.

This observation adds a third relation shape using LOAM's retained
`ActualReversalMemory` semantics:

- reversal evidence does not supersede either endpoint;
- endpoint identities are globally unique across target and reversal roles;
- a future publication may therefore be accepted in one retained world and
  rejected in another because an endpoint identity has already been consumed.

The complete practical reversal publisher has stronger obligations. This probe
deliberately stays at the retained Core relation-memory boundary.
-/

private def eventA : EventId := ⟨"reversal:a"⟩
private def eventB : EventId := ⟨"reversal:b"⟩
private def eventC : EventId := ⟨"reversal:c"⟩
private def eventD : EventId := ⟨"reversal:d"⟩

inductive ReversalSeed where
  | bConsumed
  | dConsumed
  deriving Repr, DecidableEq

private def reversalStateFromSeed :
    ReversalSeed → Loam.Examples.ActualReversalFutureContext.State
  | .bConsumed =>
      { reversals :=
          { reversals :=
              [ { target := eventC
                  reversal := eventB } ]
            endpointNodup := by native_decide } }
  | .dConsumed =>
      { reversals :=
          { reversals :=
              [ { target := eventC
                  reversal := eventD } ]
            endpointNodup := by native_decide } }

private def reversalSeeds : List ReversalSeed :=
  [.bConsumed, .dConsumed]

private def publishFuture :
    Loam.Examples.ActualReversalFutureContext.Operation :=
  .publish
    { target := eventA
      reversal := eventB }

private def reversalOperations :
    List Loam.Examples.ActualReversalFutureContext.Operation :=
  [publishFuture]

private def reversalQuestions :
    List Loam.Examples.ActualReversalFutureContext.Question :=
  [.aIsReversed]

def decideReversalVocabulary :
    ∀ question : Loam.Examples.ActualReversalFutureContext.Question,
      Decidable
        (Loam.Examples.ActualReversalFutureContext.Vocabulary question) :=
  fun _ => isTrue trivial

private def reversalSearchSpace (depth : Nat) :
    Loam.Observation299.SearchSpace
      Loam.Examples.ActualReversalFutureContext.State
      Loam.Examples.ActualReversalFutureContext.Operation
      Loam.Examples.ActualReversalFutureContext.Question :=
  Loam.Observation299.SearchSpace.fromSeeds
    reversalSeeds
    reversalStateFromSeed
    reversalOperations
    reversalQuestions
    depth

theorem reversal_seed_count :
    (reversalSearchSpace 1).states.length = reversalSeeds.length := by
  simp [reversalSearchSpace]

/-- Both generated worlds currently collapse to the same selected provenance answer. -/
theorem reversal_generated_current_summaries :
    reversalSeeds.map
        (fun seed =>
          Loam.Examples.ActualReversalFutureContext.encodeCurrentAnswer
            (reversalStateFromSeed seed)) =
      [false, false] := by
  native_decide

def reversalSearch (depth : Nat) :=
  (reversalSearchSpace depth).search
    Loam.Examples.ActualReversalFutureContext.answer
    Loam.Examples.ActualReversalFutureContext.step
    Loam.Examples.ActualReversalFutureContext.Vocabulary
    decideReversalVocabulary
    Loam.Examples.ActualReversalFutureContext.encodeCurrentAnswer

theorem reversal_depth_one_candidate_count :
    (reversalSearchSpace 1).candidateCount = 8 := by
  native_decide


theorem reversal_depth_one_distinct_collision_candidate_count :
    (reversalSearchSpace 1).distinctSummaryCollisionCandidateCount
      Loam.Examples.ActualReversalFutureContext.encodeCurrentAnswer = 2 := by
  native_decide

def reversalDistinctCollisionSearch :=
  (reversalSearchSpace 1).searchDistinctSummaryCollisions
    Loam.Examples.ActualReversalFutureContext.answer
    Loam.Examples.ActualReversalFutureContext.step
    Loam.Examples.ActualReversalFutureContext.Vocabulary
    decideReversalVocabulary
    Loam.Examples.ActualReversalFutureContext.encodeCurrentAnswer

theorem reversal_distinct_collision_search_finds_counterexample :
    reversalDistinctCollisionSearch.isSome = true := by
  native_decide

theorem reversal_depth_zero_finds_no_counterexample :
    (reversalSearch 0).isNone = true := by
  native_decide

theorem reversal_depth_one_finds_counterexample :
    (reversalSearch 1).isSome = true := by
  native_decide

theorem reversal_distinct_collision_search_refutes_current_answer_summary :
    ¬ Loam.Observation192.FutureSufficient
      Loam.Examples.ActualReversalFutureContext.answer
      Loam.Examples.ActualReversalFutureContext.step
      Loam.Examples.ActualReversalFutureContext.Vocabulary
      Loam.Examples.ActualReversalFutureContext.encodeCurrentAnswer := by
  have hSome : reversalDistinctCollisionSearch.isSome = true :=
    reversal_distinct_collision_search_finds_counterexample
  cases hSearch : reversalDistinctCollisionSearch with
  | none =>
      simp [hSearch] at hSome
  | some payload =>
      exact
        (reversalSearchSpace 1).searchDistinctSummaryCollisions_some_refutes_futureSufficient
          Loam.Examples.ActualReversalFutureContext.answer
          Loam.Examples.ActualReversalFutureContext.step
          Loam.Examples.ActualReversalFutureContext.Vocabulary
          decideReversalVocabulary
          Loam.Examples.ActualReversalFutureContext.encodeCurrentAnswer
          payload
          (by simpa [reversalDistinctCollisionSearch] using hSearch)

theorem reversal_search_refutes_current_answer_summary :
    ¬ Loam.Observation192.FutureSufficient
      Loam.Examples.ActualReversalFutureContext.answer
      Loam.Examples.ActualReversalFutureContext.step
      Loam.Examples.ActualReversalFutureContext.Vocabulary
      Loam.Examples.ActualReversalFutureContext.encodeCurrentAnswer := by
  have hSome : (reversalSearch 1).isSome = true :=
    reversal_depth_one_finds_counterexample
  cases hSearch : reversalSearch 1 with
  | none =>
      simp [hSearch] at hSome
  | some payload =>
      exact
        (reversalSearchSpace 1).search_some_refutes_futureSufficient
          Loam.Examples.ActualReversalFutureContext.answer
          Loam.Examples.ActualReversalFutureContext.step
          Loam.Examples.ActualReversalFutureContext.Vocabulary
          decideReversalVocabulary
          Loam.Examples.ActualReversalFutureContext.encodeCurrentAnswer
          payload
          (by simpa [reversalSearch] using hSearch)

/-!
## Finding

The bounded search/check architecture now reaches three relation meanings:

1. EventCorrection: supersession and effective-frontier selection.
2. DocumentDerivation: unrestricted retained provenance without supersession.
3. ActualReversalMemory: retained inverse provenance with globally unique
   endpoint participation.

For the reversal fixture, the current selected answer is identical in both
worlds. One common future publication is rejected in the world where B is
already consumed and accepted where B remains fresh. The generic checker turns
the automatically found payload into a proof that the current-answer summary is
not future-sufficient.

This does not imply that the bounded searcher covers complete practical reversal
admission. Referential closure, exact physical inversion, writer ownership, and
other production obligations remain outside this deliberately narrow probe.
-/

end Loam.Observation302
