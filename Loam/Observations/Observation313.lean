import Loam.Examples.DocumentProvenanceFutureContext
import Loam.Observations.Observation308
import Loam.Observations.Observation312

namespace Loam.Observation313

open Loam.Core
open Loam.Examples.DocumentProvenanceBoundary

set_option autoImplicit false

/-!
# Observation 313 — selected-operation provenance quotient

Observation 312 made the future operation language explicit. This observation
uses that new boundary on the independent document-provenance semantics.

The underlying operation type remains broad:

    publish : DocumentDerivation -> Operation

but the declared future language selects one edge only:

    B -> D

The selected terminal question remains whether A reaches D through exactly two
retained derivation edges.

The target result is stronger than the earlier bounded counterexample:

- depth zero is too shallow;
- depth one records current and after-one-publication answers;
- repeated selected publication adds no new selected answer after the first;
- therefore the depth-one generated signature is an
  ExactFutureClassifierUnder for this selected future language.
-/

private def document (token : String) : Event :=
  { id := ⟨token⟩
    effects := []
    keyNodup := by simp [retainedEffectKeys] }

private def docA : Event := document "document:a"
private def docB : Event := document "document:b"
private def docC : Event := document "document:c"
private def docD : Event := document "document:d"

private def documents : EventMemory :=
  { events := [docA, docB, docC, docD]
    idNodup := by native_decide }

private def edgeAB : DocumentDerivation :=
  { source := docA.id, derived := docB.id }

private def edgeCB : DocumentDerivation :=
  { source := docC.id, derived := docB.id }

private def edgeBD : DocumentDerivation :=
  { source := docB.id, derived := docD.id }

private def availableState : Loam.Examples.DocumentProvenanceFutureContext.State :=
  { documents := documents
    derivations := { edges := [edgeAB] } }

private def blockedState : Loam.Examples.DocumentProvenanceFutureContext.State :=
  { documents := documents
    derivations := { edges := [edgeCB] } }

private def alreadyDerivedState : Loam.Examples.DocumentProvenanceFutureContext.State :=
  { documents := documents
    derivations := { edges := [edgeAB, edgeBD] } }

def publishFuture : Loam.Examples.DocumentProvenanceFutureContext.Operation :=
  .publish edgeBD

/-- The declared future language contains exactly publication of B -> D. -/
def SelectedOperations :
    Loam.Observation312.OperationVocabulary Loam.Examples.DocumentProvenanceFutureContext.Operation :=
  fun operation => operation = publishFuture

def decideSelectedOperations :
    ∀ operation : Loam.Examples.DocumentProvenanceFutureContext.Operation,
      Decidable (SelectedOperations operation) :=
  fun operation => by
    unfold SelectedOperations
    infer_instance

theorem future_edge_projects :
    (DocumentDerivation.project? documents edgeBD).isSome = true := by
  native_decide

/-- Duplicating one already-appended edge does not change direct-edge existence. -/
theorem hasEdge_append_duplicate
    (memory : Loam.Examples.DocumentProvenanceFutureContext.DerivationMemory)
    (edge : DocumentDerivation)
    (source derived : EventId) :
    Loam.Examples.DocumentProvenanceFutureContext.hasEdge
        { edges := memory.edges ++ [edge, edge] }
        source derived =
      Loam.Examples.DocumentProvenanceFutureContext.hasEdge
        { edges := memory.edges ++ [edge] }
        source derived := by
  simp [Loam.Examples.DocumentProvenanceFutureContext.hasEdge,
    Bool.or_assoc]

/--
The same duplicate-invariance lifts to the selected two-step reachability
observation.
-/
theorem derivedInTwoSteps_append_duplicate
    (memory : Loam.Examples.DocumentProvenanceFutureContext.DerivationMemory)
    (edge : DocumentDerivation)
    (source target : EventId) :
    Loam.Examples.DocumentProvenanceFutureContext.derivedInTwoSteps
        { edges := memory.edges ++ [edge, edge] }
        source target =
      Loam.Examples.DocumentProvenanceFutureContext.derivedInTwoSteps
        { edges := memory.edges ++ [edge] }
        source target := by
  simp [Loam.Examples.DocumentProvenanceFutureContext.derivedInTwoSteps,
    Loam.Examples.DocumentProvenanceFutureContext.hasEdge,
    Bool.or_assoc, Bool.or_left_comm, Bool.or_comm]

/--
Publishing the same selected provenance edge twice does not change the selected
two-step answer beyond the first publication.

The retained raw edge list may grow by one duplicate. The selected provenance
answer does not.
-/
theorem selected_answer_after_publish_is_idempotent
    (state : Loam.Examples.DocumentProvenanceFutureContext.State) :
    Loam.Examples.DocumentProvenanceFutureContext.answer
        (Loam.Examples.DocumentProvenanceFutureContext.step
          (Loam.Examples.DocumentProvenanceFutureContext.step state publishFuture)
          publishFuture)
        .aDerivedToDInTwoSteps =
      Loam.Examples.DocumentProvenanceFutureContext.answer
        (Loam.Examples.DocumentProvenanceFutureContext.step state publishFuture)
        .aDerivedToDInTwoSteps := by
  by_cases hProject :
      (DocumentDerivation.project? state.documents edgeBD).isSome = true
  · have hStep :
        Loam.Examples.DocumentProvenanceFutureContext.step state publishFuture =
          { state with
            derivations :=
              { edges := state.derivations.edges ++ [edgeBD] } } := by
      simp [publishFuture,
        Loam.Examples.DocumentProvenanceFutureContext.step, hProject]
    have hStepAgain :
        Loam.Examples.DocumentProvenanceFutureContext.step
            { state with
              derivations :=
                { edges := state.derivations.edges ++ [edgeBD] } }
            publishFuture =
          { state with
            derivations :=
              { edges := state.derivations.edges ++ [edgeBD, edgeBD] } } := by
      simp [publishFuture,
        Loam.Examples.DocumentProvenanceFutureContext.step, hProject]
    rw [hStep, hStepAgain]
    unfold Loam.Examples.DocumentProvenanceFutureContext.answer
    simpa using
      (derivedInTwoSteps_append_duplicate
        state.derivations edgeBD _ _)
  · have hStep :
        Loam.Examples.DocumentProvenanceFutureContext.step state publishFuture =
          state := by
      simp [publishFuture,
        Loam.Examples.DocumentProvenanceFutureContext.step, hProject]
    rw [hStep, hStep]


/-! ## Bounded signatures over three canonical provenance worlds -/

def provenanceSynthesisSpace (depth : Nat) :
    Loam.Observation299.SearchSpace
      Loam.Examples.DocumentProvenanceFutureContext.State
      Loam.Examples.DocumentProvenanceFutureContext.Operation
      Loam.Examples.DocumentProvenanceFutureContext.Question :=
  { states := [availableState, blockedState, alreadyDerivedState]
    operations := [publishFuture]
    questions := [.aDerivedToDInTwoSteps]
    depth := depth }

def decideQuestionVocabulary :
    ∀ question : Loam.Examples.DocumentProvenanceFutureContext.Question,
      Decidable (Loam.Examples.DocumentProvenanceFutureContext.Vocabulary question) :=
  fun _ => isTrue trivial

def provenanceSignatureAtDepth
    (depth : Nat)
    (state : Loam.Examples.DocumentProvenanceFutureContext.State) : List Bool :=
  Loam.Observation308.boundedBehaviourSignature
    (provenanceSynthesisSpace depth)
    Loam.Examples.DocumentProvenanceFutureContext.answer
    Loam.Examples.DocumentProvenanceFutureContext.step
    Loam.Examples.DocumentProvenanceFutureContext.Vocabulary
    decideQuestionVocabulary
    state

theorem available_depth_one_signature :
    provenanceSignatureAtDepth 1 availableState = [false, true] := by
  native_decide

theorem blocked_depth_one_signature :
    provenanceSignatureAtDepth 1 blockedState = [false, false] := by
  native_decide

theorem already_derived_depth_one_signature :
    provenanceSignatureAtDepth 1 alreadyDerivedState = [true, true] := by
  native_decide

theorem depth_zero_merges_available_and_blocked :
    provenanceSignatureAtDepth 0 availableState =
      provenanceSignatureAtDepth 0 blockedState := by
  native_decide

theorem available_and_blocked_differ_after_selected_future :
    Loam.Examples.DocumentProvenanceFutureContext.answer
        (Loam.Examples.DocumentProvenanceFutureContext.step availableState publishFuture)
        .aDerivedToDInTwoSteps =
      true ∧
    Loam.Examples.DocumentProvenanceFutureContext.answer
        (Loam.Examples.DocumentProvenanceFutureContext.step blockedState publishFuture)
        .aDerivedToDInTwoSteps =
      false := by
  native_decide

/-! ## The generated depth-one signature is exact for the selected future language -/

theorem provenance_depth_one_contexts :
    Loam.Observation308.boundedContexts
        (provenanceSynthesisSpace 1)
        Loam.Examples.DocumentProvenanceFutureContext.Vocabulary
        decideQuestionVocabulary =
      [ ([], .aDerivedToDInTwoSteps)
      , ([publishFuture], .aDerivedToDInTwoSteps)
      ] := by
  native_decide

theorem provenance_depth_one_signature_formula
    (state : Loam.Examples.DocumentProvenanceFutureContext.State) :
    provenanceSignatureAtDepth 1 state =
      [ Loam.Examples.DocumentProvenanceFutureContext.answer
          state .aDerivedToDInTwoSteps
      , Loam.Examples.DocumentProvenanceFutureContext.answer
          (Loam.Examples.DocumentProvenanceFutureContext.step
            state publishFuture)
          .aDerivedToDInTwoSteps
      ] := by
  simp [provenanceSignatureAtDepth,
    Loam.Observation308.boundedBehaviourSignature,
    provenance_depth_one_contexts,
    Loam.Observation192.run]

/--
Once the selected publication has happened, any further continuation made only
of that selected operation leaves the selected answer unchanged.
-/
theorem selected_answer_stable_after_publish
    (state : Loam.Examples.DocumentProvenanceFutureContext.State)
    (continuation :
      List Loam.Examples.DocumentProvenanceFutureContext.Operation)
    (hAllowed :
      Loam.Observation312.ContinuationAllowed
        SelectedOperations continuation) :
    Loam.Examples.DocumentProvenanceFutureContext.answer
        (Loam.Observation192.run
          Loam.Examples.DocumentProvenanceFutureContext.step
          (Loam.Examples.DocumentProvenanceFutureContext.step
            state publishFuture)
          continuation)
        .aDerivedToDInTwoSteps =
      Loam.Examples.DocumentProvenanceFutureContext.answer
        (Loam.Examples.DocumentProvenanceFutureContext.step
          state publishFuture)
        .aDerivedToDInTwoSteps := by
  induction continuation generalizing state with
  | nil =>
      rfl
  | cons operation rest ih =>
      have hOperation : SelectedOperations operation :=
        hAllowed operation (by simp)
      have hOperationEq : operation = publishFuture :=
        hOperation
      subst operation
      have hRest :
          Loam.Observation312.ContinuationAllowed
            SelectedOperations rest := by
        intro candidate hMem
        exact hAllowed candidate (by simp [hMem])
      simp only [Loam.Observation192.run]
      calc
        Loam.Examples.DocumentProvenanceFutureContext.answer
            (Loam.Observation192.run
              Loam.Examples.DocumentProvenanceFutureContext.step
              (Loam.Examples.DocumentProvenanceFutureContext.step
                (Loam.Examples.DocumentProvenanceFutureContext.step
                  state publishFuture)
                publishFuture)
              rest)
            .aDerivedToDInTwoSteps =
          Loam.Examples.DocumentProvenanceFutureContext.answer
            (Loam.Examples.DocumentProvenanceFutureContext.step
              (Loam.Examples.DocumentProvenanceFutureContext.step
                state publishFuture)
              publishFuture)
            .aDerivedToDInTwoSteps :=
          ih
            (state :=
              Loam.Examples.DocumentProvenanceFutureContext.step
                state publishFuture)
            hRest
        _ =
          Loam.Examples.DocumentProvenanceFutureContext.answer
            (Loam.Examples.DocumentProvenanceFutureContext.step
              state publishFuture)
            .aDerivedToDInTwoSteps :=
          selected_answer_after_publish_is_idempotent state

/--
Every selected continuation has only two observable cases: empty, or at least
one B -> D publication.
-/
theorem selected_continuation_answer
    (state : Loam.Examples.DocumentProvenanceFutureContext.State)
    (continuation :
      List Loam.Examples.DocumentProvenanceFutureContext.Operation)
    (hAllowed :
      Loam.Observation312.ContinuationAllowed
        SelectedOperations continuation) :
    Loam.Examples.DocumentProvenanceFutureContext.answer
        (Loam.Observation192.run
          Loam.Examples.DocumentProvenanceFutureContext.step
          state continuation)
        .aDerivedToDInTwoSteps =
      if continuation = [] then
        Loam.Examples.DocumentProvenanceFutureContext.answer
          state .aDerivedToDInTwoSteps
      else
        Loam.Examples.DocumentProvenanceFutureContext.answer
          (Loam.Examples.DocumentProvenanceFutureContext.step
            state publishFuture)
          .aDerivedToDInTwoSteps := by
  cases continuation with
  | nil =>
      rfl
  | cons operation rest =>
      have hOperation : SelectedOperations operation :=
        hAllowed operation (by simp)
      have hOperationEq : operation = publishFuture :=
        hOperation
      subst operation
      have hRest :
          Loam.Observation312.ContinuationAllowed
            SelectedOperations rest := by
        intro candidate hMem
        exact hAllowed candidate (by simp [hMem])
      simp only [Loam.Observation192.run]
      rw [selected_answer_stable_after_publish state rest hRest]
      simp

/--
Depth-one generated signature equality is exactly selected-operation
future-context equivalence for every retained provenance state.
-/
theorem same_depth_one_signature_iff_futureEquivalentUnder
    (left right : Loam.Examples.DocumentProvenanceFutureContext.State) :
    provenanceSignatureAtDepth 1 left =
        provenanceSignatureAtDepth 1 right ↔
      Loam.Observation312.FutureEquivalentUnder
        Loam.Examples.DocumentProvenanceFutureContext.answer
        Loam.Examples.DocumentProvenanceFutureContext.step
        SelectedOperations
        Loam.Examples.DocumentProvenanceFutureContext.Vocabulary
        left right := by
  constructor
  · intro hSignature
    rw [provenance_depth_one_signature_formula left,
      provenance_depth_one_signature_formula right] at hSignature
    simp at hSignature
    rcases hSignature with ⟨hNow, hNext⟩
    intro continuation question hAllowed hVisible
    cases question
    rw [selected_continuation_answer left continuation hAllowed,
      selected_continuation_answer right continuation hAllowed]
    by_cases hEmpty : continuation = []
    · simp [hEmpty, hNow]
    · simp [hEmpty, hNext]
  · intro hFuture
    rw [provenance_depth_one_signature_formula,
      provenance_depth_one_signature_formula]
    have hNow :=
      hFuture [] .aDerivedToDInTwoSteps
        (by
          exact
            Loam.Observation312.empty_continuation_allowed
              SelectedOperations)
        (by simp [Loam.Examples.DocumentProvenanceFutureContext.Vocabulary])
    have hNext :=
      hFuture [publishFuture] .aDerivedToDInTwoSteps
        (by
          intro operation hMem
          simp at hMem
          subst operation
          rfl)
        (by simp [Loam.Examples.DocumentProvenanceFutureContext.Vocabulary])
    simpa [Loam.Observation192.run] using And.intro hNow hNext

theorem provenance_depth_one_signature_is_exact :
    Loam.Observation312.ExactFutureClassifierUnder
      Loam.Examples.DocumentProvenanceFutureContext.answer
      Loam.Examples.DocumentProvenanceFutureContext.step
      SelectedOperations
      Loam.Examples.DocumentProvenanceFutureContext.Vocabulary
      (provenanceSignatureAtDepth 1) :=
  same_depth_one_signature_iff_futureEquivalentUnder

/-! ## Depth zero is still too shallow -/

theorem available_not_futureEquivalentUnder_blocked :
    ¬ Loam.Observation312.FutureEquivalentUnder
      Loam.Examples.DocumentProvenanceFutureContext.answer
      Loam.Examples.DocumentProvenanceFutureContext.step
      SelectedOperations
      Loam.Examples.DocumentProvenanceFutureContext.Vocabulary
      availableState blockedState := by
  intro hFuture
  have hAfter :=
    hFuture [publishFuture] .aDerivedToDInTwoSteps
      (by
        intro operation hMem
        simp at hMem
        subst operation
        rfl)
      (by simp [Loam.Examples.DocumentProvenanceFutureContext.Vocabulary])
  rcases available_and_blocked_differ_after_selected_future with
    ⟨hAvailable, hBlocked⟩
  simpa [Loam.Observation192.run, hAvailable, hBlocked] using hAfter

theorem provenance_depth_zero_signature_is_not_exact :
    ¬ Loam.Observation312.ExactFutureClassifierUnder
      Loam.Examples.DocumentProvenanceFutureContext.answer
      Loam.Examples.DocumentProvenanceFutureContext.step
      SelectedOperations
      Loam.Examples.DocumentProvenanceFutureContext.Vocabulary
      (provenanceSignatureAtDepth 0) := by
  intro hExact
  have hFuture :=
    (hExact availableState blockedState).1
      depth_zero_merges_available_and_blocked
  exact available_not_futureEquivalentUnder_blocked hFuture

/-!
## Finding

The same synthesis/certification pattern now appears in a second relation
semantics that is intentionally not Correction and not ActualReversal.

For the selected document-provenance future language:

    allowed operation:
      publish B -> D

    selected question:
      A derived to D in exactly two steps?

bounded synthesis yields:

    available       -> [false, true]
    blocked         -> [false, false]
    alreadyDerived  -> [true, true]

and Lean proves:

    depth-zero signature equality
      is not exact

    depth-one signature equality
      iff
    FutureEquivalentUnder

The raw provenance transition is not state-idempotent: publishing B -> D again
can append duplicate retained evidence. What matters is observational
idempotence for the selected question. The duplicate-invariance lemmas make
that distinction explicit.

This is stronger evidence that the reversal result was not only a peculiarity
of one operation family. The reusable shape is now:

    declared operation vocabulary
      + declared question vocabulary
      + bounded future-answer synthesis
      + independent unbounded semantic proof
        ->
      exact vocabulary-relative behavioural quotient

No generic claim is made that depth one suffices for provenance in general, or
that the example-local DocumentDerivation relation should move into Core.
-/

end Loam.Observation313
