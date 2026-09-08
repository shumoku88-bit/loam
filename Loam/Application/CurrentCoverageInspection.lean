import Init.Data.Order
import Loam.Application.CapacityInspection
import Loam.Application.ConsumptionInspection
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

- all-retained Capacity -> Entitlement;
- correction-frontier Actual + historical Actual routing -> Consumption;
- current-open replacement-aware Scheduled + routing/role evidence -> Commitment.

The result is explicitly current. `observedAt` selects Scheduled-routing evidence
visible to the current-open lifecycle answer, while `endExclusive` is only the
future Scheduled horizon. There is deliberately no `start` coordinate and no
claim of historical Scheduled replay.

No status, recommendation, `SafeToSpend`, Budget object, or retained Coverage
state is introduced. Presentation may derive labels such as OVER NOW or FUTURE
SHORT from the returned quantities while keeping unresolved pressure visible.
-/

/--
One current Purpose coverage answer. Unmanaged, unrouted, and unresolved future
pressure remain explicit rather than being guessed into managed Commitment.
-/
structure CurrentCoverageView where
  entitlement : Quantity
  consumption : Quantity
  remaining : Quantity
  commitment : Quantity
  headroom : Quantity
  unmanagedCommitment : Quantity
  unroutedCommitment : Quantity
  unresolvedEligibility : Quantity
  deriving Repr, DecidableEq

/--
Compose current all-retained Capacity/Actual evidence with replacement-aware
current-open Scheduled pressure for one Purpose and Measure.

Fails closed when either correction-aware Actual consumption or current-open
Scheduled pressure cannot be justified from retained evidence.
-/
def currentCoverageAtCorrectionFrontierWithReplacement?
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
    (observedAt endExclusive : Time) : Option CurrentCoverageView := do
  let consumption ←
    consumptionAtCorrectionFrontier?
      events corrections validities actualRouting purpose measure
  let commitment ←
    currentScheduledCommitmentWithReplacement?
      scheduled completions retirements replacements events roles scheduledRouting
      purpose measure observedAt endExclusive
  let entitlement := entitlementAt capacityMovements purpose measure
  let remaining := Quantity.ofQuanta (entitlement.quanta - consumption.quanta)
  return {
    entitlement := entitlement
    consumption := consumption
    remaining := remaining
    commitment := commitment.managed
    headroom := Quantity.ofQuanta (remaining.quanta - commitment.managed.quanta)
    unmanagedCommitment := commitment.unmanaged
    unroutedCommitment := commitment.unrouted
    unresolvedEligibility := commitment.unresolvedEligibility
  }

end Loam.Application
