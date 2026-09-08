import Loam.ActualDate
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

/--
Expose the replacement-aware current-open Scheduled frontier through the shared
review boundary. This does not invent a status store: completion, cancellation,
and replacement remain determined by retained lifecycle evidence.
-/
def currentOpenRecords (snapshot : EvidenceSnapshot) : Except String (List Record) :=
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
  | .open occurrences => .ok occurrences

private def lifecycleAdmission
    (snapshot : EvidenceSnapshot) : Except String Unit := do
  let _ ← currentOpenRecords snapshot
  pure ()

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

/--
Return current-open Scheduled occurrences whose retained expected date is before
one explicit calendar boundary. The original expected date is preserved; this
projection never re-dates an occurrence into the future.

The practical Scheduled publisher already admits real ISO calendar dates. The
review still validates retained dates before using lexical ISO ordering so old or
malformed evidence fails closed rather than becoming a false pending result.
-/
def currentOpenBeforeDate
    (snapshot : EvidenceSnapshot) (date : String) : Except String (List Record) := do
  if !Loam.ActualDate.validIsoDate date then
    throw "loam: pending Scheduled boundary must be a real YYYY-MM-DD calendar date"
  let records ← currentOpenRecords snapshot
  if !(records.all fun record => Loam.ActualDate.validIsoDate record.scheduledOn) then
    throw "loam: current-open Scheduled evidence contains an invalid retained date"
  return
    (records.filter fun record => decide (record.scheduledOn < date)).mergeSort fun left right =>
      if left.scheduledOn = right.scheduledOn then
        left.id.token ≤ right.id.token
      else
        left.scheduledOn ≤ right.scheduledOn

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
