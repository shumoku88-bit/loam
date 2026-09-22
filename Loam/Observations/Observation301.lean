import Loam.Examples.DocumentProvenanceFutureContext
import Loam.Observations.Observation299

namespace Loam.Observation301

open Loam.Core
open Loam.Examples.DocumentProvenanceBoundary

set_option autoImplicit false

/-!
# Observation 301 — bounded search against document provenance semantics

Observation 300 connected the bounded retention searcher to LOAM's existing
Correction semantics. This observation asks whether the same search/check split
survives a deliberately independent relation family.

The semantic machinery comes from
`Loam.Examples.DocumentProvenanceFutureContext`:

- quantity-free retained document Events;
- example-local `DocumentDerivation` evidence;
- publication that preserves both source and derived documents;
- a selected two-step derivation question;
- the current-answer-only candidate summary.

Unlike Correction, `derived-from` has no supersession meaning. A successful
search here therefore tests reuse across two intentionally different relation
semantics, not reuse of one correction-specific trick.
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

private def leftBase : DocumentDerivation :=
  { source := docA.id, derived := docB.id }

private def rightBase : DocumentDerivation :=
  { source := docC.id, derived := docB.id }

private def leftState :
    Loam.Examples.DocumentProvenanceFutureContext.State :=
  { documents := documents
    derivations := { edges := [leftBase] } }

private def rightState :
    Loam.Examples.DocumentProvenanceFutureContext.State :=
  { documents := documents
    derivations := { edges := [rightBase] } }

private def publishFuture :
    Loam.Examples.DocumentProvenanceFutureContext.Operation :=
  .publish { source := docB.id, derived := docD.id }

private def provenanceStates :
    List Loam.Examples.DocumentProvenanceFutureContext.State :=
  [leftState, rightState]

private def provenanceOperations :
    List Loam.Examples.DocumentProvenanceFutureContext.Operation :=
  [publishFuture]

private def provenanceQuestions :
    List Loam.Examples.DocumentProvenanceFutureContext.Question :=
  [.aDerivedToDInTwoSteps]

def decideProvenanceVocabulary :
    ∀ question : Loam.Examples.DocumentProvenanceFutureContext.Question,
      Decidable
        (Loam.Examples.DocumentProvenanceFutureContext.Vocabulary question) :=
  fun _ => isTrue trivial

private def provenanceSearchSpace (depth : Nat) :
    Loam.Observation299.SearchSpace
      Loam.Examples.DocumentProvenanceFutureContext.State
      Loam.Examples.DocumentProvenanceFutureContext.Operation
      Loam.Examples.DocumentProvenanceFutureContext.Question :=
  { states := provenanceStates
    operations := provenanceOperations
    questions := provenanceQuestions
    depth := depth }

def provenanceSearch (depth : Nat) :=
  (provenanceSearchSpace depth).search
    Loam.Examples.DocumentProvenanceFutureContext.answer
    Loam.Examples.DocumentProvenanceFutureContext.step
    Loam.Examples.DocumentProvenanceFutureContext.Vocabulary
    decideProvenanceVocabulary
    Loam.Examples.DocumentProvenanceFutureContext.encodeCurrentAnswer

/-- The depth-one provenance fixture also enumerates eight candidate payloads. -/
theorem provenance_depth_one_candidate_count :
    (provenanceSearchSpace 1).candidateCount = 8 := by
  native_decide

/--
Without any future publication, the current-answer-only summary loses no
selected answer inside this finite candidate set.
-/
theorem provenance_depth_zero_finds_no_counterexample :
    (provenanceSearch 0).isNone = true := by
  native_decide

/--
At depth one the searcher discovers that the retained derivation topology matters
after publishing the same future edge.
-/
theorem provenance_depth_one_finds_counterexample :
    (provenanceSearch 1).isSome = true := by
  native_decide

/--
The automatically found provenance payload passes through the same generic
soundness bridge and refutes future sufficiency of retaining only today's
two-step provenance answer.
-/
theorem provenance_search_refutes_current_answer_summary :
    ¬ Loam.Observation192.FutureSufficient
      Loam.Examples.DocumentProvenanceFutureContext.answer
      Loam.Examples.DocumentProvenanceFutureContext.step
      Loam.Examples.DocumentProvenanceFutureContext.Vocabulary
      Loam.Examples.DocumentProvenanceFutureContext.encodeCurrentAnswer := by
  have hSome : (provenanceSearch 1).isSome = true :=
    provenance_depth_one_finds_counterexample
  cases hSearch : provenanceSearch 1 with
  | none =>
      simp [hSearch] at hSome
  | some payload =>
      exact
        (provenanceSearchSpace 1).search_some_refutes_futureSufficient
          Loam.Examples.DocumentProvenanceFutureContext.answer
          Loam.Examples.DocumentProvenanceFutureContext.step
          Loam.Examples.DocumentProvenanceFutureContext.Vocabulary
          decideProvenanceVocabulary
          Loam.Examples.DocumentProvenanceFutureContext.encodeCurrentAnswer
          payload
          (by simpa [provenanceSearch] using hSearch)

/-!
## Finding

The same bounded search/check boundary now works across two semantically
different relation families:

    Correction
      means supersession/effective-frontier selection

    DocumentDerivation
      means provenance without supersession

For the finite provenance fixture:

    same retained documents
      + same current selected provenance answer
      + different retained derivation topology
      + one common future derivation publication
          |
          v
    bounded search
          |
          v
    distinguishing payload
          |
          v
    generic checker
          |
          v
    not FutureSufficient

This remains a bounded research result. `DocumentDerivation` is intentionally
example-local, not a production Core relation, and the observation makes no
claim that two-step reachability is a complete document-provenance semantics.

The useful result is structural: the searcher is not tied to Correction's
supersession behavior. It can discover future-context retention failures for an
independently defined relation semantics using the same small trusted checker.
-/

end Loam.Observation301
