import Loam.Application.ScheduledOpenWorldInspection
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

Prototype 11 needs to ask a different exact day every time `SelectedDay` moves.
For that reason this adapter keeps the admitted lifecycle evidence snapshot and
delegates each exact-day answer to
`Loam.Application.currentScheduledDayEvidenceWithReplacement`.

An absent explicit current-open occurrence therefore remains `unknown`; it is
never converted into `NotDue` or an empty closed-world household claim.
-/

abbrev Record := ScheduledOccurrence String
abbrev DayEvidence := Loam.Application.CurrentScheduledDayEvidenceResult String

/--
Read-only evidence retained by the TUI process after startup admission. This is
not presentation state and is never persisted by the TUI.
-/
structure EvidenceSnapshot where
  scheduled : ScheduledMemory String
  completions : ScheduledCompletionMemory
  retirements : ScheduledRetirementMemory
  replacements : ScheduledReplacementMemory
  events : EventMemory

private def loadScheduledMemoryOrEmpty?
    (path : System.FilePath) : IO (Option (ScheduledMemory String)) := do
  if ← path.pathExists then
    Loam.Persistence.loadScheduledMemory? path
  else
    return ScheduledMemory.ofOccurrences? []

private def lifecycleAdmission
    (snapshot : EvidenceSnapshot) : Except String Unit :=
  match Loam.Application.currentOpenScheduledWithReplacement
      snapshot.scheduled snapshot.completions snapshot.retirements
      snapshot.replacements snapshot.events with
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

private def loadLifecycleSnapshot?
    (scheduledFile : System.FilePath)
    (eventMemory : EventMemory) : IO (Except String EvidenceSnapshot) := do
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
  let snapshot : EvidenceSnapshot := {
    scheduled := scheduledMemory
    completions := completionMemory
    retirements := retirementMemory
    replacements := replacementMemory
    events := eventMemory
  }
  match lifecycleAdmission snapshot with
  | .error message => return .error message
  | .ok () => return .ok snapshot

/--
Load Scheduled lifecycle evidence while taking Actual Event identity from one
explicitly selected Movement generation. There is no Movement sidecar fallback on
this path. Lifecycle structure is admitted before raw terminal mode begins.
-/
def loadEvidenceFromManifest
    (scheduledFile manifestRoot : System.FilePath) : IO (Except String EvidenceSnapshot) := do
  match ← Loam.MovementManifestAuthority.loadSelectedWorld? manifestRoot with
  | .error message => return .error message
  | .ok world => loadLifecycleSnapshot? scheduledFile world.events

/--
Ask one exact day using the production open-world Scheduled contract.

`unknown` means only that no explicit current-open occurrence is retained for the
queried day. It is deliberately not a negative obligation claim.
-/
def dayEvidence (snapshot : EvidenceSnapshot) (date : String) : DayEvidence :=
  Loam.Application.currentScheduledDayEvidenceWithReplacement
    snapshot.scheduled snapshot.completions snapshot.retirements
    snapshot.replacements snapshot.events date

/-- Explicit rows carried by a `due` answer, used only for presentation. -/
def explicitDueRecords : DayEvidence → List Record
  | .due first rest => first :: rest
  | _ => []

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
