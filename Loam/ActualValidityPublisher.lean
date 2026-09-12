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

/-- Small frontend receipt for one occurrence-date publication. -/
structure Receipt where
  target : EventId
  previous : String
  validOn : String
  changed : Bool
  deriving Repr

private def freshRevisionId?
    (history : ActualValidityHistory String) : Option ActualValidityRevisionId := do
  let token ← Loam.firstUnusedNumberedToken?
    "validity-"
    (fun token =>
      (history.findFactByRef? (.revision (⟨token⟩ : ActualValidityRevisionId))).isSome)
    1
    (history.facts.length + 1)
  pure ⟨token⟩

private def currentFactForEvent?
    (facts : List (ActualValidityFact String)) (event : EventId) :
    Option (ActualValidityFact String) :=
  facts.find? fun fact => decide (fact.event = event)

private def targetCurrent?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (target : EventId) : Except String Event := do
  let targetEvent ←
    match EventMemory.findById? events target with
    | some event => pure event
    | none => throw "loam: selected date-correction target is not retained"
  if corrections.corrections.any (fun correction => decide (correction.target = target)) then
    throw "loam: selected Actual is no longer current"
  pure targetEvent

private def appendDateChange?
    (history : ActualValidityHistory String)
    (event : Event)
    (currentFact : ActualValidityFact String)
    (validOn : String) : Except String (ActualValidityHistory String) := do
  let revisionId ←
    match freshRevisionId? history with
    | some id => pure id
    | none => throw "loam: could not generate a fresh occurrence-date revision identity"
  let replacement : ActualValidityFact String :=
    .revision revisionId event.id validOn
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
    (draft : Draft) : Except String (ActualEvidence × Receipt) := do
  if !Loam.ActualDate.validIsoDate draft.validOn then
    throw "loam: date must be a real calendar date in YYYY-MM-DD form"
  let event ← targetCurrent? evidence.events evidence.corrections draft.target
  let currentFacts := Loam.Application.actualValidityFrontierFacts evidence.validity
  let currentFact ←
    match currentFactForEvent? currentFacts draft.target with
    | some fact => pure fact
    | none => throw "loam: selected Actual has no current occurrence date"
  if currentFact.validOn = draft.validOn then
    pure (evidence, {
      target := draft.target
      previous := currentFact.validOn
      validOn := draft.validOn
      changed := false
    })
  else
    let updatedValidity ← appendDateChange? evidence.validity event currentFact draft.validOn
    pure ({ evidence with validity := updatedValidity }, {
      target := draft.target
      previous := currentFact.validOn
      validOn := draft.validOn
      changed := true
    })

private def publishUnderOwnership
    (root : System.FilePath)
    (draft : Draft) : IO (Except String Receipt) := do
  let evidence ←
    match ← Loam.ActualAuthority.loadActual? root with
    | .ok ev => pure ev
    | .error message => return .error message
  let (updated, receipt) ←
    match admit? evidence draft with
    | .ok value => pure value
    | .error message => return .error message
  if !receipt.changed then
    return .ok receipt
  match ← Loam.ActualAuthority.publishActual? root updated with
  | .error message => return .error message
  | .ok () => return .ok receipt

/--
Publish one occurrence-date reaffirmation/correction against normalized Actual authority.
-/
def publishDate
    (rootPath : String) (draft : Draft) : IO (Except String Receipt) := do
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.ActualAuthority.withActualOwnership root
    (publishUnderOwnership root draft)

end Loam.ActualValidityPublisher
