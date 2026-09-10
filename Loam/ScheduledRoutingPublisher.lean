import Loam.ActualDate
import Loam.Core.ScheduledRouting
import Loam.Persistence.TokenSyntax
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Persistence.ScheduledRoutingPersistence
import Loam.WriterOwnership

namespace Loam.ScheduledRoutingPublisher

open Loam.Core
open Loam.Persistence

set_option autoImplicit false

/-!
# Shared Scheduled routing publication

Observation 107 and 111 qualify historical routing as explicit assertions attaching
Purpose intent to a subject coordinate over time. Observation 153 refined the
Scheduled routing coordinate to `ScheduledId × LocusId`.

This module provides the shared, presentation-neutral publication boundary
used by both CLI and interactive TUI. It does not judge whether a subject is
currently unresolved; that classification remains the responsibility of
reading projections such as `ScheduledCommitmentInspection`.

The publisher enforces:
- WriterOwnership over the routing authority
- re-reading the authoritative Scheduled lifecycle under lock
- verification that `ScheduledId` exists and contains the requested `LocusId`
- re-reading the routing authority under lock
- rejection of duplicate `(subject, effectiveOn)` coordinates
- append-only history without editing earlier coordinates
-/

/-- Destination of one historical Scheduled routing assertion. -/
inductive Target where
  | managed (purpose : PurposeId)
  | unmanaged
deriving Repr, DecidableEq

/-- Presentation-neutral draft routing assertion. -/
structure Draft where
  subject : ScheduledRoutingSubject
  effectiveOn : String
  target : Target
deriving Repr, DecidableEq

/-- Evidence receipt returned upon successful routing publication. -/
structure Receipt where
  subject : ScheduledRoutingSubject
  effectiveOn : String
  target : Target
deriving Repr, DecidableEq

private def occurrenceHasLocus
    (occurrence : ScheduledOccurrence String)
    (locus : LocusId) : Bool :=
  occurrence.movement.changes.any fun change => decide (change.coordinate = locus)

private def publishUnlocked
    (routingFile scheduledFile : System.FilePath)
    (draft : Draft) : IO (Except String Receipt) := do
  match ← loadScheduledLifecycleImage? scheduledFile with
  | none =>
      return .error "loam: Scheduled lifecycle authority is missing, malformed, or unsupported"
  | some lifecycle =>
      match ScheduledMemory.findById? lifecycle.scheduled draft.subject.scheduled with
      | none =>
          return .error "loam: scheduled identity not found"
      | some occurrence =>
          if !occurrenceHasLocus occurrence draft.subject.locus then
            return .error "loam: Scheduled occurrence does not contain that Locus"
          else
            if !(← routingFile.pathExists) then
              return .error "loam: Scheduled routing authority is missing"
            else
              match ← loadScheduledRoutingHistory? routingFile with
              | none =>
                  return .error "loam: malformed or unsupported Scheduled routing authority"
              | some history =>
                  let purposeOpt : Option PurposeId :=
                    match draft.target with
                    | .managed p => some p
                    | .unmanaged => none
                  let entry : RoutingEntry ScheduledRoutingSubject String := {
                    subject := draft.subject
                    effectiveOn := draft.effectiveOn
                    purpose := purposeOpt
                  }
                  match RoutingHistory.ofEntries? (history.entries ++ [entry]) with
                  | none =>
                      return .error
                        "loam: Scheduled routing already has evidence at this subject/effective coordinate"
                  | some updated =>
                      if ← saveScheduledRoutingHistory? routingFile updated then
                        return .ok {
                          subject := draft.subject
                          effectiveOn := draft.effectiveOn
                          target := draft.target
                        }
                      else
                        return .error "loam: Scheduled routing evidence could not be published"

/--
Publish one dated Scheduled routing assertion under routing-authority ownership.

Both the complete Scheduled lifecycle authority and independent routing authority
must already exist. Admission verifies the subject exists in the Scheduled lifecycle
and rejects duplicate `(subject, effectiveOn)` coordinates fail-closed.
-/
def publish
    (routingPath scheduledPath : String)
    (draft : Draft) : IO (Except String Receipt) := do
  if !Loam.ActualDate.validIsoDate draft.effectiveOn then
    return .error "loam: Scheduled routing effective date must be a real calendar date in YYYY-MM-DD form"
  if !validToken draft.subject.scheduled.token || !validToken draft.subject.locus.token then
    return .error "loam: Scheduled identity and Locus must be nonempty single-line tokens"
  match draft.target with
  | .managed purpose =>
      if !validToken purpose.token then
        return .error "loam: route must be 'managed PURPOSE' or 'unmanaged'"
  | .unmanaged => pure ()
  if routingPath.isEmpty then
    return .error "loam: routing path must not be empty"
  if scheduledPath.isEmpty then
    return .error "loam: scheduled path must not be empty"
  let routingFile := System.FilePath.mk routingPath
  let scheduledFile := System.FilePath.mk scheduledPath
  Loam.WriterOwnership.withOwnership routingFile
    (publishUnlocked routingFile scheduledFile draft)

end Loam.ScheduledRoutingPublisher
