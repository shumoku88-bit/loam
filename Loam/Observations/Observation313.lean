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

namespace Provenance :=
  Loam.Examples.DocumentProvenanceFutureContext

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

private def availableState : Provenance.State :=
  { documents := documents
    derivations := { edges := [edgeAB] } }

private def blockedState : Provenance.State :=
  { documents := documents
    derivations := { edges := [edgeCB] } }

private def alreadyDerivedState : Provenance.State :=
  { documents := documents
    derivations := { edges := [edgeAB, edgeBD] } }

def publishFuture : Provenance.Operation :=
  .publish edgeBD

/-- The declared future language contains exactly publication of B -> D. -/
def SelectedOperations :
    Loam.Observation312.OperationVocabulary Provenance.Operation :=
  fun operation => operation = publishFuture

def decideSelectedOperations :
    ∀ operation : Provenance.Operation,
      Decidable (SelectedOperations operation) :=
  fun operation => inferInstance

theorem future_edge_projects :
    (DocumentDerivation.project? documents edgeBD).isSome = true := by
  native_decide

/--
Publishing the same selected provenance edge twice does not change the selected
two-step answer beyond the first publication.

The retained raw edge list may grow by one duplicate. The selected provenance
answer does not.
-/
theorem selected_answer_after_publish_is_idempotent
    (state : Provenance.State) :
    Provenance.answer
        (Provenance.step
          (Provenance.step state publishFuture)
          publishFuture)
        .aDerivedToDInTwoSteps =
      Provenance.answer
        (Provenance.step state publishFuture)
        .aDerivedToDInTwoSteps := by
  by_cases hProject :
      (DocumentDerivation.project? state.documents edgeBD).isSome = true
  · have hDocuments :
        (Provenance.step state publishFuture).documents = state.documents :=
      Provenance.step_preserves_documents state edgeBD
    simp [publishFuture, Provenance.step, hProject, hDocuments,
      Provenance.answer, Provenance.derivedInTwoSteps, Provenance.hasEdge,
      edgeBD]
  · have hDocuments :
        (Provenance.step state publishFuture).documents = state.documents :=
      Provenance.step_preserves_documents state edgeBD
    simp [publishFuture, Provenance.step, hProject, hDocuments]

/-! ## Bounded signatures over three canonical provenance worlds -/

def provenanceSynthesisSpace (depth : Nat) :
    Loam.Observation299.SearchSpace
      Provenance.State
      Provenance.Operation
      Provenance.Question :=
  { states := [availableState, blockedState, alreadyDerivedState]
    operations := [publishFuture]
    questions := [.aDerivedToDInTwoSteps]
    depth := depth }

def decideQuestionVocabulary :
    ∀ question : Provenance.Question,
      Decidable (Provenance.Vocabulary question) :=
  fun _ => isTrue trivial

def provenanceSignatureAtDepth
    (depth : Nat)
    (state : Provenance.State) : List Bool :=
  Loam.Observation308.boundedBehaviourSignature
    (provenanceSynthesisSpace depth)
    Provenance.answer
    Provenance.step
    Provenance.Vocabulary
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
    Provenance.answer
        (Provenance.step availableState publishFuture)
        .aDerivedToDInTwoSteps =
      true ∧
    Provenance.answer
        (Provenance.step blockedState publishFuture)
        .aDerivedToDInTwoSteps =
      false := by
  native_decide

/-!
The remainder of the observation will connect the generated depth-one signature
to FutureEquivalentUnder once the selected-publication idempotence lemma above
is admitted by Lean.
-/

end Loam.Observation313
