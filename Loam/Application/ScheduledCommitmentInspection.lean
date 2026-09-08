import Init.Data.Order
import Loam.Application.ConsumptionInspection
import Loam.Application.ScheduledInspection
import Loam.Core.AccountingRole
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
`Loam.Core.ScheduledRouting`.

Observation 227 strengthened the production household projection without adding
a fixed-cost or eligibility authority. Scheduled is a future-cashflow surface,
so a positive quantity is not by itself Capacity pressure. Explicit
ScheduledRouting selects positive pressure directly. Without a route, positive
Expense and Liability coordinates exert pressure by default, positive
Asset/Income/Equity coordinates are resolved non-pressure, and a missing
AccountingRole remains an unresolved eligibility frontier.

The current Scheduled lifecycle has no learned-time coordinate, so this module
answers only the current-open view. `observedAt` selects historical routing; it
does not pretend to reconstruct when completion, retirement, or replacement
became known.
-/

/--
Query-local Scheduled Capacity-pressure partition for one Purpose and Measure.

`managed` is only the amount routed to the queried Purpose. `unmanaged` and
`unrouted` retain selected pressure whose Purpose status is not managed.
`unresolvedEligibility` retains positive, unrouted quantity whose AccountingRole
is absent; it is neither silently counted as Commitment nor silently discarded.
-/
structure ScheduledCommitmentView where
  managed : Quantity
  unmanaged : Quantity
  unrouted : Quantity
  unresolvedEligibility : Quantity
deriving Repr, DecidableEq

/-- Arithmetic evidence for one current Headroom answer. -/
structure HeadroomView where
  remaining : Quantity
  commitment : Quantity
  headroom : Quantity
  unmanagedCommitment : Quantity
  unroutedCommitment : Quantity
  unresolvedEligibility : Quantity
deriving Repr, DecidableEq

private structure CommitmentQuanta where
  managed : Int := 0
  unmanaged : Int := 0
  unrouted : Int := 0
  unresolvedEligibility : Int := 0

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

/--
Add one positive Scheduled coordinate according to Observation 227.

Explicit routing owns explicit pressure intent. Only an unrouted positive
coordinate falls back to partial AccountingRole classification. Missing role
evidence remains visible as unresolved eligibility rather than becoming a
default role or zero pressure.
-/
private def addPositiveScheduledLocus
    (roles : AccountingRoleMap)
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
        match roles.roleOf? locus with
        | some .expense | some .liability =>
            { total with unrouted := total.unrouted + quantity.quanta }
        | some .asset | some .income | some .equity =>
            total
        | none =>
            { total with
                unresolvedEligibility := total.unresolvedEligibility + quantity.quanta }

private def addOpenOccurrence
    (roles : AccountingRoleMap)
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
      (addPositiveScheduledLocus roles routing purpose observedAt occurrence)
      total

private def commitmentFromOpenOccurrences
    (occurrences : List (ScheduledOccurrence Time))
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : ScheduledCommitmentView :=
  let total := occurrences.foldl
    (addOpenOccurrence roles routing purpose measure observedAt endExclusive)
    {}
  {
    managed := Quantity.ofQuanta total.managed
    unmanaged := Quantity.ofQuanta total.unmanaged
    unrouted := Quantity.ofQuanta total.unrouted
    unresolvedEligibility := Quantity.ofQuanta total.unresolvedEligibility
  }

/-- Project current Scheduled Capacity pressure for one Purpose and Measure. -/
def currentScheduledCommitment?
    (scheduled : ScheduledMemory Time)
    (completions : ScheduledCompletionMemory)
    (retirements : ScheduledRetirementMemory)
    (events : EventMemory)
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : Option ScheduledCommitmentView :=
  match currentOpenScheduled scheduled completions retirements events with
  | .unknownCompletionScheduled => none
  | .unknownRetirementScheduled => none
  | .conflictingTerminalEvidence => none
  | .open occurrences =>
      some <| commitmentFromOpenOccurrences
        occurrences roles routing purpose measure observedAt endExclusive

/--
Project current Scheduled Capacity pressure through explicit replacement
provenance. Any replacement-graph or lifecycle refusal fails closed as `none`.
-/
def currentScheduledCommitmentWithReplacement?
    (scheduled : ScheduledMemory Time)
    (completions : ScheduledCompletionMemory)
    (retirements : ScheduledRetirementMemory)
    (replacements : ScheduledReplacementMemory)
    (events : EventMemory)
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : Option ScheduledCommitmentView :=
  match currentOpenScheduledWithReplacement
      scheduled completions retirements replacements events with
  | .open occurrences =>
      some <| commitmentFromOpenOccurrences
        occurrences roles routing purpose measure observedAt endExclusive
  | _ => none

/--
Compose correction-aware Actual Remaining with current open Scheduled pressure.
Only managed pressure for the queried Purpose is subtracted from Remaining;
other pressure and unresolved eligibility stay visible in the answer.
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
    (roles : AccountingRoleMap)
    (scheduledRouting : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : Option HeadroomView := do
  let remaining ←
    remainingAtCorrectionFrontier?
      capacityMovements events corrections validities actualRouting purpose measure
  let commitment ←
    currentScheduledCommitment?
      scheduled completions retirements events roles scheduledRouting purpose measure
      observedAt endExclusive
  return {
    remaining := remaining
    commitment := commitment.managed
    headroom := Quantity.ofQuanta (remaining.quanta - commitment.managed.quanta)
    unmanagedCommitment := commitment.unmanaged
    unroutedCommitment := commitment.unrouted
    unresolvedEligibility := commitment.unresolvedEligibility
  }

/--
Compose correction-aware Actual Remaining with replacement-aware Scheduled
pressure. Replacement provenance changes only which retained Scheduled
occurrences contribute; Remaining remains the same correction-aware Actual
projection.
-/
def headroomAtCorrectionFrontierWithReplacement?
    (capacityMovements : List CapacityMovement)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory Time)
    (actualRouting : RoutingHistory LocusId Time)
    (scheduled : ScheduledMemory Time)
    (completions : ScheduledCompletionMemory)
    (retirements : ScheduledRetirementMemory)
    (replacements : ScheduledReplacementMemory)
    (roles : AccountingRoleMap)
    (scheduledRouting : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : Option HeadroomView := do
  let remaining ←
    remainingAtCorrectionFrontier?
      capacityMovements events corrections validities actualRouting purpose measure
  let commitment ←
    currentScheduledCommitmentWithReplacement?
      scheduled completions retirements replacements events roles scheduledRouting
      purpose measure observedAt endExclusive
  return {
    remaining := remaining
    commitment := commitment.managed
    headroom := Quantity.ofQuanta (remaining.quanta - commitment.managed.quanta)
    unmanagedCommitment := commitment.unmanaged
    unroutedCommitment := commitment.unrouted
    unresolvedEligibility := commitment.unresolvedEligibility
  }

end Loam.Application
