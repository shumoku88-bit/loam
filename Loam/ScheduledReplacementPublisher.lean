import Loam.ActualAuthority
import Loam.ActualDate
import Loam.ActualEvidence
import Loam.Application.ScheduledInspection
import Loam.LocusAdmissionAuthority
import Loam.Persistence.TokenSyntax
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.ScheduledOccurrenceConstruction
import Loam.WriterOwnership

namespace Loam.ScheduledReplacementPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Shared Scheduled replacement publication

This module exposes the surface-independent write boundary for Scheduled replacement.

The fixed ownership order matches other Scheduled publishers:
```text
Scheduled lifecycle authority -> actual.loam
```
-/

structure Draft where
  source : ScheduledId
  scheduledOn : String
  movement : BalancedMovement LocusId

structure Receipt where
  source : ScheduledId
  replacement : ScheduledId
  scheduledOn : String
  total : Int
  deriving Repr

private def loadLifecycle?
    (scheduledFile : System.FilePath) : IO (Except String Loam.Persistence.ScheduledLifecycleImage) := do
  let some lifecycle ← Loam.Persistence.loadScheduledLifecycleImage? scheduledFile
    | return .error "loam: Scheduled lifecycle authority is missing, malformed, or unsupported"
  return .ok lifecycle

private def currentOpen?
    (lifecycle : Loam.Persistence.ScheduledLifecycleImage)
    (events : EventMemory) : Except String (List (ScheduledOccurrence String)) :=
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
  | .open occurrences => .ok occurrences

private def containsScheduled
    (occurrences : List (ScheduledOccurrence String))
    (target : ScheduledId) : Bool :=
  occurrences.any fun occurrence => decide (occurrence.id = target)

private def validateDraft (draft : Draft) : Except String Unit := do
  if !Loam.ActualDate.validIsoDate draft.scheduledOn then
    throw "loam: Scheduled replacement requires a valid ISO calendar date"
  if draft.movement.measure != ⟨"jpy"⟩ then
    throw "loam: Scheduled replacement requires a JPY movement"
  if draft.movement.changes.isEmpty then
    throw "loam: Scheduled replacement requires at least one movement change"
  if !draft.movement.changes.all (fun change =>
      Loam.Persistence.validToken change.coordinate.token &&
      change.quantity.quanta != 0) then
    throw "loam: Scheduled replacement requires valid Locus tokens and nonzero JPY quantities"
  if Loam.ScheduledOccurrenceConstruction.positiveTotalQuanta draft.movement <= 0 then
    throw "loam: Scheduled replacement requires a positive balanced total"

private def transitionAdmissible?
    (lifecycle : Loam.Persistence.ScheduledLifecycleImage)
    (events : EventMemory)
    (source replacement : ScheduledId) : Except String Unit := do
  let occurrences ← currentOpen? lifecycle events
  if containsScheduled occurrences source then
    throw "loam: proposed Scheduled replacement did not close its source"
  if !containsScheduled occurrences replacement then
    throw "loam: proposed Scheduled replacement did not expose its replacement as current-open"

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
  if !draft.movement.changes.all (fun change =>
      locusAdmission.allows change.coordinate) then
    return .error "loam: Scheduled replacement uses a Locus not approved for new publication"
  if (ScheduledMemory.findById? lifecycle.scheduled draft.source).isNone then
    return .error "loam: selected Scheduled identity is not retained"
  if (lifecycle.terminals.replacementFor? draft.source).isSome then
    return .error "loam: selected Scheduled identity is already replaced"
  let openOccurrences ←
    match currentOpen? lifecycle evidence.events with
    | .ok occurrences => pure occurrences
    | .error message => return .error message
  if !containsScheduled openOccurrences draft.source then
    return .error "loam: only a currently open Scheduled identity can be replaced"
  let replacementId ←
    match Loam.ScheduledOccurrenceConstruction.freshId? lifecycle.scheduled with
    | some id => pure id
    | none => return .error "loam: could not generate a fresh replacement Scheduled identity"
  let occurrence : ScheduledOccurrence String := {
    id := replacementId
    scheduledOn := draft.scheduledOn
    movement := draft.movement
  }
  let updatedScheduled ←
    match lifecycle.scheduled.add? occurrence with
    | some scheduled => pure scheduled
    | none => return .error "loam: replacement Scheduled identity collides with retained evidence"
  let relation : ScheduledTerminal := {
    source := draft.source
    target := some (.scheduled replacementId)
  }
  let updatedTerminals ←
    match lifecycle.terminals.add? relation with
    | some terminals => pure terminals
    | none => return .error "loam: replacement relation violates one-to-one endpoint ownership"
  let updatedLifecycle := {
    lifecycle with
    scheduled := updatedScheduled
    terminals := updatedTerminals
  }
  match transitionAdmissible?
      updatedLifecycle evidence.events draft.source replacementId with
  | .error message => return .error message
  | .ok () => pure ()
  if (Loam.Persistence.encodeScheduledLifecycleImage? updatedLifecycle).isNone then
    return .error "loam: Scheduled replacement lifecycle could not be encoded"
  if !(← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile updatedLifecycle) then
    return .error "loam: Scheduled replacement lifecycle could not be published"
  return .ok {
    source := draft.source
    replacement := replacementId
    scheduledOn := draft.scheduledOn
    total := Loam.ScheduledOccurrenceConstruction.positiveTotalQuanta draft.movement
  }

private def withReplacementOwnership {α : Type}
    (scheduledFile root : System.FilePath)
    (action : IO (Except String α)) : IO (Except String α) :=
  Loam.WriterOwnership.withOwnership scheduledFile <|
    Loam.ActualAuthority.withActualOwnership root action

/--
Publish one Scheduled replacement into the complete lifecycle image.
-/
def publishReplacement
    (scheduledPath rootPath : String)
    (draft : Draft) : IO (Except String Receipt) := do
  if scheduledPath.isEmpty then
    return .error "loam: scheduled path must not be empty"
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let scheduledFile := System.FilePath.mk scheduledPath
  let root := System.FilePath.mk rootPath
  withReplacementOwnership scheduledFile root
    (publishUnderOwnership scheduledFile root draft)


end Loam.ScheduledReplacementPublisher
