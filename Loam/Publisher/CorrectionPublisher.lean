import Loam.ActualAuthority
import Loam.ActualEvidence
import Loam.Application.ActualValidityFrontier
import Loam.FreshNumberedToken
import Loam.LocusAdmissionAuthority
import Loam.Persistence.TokenSyntax
import Loam.PracticalMovement
import Loam.SparseEffectIdentity

namespace Loam.CorrectionPublisher

open Loam.Core

set_option autoImplicit false

structure Draft where
  target : EventId
  effects : List Effect
  description : Option String := none

private def freshReplacementId
    (evidence : ActualEvidence) : EventId :=
  let used := evidence.events.events.map (fun event => event.id.token)
  ⟨Loam.firstUnusedNumberedToken "replacement-" used 1⟩

private def targetCurrent?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (target : EventId) : Except String Event := do
  let targetEvent ←
    match EventMemory.findById? events target with
    | some event => pure event
    | none => throw "loam: selected correction target is not retained"
  if corrections.targetsEvent target then
    throw "loam: selected Actual is no longer current"
  pure targetEvent

private def admit?
    (evidence : ActualEvidence)
    (locusAdmission : LocusAdmissionVocabulary)
    (draft : Draft) : Except String ActualEvidence := do
  let effects := Loam.SparseEffectIdentity.canonicalizeEffects [] draft.effects
  if !effects.all (fun effect =>
      Loam.Persistence.validToken effect.locus.token &&
      Loam.Persistence.validToken effect.measure.token) then
    throw "loam: correction replacement must use valid Locus and Measure tokens"
  let replacementMovement ←
    match Loam.PracticalMovement.ofSingleMeasureEffects? effects with
    | some movement => pure movement
    | none =>
        throw "loam: correction replacement must be one balanced nonzero single-Measure Movement"
  if !locusAdmission.admitsEffects effects then
    throw "loam: correction replacement uses a Locus not approved for new publication"

  let target ← targetCurrent? evidence.events evidence.corrections draft.target
  let targetMovement ←
    match Loam.PracticalMovement.ofSingleMeasureEffects? target.effects with
    | some movement => pure movement
    | none =>
        throw "loam: selected Actual is outside the practical balanced single-Measure correction entrance"
  if replacementMovement.measure != targetMovement.measure then
    throw "loam: correction must preserve the target Measure; cross-Measure change requires separate exchange semantics"
  if evidence.relationEvidenceMentionsEvent draft.target then
    throw "loam: correction of an Event already referenced by relation/discharge evidence is not yet qualified"
  if evidence.reversals.mentionsEvent draft.target then
    throw "loam: correction of an Actual participating in Reversal evidence is not yet qualified"

  let currentFacts := Loam.Application.actualValidityFrontierFacts evidence.validity
  let targetFact ←
    match currentFacts.find? fun fact => decide (fact.event = draft.target) with
    | some fact => pure fact
    | none => throw "loam: selected Actual has no current occurrence date"

  let replacementId := freshReplacementId evidence
  let correction : EventCorrection := {
    target := draft.target
    replacement := replacementId
  }

  let replacement ←
    match Event.ofEffects? correction.replacement effects with
    | some event => pure event
    | none => throw "loam: correction replacement Effect identity is not unique"
  let updatedEvents ←
    match EventMemory.add? evidence.events replacement with
    | some events => pure events
    | none => throw "loam: replacement Event could not be appended"
  let updatedCorrections ←
    match evidence.corrections.add? correction with
    | some memory => pure memory
    | none => throw "loam: correction relation could not be appended"

  let updatedValidity ←
    match evidence.validity.addFact? (.base correction.replacement targetFact.validOn) with
    | some history => pure history
    | none => throw "loam: could not append replacement occurrence-date evidence"
  let updatedDescriptions ←
    match draft.description with
    | none => pure evidence.descriptions
    | some text =>
        match evidence.descriptions.add?
            { event := correction.replacement, text := text } with
        | some descriptions => pure descriptions
        | none => throw "loam: could not append replacement description"

  pure {
    evidence with
    events := updatedEvents
    validity := updatedValidity
    descriptions := updatedDescriptions
    corrections := updatedCorrections
  }

private def publishUnderOwnership
    (root : System.FilePath)
    (draft : Draft) : IO (Except String Unit) := do
  let evidence ←
    match ← Loam.ActualAuthority.loadActual? root with
    | .ok ev => pure ev
    | .error message => return .error message
  let locusAdmission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? root with
    | .ok la => pure la
    | .error message => return .error message
  let admitted ←
    match admit? evidence locusAdmission draft with
    | .ok admitted => pure admitted
    | .error message => return .error message

  match ← Loam.ActualAuthority.publishActual? root admitted with
  | .error message => return .error message
  | .ok () => return .ok ()

/--
Publish one practical Movement correction against normalized Actual authority.
-/
def publishCorrection
    (rootPath : String) (draft : Draft) : IO (Except String Unit) := do
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.ActualAuthority.withActualOwnership root
    (publishUnderOwnership root draft)


end Loam.CorrectionPublisher
