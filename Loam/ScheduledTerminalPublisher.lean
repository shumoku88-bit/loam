import Loam.ActualAuthority
import Loam.ActualEvidence
import Loam.Application.ScheduledInspection
import Loam.LocusAdmissionAuthority
import Loam.MovementAdmission
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.ScheduledActualOwnership
import Loam.SparseEffectIdentity

namespace Loam.ScheduledTerminalPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Shared Scheduled terminal publication

Scheduled lifecycle evidence remains one complete Scheduled authority image while
Actual Events remain in normalized Actual authority (`actual.loam`). Completion and
cancellation retain different terminal meanings in one `ScheduledTerminalMemory`.

The lock order and crash behavior:
```text
Scheduled lifecycle authority -> actual.loam
```

Completion publishes the lifecycle image containing the Scheduled -> Actual
terminal claim first and the normalized Actual generation second. A
retained Actual target that is still absent from Actual is inert to Scheduled
readers, so interruption remains fail-closed and a later retry can finish the
same endpoint. Cancellation refuses such an interrupted completion instead of
competing with it.
-/

structure CompletionDraft where
  scheduled : ScheduledId
  movement : Loam.MovementAdmission.Draft

structure CancellationDraft where
  scheduled : ScheduledId

private def completionEventId (scheduled : ScheduledId) : EventId :=
  ⟨"scheduled-completion:" ++ scheduled.token⟩

private def loadLifecycle?
    (scheduledFile : System.FilePath) :
    IO (Except String Loam.Persistence.ScheduledLifecycleImage) := do
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

private def findOpen?
    (lifecycle : Loam.Persistence.ScheduledLifecycleImage)
    (events : EventMemory)
    (target : ScheduledId) : Except String (ScheduledOccurrence String) := do
  let occurrences ← currentOpen? lifecycle events
  match occurrences.find? fun occurrence => decide (occurrence.id = target) with
  | some occurrence => pure occurrence
  | none => throw "loam: selected Scheduled identity is no longer current-open"

private def appendCompletionActual?
    (world : Loam.MovementAdmission.World)
    (actualId : EventId)
    (rawDraft : Loam.MovementAdmission.Draft) :
    Except String Loam.MovementAdmission.World := do
  let effects := Loam.SparseEffectIdentity.canonicalizeEffects [] rawDraft.effects
  let draft := { rawDraft with effects := effects }
  Loam.MovementAdmission.validateDraft draft
  if !draft.relations.isEmpty || !draft.discharges.isEmpty then
    throw "loam: Scheduled completion currently admits plain Actual Movement effects only"
  if !world.locusAdmission.admitsEffects draft.effects then
    throw "loam: Scheduled completion uses a Locus not approved for new publication"
  let event : Event := {
    id := actualId
    effects := effects
    keyNodup := by
      change (retainedEffectKeys effects).Nodup
      rw [show retainedEffectKeys effects = [] by
        simpa only [effects] using
          Loam.SparseEffectIdentity.retainedEffectKeys_canonicalizeEffects_nil rawDraft.effects]
      exact List.nodup_nil
  }
  let fact : ActualValidityFact String :=
    .base actualId draft.validOn
  let events ←
    match EventMemory.add? world.events event with
    | some events => pure events
    | none => throw "loam: could not append Scheduled completion Actual Event"
  let validity ←
    match world.validity.addFact? fact with
    | some validity => pure validity
    | none => throw "loam: could not append Scheduled completion occurrence date"
  let descriptions ←
    match draft.description with
    | none => pure world.descriptions
    | some text =>
        match world.descriptions.add? { event := actualId, text := text } with
        | some descriptions => pure descriptions
        | none => throw "loam: could not append Scheduled completion description"
  pure {
    events := events
    validity := validity
    descriptions := descriptions
    relations := world.relations
    discharges := world.discharges
    locusAdmission := world.locusAdmission
  }

private def publishCompletionUnderOwnership
    (scheduledFile root : System.FilePath)
    (draft : CompletionDraft) : IO (Except String Unit) := do
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
  let world := Loam.ActualAuthority.movementWorld evidence locusAdmission
  let _ ←
    match findOpen? lifecycle world.events draft.scheduled with
    | .ok occurrence => pure occurrence
    | .error message => return .error message
  let existing := lifecycle.terminals.completionActualFor? draft.scheduled
  let actualId := existing.getD (completionEventId draft.scheduled)
  match EventMemory.findById? world.events actualId with
  | some _ =>
      return .error "loam: selected Scheduled identity is already completed"
  | none => pure ()
  match lifecycle.terminals.completionSourceForActual? actualId with
  | some source =>
      if source != draft.scheduled then
        return .error "loam: Scheduled completion Actual identity belongs to another Scheduled occurrence"
  | none => pure ()
  let updatedWorld ←
    match appendCompletionActual? world actualId draft.movement with
    | .ok updated => pure updated
    | .error message => return .error message
  let relation : ScheduledTerminal := {
    source := draft.scheduled
    target := some (.actual actualId)
  }
  let updatedTerminals ←
    match existing with
    | some _ => pure lifecycle.terminals
    | none =>
        match lifecycle.terminals.add? relation with
        | some terminals => pure terminals
        | none => return .error "loam: Scheduled completion violates one-to-one endpoint ownership"
  let updatedLifecycle := { lifecycle with terminals := updatedTerminals }
  match existing with
  | none =>
      if !(← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile updatedLifecycle) then
        return .error "loam: Scheduled completion lifecycle could not be published"
  | some _ => pure ()
  let updatedEvidence : ActualEvidence := {
    events := updatedWorld.events
    validity := updatedWorld.validity
    descriptions := updatedWorld.descriptions
    corrections := evidence.corrections
    reversals := evidence.reversals
    relations := updatedWorld.relations
    discharges := updatedWorld.discharges
  }
  match ← Loam.ActualAuthority.publishActual? root updatedEvidence with
  | .error message =>
      return .error
        ("loam: Actual Event was not published; retained Scheduled completion remains inert and can be retried: " ++ message)
  | .ok () =>
      return .ok ()

private def publishCancellationUnderOwnership
    (scheduledFile root : System.FilePath)
    (draft : CancellationDraft) : IO (Except String Unit) := do
  let lifecycle ←
    match ← loadLifecycle? scheduledFile with
    | .ok lifecycle => pure lifecycle
    | .error message => return .error message
  let evidence ←
    match ← Loam.ActualAuthority.loadActual? root with
    | .ok ev => pure ev
    | .error message => return .error message
  match lifecycle.terminals.completionActualFor? draft.scheduled with
  | some actual =>
      if (EventMemory.findById? evidence.events actual).isSome then
        return .error "loam: selected Scheduled identity is already completed"
      else
        return .error "loam: selected Scheduled identity has an interrupted completion; retry completion before cancellation"
  | none => pure ()
  let _ ←
    match findOpen? lifecycle evidence.events draft.scheduled with
    | .ok occurrence => pure occurrence
    | .error message => return .error message
  let retirement : ScheduledTerminal := {
    source := draft.scheduled
    target := none
  }
  let updatedTerminals ←
    match lifecycle.terminals.add? retirement with
    | some terminals => pure terminals
    | none => return .error "loam: could not append Scheduled retirement evidence"
  let updatedLifecycle := { lifecycle with terminals := updatedTerminals }
  if !(← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile updatedLifecycle) then
    return .error "loam: Scheduled retirement lifecycle could not be published"
  return .ok ()

/--
Publish one Scheduled realization as an Actual Event in normalized Actual authority.
Both fresh completions and resumed interrupted completions produce the same canonical
completion result.
-/
def publishCompletion
    (scheduledPath rootPath : String)
    (draft : CompletionDraft) : IO (Except String Unit) := do
  if scheduledPath.isEmpty then
    return .error "loam: scheduled path must not be empty"
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let scheduledFile := System.FilePath.mk scheduledPath
  let root := System.FilePath.mk rootPath
  Loam.ScheduledActualOwnership.withOwnership scheduledFile root
    (publishCompletionUnderOwnership scheduledFile root draft)

/--
Cancel one current-open Scheduled occurrence.
-/
def publishCancellation
    (scheduledPath rootPath : String)
    (draft : CancellationDraft) : IO (Except String Unit) := do
  if scheduledPath.isEmpty then
    return .error "loam: scheduled path must not be empty"
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let scheduledFile := System.FilePath.mk scheduledPath
  let root := System.FilePath.mk rootPath
  Loam.ScheduledActualOwnership.withOwnership scheduledFile root
    (publishCancellationUnderOwnership scheduledFile root draft)


end Loam.ScheduledTerminalPublisher
