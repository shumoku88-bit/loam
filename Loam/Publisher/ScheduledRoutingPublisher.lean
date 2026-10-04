import Loam.ActualDate
import Loam.Core.ScheduledRouting
import Loam.Persistence.TokenSyntax
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Persistence.ScheduledRoutingPersistence
import Loam.Persistence.WriterOwnership
import Loam.Authority.ScheduledRoutingAuthority
import Loam.Authority.ScheduledLifecycleAuthority
import Loam.Authority.ActualAuthority

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
- re-reading the authoritative Scheduled lifecycle during publication
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

private def occurrenceHasLocus
    (occurrence : ScheduledOccurrence String)
    (locus : LocusId) : Bool :=
  occurrence.movement.changes.any fun change => decide (change.coordinate = locus)

private def validateDraft? (draft : Draft) : Except String Unit := do
  if !Loam.ActualDate.validIsoDate draft.effectiveOn then
    throw "loam: Scheduled routing effective date must be a real calendar date in YYYY-MM-DD form"
  if !validToken draft.subject.scheduled.token || !validToken draft.subject.locus.token then
    throw "loam: Scheduled identity and Locus must be nonempty single-line tokens"
  match draft.target with
  | .managed purpose =>
      if !validToken purpose.token then
        throw "loam: route must be 'managed PURPOSE' or 'unmanaged'"
  | .unmanaged => pure ()

/--
Pure routing proposal shared by legacy-file and HouseholdImage publication.

The Scheduled lifecycle is still an independent authority at this stage. The
storage topology of routing evidence cannot alter subject admission, duplicate
rejection, or the resulting canonical history.
-/
private def propose?
    (lifecycle : ScheduledLifecycleImage)
    (history : ScheduledRoutingHistory String)
    (draft : Draft) : Except String (ScheduledRoutingHistory String) := do
  let some occurrence :=
      ScheduledMemory.findById? lifecycle.scheduled draft.subject.scheduled
    | throw "loam: scheduled identity not found"
  if !occurrenceHasLocus occurrence draft.subject.locus then
    throw "loam: Scheduled occurrence does not contain that Locus"
  let purposeOpt : Option PurposeId :=
    match draft.target with
    | .managed purpose => some purpose
    | .unmanaged => none
  let entry : RoutingEntry ScheduledRoutingSubject String := {
    subject := draft.subject
    effectiveOn := draft.effectiveOn
    purpose := purposeOpt
  }
  let some updated := history.add? entry
    | throw "loam: Scheduled routing already has evidence at this subject/effective coordinate"
  return updated

private def publishUnlocked
    (routingFile scheduledFile : System.FilePath)
    (draft : Draft) : IO (Except String Unit) := do
  let lifecycle ←
    match ← loadScheduledLifecycleImage? scheduledFile with
    | some lifecycle => pure lifecycle
    | none =>
        return .error "loam: Scheduled lifecycle authority is missing, malformed, or unsupported"
  if !(← routingFile.pathExists) then
    return .error "loam: Scheduled routing authority is missing"
  let history ←
    match ← loadScheduledRoutingHistory? routingFile with
    | some history => pure history
    | none =>
        return .error "loam: malformed or unsupported Scheduled routing authority"
  let updated ←
    match propose? lifecycle history draft with
    | .ok updated => pure updated
    | .error message => return .error message
  if ← saveScheduledRoutingHistory? routingFile updated then
    return .ok ()
  return .error "loam: Scheduled routing evidence could not be published"

/--
Publish one dated Scheduled routing assertion under routing-authority ownership.

Both the complete Scheduled lifecycle authority and independent routing authority
must already exist. Admission verifies the subject exists in the Scheduled lifecycle
and rejects duplicate `(subject, effectiveOn)` coordinates fail-closed.
-/
def publish
    (routingPath scheduledPath : String)
    (draft : Draft) : IO (Except String Unit) := do
  match validateDraft? draft with
  | .ok () => pure ()
  | .error message => return .error message
  if routingPath.isEmpty then
    return .error "loam: routing path must not be empty"
  if scheduledPath.isEmpty then
    return .error "loam: scheduled path must not be empty"
  let routingFile := System.FilePath.mk routingPath
  let scheduledFile := System.FilePath.mk scheduledPath
  Loam.WriterOwnership.withOwnership routingFile
    (publishUnlocked routingFile scheduledFile draft)

private def publishHouseholdUnderActualOwnership
    (root : System.FilePath)
    (draft : Draft) : IO (Except String Unit) := do
  let lifecycle ←
    match ← Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? root with
    | .ok lifecycle => pure lifecycle
    | .error message => return .error message
  Loam.ScheduledRoutingAuthority.updateHouseholdCurrent? root fun history => do
    let updated ← propose? lifecycle history draft
    return (updated, ())

/--
Publish one Scheduled routing assertion into the required HouseholdImage sections.

Actual ownership excludes concurrent Scheduled lifecycle mutation while routing
admission reads Scheduled and updates ScheduledRouting. Household publication
then follows the P9 Actual -> Household lock order.
-/
def publishHousehold
    (root : System.FilePath)
    (draft : Draft) : IO (Except String Unit) := do
  match validateDraft? draft with
  | .ok () => pure ()
  | .error message => return .error message
  if root.toString.isEmpty then
    return .error "loam: data root must not be empty"
  Loam.ActualAuthority.withActualOwnership root
    (publishHouseholdUnderActualOwnership root draft)

end Loam.ScheduledRoutingPublisher
