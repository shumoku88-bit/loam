import Loam.Application.ScheduledInspection
import Loam.MovementManifestAuthority
import Loam.Persistence
import Loam.Persistence.ScheduledCompletionPersistence
import Loam.Persistence.ScheduledPersistence
import Loam.Persistence.ScheduledReplacementPersistence
import Loam.Persistence.ScheduledRetirementPersistence

namespace Loam.ScheduledReview

open Loam.Core

set_option autoImplicit false

/-!
# Scheduled review projection and read boundary

This module is intentionally a read-only projection boundary, not a Scheduled
repository or lifecycle authority. The retained Scheduled occurrence stream and
its completion / retirement / replacement evidence remain authoritative.

The current-open answer is delegated to
`Loam.Application.currentOpenScheduledWithReplacement`; presentations may then
select one scheduled day without changing lifecycle semantics.
-/

abbrev Record := ScheduledOccurrence String

private def loadScheduledMemoryOrEmpty?
    (path : System.FilePath) : IO (Option (ScheduledMemory String)) := do
  if ← path.pathExists then
    Loam.Persistence.loadScheduledMemory? path
  else
    return ScheduledMemory.ofOccurrences? []

private def loadEventMemoryOrEmpty?
    (path : System.FilePath) : IO (Option EventMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventMemory? path
  else
    return EventMemory.ofEvents? []

private def currentOpen?
    (scheduledMemory : ScheduledMemory String)
    (completionMemory : ScheduledCompletionMemory)
    (retirementMemory : ScheduledRetirementMemory)
    (replacementMemory : ScheduledReplacementMemory)
    (eventMemory : EventMemory) : Except String (List Record) :=
  match Loam.Application.currentOpenScheduledWithReplacement
      scheduledMemory completionMemory retirementMemory replacementMemory eventMemory with
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

private def loadLifecycle?
    (scheduledFile : System.FilePath)
    (eventMemory : EventMemory) : IO (Except String (List Record)) := do
  let some scheduledMemory ← loadScheduledMemoryOrEmpty? scheduledFile
    | return .error "loam: malformed or unsupported scheduled file"
  let completionFile :=
    Loam.Persistence.scheduledCompletionPathForScheduledMemory scheduledFile
  let retirementFile :=
    Loam.Persistence.scheduledRetirementPathForScheduledMemory scheduledFile
  let replacementFile :=
    Loam.Persistence.scheduledReplacementPathForScheduledMemory scheduledFile
  let some completionMemory ←
      Loam.Persistence.loadScheduledCompletionMemoryOrEmpty? completionFile
    | return .error "loam: malformed or unsupported scheduled-completion file"
  let some retirementMemory ←
      Loam.Persistence.loadScheduledRetirementMemoryOrEmpty? retirementFile
    | return .error "loam: malformed or unsupported scheduled-retirement file"
  let some replacementMemory ←
      Loam.Persistence.loadScheduledReplacementMemoryOrEmpty? replacementFile
    | return .error "loam: malformed or unsupported scheduled-replacement file"
  return currentOpen?
    scheduledMemory completionMemory retirementMemory replacementMemory eventMemory

/--
Load current-open Scheduled evidence while taking Actual Event identity from one
explicitly selected Movement generation. There is no Movement sidecar fallback on
this path.
-/
def loadCurrentOpenFromManifest
    (scheduledFile manifestRoot : System.FilePath) : IO (Except String (List Record)) := do
  match ← Loam.MovementManifestAuthority.loadSelectedWorld? manifestRoot with
  | .error message => return .error message
  | .ok world => loadLifecycle? scheduledFile world.events

/--
Sidecar Event-memory read path retained for the existing line Scheduled
presentation and isolated fixtures. Missing Event memory means no retained Actual
endpoints yet, matching the existing practical reader behavior.
-/
def loadCurrentOpenFromSidecar
    (scheduledFile eventMemoryFile : System.FilePath) : IO (Except String (List Record)) := do
  let some eventMemory ← loadEventMemoryOrEmpty? eventMemoryFile
    | return .error "loam: malformed or unsupported event-memory file"
  loadLifecycle? scheduledFile eventMemory

/-- Exact selected-day projection over an already admitted current-open set. -/
def selectDay (records : List Record) (date : String) : List Record :=
  records.filter fun occurrence => occurrence.scheduledOn == date

private def fromChanges (record : Record) : List (MovementChange LocusId) :=
  record.movement.changes.filter fun change => change.quantity.quanta < 0

private def toChanges (record : Record) : List (MovementChange LocusId) :=
  record.movement.changes.filter fun change => change.quantity.quanta > 0

/-- Small plain-text summary for read-only presentation experiments. -/
def summary (record : Record) : String :=
  match fromChanges record, toChanges record with
  | [source], [destination] =>
      source.coordinate.token ++ " -> " ++ destination.coordinate.token ++ ": " ++
        toString destination.quantity.quanta ++ " " ++ record.measure.token
  | _, _ =>
      toString record.movement.changes.length ++ " movement change(s)  " ++ record.measure.token

end Loam.ScheduledReview
