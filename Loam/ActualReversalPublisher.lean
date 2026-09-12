import Loam.ActualAuthority
import Loam.ActualDate
import Loam.ActualEvidence
import Loam.Application.ActualValidityFrontier
import Loam.Application.CorrectionFrontier
import Loam.Core.ActualReversal
import Loam.Core.BalancedMovement
import Loam.LocusAdmissionAuthority
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Persistence.TokenSyntax
import Loam.WriterOwnership

namespace Loam.ActualReversalPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Single-File Actual Reversal Publication

A reversal is two co-published facts:
1. an ordinary Actual Event whose Effects are the exact additive inverse of one
   selected current Actual; and
2. an explicit `ActualReversal` relation naming the cancelled target.

Both facts are committed atomically together in `actual.loam`. Interruption never
exposes an unlinked inverse Movement or a torn relation.

Effects of the reversal Event are anonymous (`Effect.ofAnonymousQuantity`),
without synthetic keys.
-/

structure Draft where
  target : EventId
  validOn : String

structure Receipt where
  target : EventId
  reversal : EventId
  validOn : String
  deriving Repr

private structure Admitted where
  evidence : ActualEvidence
  receipt : Receipt

private def loadScheduledLifecycle?
    (path : System.FilePath) : IO (Except String Loam.Persistence.ScheduledLifecycleImage) := do
  if !(← path.pathExists) then
    return .error "loam: Scheduled lifecycle authority is missing; reversal cannot prove relation independence"
  match ← Loam.Persistence.loadScheduledLifecycleImage? path with
  | some image => return .ok image
  | none => return .error "loam: Scheduled lifecycle authority is malformed or unsupported"

/--
Operation-level qualification for an Event already admitted by normalized Actual
persistence. Token syntax is trusted from canonical decoding; reversal still
requires one nonempty balanced Movement of nonzero JPY Effects.
-/
private def practicalTargetMovementValid (effects : List Effect) : Bool :=
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
    | none => throw "loam: selected reversal target is not retained"
  match Loam.Application.correctionFrontierMemory? events corrections with
  | none => throw "loam: movement corrections do not justify one current record frontier"
  | some frontier =>
      match EventMemory.findById? frontier target with
      | some _ => pure targetEvent
      | none => throw "loam: selected Actual is no longer current"

private def worldRelationsMentionEvent
    (evidence : ActualEvidence) (event : EventId) : Bool :=
  evidence.relations.any (fun relation => decide (relation.sourceEvent = event)) ||
    evidence.discharges.any (fun discharge => decide (discharge.event = event))

private def scheduledCompletionMentionsEvent
    (lifecycle : Loam.Persistence.ScheduledLifecycleImage) (event : EventId) : Bool :=
  (lifecycle.terminals.completionSourceForActual? event).isSome

private def deterministicReversalId (target : EventId) : EventId :=
  ⟨"actual-reversal:" ++ target.token⟩

private def inverseEffects (target : Event) : List Effect :=
  target.effects.map fun effect =>
    Effect.ofAnonymousQuantity effect.locus effect.measure (-effect.quantity)

private def admit?
    (evidence : ActualEvidence)
    (locusAdmission : LocusAdmissionVocabulary)
    (lifecycle : Loam.Persistence.ScheduledLifecycleImage)
    (draft : Draft) : Except String Admitted := do
  if !Loam.ActualDate.validIsoDate draft.validOn then
    throw "loam: reversal occurrence date must be a real YYYY-MM-DD calendar date"
  if !Loam.Persistence.validToken draft.target.token then
    throw "loam: reversal target identity is not persistable"
  if (evidence.reversals.findByReversal? draft.target).isSome then
    throw "loam: reversal-of-reversal chains are not yet qualified"
  if (evidence.reversals.findByTarget? draft.target).isSome then
    throw "loam: selected Actual is already reversed"
  if worldRelationsMentionEvent evidence draft.target then
    throw "loam: reversal of an Actual referenced by retained relation/discharge evidence is not yet qualified"
  if scheduledCompletionMentionsEvent lifecycle draft.target then
    throw "loam: reversal of a Scheduled-completion Actual is not yet qualified"

  let target ← targetCurrent? evidence.events evidence.corrections draft.target
  if !practicalTargetMovementValid target.effects then
    throw "loam: selected Actual is outside the practical balanced-JPY reversal entrance"

  let reversal := deterministicReversalId draft.target
  if (EventMemory.findById? evidence.events reversal).isSome then
    throw "loam: deterministic reversal Event identity collides with retained Movement evidence"
  let relation : ActualReversal := { target := draft.target, reversal := reversal }

  let effects := inverseEffects target
  if !locusAdmission.admitsEffects effects then
    throw "loam: reversal uses a Locus not approved for new publication"

  let event ←
    match Event.ofEffects? relation.reversal effects with
    | some event => pure event
    | none => throw "loam: reversal Effect identities are not unique"
  let events ←
    match EventMemory.add? evidence.events event with
    | some events => pure events
    | none => throw "loam: reversal Event could not be appended"

  let validity ←
    match evidence.validity.addFact? (.base relation.reversal draft.validOn) with
    | some history => pure history
    | none => throw "loam: reversal occurrence date could not be appended"
  let some admittedDates := Loam.Application.admittedActualValidityFacts? validity
    | throw "loam: reversal date evidence does not justify one current date per Event"
  if !(admittedDates.any fun fact =>
      decide (fact.event = relation.reversal ∧ fact.validOn = draft.validOn)) then
    throw "loam: reversal occurrence date did not become current"

  let updatedReversals ←
    match evidence.reversals.add? relation with
    | some memory => pure memory
    | none => throw "loam: reversal relation could not be appended"

  pure {
    evidence := {
      events := events
      validity := validity
      descriptions := evidence.descriptions
      corrections := evidence.corrections
      reversals := updatedReversals
      relations := evidence.relations
      discharges := evidence.discharges
    }
    receipt := {
      target := draft.target
      reversal := relation.reversal
      validOn := draft.validOn
    }
  }

private def publishUnderOwnership
    (scheduledFile root : System.FilePath)
    (draft : Draft) : IO (Except String Receipt) := do
  let evidence ←
    match ← Loam.ActualAuthority.loadActual? root with
    | .ok ev => pure ev
    | .error message => return .error message
  let locusAdmission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? root with
    | .ok la => pure la
    | .error message => return .error message
  let lifecycle ←
    match ← loadScheduledLifecycle? scheduledFile with
    | .ok image => pure image
    | .error message => return .error message
  let admitted ←
    match admit? evidence locusAdmission lifecycle draft with
    | .ok admitted => pure admitted
    | .error message => return .error message

  match ← Loam.ActualAuthority.publishActual? root admitted.evidence with
  | .error message => return .error message
  | .ok () => return .ok admitted.receipt

/--
Publish one explicit Actual reversal to normalized Actual authority.
-/
def publishReversal
    (scheduledPath rootPath : String)
    (draft : Draft) : IO (Except String Receipt) := do
  if scheduledPath.isEmpty then
    return .error "loam: scheduled path must not be empty"
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let scheduledFile := System.FilePath.mk scheduledPath
  let root := System.FilePath.mk rootPath
  Loam.WriterOwnership.withOwnership scheduledFile <|
    Loam.ActualAuthority.withActualOwnership root
      (publishUnderOwnership scheduledFile root draft)


end Loam.ActualReversalPublisher
