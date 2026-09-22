import Loam.Examples.DocumentProvenanceBoundary
import Loam.Observations.Observation192

namespace Loam.Examples.DocumentProvenanceFutureContext

open Loam.Core
open Loam.Examples.DocumentProvenanceBoundary

set_option autoImplicit false

/-!
# Independent future-context probe: document derivation

`DocumentProvenanceBoundary` established a non-household semantic boundary:
`derived-from` is not `EventCorrection`. A derived document may remain valid
alongside its source, so supersession/correction semantics must not be reused.

This follow-up asks whether Observation 192's future-context distinction appears
again with an independently earned operation family rather than Correction.

The retained documents are quantity-free Events. The only changing evidence is
an example-local list of `DocumentDerivation` edges. Publishing one derivation
never removes or supersedes a document.

The selected question is deliberately small: whether one document is derived
from another through exactly two retained derivation edges. Two states answer
that question equally now, but the same future derivation edge makes the answer
different because the states retained different provenance topology.

This is a research-only witness. It does not propose a generic provenance graph
for Core and does not claim that exactly-two-step reachability is a final
document semantics.
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

/-- Example-local retained provenance edges. No correction/supersession meaning. -/
structure DerivationMemory where
  edges : List DocumentDerivation
  deriving Repr, DecidableEq

structure State where
  documents : EventMemory
  derivations : DerivationMemory

inductive Operation where
  | publish : DocumentDerivation → Operation
  deriving Repr, DecidableEq

inductive Question where
  | aDerivedToDInTwoSteps
  deriving Repr, DecidableEq

/-- A direct edge predicate over retained derivation evidence. -/
def hasEdge
    (memory : DerivationMemory)
    (source derived : EventId) : Bool :=
  memory.edges.any fun edge =>
    decide (edge.source = source ∧ edge.derived = derived)

/--
Selected provenance observation: there exists one retained intermediate document
forming exactly two derivation edges from `source` to `target`.
-/
def derivedInTwoSteps
    (memory : DerivationMemory)
    (source target : EventId) : Bool :=
  memory.edges.any fun first =>
    decide (first.source = source) &&
      hasEdge memory first.derived target

/--
Publish one derivation only when both endpoint documents are retained.

Unlike Correction publication, this operation does not supersede either endpoint.
-/
def step (state : State) : Operation → State
  | .publish edge =>
      if (DocumentDerivation.project? state.documents edge).isSome then
        { state with
          derivations := { edges := state.derivations.edges ++ [edge] } }
      else
        state

/-- Publishing provenance leaves retained document evidence unchanged. -/
theorem step_preserves_documents
    (state : State)
    (edge : DocumentDerivation) :
    (step state (.publish edge)).documents = state.documents := by
  unfold step
  split <;> rfl

def answer (state : State) : Question → Bool
  | .aDerivedToDInTwoSteps =>
      derivedInTwoSteps state.derivations docA.id docD.id

def Vocabulary : Loam.Observation029.Vocabulary Question :=
  fun _ => True

private def leftBase : DocumentDerivation :=
  { source := docA.id, derived := docB.id }

private def rightBase : DocumentDerivation :=
  { source := docC.id, derived := docB.id }

private def leftState : State :=
  { documents := documents
    derivations := { edges := [leftBase] } }

private def rightState : State :=
  { documents := documents
    derivations := { edges := [rightBase] } }

/-- Both worlds retain exactly the same quantity-free documents. -/
theorem retained_documents_are_identical :
    leftState.documents = rightState.documents := by
  rfl

/-- Neither one-edge world currently contains an A -> _ -> D derivation path. -/
theorem left_current_answer :
    answer leftState .aDerivedToDInTwoSteps = false := by
  native_decide

theorem right_current_answer :
    answer rightState .aDerivedToDInTwoSteps = false := by
  native_decide

/-- The selected current provenance question cannot distinguish the worlds. -/
theorem states_are_currently_equivalent :
    Loam.Observation029.Equivalent
      answer Vocabulary leftState rightState := by
  intro question _
  cases question
  rw [left_current_answer, right_current_answer]

private def futureEdge : DocumentDerivation :=
  { source := docB.id, derived := docD.id }

private def publishFuture : Operation :=
  .publish futureEdge

/-- The future edge is semantically closed over retained documents. -/
theorem future_edge_projects :
    (DocumentDerivation.project? documents futureEdge).isSome = true := by
  native_decide

/-!
After publishing the same B -> D derivation:

left retained topology:

    A -> B -> D

right retained topology:

    C -> B -> D

The future operation is identical. The distinction comes only from provenance
evidence retained before the operation.
-/

theorem left_after_future_answer :
    answer (step leftState publishFuture) .aDerivedToDInTwoSteps = true := by
  native_decide

theorem right_after_future_answer :
    answer (step rightState publishFuture) .aDerivedToDInTwoSteps = false := by
  native_decide

/--
Current observational equivalence is strictly weaker than future-context
equivalence for this non-Correction provenance operation family.
-/
theorem states_are_not_futureEquivalent :
    ¬ Loam.Observation192.FutureEquivalent
      answer step Vocabulary leftState rightState := by
  intro hFuture
  have hAfter :=
    hFuture [publishFuture] .aDerivedToDInTwoSteps (by simp [Vocabulary])
  change
    answer
        (Loam.Observation192.run step leftState [publishFuture])
        .aDerivedToDInTwoSteps =
      answer
        (Loam.Observation192.run step rightState [publishFuture])
        .aDerivedToDInTwoSteps
    at hAfter
  simp [Loam.Observation192.run] at hAfter
  rw [left_after_future_answer, right_after_future_answer] at hAfter
  simp at hAfter

/-- The distinguishing operation still leaves the shared documents untouched. -/
theorem retained_documents_remain_identical_after_future :
    (step leftState publishFuture).documents =
      (step rightState publishFuture).documents := by
  rw [step_preserves_documents, step_preserves_documents]
  exact retained_documents_are_identical

/-- Current provenance answer alone is the candidate lossy summary. -/
def encodeCurrentAnswer (state : State) : Bool :=
  answer state .aDerivedToDInTwoSteps

/--
Keeping only today's selected provenance answer is not enough for the future
vocabulary that permits publication of another derivation edge.
-/
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

/-!
## Finding

The future-context compression boundary is not specific to accounting and is not
specific to Correction/supersession topology.

For this independently earned document-provenance relation:

    same retained documents
    + same selected current provenance answer
    + different retained derivation topology
    + same future derivation publication
        ->
    different future selected answer

Therefore a current-answer-only summary again fails `FutureSufficient`.

The generic mathematics remains Observation 192. This file contributes a second
operation-family witness, not a new theorem or a proposal to move provenance
machinery into production Core.
-/

end Loam.Examples.DocumentProvenanceFutureContext
