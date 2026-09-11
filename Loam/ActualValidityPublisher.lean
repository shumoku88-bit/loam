import Loam.ActualDate
import Loam.Application.ActualValidityFrontier
import Loam.Application.CorrectionFrontier
import Loam.FreshNumberedToken
import Loam.MovementManifestAuthority
import Loam.Persistence.EventCorrectionPersistence
import Loam.WriterOwnership

namespace Loam.ActualValidityPublisher

open Loam.Core

set_option autoImplicit false

/-- Surface-independent request to attach or replace one current occurrence date. -/
structure Draft where
  target : EventId
  validOn : String

/-- Small frontend receipt for one manifest-backed occurrence-date publication. -/
structure Receipt where
  target : EventId
  previous : Option String
  validOn : String
  changed : Bool
  firstDate : Bool
  deriving Repr

private def emptyCorrections : EventCorrectionMemory :=
  { corrections := [], idNodup := by simp }

private def loadCorrectionsOrEmpty?
    (path : System.FilePath) : IO (Except String EventCorrectionMemory) := do
  if ← path.pathExists then
    match ← Loam.Persistence.loadEventCorrectionMemory? path with
    | some memory => return .ok memory
    | none => return .error "loam: malformed or unsupported correction-memory file"
  else
    return .ok emptyCorrections

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
    (world : Loam.MovementAdmission.World)
    (corrections : EventCorrectionMemory)
    (draft : Draft) : Except String (Loam.MovementAdmission.World × Receipt) := do
  if !Loam.ActualDate.validIsoDate draft.validOn then
    throw "loam: date must be a real calendar date in YYYY-MM-DD form"
  let event ← targetCurrent? world.events corrections draft.target
  let currentFacts ←
    match Loam.Application.admittedActualValidityFacts? world.validity with
    | some facts => pure facts
    | none => throw "loam: actual-validity corrections do not justify one current date per Event"
  let currentFact? := currentFactForEvent? currentFacts draft.target
  match currentFact? with
  | some currentFact =>
      if currentFact.validOn = draft.validOn then
        pure (world, {
          target := draft.target
          previous := some currentFact.validOn
          validOn := draft.validOn
          changed := false
          firstDate := false
        })
      else
        let updatedValidity ← appendDateChange? world.validity event currentFact? draft.validOn
        let admitted ←
          match Loam.Application.admittedActualValidityFacts? updatedValidity with
          | some facts => pure facts
          | none => throw "loam: proposed date correction does not justify one current date per Event"
        match currentFactForEvent? admitted draft.target with
        | some replacement =>
            if replacement.validOn != draft.validOn then
              throw "loam: proposed date correction frontier did not select the replacement date"
        | none => throw "loam: proposed date correction lost the selected Actual date"
        pure ({ world with validity := updatedValidity }, {
          target := draft.target
          previous := some currentFact.validOn
          validOn := draft.validOn
          changed := true
          firstDate := false
        })
  | none =>
      let updatedValidity ← appendDateChange? world.validity event none draft.validOn
      let admitted ←
        match Loam.Application.admittedActualValidityFacts? updatedValidity with
        | some facts => pure facts
        | none => throw "loam: proposed first date does not justify one current date per Event"
      match currentFactForEvent? admitted draft.target with
      | some replacement =>
          if replacement.validOn != draft.validOn then
            throw "loam: proposed first date frontier did not select the supplied date"
      | none => throw "loam: proposed first date did not become current"
      pure ({ world with validity := updatedValidity }, {
        target := draft.target
        previous := none
        validOn := draft.validOn
        changed := true
        firstDate := true
      })

private def publishUnderOwnership
    (root correctionFile : System.FilePath)
    (draft : Draft) : IO (Except String Receipt) := do
  let world ←
    match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
    | .ok world => pure world
    | .error message => return .error message
  let corrections ←
    match ← loadCorrectionsOrEmpty? correctionFile with
    | .ok memory => pure memory
    | .error message => return .error message
  let (updated, receipt) ←
    match admit? world corrections draft with
    | .ok value => pure value
    | .error message => return .error message
  if !receipt.changed then
    return .ok receipt
  match ← Loam.MovementManifestAuthority.publishWorld? root updated with
  | .error message => return .error message
  | .ok _ => return .ok receipt

/--
Publish one occurrence-date attachment/correction against current manifest authority.

The publisher shares the Movement `CURRENT` ownership anchor, re-reads selected
Movement and EventCorrection evidence under ownership, verifies that the target
Event is still current, appends only ActualValidity evidence, and republishes one
complete manifest generation. Event payload, Movement correction, description,
relation/discharge evidence, and Locus policy are left unchanged.
-/
def publishManifestDate
    (rootPath correctionPath : String) (draft : Draft) : IO (Except String Receipt) := do
  if rootPath.isEmpty then
    return .error "loam: LOAM_MOVEMENT_MANIFEST_ROOT must not be empty"
  if correctionPath.isEmpty then
    return .error "loam: correction path must not be empty"
  let root := System.FilePath.mk rootPath
  let correctionFile := System.FilePath.mk correctionPath
  Loam.WriterOwnership.withOwnership
    (root / "CURRENT")
    (publishUnderOwnership root correctionFile draft)

end Loam.ActualValidityPublisher
