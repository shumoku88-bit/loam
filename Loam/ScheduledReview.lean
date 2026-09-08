import Loam.Application.ScheduledOpenWorldInspection
import Loam.MovementManifestAuthority
import Loam.Persistence.ScheduledLifecyclePersistence

namespace Loam.ScheduledReview

open Loam.Core

set_option autoImplicit false

/-!
# Scheduled review projection and read boundary

This is a read-only projection boundary, not a Scheduled repository or lifecycle
authority. Retained Scheduled occurrence, completion, retirement and replacement
evidence remains authoritative. Absence of explicit current-open evidence stays
`unknown`; it is never converted into a closed-world NotDue claim.

Observation 226 cut production reads to one complete Scheduled lifecycle image.
The configured lifecycle path must exist and all four typed facets must decode;
missing storage is no longer interpreted as an empty household.
-/

abbrev Record := ScheduledOccurrence String
abbrev DayEvidence := Loam.Application.CurrentScheduledDayEvidenceResult String

structure EvidenceSnapshot where
  scheduled : ScheduledMemory String
  completions : ScheduledCompletionMemory
  retirements : ScheduledRetirementMemory
  replacements : ScheduledReplacementMemory
  events : EventMemory

private def lifecycleAdmission
    (snapshot : EvidenceSnapshot) : Except String Unit :=
  match Loam.Application.currentOpenScheduledWithReplacement
      snapshot.scheduled snapshot.completions snapshot.retirements
      snapshot.replacements snapshot.events with
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

private def loadLifecycleSnapshot?
    (scheduledFile : System.FilePath)
    (eventMemory : EventMemory) : IO (Except String EvidenceSnapshot) := do
  let some lifecycle ←
      Loam.Persistence.loadScheduledLifecycleImage? scheduledFile
    | return .error "loam: Scheduled lifecycle authority is missing, malformed, or unsupported"
  let snapshot : EvidenceSnapshot := {
    scheduled := lifecycle.scheduled
    completions := lifecycle.completions
    retirements := lifecycle.retirements
    replacements := lifecycle.replacements
    events := eventMemory
  }
  match lifecycleAdmission snapshot with
  | .error message => return .error message
  | .ok () => return .ok snapshot

def loadEvidenceFromManifest
    (scheduledFile manifestRoot : System.FilePath) : IO (Except String EvidenceSnapshot) := do
  match ← Loam.MovementManifestAuthority.loadSelectedWorld? manifestRoot with
  | .error message => return .error message
  | .ok world => loadLifecycleSnapshot? scheduledFile world.events

def dayEvidence (snapshot : EvidenceSnapshot) (date : String) : DayEvidence :=
  Loam.Application.currentScheduledDayEvidenceWithReplacement
    snapshot.scheduled snapshot.completions snapshot.retirements
    snapshot.replacements snapshot.events date

def explicitDueRecords : DayEvidence → List Record
  | .due first rest => first :: rest
  | _ => []

private def fromChanges (record : Record) : List (MovementChange LocusId) :=
  record.movement.changes.filter fun change => change.quantity.quanta < 0

private def toChanges (record : Record) : List (MovementChange LocusId) :=
  record.movement.changes.filter fun change => change.quantity.quanta > 0

def summary (record : Record) : String :=
  match fromChanges record, toChanges record with
  | [source], [destination] =>
      source.coordinate.token ++ " -> " ++ destination.coordinate.token ++ ": " ++
        toString destination.quantity.quanta ++ " " ++ record.measure.token
  | _, _ =>
      toString record.movement.changes.length ++ " movement change(s)  " ++ record.measure.token

end Loam.ScheduledReview
