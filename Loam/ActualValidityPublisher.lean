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

private def freshRevisionId?
    (history : ActualValidityHistory String) : Option ActualValidityRevisionId := do
  let token ← Loam.firstUnusedNumberedToken?
    "validity-"
    (fun token =>
      (history.findFactByRef? (.revision (⟨token⟩ : ActualValidityRevisionId))).isSome)
    1
    (history.facts.length + 1)
  pure ⟨token⟩

private def appendDateChange?
    (history : ActualValidityHistory String)
    (currentFact : ActualValidityFact String)
    (validOn : String) : Except String (ActualValidityHistory String) := do
  let revisionId ←
    match freshRevisionId? history with
    | some id => pure id
    | none => throw "loam: could not generate a fresh occurrence-date revision identity"
  let replacement : ActualValidityFact String :=
    .revision revisionId currentFact.event validOn
  let withFact ←
    match history.addFact? replacement with
    | some updated => pure updated
    | none => throw "loam: could not append occurrence-date revision evidence"
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
