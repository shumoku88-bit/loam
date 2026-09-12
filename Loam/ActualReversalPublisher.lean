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
  resumed : Bool
  deriving Repr

private structure Admitted where
  evidence : ActualEvidence
  reversalChanged : Bool
  receipt : Receipt

private def loadScheduledLifecycle?
    (path : System.FilePath) : IO (Except String Loam.Persistence.ScheduledLifecycleImage) := do
  if !(← path.pathExists) then
    return .error "loam: Scheduled lifecycle authority is missing; reversal cannot prove relation independence"
  match ← Loam.Persistence.loadScheduledLifecycleImage? path with
  | some image => return .ok image
  | none => return .error "loam: Scheduled lifecycle authority is malformed or unsupported"

/-- Anonymous Effects need no persisted identity token; retained keys still do. -/
private def retainedEffectKeyPersistable (effect : Effect) : Bool :=
  match effect.key with
  | none => true
  | some key => Loam.Persistence.validToken key.token

private def movementEffectsValid (effects : List Effect) : Bool :=
  if effects.isEmpty then false
  else if !effects.all (fun effect =>
      retainedEffectKeyPersistable effect &&
      Loam.Persistence.validToken effect.locus.token &&
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

private def eventIdentityReserved
    (evidence : ActualEvidence) (id : EventId) : Bool :=
  (EventMemory.findById? evidence.events id).isSome ||
    evidence.validity.facts.any (fun fact => decide (fact.event = id)) ||
    (evidence.descriptions.findText? id).isSome ||
    evidence.relations.any (fun relation => decide (relation.sourceEvent = id)) ||
    evidence.discharges.any (fun discharge => decide (discharge.event = id))

private def pendingForTarget?
    (events : EventMemory)
    (memory : ActualReversalMemory)
    (target : EventId) : Except String (Option ActualReversal) :=
  match memory.findByTarget? target with
  | none => .ok none
  | some relation =>
      match EventMemory.findById? events relation.reversal with
      | none => .ok (some relation)
      | some _ => .error "loam: selected Actual is already reversed"

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
  if worldRelationsMentionEvent evidence draft.target then
    throw "loam: reversal of an Actual referenced by retained relation/discharge evidence is not yet qualified"
  if scheduledCompletionMentionsEvent lifecycle draft.target then
    throw "loam: reversal of a Scheduled-completion Actual is not yet qualified"

  let target ← targetCurrent? evidence.events evidence.corrections draft.target
  if !movementEffectsValid target.effects then
    throw "loam: selected Actual is outside the practical balanced-JPY reversal entrance"

  let pending? ← pendingForTarget? evidence.events evidence.reversals draft.target
  let relation ←
    match pending? with
    | some relation => pure relation
    | none =>
        let reversal := deterministicReversalId draft.target
        if eventIdentityReserved evidence reversal then
          throw "loam: deterministic reversal Event identity collides with retained Movement evidence"
        if (evidence.reversals.findByReversal? reversal).isSome then
          throw "loam: deterministic reversal Event identity is already reserved by another reversal"
        pure { target := draft.target, reversal := reversal }

  let effects := inverseEffects target
  if !movementEffectsValid effects then
    throw "loam: exact inverse Effects did not remain one balanced nonzero JPY Movement"
  if !locusAdmission.admitsEffects effects then
    throw "loam: reversal uses a Locus not approved for new publication"
  if (EventMemory.findById? evidence.events relation.reversal).isSome then
    throw "loam: selected Actual is already reversed"

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

  let reversalChanged := pending?.isNone
  let updatedReversals ←
    if reversalChanged then
      match evidence.reversals.add? relation with
      | some memory => pure memory
      | none => throw "loam: reversal relation could not be appended"
    else
      pure evidence.reversals

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
    reversalChanged := reversalChanged
    receipt := {
      target := draft.target
      reversal := relation.reversal
      validOn := draft.validOn
      resumed := !reversalChanged
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

/-- Backward-compatible alias for existing call sites. -/
def publishManifestReversal
    (scheduledPath rootPath _correctionPath _reversalPath : String)
    (draft : Draft) : IO (Except String Receipt) :=
  publishReversal scheduledPath rootPath draft

end Loam.ActualReversalPublisher