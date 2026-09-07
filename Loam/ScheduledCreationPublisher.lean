import Loam.ActualDate
import Loam.Application.ScheduledInspection
import Loam.MovementManifestAuthority
import Loam.Persistence
import Loam.Persistence.ScheduledCompletionPersistence
import Loam.Persistence.ScheduledPersistence
import Loam.Persistence.ScheduledReplacementPersistence
import Loam.Persistence.ScheduledRetirementPersistence
import Loam.WriterOwnership

namespace Loam.ScheduledCreationPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Shared Scheduled creation publication

The legacy Scheduled CLI owns both prompting and persistence. This module exposes
only the surface-independent write boundary needed by production TUI and later
callers.

Creation re-reads the same replacement-aware lifecycle world used by production
Scheduled readers before choosing a fresh Scheduled identity. This prevents a new
occurrence from accidentally making orphan terminal evidence appear valid merely
by recycling the referenced identity.

The fixed ownership order matches other Scheduled publishers:

```text
Scheduled authority -> Movement CURRENT
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

private structure LifecycleState where
  scheduled : ScheduledMemory String
  completions : ScheduledCompletionMemory
  retirements : ScheduledRetirementMemory
  replacements : ScheduledReplacementMemory

private def loadScheduledMemoryOrEmpty?
    (path : System.FilePath) : IO (Option (ScheduledMemory String)) := do
  if ← path.pathExists then
    Loam.Persistence.loadScheduledMemory? path
  else
    return ScheduledMemory.ofOccurrences? []

private def loadLifecycle?
    (scheduledFile : System.FilePath) : IO (Except String LifecycleState) := do
  let some scheduled ← loadScheduledMemoryOrEmpty? scheduledFile
    | return .error "loam: malformed or unsupported scheduled file"
  let completionFile :=
    Loam.Persistence.scheduledCompletionPathForScheduledMemory scheduledFile
  let retirementFile :=
    Loam.Persistence.scheduledRetirementPathForScheduledMemory scheduledFile
  let replacementFile :=
    Loam.Persistence.scheduledReplacementPathForScheduledMemory scheduledFile
  let some completions ←
      Loam.Persistence.loadScheduledCompletionMemoryOrEmpty? completionFile
    | return .error "loam: malformed or unsupported scheduled-completion file"
  let some retirements ←
      Loam.Persistence.loadScheduledRetirementMemoryOrEmpty? retirementFile
    | return .error "loam: malformed or unsupported scheduled-retirement file"
  let some replacements ←
      Loam.Persistence.loadScheduledReplacementMemoryOrEmpty? replacementFile
    | return .error "loam: malformed or unsupported scheduled-replacement file"
  return .ok { scheduled, completions, retirements, replacements }

private def lifecycleReadable?
    (lifecycle : LifecycleState)
    (events : EventMemory) : Except String Unit :=
  match Loam.Application.currentOpenScheduledWithReplacement
      lifecycle.scheduled lifecycle.completions lifecycle.retirements
      lifecycle.replacements events with
  | .unknownCompletionScheduled =>
      .error "loam: scheduled-completion file refers to an unknown Scheduled identity"
  | .unknownRetirementScheduled =>
      .error "loam: scheduled-retirement file refers to an unknown Scheduled identity"
  | .unknownReplacementScheduled =>
      .error "loam: scheduled-replacement file refers to an unknown Scheduled identity"
  | .invalidReplacementGraph =>
      .error "loam: scheduled-replacement graph is cyclic or otherwise invalid"
  | .conflictingTerminalEvidence =>
      .error "loam: Scheduled terminal evidence conflicts across completion, retirement, or replacement"
  | .open _ => .ok ()

private def freshScheduledIdFrom
    (memory : ScheduledMemory String) : Nat → Nat → Option ScheduledId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : ScheduledId := ⟨"scheduled-" ++ toString index⟩
      match ScheduledMemory.findById? memory candidate with
      | none => some candidate
      | some _ => freshScheduledIdFrom memory (index + 1) fuel

private def freshScheduledId?
    (memory : ScheduledMemory String) : Option ScheduledId :=
  freshScheduledIdFrom memory 1 (memory.occurrences.length + 1)

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
  let updated ←
    match lifecycle.scheduled.add? occurrence with
    | some scheduled => pure scheduled
    | none => return .error "loam: generated Scheduled identity already retained"
  if (Loam.Persistence.encodeScheduledMemory? updated).isNone then
    return .error "loam: Scheduled movement could not be encoded"
  if !(← Loam.Persistence.saveScheduledMemory? scheduledFile updated) then
    return .error "loam: Scheduled movement could not be published"
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
Publish one independent Scheduled occurrence.

The draft carries only date and expected balanced signed JPY effects. Creation does
not imply recurrence, continuation, replacement, routing inheritance, or Actual
evidence. Existing lifecycle evidence must already be readable before a fresh
identity can be admitted.
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
