import Init.Data.Order
import Loam.Application.ConsumptionInspection
import Loam.Application.ScheduledInspection
import Loam.Core.ScheduledRouting

namespace Loam.Application

open Loam.Core
open Std (IsLinearOrder)

set_option autoImplicit false

variable {Time : Type}
  [DecidableEq Time]
  [LE Time]
  [DecidableRel (· ≤ · : Time → Time → Prop)]
  [Std.IsLinearOrder Time]

/-!
# Scheduled Commitment and Headroom inspection

Observation 108 selected Commitment as a projection over open Scheduled evidence
plus historical routing. Observation 113 selected:

  Remaining = Entitlement - Consumption
  Headroom  = Remaining - Commitment

without retained reservation, Commitment, Remaining, or Headroom state.

Observation 153 then pruned the practical Scheduled routing subject. Whole
`ScheduledId` is too coarse for split-purpose movement; bare `LocusId` is too
coarse across distinct Scheduled intent; a fresh Claim identity is not yet earned
when it is only a bijective wrapper. The reusable coordinate is owned by
`Loam.Core.ScheduledRouting`; this module only consumes it for Commitment and
Headroom projections.

The current Scheduled lifecycle has no learned-time coordinate, so this module
answers only the current-open view. `observedAt` selects historical routing; it
does not pretend to reconstruct when completion or retirement became known.
-/

/--
Query-local Commitment partition for one Purpose and Measure.

`managed` is only the amount routed to the queried Purpose. `unmanaged` and
`unrouted` retain the visible uncertainty pressure instead of silently treating
those claims as zero commitment.
-/
structure ScheduledCommitmentView where
  managed : Quantity
  unmanaged : Quantity
  unrouted : Quantity
deriving Repr, DecidableEq

/-- Arithmetic evidence for one current Headroom answer. -/
structure HeadroomView where
  remaining : Quantity
  commitment : Quantity
  headroom : Quantity
  unmanagedCommitment : Quantity
  unroutedCommitment : Quantity
deriving Repr, DecidableEq

private structure CommitmentQuanta where
  managed : Int := 0
  unmanaged : Int := 0
  unrouted : Int := 0

private def inEndExclusiveHorizon
    (scheduledOn endExclusive : Time) : Bool :=
  decide (scheduledOn ≤ endExclusive ∧ scheduledOn ≠ endExclusive)

private def addLocusIfAbsent
    (loci : List LocusId)
    (locus : LocusId) : List LocusId :=
  if locus ∈ loci then loci else loci ++ [locus]

/--
Recover each represented Locus once. `BalancedMovement` may retain repeated
changes at one Locus; the routing subject qualified by Observation 153 is the
aggregated `ScheduledId × LocusId` coordinate, not an individual raw change row.
-/
private def scheduledLoci
    (occurrence : ScheduledOccurrence Time) : List LocusId :=
  occurrence.movement.changes.foldl
    (fun loci change => addLocusIfAbsent loci change.coordinate)
    []

private def addPositiveScheduledLocus
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (observedAt : Time)
    (occurrence : ScheduledOccurrence Time)
    (total : CommitmentQuanta)
    (locus : LocusId) : CommitmentQuanta :=
  let quantity := occurrence.quantityAt locus
  if quantity.quanta ≤ 0 then
    total
  else
    let subject : ScheduledRoutingSubject :=
      { scheduled := occurrence.id, locus := locus }
    match routing.statusAt subject observedAt with
    | .managed routedPurpose =>
        if routedPurpose = purpose then
          { total with managed := total.managed + quantity.quanta }
        else
          total
    | .unmanaged =>
        { total with unmanaged := total.unmanaged + quantity.quanta }
    | .unrouted =>
        { total with unrouted := total.unrouted + quantity.quanta }

private def addOpenOccurrence
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (observedAt endExclusive : Time)
    (total : CommitmentQuanta)
    (occurrence : ScheduledOccurrence Time) : CommitmentQuanta :=
  if occurrence.measure ≠ measure then
    total
  else if !inEndExclusiveHorizon occurrence.scheduledOn endExclusive then
    total
  else
    (scheduledLoci occurrence).foldl
      (addPositiveScheduledLocus routing purpose observedAt occurrence)
      total

/--
Project current Scheduled Commitment for one Purpose and Measure.

Only positive aggregated Scheduled Locus coordinates are claims against spending
capacity. Negative or net-negative source coordinates remain visible in the
Scheduled movement but do not consume Purpose authority. Past-due open
occurrences remain in the projection; an occurrence exactly at `endExclusive`
is excluded.

Fails closed (`none`) if current Scheduled lifecycle evidence is structurally
inconsistent.
-/
def currentScheduledCommitment?
    (scheduled : ScheduledMemory Time)
    (completions : ScheduledCompletionMemory)
    (retirements : ScheduledRetirementMemory)
    (events : EventMemory)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : Option ScheduledCommitmentView :=
  match currentOpenScheduled scheduled completions retirements events with
  | .unknownCompletionScheduled => none
  | .unknownRetirementScheduled => none
  | .conflictingTerminalEvidence => none
  | .open occurrences =>
      let total := occurrences.foldl
        (addOpenOccurrence routing purpose measure observedAt endExclusive)
        {}
      some {
        managed := Quantity.ofQuanta total.managed
        unmanaged := Quantity.ofQuanta total.unmanaged
        unrouted := Quantity.ofQuanta total.unrouted
      }

/--
Compose correction-aware Actual Remaining with current open Scheduled Commitment:

  Headroom = Remaining - managed Commitment

Unmanaged and unrouted Scheduled quantities remain explicit evidence on the
returned view. They are not guessed into or out of the queried Purpose.
-/
def headroomAtCorrectionFrontier?
    (capacityMovements : List CapacityMovement)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory Time)
    (actualRouting : RoutingHistory LocusId Time)
    (scheduled : ScheduledMemory Time)
    (completions : ScheduledCompletionMemory)
    (retirements : ScheduledRetirementMemory)
    (scheduledRouting : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : Option HeadroomView := do
  let remaining ←
    remainingAtCorrectionFrontier?
      capacityMovements events corrections validities actualRouting purpose measure
  let commitment ←
    currentScheduledCommitment?
      scheduled completions retirements events scheduledRouting purpose measure
      observedAt endExclusive
  return {
    remaining := remaining
    commitment := commitment.managed
    headroom := Quantity.ofQuanta (remaining.quanta - commitment.managed.quanta)
    unmanagedCommitment := commitment.unmanaged
    unroutedCommitment := commitment.unrouted
  }

end Loam.Application
