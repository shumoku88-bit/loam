import Loam.ActualDate
import Loam.Application.ScheduledInspection
import Loam.MovementManifestAuthority
import Loam.Persistence
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.WriterOwnership

namespace Loam.ScheduledReplacementPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Shared Scheduled replacement publication

Replacement remains explicit `Scheduled -> Scheduled` provenance. Observation 226
moves the occurrence and replacement relation into one complete Scheduled
lifecycle authority image, so replacement no longer needs a relation-first
intermediate publication or resume protocol.

The fixed ownership order matches Scheduled terminal publication:

```text
Scheduled lifecycle authority -> Movement CURRENT
```

The Movement authority is read-only here. Holding its ownership boundary prevents
a concurrent completion from changing the Event frontier between current-open
admission and lifecycle publication.
-/

/-- Surface-independent replacement content. Effect identities are presentation-only. -/
structure Draft where
  source : ScheduledId
  scheduledOn : String
  effects : List Effect
  total : Int

structure Receipt where
  source : ScheduledId
  replacement : ScheduledId
  scheduledOn : String
  total : Int
  deriving Repr

private def loadLifecycle?
    (scheduledFile : System.FilePath) :
    IO (Except String Loam.Persistence.ScheduledLifecycleImage) := do
  let some lifecycle ← Loam.Persistence.loadScheduledLifecycleImage? scheduledFile
    | return .error "loam: Scheduled lifecycle authority is missing, malformed, or unsupported"
  return .ok lifecycle

private def currentOpen?
    (lifecycle : Loam.Persistence.ScheduledLifecycleImage)
    (events : EventMemory) : Except String (List (ScheduledOccurrence String)) :=
  match Loam.Application.currentOpenScheduledWithReplacement
      lifecycle.scheduled lifecycle.completions lifecycle.retirements
      lifecycle.replacements events with
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
    (id : ScheduledId) : Bool :=
  occurrences.any fun occurrence => decide (occurrence.id = id)

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
    throw "loam: replacement date must be a real calendar date in YYYY-MM-DD form"
  if !draft.effects.all (fun effect =>
      Loam.Persistence.validToken effect.locus.token &&
      decide (effect.measure = ⟨"jpy"⟩) &&
      effect.quantity.quanta != 0) then
    throw "loam: Scheduled replacement requires valid Locus tokens and nonzero JPY quantities"
  let changes : List (MovementChange LocusId) :=
    draft.effects.map fun effect =>
      { coordinate := effect.locus, quantity := effect.quantity }
  if (BalancedMovement.ofChanges? ⟨"jpy"⟩ changes).isNone then
    throw "loam: Scheduled replacement movement totals differ"
  let positive := draft.effects.foldl
    (fun total effect => total + max 0 effect.quantity.quanta) 0
  if positive <= 0 || draft.total != positive then
    throw "loam: Scheduled replacement requires a positive total matching the draft"

private def occurrenceFromDraft?
    (id : ScheduledId) (draft : Draft) : Option (ScheduledOccurrence String) := do
  let changes : List (MovementChange LocusId) :=
    draft.effects.map fun effect =>
      { coordinate := effect.locus, quantity := effect.quantity }
  let movement ← BalancedMovement.ofChanges? ⟨"jpy"⟩ changes
  pure { id := id, scheduledOn := draft.scheduledOn, movement := movement }

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
  let world ←
    match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
    | .ok world => pure world
    | .error message => return .error message
  if (ScheduledMemory.findById? lifecycle.scheduled draft.source).isNone then
    return .error "loam: selected Scheduled identity is not retained"
  if (ScheduledReplacementMemory.findBySource?
      lifecycle.replacements draft.source).isSome then
    return .error "loam: selected Scheduled identity is already replaced"
  let openOccurrences ←
    match currentOpen? lifecycle world.events with
    | .ok occurrences => pure occurrences
    | .error message => return .error message
  if !containsScheduled openOccurrences draft.source then
    return .error "loam: only a currently open Scheduled identity can be replaced"
  let replacementId ←
    match freshScheduledId? lifecycle.scheduled with
    | some id => pure id
    | none => return .error "loam: could not generate a fresh replacement Scheduled identity"
  let occurrence ←
    match occurrenceFromDraft? replacementId draft with
    | some occurrence => pure occurrence
    | none => return .error "loam: replacement Scheduled movement could not be admitted"
  let updatedScheduled ←
    match lifecycle.scheduled.add? occurrence with
    | some scheduled => pure scheduled
    | none => return .error "loam: replacement Scheduled identity collides with retained evidence"
  let relation : ScheduledReplacement := {
    source := draft.source
    replacement := replacementId
  }
  let updatedReplacements ←
    match lifecycle.replacements.add? relation with
    | some replacements => pure replacements
    | none => return .error "loam: replacement relation violates one-to-one endpoint ownership"
  let updatedLifecycle := {
    lifecycle with
    scheduled := updatedScheduled
    replacements := updatedReplacements
  }
  match transitionAdmissible?
      updatedLifecycle world.events draft.source replacementId with
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
    total := draft.total
  }

private def withReplacementOwnership {α : Type}
    (scheduledFile root : System.FilePath)
    (action : IO (Except String α)) : IO (Except String α) :=
  Loam.WriterOwnership.withOwnership scheduledFile <|
    Loam.WriterOwnership.withOwnership (root / "CURRENT") action

/--
Replace one current-open Scheduled occurrence with one new Scheduled occurrence.

The source-closing relation and replacement occurrence are constructed in memory
and published together as one complete lifecycle image. There is no reader-visible
missing replacement endpoint and therefore no replacement resume state. No
recurrence, continuation, edit-kind, routing inheritance, or Movement Event is
created here.
-/
def publishManifestReplacement
    (scheduledPath rootPath : String)
    (draft : Draft) : IO (Except String Receipt) := do
  if scheduledPath.isEmpty then
    return .error "loam: scheduled path must not be empty"
  if rootPath.isEmpty then
    return .error "loam: LOAM_MOVEMENT_MANIFEST_ROOT must not be empty"
  let scheduledFile := System.FilePath.mk scheduledPath
  let root := System.FilePath.mk rootPath
  withReplacementOwnership scheduledFile root
    (publishUnderOwnership scheduledFile root draft)

end Loam.ScheduledReplacementPublisher
