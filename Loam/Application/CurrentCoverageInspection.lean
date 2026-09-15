import Init.Data.Order
import Loam.Application.CapacityWindowInspection
import Loam.Application.ScheduledCommitmentInspection

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

variable {Time : Type}
  [DecidableEq Time]
  [LE Time]
  [DecidableRel (· ≤ · : Time → Time → Prop)]
  [Std.IsLinearOrder Time]

/-!
# Current Capacity coverage inspection

This module composes the already-qualified current household observations needed
for one decision-support answer without mixing coordinate systems:

- current elapsed effective Capacity -> Entitlement;
- correction-frontier Actual + historical Actual routing -> Consumption;
- current-open Scheduled + routing/role evidence -> Commitment.

Completion, retirement, and replacement are ordinary target forms of one
Scheduled-terminal relation at this boundary; replacement is no longer a second
Application entrance.

The result is explicitly current. `currentWindowStart` bounds effective Capacity
and elapsed Actual Consumption, inclusive through `observedAt`. The same
`observedAt` selects Scheduled-routing evidence and starts future current-open
pressure; `endExclusive` ends only that Scheduled horizon. This is not historical
Scheduled replay and is not the historical Budget Window report.
-/

structure CurrentCoverageView where
  entitlement : Quantity
  consumption : Quantity
  commitment : Quantity
  unmanagedCommitment : Quantity
  unroutedCommitment : Quantity
  unresolvedEligibility : Quantity
  deriving Repr, DecidableEq

/-- Current Remaining is uniquely derived from Entitlement and Consumption. -/
def CurrentCoverageView.remaining (view : CurrentCoverageView) : Quantity :=
  view.entitlement - view.consumption

/-- Current Headroom is uniquely derived from Remaining and managed Commitment. -/
def CurrentCoverageView.headroom (view : CurrentCoverageView) : Quantity :=
  view.remaining - view.commitment

@[simp] theorem CurrentCoverageView.remaining_eq_components (view : CurrentCoverageView) :
    view.remaining = view.entitlement - view.consumption :=
  rfl

@[simp] theorem CurrentCoverageView.headroom_eq_components (view : CurrentCoverageView) :
    view.headroom = (view.entitlement - view.consumption) - view.commitment :=
  rfl

private def assembleCurrentCoverage
    (entitlement consumption : Quantity)
    (commitment : ScheduledCommitmentView) : CurrentCoverageView :=
  {
    entitlement := entitlement
    consumption := consumption
    commitment := commitment.managed
    unmanagedCommitment := commitment.unmanaged
    unroutedCommitment := commitment.unrouted
    unresolvedEligibility := commitment.unresolvedEligibility
  }

/--
Compose current elapsed Capacity/Actual evidence with current-open Scheduled
pressure for one Purpose and Measure.
-/
def currentCoverageAtCorrectionFrontier?
    (capacity : CapacityMemory)
    (effective : CapacityEffectiveMemory Time)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory Time)
    (actualRouting : RoutingHistory LocusId Time)
    (scheduled : ScheduledMemory Time)
    (terminals : ScheduledTerminalMemory)
    (roles : AccountingRoleMap)
    (scheduledRouting : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (currentWindowStart observedAt endExclusive : Time) : Option CurrentCoverageView := do
  let consumption ←
    consumptionAtCorrectionFrontierThrough?
      events corrections validities actualRouting currentWindowStart observedAt purpose measure
  let commitment ←
    currentScheduledCommitment?
      scheduled terminals events roles scheduledRouting
      purpose measure observedAt endExclusive
  let entitlement ← entitlementAtEffectiveThrough?
    capacity effective currentWindowStart observedAt purpose measure
  return assembleCurrentCoverage entitlement consumption commitment

/--
Production-compatible current coverage using the explicit `initial | dated`
Actual-routing coordinate retained by `ActualRoutingPersistence`.

This is the same current coverage arithmetic as `currentCoverageAtCorrectionFrontier?`;
only the Actual routing composition boundary differs. No initial calendar date is
fabricated.
-/
def currentCoverageAtCorrectionFrontierEffectiveRouting?
    (capacity : CapacityMemory)
    (effective : CapacityEffectiveMemory Time)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory Time)
    (actualRouting : RoutingHistory LocusId (RoutingEffective Time))
    (scheduled : ScheduledMemory Time)
    (terminals : ScheduledTerminalMemory)
    (roles : AccountingRoleMap)
    (scheduledRouting : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (currentWindowStart observedAt endExclusive : Time) : Option CurrentCoverageView := do
  let consumption ←
    consumptionAtCorrectionFrontierEffectiveRoutingThrough?
      events corrections validities actualRouting currentWindowStart observedAt purpose measure
  let commitment ←
    currentScheduledCommitment?
      scheduled terminals events roles scheduledRouting
      purpose measure observedAt endExclusive
  let entitlement ← entitlementAtEffectiveThrough?
    capacity effective currentWindowStart observedAt purpose measure
  return assembleCurrentCoverage entitlement consumption commitment

end Loam.Application
