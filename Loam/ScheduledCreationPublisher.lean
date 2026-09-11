import Loam.ActualDate
import Loam.Application.ScheduledInspection
import Loam.FreshNumberedToken
import Loam.MovementManifestAuthority
import Loam.Persistence.TokenSyntax
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.ScheduledOccurrenceConstruction
import Loam.WriterOwnership

namespace Loam.ScheduledCreationPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Shared Scheduled creation publication

This module exposes only the surface-independent write boundary needed by
production TUI and later callers.

Creation re-reads the same lifecycle world used by production Scheduled readers
before choosing a fresh Scheduled identity. Observation 226 makes that world one
complete lifecycle image; missing authority no longer means an empty lifecycle.

The fixed ownership order matches other Scheduled publishers:

```text
Scheduled lifecycle authority -> Movement CURRENT
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

private def freshScheduledId?
    (memory : ScheduledMemory String) : Option ScheduledId := do
  let token ← Loam.firstUnusedNumberedToken?
    "scheduled-"
    (fun token => (ScheduledMemory.findById? memory (⟨token⟩ : ScheduledId)).isSome)
    1
    (memory.occurrences.length + 1)
  pure ⟨token⟩

private def validateDraft (draft : Draft) : Except String Unit := do
  if !Loam.ActualDate.validIsoDate draft.scheduledOn then
    throw "loam: Scheduled date must be a real calendar date in YYYY-MM-DD form"
  if !draft.effects.all (fun effect =>
      Loam.Persistence.validToken effect.locus.token &&
      decide (effect.measure = ⟨"jpy"⟩) &&
      effect.quantity.quanta != 0) then
    throw "loam: Scheduled creation requires valid Locus tokens and nonzero JPY quantities"
  let changes : List (MovementChange LocusId) :=
    draft.effects.map fun effect =>
      { coordinate := effect.locus, quantity := effect.quantity }
  if (BalancedMovement.ofChanges? ⟨"jpy"⟩ changes).isNone then
    throw "loam: Scheduled movement totals differ"
  let positive := draft.effects.foldl
    (fun total effect => total + max 0 effect.quantity.quanta) 0
  if positive <= 0 || draft.total != positive then
    throw "loam: Scheduled creation requires a positive total matching the draft"

private def occurrenceFromDraft?
    (id : ScheduledId) (draft : Draft) : Option (ScheduledOccurrence String) := do
  let changes : List (MovementChange LocusId) :=
    draft.effects.map fun effect =>
      { coordinate := effect.locus, quantity := effect.quantity }
  let movement ← BalancedMovement.ofChanges? ⟨"jpy"⟩ changes
  pure { id := id, scheduledOn := draft.scheduledOn, movement := movement }

private theorem freshScheduledId_eq_shared
    (memory : ScheduledMemory String) :
    freshScheduledId? memory =
      Loam.ScheduledOccurrenceConstruction.freshId? memory := rfl

private theorem draftMovement_eq_shared (draft : Draft) :
    (let changes : List (MovementChange LocusId) :=
       draft.effects.map fun effect =>
         { coordinate := effect.locus, quantity := effect.quantity }
     BalancedMovement.ofChanges? ⟨"jpy"⟩ changes) =
      Loam.ScheduledOccurrenceConstruction.movementFromEffects? draft.effects := rfl

private theorem occurrenceFromDraft_eq_shared
    (id : ScheduledId) (draft : Draft) :
    occurrenceFromDraft? id draft =
      Loam.ScheduledOccurrenceConstruction.occurrenceFromEffects?
        id draft.scheduledOn draft.effects := rfl

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
  let world ←
    match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
    | .ok world => pure world
    | .error message => return .error message
  if !world.locusAdmission.admitsEffects draft.effects then
    return .error "loam: Scheduled creation uses a Locus not approved for new publication"
  match lifecycleReadable? lifecycle world.events with
  | .error message => return .error message
  | .ok () => pure ()
  let scheduledId ←
    match freshScheduledId? lifecycle.scheduled with
    | some id => pure id
    | none => return .error "loam: could not generate a fresh Scheduled identity"
  let occurrence ←
    match occurrenceFromDraft? scheduledId draft with
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
    Loam.WriterOwnership.withOwnership (root / "CURRENT") action

/--
Publish one independent Scheduled occurrence into the complete lifecycle image.

The draft carries only date and expected balanced signed JPY effects. Creation does
not imply recurrence, continuation, replacement, routing inheritance, or Actual
evidence. Existing lifecycle evidence must already be readable before a fresh
identity can be admitted. Every Effect must also use the current explicit Locus
admission vocabulary; UI completion remains advisory rather than authoritative.
-/
def publishManifestCreation
    (scheduledPath rootPath : String)
    (draft : Draft) : IO (Except String Receipt) := do
  if scheduledPath.isEmpty then
    return .error "loam: scheduled path must not be empty"
  if rootPath.isEmpty then
    return .error "loam: LOAM_MOVEMENT_MANIFEST_ROOT must not be empty"
  let scheduledFile := System.FilePath.mk scheduledPath
  let root := System.FilePath.mk rootPath
  withCreationOwnership scheduledFile root
    (publishUnderOwnership scheduledFile root draft)

end Loam.ScheduledCreationPublisher
