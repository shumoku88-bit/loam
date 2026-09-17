import Loam.ActualAuthority
import Loam.ActualDate
import Loam.ActualEvidence
import Loam.Application.ScheduledInspection
import Loam.LocusAdmissionAuthority
import Loam.Persistence.TokenSyntax
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.ScheduledActualOwnership
import Loam.ScheduledOccurrenceConstruction

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
  movement : BalancedMovement LocusId

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

private def validateDraft (draft : Draft) : Except String Unit := do
  if !Loam.ActualDate.validIsoDate draft.scheduledOn then
    throw "loam: Scheduled creation requires a valid ISO calendar date"
  if draft.movement.measure != ⟨"jpy"⟩ then
    throw "loam: Scheduled creation requires a JPY movement"
  if draft.movement.changes.isEmpty then
    throw "loam: Scheduled creation requires at least one movement change"
  if !draft.movement.changes.all (fun change =>
      Loam.Persistence.validToken change.coordinate.token &&
      change.quantity.quanta != 0) then
    throw "loam: Scheduled creation requires valid Locus tokens and nonzero JPY quantities"

private def publishUnderOwnership
    (scheduledFile root : System.FilePath)
    (draft : Draft) : IO (Except String ScheduledId) := do
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
  if !draft.movement.changes.all (fun change =>
      locusAdmission.allows change.coordinate) then
    return .error "loam: Scheduled creation uses a Locus not approved for new publication"
  match lifecycleReadable? lifecycle evidence.events with
  | .error message => return .error message
  | .ok () => pure ()
  let scheduledId :=
    Loam.ScheduledOccurrenceConstruction.freshId lifecycle.scheduled
  let occurrence : ScheduledOccurrence String := {
    id := scheduledId
    scheduledOn := draft.scheduledOn
    movement := draft.movement
  }
  let updatedScheduled := ScheduledMemory.addFresh lifecycle.scheduled occurrence (by
    change scheduledId ∉ lifecycle.scheduled.occurrences.map ScheduledOccurrence.id
    exact Loam.ScheduledOccurrenceConstruction.freshId_fresh lifecycle.scheduled)
  let updatedLifecycle := { lifecycle with scheduled := updatedScheduled }
  if !(← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile updatedLifecycle) then
    return .error "loam: Scheduled lifecycle could not be published"
  return .ok scheduledId

/--
Publish one independent Scheduled occurrence into the complete lifecycle image.
-/
def publishCreation
    (scheduledPath rootPath : String)
    (draft : Draft) : IO (Except String ScheduledId) := do
  if scheduledPath.isEmpty then
    return .error "loam: scheduled path must not be empty"
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let scheduledFile := System.FilePath.mk scheduledPath
  let root := System.FilePath.mk rootPath
  Loam.ScheduledActualOwnership.withOwnership scheduledFile root
    (publishUnderOwnership scheduledFile root draft)

end Loam.ScheduledCreationPublisher
