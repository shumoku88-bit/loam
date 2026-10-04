import Loam.ActualDate
import Loam.Core.ScheduledRouting
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Persistence.ScheduledRoutingPersistence
import Loam.Authority.ScheduledRoutingAuthority
import Loam.Authority.ScheduledLifecycleAuthority
import Loam.Publisher.ScheduledRoutingPublisher

namespace Loam.ScheduledContinuationRouting

open Loam.Core
open Loam.Persistence
open Loam.ScheduledRoutingPublisher

set_option autoImplicit false

/-!
# Scheduled continuation routing

When completing a Scheduled occurrence and creating a continuation occurrence
for recurring obligations, routing decisions attached to the predecessor
occurrence can be inherited by the new occurrence.

This module provides the presentation-neutral, headless-ready boundary for
routing continuation. It separates product-level continuation orchestration
from TUI presentation concerns while preserving existing routing semantics:

- only positive-quantity changes are routed;
- publication is delegated exclusively to the shared `ScheduledRoutingPublisher`;
- production household inheritance reads and writes ScheduledRouting only through HouseholdImage;
- preconditions (authority presence, well-formedness, predecessor and created identity existence,
  and calendar date validity) fail closed as an outer `Except.error` before
  any mutation occurs;
- per-route publication outcomes (success or refusal) are retained individually
  in `Report.outcomes` without imposing arbitrary atomic batch semantics across
  independent assertions;
- unrouted predecessor loci produce no new assertion.
-/

/-- Outcome of attempting to inherit one route from predecessor to continuation. -/
inductive Outcome where
  | inherited (locus : LocusId) (target : ScheduledRoutingPublisher.Target)
  | refused (locus : LocusId) (message : String)
deriving Repr, DecidableEq

/-- Presentation-neutral report summarizing all per-route continuation outcomes. -/
structure Report where
  outcomes : List Outcome
deriving Repr, DecidableEq

namespace Report

def empty : Report := { outcomes := [] }

/-- Format per-route outcomes into human-readable notification strings. -/
def formatOutcomes (report : Report) : List String :=
  report.outcomes.map fun
    | .inherited locus (.managed purpose) =>
        s!"inherited route: {locus.token} -> managed {purpose.token}"
    | .inherited locus .unmanaged =>
        s!"inherited route: {locus.token} -> unmanaged"
    | .refused locus message =>
        s!"route refused for {locus.token}: {message}"

end Report

private def inheritFrom
    (lifecycle : ScheduledLifecycleImage)
    (history : ScheduledRoutingHistory String)
    (predecessor created : ScheduledId)
    (effectiveOn : String)
    (publishDraft : Loam.ScheduledRoutingPublisher.Draft →
      IO (Except String Unit)) : IO (Except String Report) := do
  let some _ := ScheduledMemory.findById? lifecycle.scheduled predecessor
    | return .error s!"loam: predecessor Scheduled occurrence '{predecessor.token}' not found"
  let some occurrence := ScheduledMemory.findById? lifecycle.scheduled created
    | return .error s!"loam: created Scheduled occurrence '{created.token}' not found"

  let mut outcomes : List Outcome := []
  for change in occurrence.movement.changes do
    if change.quantity.quanta > 0 then
      let subject : ScheduledRoutingSubject := {
        scheduled := predecessor
        locus := change.coordinate
      }
      match history.statusAt subject effectiveOn with
      | .managed purpose =>
          let draft : Loam.ScheduledRoutingPublisher.Draft := {
            subject := { scheduled := created, locus := change.coordinate }
            effectiveOn := effectiveOn
            target := .managed purpose
          }
          match ← publishDraft draft with
          | .ok _ =>
              outcomes := outcomes ++ [.inherited change.coordinate (.managed purpose)]
          | .error message =>
              outcomes := outcomes ++ [.refused change.coordinate message]
      | .unmanaged =>
          let draft : Loam.ScheduledRoutingPublisher.Draft := {
            subject := { scheduled := created, locus := change.coordinate }
            effectiveOn := effectiveOn
            target := .unmanaged
          }
          match ← publishDraft draft with
          | .ok _ =>
              outcomes := outcomes ++ [.inherited change.coordinate .unmanaged]
          | .error message =>
              outcomes := outcomes ++ [.refused change.coordinate message]
      | .unrouted =>
          pure ()
  return .ok { outcomes := outcomes }

/--
Legacy explicit-path continuation-routing entrance.

This remains for standalone diagnostics and migration qualification. Production
household commands use `inheritHousehold` so routing reads and writes share the
installed HouseholdImage authority.
-/
def inherit
    (routingPath scheduledPath : System.FilePath)
    (predecessor : ScheduledId)
    (created : ScheduledId)
    (effectiveOn : String) : IO (Except String Report) := do
  if !Loam.ActualDate.validIsoDate effectiveOn then
    return .error "loam: Scheduled continuation routing effective date must be a real calendar date in YYYY-MM-DD form"
  if !(← scheduledPath.pathExists) then
    return .error "loam: Scheduled lifecycle authority is missing"
  let lifecycle ←
    match ← loadScheduledLifecycleImage? scheduledPath with
    | some lifecycle => pure lifecycle
    | none =>
        return .error "loam: Scheduled lifecycle authority is missing, malformed, or unsupported"
  let history ←
    match ← Loam.ScheduledRoutingAuthority.loadLegacyCurrent? routingPath with
    | .ok history => pure history
    | .error message => return .error message
  inheritFrom lifecycle history predecessor created effectiveOn fun draft =>
    Loam.ScheduledRoutingPublisher.publish
      routingPath.toString scheduledPath.toString draft

/--
Production continuation-routing entrance.

Both Scheduled lifecycle and ScheduledRouting are read from HouseholdImage.
Frozen legacy scheduled.loam and scheduled-routing.loam are neither read nor
written by this production path.
-/
def inheritHousehold
    (root : System.FilePath)
    (predecessor : ScheduledId)
    (created : ScheduledId)
    (effectiveOn : String) : IO (Except String Report) := do
  if !Loam.ActualDate.validIsoDate effectiveOn then
    return .error "loam: Scheduled continuation routing effective date must be a real calendar date in YYYY-MM-DD form"
  let lifecycle ←
    match ← Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? root with
    | .ok lifecycle => pure lifecycle
    | .error message => return .error message
  let history ←
    match ← Loam.ScheduledRoutingAuthority.loadHouseholdCurrent? root with
    | .ok history => pure history
    | .error message => return .error message
  inheritFrom lifecycle history predecessor created effectiveOn fun draft =>
    Loam.ScheduledRoutingPublisher.publishHousehold root draft

end Loam.ScheduledContinuationRouting
