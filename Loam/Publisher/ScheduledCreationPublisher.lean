import Loam.Authority.ActualAuthority
import Loam.ActualDate
import Loam.Core.ActualEvidence
import Loam.Application.ScheduledInspection
import Loam.Authority.LocusAdmissionAuthority
import Loam.Authority.ScheduledLifecycleAuthority
import Loam.Persistence.TokenSyntax
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Application.ScheduledOccurrenceConstruction

namespace Loam.ScheduledCreationPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Shared Scheduled creation publication

This module exposes the surface-independent write boundary for Scheduled creation.

Production publication uses the Scheduled section of HouseholdImage.
-/

structure Draft where
  scheduledOn : String
  movement : BalancedMovement LocusId

private def lifecycleReadable?
    (lifecycle : Loam.Persistence.ScheduledLifecycleImage)
    (events : EventMemory) : Except String Unit :=
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
  | .open _ => .ok ()

private def validateDraft (draft : Draft) : Except String Unit := do
  if !Loam.ActualDate.validIsoDate draft.scheduledOn then
    throw "loam: Scheduled creation requires a valid ISO calendar date"
  if draft.movement.changes.isEmpty then
    throw "loam: Scheduled creation requires at least one movement change"
  if !draft.movement.changes.all (fun change =>
      Loam.Persistence.validToken change.coordinate.token &&
      change.quantity.quanta != 0) then
    throw ("loam: Scheduled creation requires valid Locus tokens and nonzero " ++
      draft.movement.measure.token ++ " quantities")

private def publishHouseholdUnderActualOwnership
    (root : System.FilePath)
    (draft : Draft) : IO (Except String ScheduledId) := do
  match validateDraft draft with
  | .error message => return .error message
  | .ok () => pure ()
  let observed ←
    match ← Loam.ScheduledLifecycleAuthority.loadHouseholdObserved? root with
    | .ok observed => pure observed
    | .error message => return .error message
  let evidence ←
    match ← Loam.ActualAuthority.loadActual? root with
    | .ok ev => pure ev
    | .error message => return .error message
  let locusAdmission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? root with
    | .ok la => pure la
    | .error message => return .error message
  if !draft.movement.changes.all (fun change =>
      locusAdmission.allows change.coordinate) then
    return .error "loam: Scheduled creation uses a Locus not approved for new publication"
  match lifecycleReadable? observed.lifecycle evidence.events with
  | .error message => return .error message
  | .ok () => pure ()
  let scheduledId :=
    Loam.ScheduledOccurrenceConstruction.freshId observed.lifecycle.scheduled
  let occurrence : ScheduledOccurrence String := {
    id := scheduledId
    scheduledOn := draft.scheduledOn
    movement := draft.movement
  }
  let updatedScheduled :=
    ScheduledMemory.addFresh observed.lifecycle.scheduled occurrence (by
      change scheduledId ∉ observed.lifecycle.scheduled.occurrences.map ScheduledOccurrence.id
      exact Loam.ScheduledOccurrenceConstruction.freshId_fresh observed.lifecycle.scheduled)
  let updatedLifecycle := { observed.lifecycle with scheduled := updatedScheduled }
  match ← Loam.ScheduledLifecycleAuthority.publishObserved?
      root observed updatedLifecycle with
  | .ok _ => return .ok scheduledId
  | .error message => return .error message

/--
Publish one production household Scheduled occurrence through HouseholdImage.

Actual ownership is acquired first. The Scheduled Household generation is then
observed and published with stale-generation refusal, preserving the temporary
P9 lock order: Actual -> Household.
-/
def publishHousehold
    (root : System.FilePath)
    (draft : Draft) : IO (Except String ScheduledId) := do
  if root.toString.isEmpty then
    return .error "loam: data directory must not be empty"
  Loam.ActualAuthority.withActualOwnership root
    (publishHouseholdUnderActualOwnership root draft)


end Loam.ScheduledCreationPublisher
