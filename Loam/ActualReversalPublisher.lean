import Loam.ActualDate
import Loam.Application.ActualValidityFrontier
import Loam.Application.CorrectionFrontier
import Loam.Core.ActualReversal
import Loam.Core.BalancedMovement
import Loam.MovementManifestAuthority
import Loam.Persistence
import Loam.Persistence.ActualReversalPersistence
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.WriterOwnership

namespace Loam.ActualReversalPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Actual reversal publication

A reversal is two retained facts:

1. an ordinary Actual Event whose Effects are the exact additive inverse of one
   selected current Actual; and
2. an explicit `ActualReversal` relation naming the cancelled target.

The relation is published before the prepared Movement generation becomes
selected. Therefore interruption may leave one inert dangling relation, but it
never exposes an unlinked inverse Movement. A retry reuses that retained reversal
Event identity and can complete publication.

This is deliberately distinct from `EventCorrection`: correction changes the
current interpretation frontier, while reversal preserves both real occurrences
in physical quantity accumulation.
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
  world : Loam.MovementAdmission.World
  reversals : ActualReversalMemory
  reversalChanged : Bool
  receipt : Receipt

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

private def loadReversals?
    (path : System.FilePath) : IO (Except String ActualReversalMemory) := do
  if !(← path.pathExists) then
    return .error "loam: Actual reversal authority is missing; initialize an explicit empty authority before reversal"
  match ← Loam.Persistence.loadActualReversalMemory? path with
  | some memory => return .ok memory
  | none => return .error "loam: Actual reversal authority is malformed or unsupported"

private def loadScheduledLifecycle?
    (path : System.FilePath) : IO (Except String Loam.Persistence.ScheduledLifecycleImage) := do
  if !(← path.pathExists) then
    return .error "loam: Scheduled lifecycle authority is missing; reversal cannot prove relation independence"
  match ← Loam.Persistence.loadScheduledLifecycleImage? path with
  | some image => return .ok image
  | none => return .error "loam: Scheduled lifecycle authority is malformed or unsupported"

private def movementEffectsValid (effects : List Effect) : Bool :=
  if effects.isEmpty then false
  else if !effects.all (fun effect =>
      Loam.Persistence.validToken effect.key.token &&
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
    (world : Loam.MovementAdmission.World) (event : EventId) : Bool :=
  world.relations.any (fun relation => decide (relation.sourceEvent = event)) ||
    world.discharges.any (fun discharge => decide (discharge.event = event))

private def scheduledCompletionMentionsEvent
    (lifecycle : Loam.Persistence.ScheduledLifecycleImage) (event : EventId) : Bool :=
  lifecycle.completions.completions.any fun completion => decide (completion.actual = event)

private def deterministicReversalId (target : EventId) : EventId :=
  ⟨"actual-reversal:" ++ target.token⟩

private def deterministicValidityId (target : EventId) : ActualValidityFactId :=
  ⟨"actual-reversal-validity:" ++ target.token⟩

private def inverseEffects (reversal : EventId) (target : Event) : List Effect :=
  target.effects.zipIdx.map fun (effect, index) =>
    Effect.ofQuantity
      ⟨reversal.token ++ "-effect-" ++ toString (index + 1)⟩
      effect.locus effect.measure (-effect.quantity)

private def eventIdentityReserved
    (world : Loam.MovementAdmission.World) (id : EventId) : Bool :=
  (EventMemory.findById? world.events id).isSome ||
    world.validity.facts.any (fun fact => decide (fact.event = id)) ||
    (world.descriptions.findText? id).isSome ||
    world.relations.any (fun relation => decide (relation.sourceEvent = id)) ||
    world.discharges.any (fun discharge => decide (discharge.event = id))

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
    (world : Loam.MovementAdmission.World)
    (corrections : EventCorrectionMemory)
    (lifecycle : Loam.Persistence.ScheduledLifecycleImage)
    (reversals : ActualReversalMemory)
    (draft : Draft) : Except String Admitted := do
  if !Loam.ActualDate.validIsoDate draft.validOn then
    throw "loam: reversal occurrence date must be a real YYYY-MM-DD calendar date"
  if !Loam.Persistence.validToken draft.target.token then
    throw "loam: reversal target identity is not persistable"
  if (reversals.findByReversal? draft.target).isSome then
    throw "loam: reversal-of-reversal chains are not yet qualified"
  if worldRelationsMentionEvent world draft.target then
    throw "loam: reversal of an Actual referenced by retained relation/discharge evidence is not yet qualified"
  if scheduledCompletionMentionsEvent lifecycle draft.target then
    throw "loam: reversal of a Scheduled-completion Actual is not yet qualified"

  let target ← targetCurrent? world.events corrections draft.target
  if !movementEffectsValid target.effects then
    throw "loam: selected Actual is outside the practical balanced-JPY reversal entrance"

  let pending? ← pendingForTarget? world.events reversals draft.target
  let relation ←
    match pending? with
    | some relation => pure relation
    | none =>
        let reversal := deterministicReversalId draft.target
        if eventIdentityReserved world reversal then
          throw "loam: deterministic reversal Event identity collides with retained Movement evidence"
        if (reversals.findByReversal? reversal).isSome then
          throw "loam: deterministic reversal Event identity is already reserved by another reversal"
        pure { target := draft.target, reversal := reversal }

  let effects := inverseEffects relation.reversal target
  if !movementEffectsValid effects then
    throw "loam: exact inverse Effects did not remain one balanced nonzero JPY Movement"
  if !world.locusAdmission.admitsEffects effects then
    throw "loam: reversal uses a Locus not approved for new publication"
  if (EventMemory.findById? world.events relation.reversal).isSome then
    throw "loam: selected Actual is already reversed"

  let event ←
    match Event.ofEffects? relation.reversal effects with
    | some event => pure event
    | none => throw "loam: reversal Effect identities are not unique"
  let events ←
    match EventMemory.add? world.events event with
    | some events => pure events
    | none => throw "loam: reversal Event could not be appended"

  let factId := deterministicValidityId draft.target
  if (world.validity.findFactById? factId).isSome then
    throw "loam: reversal occurrence-date identity already exists"
  let validity ←
    match world.validity.addFact? {
        id := factId, event := relation.reversal, validOn := draft.validOn } with
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
      match reversals.add? relation with
      | some memory => pure memory
      | none => throw "loam: reversal relation could not be appended"
    else
      pure reversals

  pure {
    world := {
      events := events
      validity := validity
      descriptions := world.descriptions
      relations := world.relations
      discharges := world.discharges
      locusAdmission := world.locusAdmission }
    reversals := updatedReversals
    reversalChanged := reversalChanged
    receipt := {
      target := draft.target
      reversal := relation.reversal
      validOn := draft.validOn
      resumed := !reversalChanged }
  }

private def publishUnderOwnership
    (scheduledFile root correctionFile reversalFile : System.FilePath)
    (draft : Draft) : IO (Except String Receipt) := do
  let world ←
    match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
    | .ok world => pure world
    | .error message => return .error message
  let corrections ←
    match ← loadCorrectionsOrEmpty? correctionFile with
    | .ok memory => pure memory
    | .error message => return .error message
  let lifecycle ←
    match ← loadScheduledLifecycle? scheduledFile with
    | .ok image => pure image
    | .error message => return .error message
  let reversals ←
    match ← loadReversals? reversalFile with
    | .ok memory => pure memory
    | .error message => return .error message
  let admitted ←
    match admit? world corrections lifecycle reversals draft with
    | .ok admitted => pure admitted
    | .error message => return .error message

  let prepared ←
    match ← Loam.MovementManifestAuthority.prepareWorld? root admitted.world with
    | .ok prepared => pure prepared
    | .error message => return .error message

  -- Relation first: a dangling reversal relation is inert until the named
  -- inverse Event is selected, while an inverse Event without provenance would
  -- already change balances and lose the reason it exists.
  if admitted.reversalChanged then
    if !(← Loam.Persistence.saveActualReversalMemory? reversalFile admitted.reversals) then
      return .error "loam: Actual reversal relation could not be published"
  match ← Loam.MovementManifestAuthority.commitPrepared? root prepared with
  | .error message => return .error message
  | .ok () => return .ok admitted.receipt

/--
Publish one explicit Actual reversal.

Lock order is `Scheduled lifecycle -> Movement CURRENT`, matching Scheduled
terminal publication. The current Movement lock also serializes this reversal
sidecar with every Movement mutation. The publisher re-reads correction,
Scheduled-completion, reversal, and Movement evidence under that window and
fails closed when a selected target participates in semantics whose reversal
behavior has not yet been qualified.
-/
def publishManifestReversal
    (scheduledPath rootPath correctionPath reversalPath : String)
    (draft : Draft) : IO (Except String Receipt) := do
  if scheduledPath.isEmpty then
    return .error "loam: scheduled path must not be empty"
  if rootPath.isEmpty then
    return .error "loam: LOAM_MOVEMENT_MANIFEST_ROOT must not be empty"
  if correctionPath.isEmpty then
    return .error "loam: correction path must not be empty"
  if reversalPath.isEmpty then
    return .error "loam: reversal authority path must not be empty"
  let scheduledFile := System.FilePath.mk scheduledPath
  let root := System.FilePath.mk rootPath
  let correctionFile := System.FilePath.mk correctionPath
  let reversalFile := System.FilePath.mk reversalPath
  Loam.WriterOwnership.withOwnership scheduledFile <|
    Loam.WriterOwnership.withOwnership (root / "CURRENT")
      (publishUnderOwnership scheduledFile root correctionFile reversalFile draft)

end Loam.ActualReversalPublisher
