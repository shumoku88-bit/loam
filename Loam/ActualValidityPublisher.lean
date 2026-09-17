import Loam.ActualAuthority
import Loam.ActualDate
import Loam.ActualEvidence
import Loam.Application.ActualValidityFrontier
import Loam.FreshNumberedToken

namespace Loam.ActualValidityPublisher

open Loam.Core

set_option autoImplicit false

/-- Surface-independent request to reaffirm or revise one current occurrence date. -/
structure Draft where
  target : EventId
  validOn : String

private def revisionIds :
    List (ActualValidityFact String) → List ActualValidityRevisionId
  | [] => []
  | .base _ _ :: rest => revisionIds rest
  | .revision id _ _ :: rest => id :: revisionIds rest

private theorem revisionId_mem_of_ref_mem
    (facts : List (ActualValidityFact String))
    (id : ActualValidityRevisionId)
    (h : ActualValidityRef.revision id ∈ facts.map ActualValidityFact.ref) :
    id ∈ revisionIds facts := by
  induction facts with
  | nil =>
      simp at h
  | cons fact rest ih =>
      cases fact with
      | base event validOn =>
          have hRest :
              ActualValidityRef.revision id ∈ rest.map ActualValidityFact.ref := by
            simpa [ActualValidityFact.ref] using h
          exact ih hRest
      | revision existing event validOn =>
          simp only [List.map_cons, ActualValidityFact.ref, List.mem_cons] at h
          rcases h with hEq | hRest
          · cases hEq
            simp [revisionIds]
          · simp [revisionIds, ih hRest]

private def freshRevisionId
    (history : ActualValidityHistory String) : ActualValidityRevisionId :=
  let used := (revisionIds history.facts).map ActualValidityRevisionId.token
  ⟨Loam.firstUnusedNumberedToken "validity-" used 1⟩

private theorem freshRevisionId_fresh
    (history : ActualValidityHistory String) :
    ActualValidityRef.revision (freshRevisionId history) ∉
      history.facts.map ActualValidityFact.ref := by
  intro hRef
  have hId :
      freshRevisionId history ∈ revisionIds history.facts :=
    revisionId_mem_of_ref_mem history.facts (freshRevisionId history) hRef
  have hToken :
      (freshRevisionId history).token ∉
        (revisionIds history.facts).map ActualValidityRevisionId.token := by
    simpa [freshRevisionId] using
      (Loam.firstUnusedNumberedToken_fresh
        "validity-"
        ((revisionIds history.facts).map ActualValidityRevisionId.token)
        1)
  apply hToken
  simp only [List.mem_map]
  exact ⟨freshRevisionId history, hId, rfl⟩

private def appendDateChange?
    (history : ActualValidityHistory String)
    (currentFact : ActualValidityFact String)
    (validOn : String) : Except String (ActualValidityHistory String) := do
  let revisionId := freshRevisionId history
  have hRevisionFresh :
      ActualValidityRef.revision revisionId ∉
        history.facts.map ActualValidityFact.ref :=
    freshRevisionId_fresh history
  let replacement : ActualValidityFact String :=
    .revision revisionId currentFact.event validOn
  let withFact := history.addFreshFact replacement (by
    simpa [replacement] using hRevisionFresh)
  let correction : ActualValidityCorrection := {
    target := currentFact.ref
    replacement := revisionId
  }
  match withFact.addCorrection? correction with
  | some updated => pure updated
  | none => throw "loam: could not append occurrence-date correction evidence"

private def admit?
    (evidence : ActualEvidence)
    (draft : Draft) : Except String (Option ActualEvidence) := do
  if !Loam.ActualDate.validIsoDate draft.validOn then
    throw "loam: date must be a real calendar date in YYYY-MM-DD form"
  if (EventMemory.findById? evidence.events draft.target).isNone then
    throw "loam: selected date-correction target is not retained"
  if evidence.corrections.targetsEvent draft.target then
    throw "loam: selected Actual is no longer current"
  let currentFacts := Loam.Application.actualValidityFrontierFacts evidence.validity
  let currentFact ←
    match currentFacts.find? fun fact => decide (fact.event = draft.target) with
    | some fact => pure fact
    | none => throw "loam: selected Actual has no current occurrence date"
  if currentFact.validOn = draft.validOn then
    pure none
  else
    let updatedValidity ← appendDateChange? evidence.validity currentFact draft.validOn
    pure (some { evidence with validity := updatedValidity })

private def publishUnderOwnership
    (root : System.FilePath)
    (draft : Draft) : IO (Except String Unit) := do
  let evidence ←
    match ← Loam.ActualAuthority.loadActual? root with
    | .ok ev => pure ev
    | .error message => return .error message
  match admit? evidence draft with
  | .error message =>
      return .error message
  | .ok none =>
      return .ok ()
  | .ok (some updated) =>
      match ← Loam.ActualAuthority.publishActual? root updated with
      | .error message => return .error message
      | .ok () => return .ok ()

/--
Publish one occurrence-date reaffirmation/correction against normalized Actual authority.
-/
def publishDate
    (rootPath : String) (draft : Draft) : IO (Except String Unit) := do
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.ActualAuthority.withActualOwnership root
    (publishUnderOwnership root draft)

end Loam.ActualValidityPublisher
