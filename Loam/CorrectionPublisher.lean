import Loam.ActualAuthority
import Loam.ActualEvidence
import Loam.Application.ActualValidityFrontier
import Loam.Application.CorrectionFrontier
import Loam.Core.BalancedMovement
import Loam.FreshNumberedToken
import Loam.LocusAdmissionAuthority
import Loam.Persistence.TokenSyntax

namespace Loam.CorrectionPublisher

open Loam.Core

set_option autoImplicit false

structure Draft where
  target : EventId
  effects : List Effect
  description : Option String := none

structure Receipt where
  target : EventId
  replacement : EventId
  deriving Repr

private structure Admitted where
  evidence : ActualEvidence
  receipt : Receipt

private def reversalMentionsEvent
    (reversals : ActualReversalMemory) (id : EventId) : Bool :=
  (reversals.findByTarget? id).isSome || (reversals.findByReversal? id).isSome

private def relationsMentionEvent
    (evidence : ActualEvidence) (id : EventId) : Bool :=
  evidence.relations.any (fun relation => decide (relation.sourceEvent = id)) ||
    evidence.discharges.any (fun discharge => decide (discharge.event = id))

private def freshReplacementId?
    (evidence : ActualEvidence) : Option EventId := do
  let token ← Loam.firstUnusedNumberedToken?
    "replacement-"
    (fun token =>
      (EventMemory.findById? evidence.events (⟨token⟩ : EventId)).isSome)
    1
    (evidence.events.events.length + 1)
  pure ⟨token⟩

/-- Anonymous Effects need no persisted identity token; retained keys still do. -/
private def retainedEffectKeyPersistable (effect : Effect) : Bool :=
  match effect.key with
  | none => true
  | some key => Loam.Persistence.validToken key.token

/--
Operation-level qualification shared by a new replacement and an Event already
admitted by normalized Actual persistence. Persistence syntax is checked only at
the boundary where new Effects enter; this helper owns practical Movement meaning.
-/
private def practicalMovementValid (effects : List Effect) : Bool :=
  if effects.isEmpty then false
  else if !effects.all (fun effect =>
      decide (effect.measure = ⟨"jpy"⟩) && effect.quantity.quanta != 0) then
    false
  else
    let changes := effects.map fun effect =>
      ({ coordinate := effect.locus, quantity := effect.quantity } : MovementChange LocusId)
    (BalancedMovement.ofChanges? ⟨"jpy"⟩ changes).isSome

private def targetCurrent?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (target : EventId) : Except String Event := do
  let targetEvent ←
    match EventMemory.findById? events target with
    | some event => pure event
    | none => throw "loam: selected correction target is not retained"
  if corrections.corrections.any (fun correction => decide (correction.target = target)) then
    throw "loam: selected Actual is no longer current"
  pure targetEvent

private def admit?
    (evidence : ActualEvidence)
    (locusAdmission : LocusAdmissionVocabulary)
    (draft : Draft) : Except String Admitted := do
  if !draft.effects.all (fun effect =>
      retainedEffectKeyPersistable effect &&
      Loam.Persistence.validToken effect.locus.token) ||
      !practicalMovementValid draft.effects then
    throw "loam: correction replacement must be one balanced nonzero JPY Movement"
  if !locusAdmission.admitsEffects draft.effects then
    throw "loam: correction replacement uses a Locus not approved for new publication"

  let target ← targetCurrent? evidence.events evidence.corrections draft.target
  if !practicalMovementValid target.effects then
    throw "loam: selected Actual is outside the practical balanced-JPY correction entrance"
  if relationsMentionEvent evidence draft.target then
    throw "loam: correction of an Event already referenced by relation/discharge evidence is not yet qualified"
  if reversalMentionsEvent evidence.reversals draft.target then
    throw "loam: correction of an Actual participating in Reversal evidence is not yet qualified"

  let currentFacts ←
    match Loam.Application.admittedActualValidityFacts? evidence.validity with
    | some facts => pure facts
    | none => throw "loam: actual-validity corrections do not justify one current date per Event"
  let targetFact ←
    match currentFacts.find? fun fact => decide (fact.event = draft.target) with
    | some fact => pure fact
    | none => throw "loam: selected Actual has no current occurrence date"

  let replacementId ←
    match freshReplacementId? evidence with
    | some id => pure id
    | none => throw "loam: could not generate a fresh replacement Event identity"
  let correction : EventCorrection := {
    target := draft.target
    replacement := replacementId
  }

  let replacement ←
    match Event.ofEffects? correction.replacement draft.effects with
    | some event => pure event
    | none => throw "loam: replacement Effect identities are not unique"
  let updatedEvents ←
    match EventMemory.add? evidence.events replacement with
    | some events => pure events
    | none => throw "loam: replacement Event could not be appended"
  let updatedCorrections ←
    match evidence.corrections.add? correction with
    | some memory => pure memory
    | none => throw "loam: correction relation could not be appended"

  let frontier ←
    match Loam.Application.correctionFrontierMemory? updatedEvents updatedCorrections with
    | some memory => pure memory
    | none => throw "loam: proposed correction does not justify one current record frontier"
  if (EventMemory.findById? frontier correction.replacement).isNone ||
      (EventMemory.findById? frontier correction.target).isSome then
    throw "loam: proposed correction frontier did not select exactly the replacement"

  let updatedValidity ←
    match evidence.validity.addFact? (.base correction.replacement targetFact.validOn) with
    | some history => pure history
    | none => throw "loam: could not append replacement occurrence-date evidence"
  let updatedDescriptions ←
    match draft.description with
    | none => pure evidence.descriptions
    | some text =>
        match EventDescriptionMemory.ofEntries?
            (evidence.descriptions.entries ++ [{ event := correction.replacement, text := text }]) with
        | some descriptions => pure descriptions
        | none => throw "loam: could not append replacement description"

  pure {
    evidence := {
      events := updatedEvents
      validity := updatedValidity
      descriptions := updatedDescriptions
      corrections := updatedCorrections
      reversals := evidence.reversals
      relations := evidence.relations
      discharges := evidence.discharges
    }
    receipt := {
      target := draft.target
      replacement := correction.replacement
    }
  }

private def publishUnderOwnership
    (root : System.FilePath)
    (draft : Draft) : IO (Except String Receipt) := do
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

  match ← Loam.ActualAuthority.publishActual? root admitted.evidence with
  | .error message => return .error message
  | .ok () => return .ok admitted.receipt

/--
Publish one practical Movement correction against normalized Actual authority.
-/
def publishCorrection
    (rootPath : String) (draft : Draft) : IO (Except String Receipt) := do
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.ActualAuthority.withActualOwnership root
    (publishUnderOwnership root draft)


end Loam.CorrectionPublisher
