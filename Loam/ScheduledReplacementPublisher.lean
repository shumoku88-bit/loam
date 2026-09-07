import Loam.ActualDate
import Loam.Application.ScheduledInspection
import Loam.MovementManifestAuthority
import Loam.Persistence
import Loam.Persistence.ScheduledCompletionPersistence
import Loam.Persistence.ScheduledPersistence
import Loam.Persistence.ScheduledReplacementPersistence
import Loam.Persistence.ScheduledRetirementPersistence
import Loam.WriterOwnership

namespace Loam.ScheduledReplacementPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Shared Scheduled replacement publication

Replacement remains explicit `Scheduled -> Scheduled` provenance. This publisher
moves the qualified relation-first writer boundary out of the legacy CLI and
makes currentness depend on the same manifest-selected Event frontier used by
production Scheduled readers.

The fixed ownership order matches Scheduled terminal publication:

```text
Scheduled authority -> Movement CURRENT
```

The Movement authority is read-only here. Holding its ownership boundary prevents
a concurrent completion from changing the Event frontier between current-open
admission and Scheduled publication.
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
  resumed : Bool
  deriving Repr

private structure LifecycleState where
  scheduled : ScheduledMemory String
  completions : ScheduledCompletionMemory
  retirements : ScheduledRetirementMemory
  replacements : ScheduledReplacementMemory

private def loadLifecycle?
    (scheduledFile : System.FilePath) : IO (Except String LifecycleState) := do
  if !(← scheduledFile.pathExists) then
    return .error "loam: scheduled authority is unavailable"
  let some scheduled ← Loam.Persistence.loadScheduledMemory? scheduledFile
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

private def currentOpen?
    (lifecycle : LifecycleState)
    (events : EventMemory) : Except String (List (ScheduledOccurrence String)) :=
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
    (lifecycle : LifecycleState)
    (events : EventMemory)
    (source replacement : ScheduledId) : Except String Unit := do
  let occurrences ← currentOpen? lifecycle events
  if containsScheduled occurrences source then
    throw "loam: proposed Scheduled replacement did not close its source"
  if !containsScheduled occurrences replacement then
    throw "loam: proposed Scheduled replacement did not expose its replacement as current-open"

private def resumeInterrupted?
    (scheduledFile : System.FilePath)
    (lifecycle : LifecycleState)
    (events : EventMemory)
    (retained : ScheduledReplacement)
    (draft : Draft) : IO (Except String Receipt) := do
  if (ScheduledMemory.findById? lifecycle.scheduled retained.replacement).isSome then
    return .error "loam: selected Scheduled identity is already replaced"
  let occurrence ←
    match occurrenceFromDraft? retained.replacement draft with
    | some occurrence => pure occurrence
    | none => return .error "loam: replacement Scheduled movement could not be admitted"
  let updatedScheduled ←
    match lifecycle.scheduled.add? occurrence with
    | some scheduled => pure scheduled
    | none => return .error "loam: replacement Scheduled identity collides with retained evidence"
  let updatedLifecycle := { lifecycle with scheduled := updatedScheduled }
  match transitionAdmissible?
      updatedLifecycle events draft.source retained.replacement with
  | .error message => return .error message
  | .ok () => pure ()
  if (Loam.Persistence.encodeScheduledMemory? updatedScheduled).isNone then
    return .error "loam: replacement Scheduled movement could not be encoded"
  if !(← Loam.Persistence.saveScheduledMemory? scheduledFile updatedScheduled) then
    return .error "loam: replacement Scheduled movement could not be published"
  return .ok {
    source := draft.source
    replacement := retained.replacement
    scheduledOn := draft.scheduledOn
    total := draft.total
    resumed := true
  }

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
  match ScheduledReplacementMemory.findBySource?
      lifecycle.replacements draft.source with
  | some retained =>
      resumeInterrupted? scheduledFile lifecycle world.events retained draft
  | none =>
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
      if (Loam.Persistence.encodeScheduledMemory? updatedScheduled).isNone ||
          (Loam.Persistence.encodeScheduledReplacementMemory? updatedReplacements).isNone then
        return .error "loam: Scheduled replacement publication could not be encoded"
      let replacementFile :=
        Loam.Persistence.scheduledReplacementPathForScheduledMemory scheduledFile
      if !(← Loam.Persistence.saveScheduledReplacementMemory?
          replacementFile updatedReplacements) then
        return .error "loam: replacement relation could not be published"
      if !(← Loam.Persistence.saveScheduledMemory? scheduledFile updatedScheduled) then
        return .error
          ("loam: replacement relation retained as " ++ draft.source.token ++ " -> " ++
            replacementId.token ++
            ", but the replacement Scheduled movement was not published; retry replacement to resume fail-closed recovery")
      return .ok {
        source := draft.source
        replacement := replacementId
        scheduledOn := draft.scheduledOn
        total := draft.total
        resumed := false
      }

private def withReplacementOwnership {α : Type}
    (scheduledFile root : System.FilePath)
    (action : IO (Except String α)) : IO (Except String α) :=
  Loam.WriterOwnership.withOwnership scheduledFile <|
    Loam.WriterOwnership.withOwnership (root / "CURRENT") action

/--
Replace one current-open Scheduled occurrence with one new Scheduled occurrence.

Publication is relation-first. If the Scheduled occurrence write is interrupted,
replacement-aware readers fail closed on the missing endpoint and a retry reuses
the retained replacement identity. No recurrence, continuation, edit-kind,
routing inheritance, or Movement Event is created here.
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
