import Loam.ActualDate
import Loam.Core.ScheduledRouting
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Persistence.ScheduledRoutingPersistence
import Loam.ScheduledCreationPublisher
import Loam.ScheduledRoutingPublisher

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

/--
Inherit Scheduled routing from a predecessor occurrence to a newly created occurrence.

Reads the authoritative Scheduled lifecycle and historical routing authorities,
inspects positive changes on the newly created occurrence, queries predecessor
routing status at `effectiveOn`, and publishes corresponding routing assertions
through `ScheduledRoutingPublisher.publish`.

Precondition and read failures return `.error` before any write is attempted.
Per-route publication results are recorded in `Report.outcomes`.
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
  match ← loadScheduledLifecycleImage? scheduledPath with
  | none =>
      return .error "loam: Scheduled lifecycle authority is missing, malformed, or unsupported"
  | some lifecycle =>
      match ScheduledMemory.findById? lifecycle.scheduled predecessor with
      | none =>
          return .error s!"loam: predecessor Scheduled occurrence '{predecessor.token}' not found"
      | some _ =>
          match ScheduledMemory.findById? lifecycle.scheduled created with
          | none =>
              return .error s!"loam: created Scheduled occurrence '{created.token}' not found"
          | some occurrence =>
          if !(← routingPath.pathExists) then
            return .error "loam: Scheduled routing authority is missing"
          match ← loadScheduledRoutingHistory? routingPath with
          | none =>
              return .error "loam: malformed or unsupported Scheduled routing authority"
          | some history =>
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
                      match ← Loam.ScheduledRoutingPublisher.publish routingPath.toString scheduledPath.toString draft with
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
                      match ← Loam.ScheduledRoutingPublisher.publish routingPath.toString scheduledPath.toString draft with
                      | .ok _ =>
                          outcomes := outcomes ++ [.inherited change.coordinate .unmanaged]
                      | .error message =>
                          outcomes := outcomes ++ [.refused change.coordinate message]
                  | .unrouted =>
                      pure ()
              return .ok { outcomes := outcomes }

/-- Convenience helper for callers holding a `ScheduledCreationPublisher.Receipt`. -/
def inheritFromReceipt
    (routingPath scheduledPath : System.FilePath)
    (predecessor : ScheduledId)
    (receipt : Loam.ScheduledCreationPublisher.Receipt)
    (effectiveOn : String) : IO (Except String Report) :=
  inherit routingPath scheduledPath predecessor receipt.scheduled effectiveOn

end Loam.ScheduledContinuationRouting
