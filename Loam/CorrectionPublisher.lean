import Loam.Application.ActualValidityFrontier
import Loam.Application.CorrectionFrontier
import Loam.Core.BalancedMovement
import Loam.FreshNumberedToken
import Loam.MovementManifestAuthority
import Loam.Persistence.EventCorrectionPersistence
import Loam.Persistence.TokenSyntax
import Loam.Persistence.ActualReversalPersistence
import Loam.WriterOwnership

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
  carriedDate : Bool
  publishedDescription : Bool
  resumed : Bool
  deriving Repr

private structure Admitted where
  world : Loam.MovementAdmission.World
  corrections : EventCorrectionMemory
  correctionChanged : Bool
  receipt : Receipt

/-- Missing Reversal authority is not absence-as-empty. -/
private def loadReversals?
    (path : System.FilePath) : IO (Except String ActualReversalMemory) := do
  if !(← path.pathExists) then
    return .error "loam: Actual reversal authority is missing; Correction cannot prove reversal independence"
  match ← Loam.Persistence.loadActualReversalMemory? path with
  | some memory => return .ok memory
  | none => return .error "loam: Actual reversal authority is malformed or unsupported"

private def correctionMentionsEvent
    (corrections : EventCorrectionMemory) (id : EventId) : Bool :=
  corrections.corrections.any fun correction =>
    decide (correction.target = id) || decide (correction.replacement = id)

private def reversalMentionsEvent
    (reversals : ActualReversalMemory) (id : EventId) : Bool :=
  (reversals.findByTarget? id).isSome || (reversals.findByReversal? id).isSome

private def historyMentionsEvent
    (history : ActualValidityHistory String) (id : EventId) : Bool :=
  history.facts.any fun fact => decide (fact.event = id)

private def descriptionsMentionEvent
    (descriptions : EventDescriptionMemory) (id : EventId) : Bool :=
  (descriptions.findText? id).isSome

private def relationsMentionEvent
    (world : Loam.MovementAdmission.World) (id : EventId) : Bool :=
  world.relations.any (fun relation => decide (relation.sourceEvent = id)) ||
    world.discharges.any (fun discharge => decide (discharge.event = id))

private def eventIdentityReserved
    (world : Loam.MovementAdmission.World)
    (corrections : EventCorrectionMemory)
    (reversals : ActualReversalMemory)
    (id : EventId) : Bool :=
  (EventMemory.findById? world.events id).isSome ||
    historyMentionsEvent world.validity id ||
    descriptionsMentionEvent world.descriptions id ||
    relationsMentionEvent world id ||
    correctionMentionsEvent corrections id ||
    reversalMentionsEvent reversals id

private def freshReplacementId?
    (world : Loam.MovementAdmission.World)
    (corrections : EventCorrectionMemory)
    (reversals : ActualReversalMemory) : Option EventId := do
  let token ← Loam.firstUnusedNumberedToken?
    "replacement-"
    (fun token => eventIdentityReserved world corrections reversals (⟨token⟩ : EventId))
    1
    (world.events.events.length + world.validity.facts.length +
      world.descriptions.entries.length + world.relations.length +
      world.discharges.length + 2 * corrections.corrections.length +
      2 * reversals.reversals.length + 1)
  pure ⟨token⟩

private def currentFactForEvent?
    (facts : List (ActualValidityFact String)) (event : EventId) :
    Option (ActualValidityFact String) :=
  facts.find? fun fact => decide (fact.event = event)

private def targetingCorrections
    (corrections : EventCorrectionMemory) (target : EventId) : List EventCorrection :=
  corrections.corrections.filter fun correction => decide (correction.target = target)

private def pendingCorrectionForTarget?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (target : EventId) : Except String (Option EventCorrection) :=
  match targetingCorrections corrections target with
  | [] => .ok none
  | [correction] =>
      match EventMemory.findById? events correction.replacement with
      | none => .ok (some correction)
      | some _ => .error "loam: selected Actual already has a published replacement"
  | _ =>
      .error "loam: multiple correction relations target the selected Actual; no retry winner is implied"

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
    | none => throw "loam: selected correction target is not retained"
  match Loam.Application.correctionFrontierMemory? events corrections with
  | none => throw "loam: movement corrections do not justify one current record frontier"
  | some frontier =>
      match EventMemory.findById? frontier target with
      | some _ => pure targetEvent
      | none => throw "loam: selected Actual is no longer current"

private def ensureReplacementValidity?
    (history : ActualValidityHistory String)
    (currentFacts : List (ActualValidityFact String))
    (targetFact? : Option (ActualValidityFact String))
    (replacement : EventId) : Except String (ActualValidityHistory String × Bool) := do
  let replacementFact? := currentFactForEvent? currentFacts replacement
  match targetFact?, replacementFact? with
  | none, none => pure (history, false)
  | none, some _ =>
      throw "loam: replacement already has occurrence-date evidence unrelated to the selected Actual"
  | some targetFact, some replacementFact =>
      if replacementFact.validOn = targetFact.validOn then
        pure (history, false)
      else
        throw "loam: replacement occurrence-date evidence conflicts with the selected Actual"
  | some targetFact, none =>
      match history.addFact? (.base replacement targetFact.validOn) with
      | some updated => pure (updated, true)
      | none => throw "loam: could not append replacement occurrence-date evidence"

private def appendDescription?
    (descriptions : EventDescriptionMemory)
    (replacement : EventId)
    (description : Option String) : Except String (EventDescriptionMemory × Bool) := do
  if (descriptions.findText? replacement).isSome then
    throw "loam: replacement identity already has retained description evidence"
  match description with
  | none => pure (descriptions, false)
  | some text =>
      match EventDescriptionMemory.ofEntries?
          (descriptions.entries ++ [{ event := replacement, text := text }]) with
      | some descriptions => pure (descriptions, true)
      | none => throw "loam: could not append replacement description"

private def admit?
    (world : Loam.MovementAdmission.World)
    (corrections : EventCorrectionMemory)
    (reversals : ActualReversalMemory)
    (draft : Draft) : Except String Admitted := do
  if !movementEffectsValid draft.effects then
    throw "loam: correction replacement must be one balanced nonzero JPY Movement"
  if !world.locusAdmission.admitsEffects draft.effects then
    throw "loam: correction replacement uses a Locus not approved for new publication"
  let rawTarget ←
    match EventMemory.findById? world.events draft.target with
    | some event => pure event
    | none => throw "loam: selected correction target is not retained"
  if !movementEffectsValid rawTarget.effects then
    throw "loam: selected Actual is outside the practical balanced-JPY correction entrance"
  if relationsMentionEvent world draft.target then
    throw "loam: correction of an Event already referenced by relation/discharge evidence is not yet qualified"
  if reversalMentionsEvent reversals draft.target then
    throw "loam: correction of an Actual participating in Reversal evidence is not yet qualified"

  let currentFacts ←
    match Loam.Application.admittedActualValidityFacts? world.validity with
    | some facts => pure facts
    | none => throw "loam: actual-validity corrections do not justify one current date per Event"

  let pending? ← pendingCorrectionForTarget? world.events corrections draft.target
  let correction ←
    match pending? with
    | some correction => pure correction
    | none =>
        let _ ← targetCurrent? world.events corrections draft.target
        let replacement ←
          match freshReplacementId? world corrections reversals with
          | some id => pure id
          | none => throw "loam: could not generate a fresh replacement Event identity"
        pure { target := draft.target, replacement := replacement }

  if correction.target != draft.target then
    throw "loam: internal correction target mismatch"
  if (EventMemory.findById? world.events correction.replacement).isSome then
    throw "loam: selected Actual already has a published replacement"
  if descriptionsMentionEvent world.descriptions correction.replacement ||
      relationsMentionEvent world correction.replacement ||
      reversalMentionsEvent reversals correction.replacement then
    throw "loam: replacement identity collides with retained non-Event evidence"

  let replacement ←
    match Event.ofEffects? correction.replacement draft.effects with
    | some event => pure event
    | none => throw "loam: replacement Effect identities are not unique"
  let updatedEvents ←
    match EventMemory.add? world.events replacement with
    | some events => pure events
    | none => throw "loam: replacement Event could not be appended"
  let correctionChanged := pending?.isNone
  let updatedCorrections ←
    if correctionChanged then
      match corrections.add? correction with
      | some memory => pure memory
      | none => throw "loam: correction relation could not be appended"
    else
      pure corrections

  let frontier ←
    match Loam.Application.correctionFrontierMemory? updatedEvents updatedCorrections with
    | some memory => pure memory
    | none => throw "loam: proposed correction does not justify one current record frontier"
  if (EventMemory.findById? frontier correction.replacement).isNone ||
      (EventMemory.findById? frontier correction.target).isSome then
    throw "loam: proposed correction frontier did not select exactly the replacement"

  let targetFact? := currentFactForEvent? currentFacts draft.target
  let (updatedValidity, carriedDate) ←
    ensureReplacementValidity? world.validity currentFacts targetFact? correction.replacement
  let (updatedDescriptions, publishedDescription) ←
    appendDescription? world.descriptions correction.replacement draft.description

  pure {
    world := {
      events := updatedEvents
      validity := updatedValidity
      descriptions := updatedDescriptions
      relations := world.relations
      discharges := world.discharges
      locusAdmission := world.locusAdmission
    }
    corrections := updatedCorrections
    correctionChanged := correctionChanged
    receipt := {
      target := draft.target
      replacement := correction.replacement
      carriedDate := carriedDate
      publishedDescription := publishedDescription
      resumed := !correctionChanged
    }
  }

private def publishUnderOwnership
    (root correctionFile : System.FilePath)
    (draft : Draft) : IO (Except String Receipt) := do
  let world ←
    match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
    | .ok world => pure world
    | .error message => return .error message
  let corrections ←
    match ← Loam.Persistence.loadEventCorrectionMemoryOrEmpty? correctionFile with
    | some memory => pure memory
    | none => return .error "loam: malformed or unsupported correction-memory file"
  let reversalFile := correctionFile.withFileName "actual-reversals.loam"
  let reversals ←
    match ← loadReversals? reversalFile with
    | .ok memory => pure memory
    | .error message => return .error message
  let admitted ←
    match admit? world corrections reversals draft with
    | .ok admitted => pure admitted
    | .error message => return .error message

  let prepared ←
    match ← Loam.MovementManifestAuthority.prepareWorld? root admitted.world with
    | .ok prepared => pure prepared
    | .error message => return .error message
  if admitted.correctionChanged then
    if !(← Loam.Persistence.saveEventCorrectionMemory? correctionFile admitted.corrections) then
      return .error "loam: correction relation could not be published"
  match ← Loam.MovementManifestAuthority.commitPrepared? root prepared with
  | .error message => return .error message
  | .ok () => return .ok admitted.receipt

/--
Publish one practical Movement correction against current manifest authority.

The publisher re-reads selected Movement, Correction, and the explicit complete
`actual-reversals.loam` sibling of the configured Correction authority while
holding Movement `CURRENT`. Missing/malformed Reversal authority fails closed.
An Actual named as either Reversal target or inverse cannot be corrected until
inheritance semantics are separately qualified.
-/
def publishManifestCorrection
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

end Loam.CorrectionPublisher