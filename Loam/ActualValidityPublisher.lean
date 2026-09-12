import Loam.ActualAuthority
import Loam.ActualDate
import Loam.ActualEvidence
import Loam.Application.ActualValidityFrontier
import Loam.Application.CorrectionFrontier
import Loam.FreshNumberedToken

namespace Loam.ActualValidityPublisher

open Loam.Core

set_option autoImplicit false

/-- Surface-independent request to attach or replace one current occurrence date. -/
structure Draft where
  target : EventId
  validOn : String

/-- Small frontend receipt for one occurrence-date publication. -/
structure Receipt where
  target : EventId
  previous : Option String
  validOn : String
  changed : Bool
  firstDate : Bool
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
  let frontier ←
    match Loam.Application.correctionFrontierMemory? events corrections with
    | some memory => pure memory
    | none => throw "loam: movement corrections do not justify one current record frontier"
  if (EventMemory.findById? frontier target).isNone then
    throw "loam: selected Actual is no longer current"
  pure targetEvent

private def appendDateChange?
    (history : ActualValidityHistory String)
    (event : Event)
    (currentFact? : Option (ActualValidityFact String))
    (validOn : String) : Except String (ActualValidityHistory String) := do
  match currentFact? with
  | none =>
      match history.addFact? (.base event.id validOn) with
      | some updated => pure updated
      | none => throw "loam: could not append first occurrence-date evidence"
  | some currentFact =>
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
  let currentFacts ←
    match Loam.Application.admittedActualValidityFacts? evidence.validity with
    | some facts => pure facts
    | none => throw "loam: actual-validity corrections do not justify one current date per Event"
  let currentFact? := currentFactForEvent? currentFacts draft.target
  match currentFact? with
  | some currentFact =>
      if currentFact.validOn = draft.validOn then
        pure (evidence, {
          target := draft.target
          previous := some currentFact.validOn
          validOn := draft.validOn
          changed := false
          firstDate := false
        })
      else
        let updatedValidity ← appendDateChange? evidence.validity event currentFact? draft.validOn
        let admitted ←
          match Loam.Application.admittedActualValidityFacts? updatedValidity with
          | some facts => pure facts
          | none => throw "loam: proposed date correction does not justify one current date per Event"
        match currentFactForEvent? admitted draft.target with
        | some replacement =>
            if replacement.validOn != draft.validOn then
              throw "loam: proposed date correction frontier did not select the replacement date"
        | none => throw "loam: proposed date correction lost the selected Actual date"
        pure ({ evidence with validity := updatedValidity }, {
          target := draft.target
          previous := some currentFact.validOn
          validOn := draft.validOn
          changed := true
          firstDate := false
        })
  | none =>
      let updatedValidity ← appendDateChange? evidence.validity event none draft.validOn
      let admitted ←
        match Loam.Application.admittedActualValidityFacts? updatedValidity with
        | some facts => pure facts
        | none => throw "loam: proposed first date does not justify one current date per Event"
      match currentFactForEvent? admitted draft.target with
      | some replacement =>
          if replacement.validOn != draft.validOn then
            throw "loam: proposed first date frontier did not select the supplied date"
      | none => throw "loam: proposed first date did not become current"
      pure ({ evidence with validity := updatedValidity }, {
        target := draft.target
        previous := none
        validOn := draft.validOn
        changed := true
        firstDate := true
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
Publish one occurrence-date attachment/correction against normalized Actual authority.
-/
def publishDate
    (rootPath : String) (draft : Draft) : IO (Except String Receipt) := do
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.ActualAuthority.withActualOwnership root
    (publishUnderOwnership root draft)

end Loam.ActualValidityPublisher
