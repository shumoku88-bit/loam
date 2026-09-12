import Loam.ActualAuthority
import Loam.ActualDate
import Loam.ActualEvidence
import Loam.Application.ScheduledInspection
import Loam.LocusAdmissionAuthority
import Loam.Persistence.TokenSyntax
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.ScheduledOccurrenceConstruction
import Loam.WriterOwnership

namespace Loam.ScheduledCreationPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Shared Scheduled creation publication

This module exposes the surface-independent write boundary for Scheduled creation.

The fixed ownership order matches other Scheduled publishers:
```text
Scheduled lifecycle authority -> actual.loam
```
-/

structure Draft where
  scheduledOn : String
  effects : List Effect
  total : Int

structure Receipt where
  scheduled : ScheduledId
  scheduledOn : String
  total : Int
  deriving Repr

private def loadLifecycle?
    (scheduledFile : System.FilePath) : IO (Except String Loam.Persistence.ScheduledLifecycleImage) := do
  let some lifecycle ← Loam.Persistence.loadScheduledLifecycleImage? scheduledFile
    | return .error "loam: Scheduled lifecycle authority is missing, malformed, or unsupported"
  return .ok lifecycle

private def lifecycleReadable?
    (lifecycle : Loam.Persistence.ScheduledLifecycleImage)
    (events : EventMemory) : Except String Unit :=
  match Loam.Application.currentOpenScheduled
      lifecycle.scheduled lifecycle.terminals events with
  | .unknownCompletionScheduled =>
      .error "loam: Scheduled completion refers to an unknown Scheduled identity"
  | .unknownRetirementScheduled =>
      .error "loam: Scheduled retirement refers to an unknown Scheduled identity"
  | .unknownReplacementScheduled =>
      .error "loam: Scheduled replacement refers to an unknown Scheduled identity"
  | .invalidReplacementGraph =>
      .error "loam: Scheduled replacement graph is cyclic or otherwise invalid"
  | .conflictingTerminalEvidence =>
      .error "loam: Scheduled terminal evidence conflicts across completion, retirement, or replacement"
  | .open _ => .ok ()

/-- Anonymous Effects need no persisted identity token; retained keys still do. -/
private def retainedEffectKeyPersistable (effect : Effect) : Bool :=
  match effect.key with
  | none => true
  | some key => Loam.Persistence.validToken key.token

private def validateDraft (draft : Draft) : Except String Unit := do
  if !Loam.ActualDate.validIsoDate draft.scheduledOn then
    throw "loam: Scheduled creation requires a valid ISO calendar date"
  if draft.effects.isEmpty then
    throw "loam: Scheduled creation requires at least one Effect"
  if !draft.effects.all (fun effect =>
      retainedEffectKeyPersistable effect &&
      Loam.Persistence.validToken effect.locus.token &&
      decide (effect.measure = ⟨"jpy"⟩) &&
      effect.quantity.quanta != 0) then
    throw "loam: Scheduled creation requires valid Locus tokens and nonzero JPY quantities"
  if (Loam.ScheduledOccurrenceConstruction.movementFromEffects? draft.effects).isNone then
    throw "loam: Scheduled movement totals differ"
  let positive := draft.effects.foldl
    (fun total effect => total + max 0 effect.quantity.quanta) 0
  if positive <= 0 || draft.total != positive then
    throw "loam: Scheduled creation requires a positive total matching the draft"

private def publishUnderOwnership
    (scheduledFile root : System.FilePath)
    (draft : Draft) : IO (Except String Receipt) := do
  match validateDraft draft with
  | .error message => return .error message
  | .ok () => pure ()
  let lifecycle ←
    match ← loadLifecycle? scheduledFile with
    | .ok lifecycle => pure lifecycle
    | .error message => return .error message
  let evidence ←
    match ← Loam.ActualAuthority.loadActual? root with
    | .ok ev => pure ev
    | .error message => return .error message
  let locusAdmission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? root with
    | .ok la => pure la
    | .error message => return .error message
  if !locusAdmission.admitsEffects draft.effects then
    return .error "loam: Scheduled creation uses a Locus not approved for new publication"
  match lifecycleReadable? lifecycle evidence.events with
  | .error message => return .error message
  | .ok () => pure ()
  let scheduledId ←
    match Loam.ScheduledOccurrenceConstruction.freshId? lifecycle.scheduled with
    | some id => pure id
    | none => return .error "loam: could not generate a fresh Scheduled identity"
  let occurrence ←
    match Loam.ScheduledOccurrenceConstruction.occurrenceFromEffects?
        scheduledId draft.scheduledOn draft.effects with
    | some occurrence => pure occurrence
    | none => return .error "loam: Scheduled movement could not be admitted"
  let updatedScheduled ←
    match lifecycle.scheduled.add? occurrence with
    | some scheduled => pure scheduled
    | none => return .error "loam: generated Scheduled identity already retained"
  let updatedLifecycle := { lifecycle with scheduled := updatedScheduled }
  if (Loam.Persistence.encodeScheduledLifecycleImage? updatedLifecycle).isNone then
    return .error "loam: Scheduled lifecycle could not be encoded"
  if !(← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile updatedLifecycle) then
    return .error "loam: Scheduled lifecycle could not be published"
  return .ok {
    scheduled := scheduledId
    scheduledOn := draft.scheduledOn
    total := draft.total
  }

private def withCreationOwnership {α : Type}
    (scheduledFile root : System.FilePath)
    (action : IO (Except String α)) : IO (Except String α) :=
  Loam.WriterOwnership.withOwnership scheduledFile <|
    Loam.ActualAuthority.withActualOwnership root action

/--
Publish one independent Scheduled occurrence into the complete lifecycle image.
-/
def publishCreation
    (scheduledPath rootPath : String)
    (draft : Draft) : IO (Except String Receipt) := do
  if scheduledPath.isEmpty then
    return .error "loam: scheduled path must not be empty"
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let scheduledFile := System.FilePath.mk scheduledPath
  let root := System.FilePath.mk rootPath
  withCreationOwnership scheduledFile root
    (publishUnderOwnership scheduledFile root draft)

end Loam.ScheduledCreationPublisher
