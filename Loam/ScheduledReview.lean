import Loam.ActualAuthority
import Loam.ActualDate
import Loam.Application.ScheduledOpenWorldInspection
import Loam.Persistence.ScheduledLifecyclePersistence

namespace Loam.ScheduledReview

open Loam.Core

set_option autoImplicit false

/-!
# Scheduled review projection and read boundary

This is a read-only projection boundary, not a Scheduled repository or lifecycle
authority. Retained Scheduled occurrences and terminal evidence remain
authoritative. Absence of explicit current-open evidence stays `unknown`; it is
never converted into a closed-world NotDue claim.

Observation 226 cut production reads to one complete Scheduled lifecycle image.
The runtime image now exposes one Scheduled-terminal memory while preserving the
existing v1 physical authority format at the persistence boundary.
-/

abbrev Record := ScheduledOccurrence String
abbrev DayEvidence := Loam.Application.CurrentScheduledDayEvidenceResult String

structure EvidenceSnapshot where
  scheduled : ScheduledMemory String
  terminals : ScheduledTerminalMemory
  events : EventMemory

/--
Expose the current-open Scheduled frontier through the shared review boundary.
This does not invent a status store: completion, cancellation, and replacement
remain projections of the retained terminal relation.
-/
def currentOpenRecords (snapshot : EvidenceSnapshot) : Except String (List Record) :=
  match Loam.Application.currentOpenScheduled
      snapshot.scheduled snapshot.terminals snapshot.events with
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
    terminals := lifecycle.terminals
    events := eventMemory
  }
  match lifecycleAdmission snapshot with
  | .error message => return .error message
  | .ok () => return .ok snapshot

def loadEvidenceFromActual
    (scheduledFile actualRoot : System.FilePath) : IO (Except String EvidenceSnapshot) := do
  let path :=
    if actualRoot.fileName == some Loam.ActualAuthority.actualFileName then actualRoot
    else Loam.ActualAuthority.actualPath actualRoot
  match ← Loam.ActualAuthority.loadActualFile? path with
  | .error message => return .error message
  | .ok evidence => loadLifecycleSnapshot? scheduledFile evidence.events

/--
Load canonical Scheduled lifecycle evidence from a household data directory while
preserving the caller's explicit Actual source selection. High-level household
readers use this entrance; low-level arbitrary-path callers keep
`loadEvidenceFromActual`.
-/
def loadHouseholdEvidence
    (dataDir actualRoot : System.FilePath) : IO (Except String EvidenceSnapshot) :=
  loadEvidenceFromActual (dataDir / "scheduled.loam") actualRoot

/--
Load the household Scheduled lifecycle against one caller-supplied Actual Event
image. This lets composed read boundaries reuse an already-loaded Actual
generation instead of reopening the same authority merely to validate Scheduled
completion references.
-/
def loadHouseholdEvidenceForEvents
    (dataDir : System.FilePath)
    (eventMemory : EventMemory) : IO (Except String EvidenceSnapshot) :=
  loadLifecycleSnapshot? (dataDir / "scheduled.loam") eventMemory


def dayEvidence (snapshot : EvidenceSnapshot) (date : String) : DayEvidence :=
  Loam.Application.currentScheduledDayEvidence
    snapshot.scheduled snapshot.terminals snapshot.events date

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
  let pending := records.filter fun record => decide (record.scheduledOn < date)
  return pending.mergeSort fun left right =>
    if left.scheduledOn = right.scheduledOn then
      left.id.token ≤ right.id.token
    else
      left.scheduledOn ≤ right.scheduledOn

/--
Return the earliest retained current-open Scheduled occurrence.

Overdue evidence is intentionally included. An old expected date remains
actionable while the occurrence is current-open; this projection never moves it
to today or silently skips it in favor of a later plan.
-/
def earliestCurrentOpenRecord
    (snapshot : EvidenceSnapshot) : Except String (Option Record) := do
  let records ← currentOpenRecords snapshot
  if !(records.all fun record => Loam.ActualDate.validIsoDate record.scheduledOn) then
    throw "loam: current-open Scheduled evidence contains an invalid retained date"
  let ordered := records.mergeSort fun left right =>
    if left.scheduledOn = right.scheduledOn then
      left.id.token ≤ right.id.token
    else
      left.scheduledOn ≤ right.scheduledOn
  match ordered with
  | [] => return none
  | first :: _ => return some first

private def positiveLocusTokensFromChanges
    (changes : List (MovementChange LocusId)) : List String :=
  ((changes.filterMap fun change =>
      if change.quantity.quanta > 0 then some change.coordinate.token else none).eraseDups)
    |>.mergeSort (fun left right => left <= right)

private def positiveLocusTokens (record : Record) : List String :=
  positiveLocusTokensFromChanges record.movement.changes

/--
Find current-open Scheduled occurrences on one exact date that share an edited
draft's positive Locus set.

This is advisory read evidence only. Exact date + positive-Locus equality does
not establish recurrence, series identity, contract identity, or duplicate
semantic identity. It is only sufficient evidence to ask before publishing
another explicit Scheduled occurrence.
-/
def sameDateSimilarOpenRecords
    (snapshot : EvidenceSnapshot)
    (scheduledOn : String)
    (movement : BalancedMovement LocusId) : Except String (List Record) := do
  if !Loam.ActualDate.validIsoDate scheduledOn then
    throw "loam: Scheduled awareness date must be a real YYYY-MM-DD calendar date"
  let proposedLoci := positiveLocusTokensFromChanges movement.changes
  if proposedLoci.isEmpty then return []
  let records ← currentOpenRecords snapshot
  if !(records.all fun record => Loam.ActualDate.validIsoDate record.scheduledOn) then
    throw "loam: current-open Scheduled evidence contains an invalid retained date"
  let candidates := records.filter fun record =>
    record.scheduledOn == scheduledOn &&
      positiveLocusTokens record == proposedLoci
  return candidates.mergeSort fun left right =>
    left.id.token <= right.id.token

/--
Find later current-open Scheduled occurrences that share the completed source's
positive Locus set.

This is a read-only presentation aid for post-completion awareness. Matching
does not assert recurrence, continuation provenance, series identity, contract
identity, or equal amounts. The caller must present the result as a possible
already-planned continuation and leave the final choice to the user.
-/
def laterSimilarOpenRecords
    (snapshot : EvidenceSnapshot) (source : Record) : Except String (List Record) := do
  if !Loam.ActualDate.validIsoDate source.scheduledOn then
    throw "loam: continuation source contains an invalid retained date"
  let sourceLoci := positiveLocusTokens source
  if sourceLoci.isEmpty then return []
  let records ← currentOpenRecords snapshot
  if !(records.all fun record => Loam.ActualDate.validIsoDate record.scheduledOn) then
    throw "loam: current-open Scheduled evidence contains an invalid retained date"
  let candidates := records.filter fun record =>
    decide (source.scheduledOn < record.scheduledOn) &&
      positiveLocusTokens record == sourceLoci
  return candidates.mergeSort fun left right =>
    if left.scheduledOn = right.scheduledOn then
      left.id.token <= right.id.token
    else
      left.scheduledOn <= right.scheduledOn

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
