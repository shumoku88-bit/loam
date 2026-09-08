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
- current-open replacement-aware Scheduled + routing/role evidence -> Commitment.

The result is explicitly current. `currentWindowStart` bounds effective Capacity
and elapsed Actual Consumption, inclusive through `observedAt`. The same `observedAt` selects
Scheduled-routing evidence and starts future current-open pressure;
`endExclusive` ends only that Scheduled horizon. This is not historical
Scheduled replay and is not the historical Budget Window report.

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
Compose current elapsed Capacity/Actual evidence with replacement-aware
current-open Scheduled pressure for one Purpose and Measure.

Fails closed when effective Capacity, correction-aware Actual consumption, or
current-open Scheduled pressure cannot be justified from retained evidence.
-/
def currentCoverageAtCorrectionFrontierWithReplacement?
    (capacity : CapacityMemory)
    (effective : CapacityEffectiveMemory Time)
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
    (currentWindowStart observedAt endExclusive : Time) : Option CurrentCoverageView := do
  let consumption ←
    consumptionAtCorrectionFrontierThrough?
      events corrections validities actualRouting currentWindowStart observedAt purpose measure
  let commitment ←
    currentScheduledCommitmentWithReplacement?
      scheduled completions retirements replacements events roles scheduledRouting
      purpose measure observedAt endExclusive
  let entitlement ← entitlementAtEffectiveThrough?
    capacity effective currentWindowStart observedAt purpose measure
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

/--
Production-compatible current coverage using the explicit `initial | dated`
Actual-routing coordinate retained by `ActualRoutingPersistence`.

This is the same current coverage arithmetic as
`currentCoverageAtCorrectionFrontierWithReplacement?`; only the Actual routing
composition boundary differs. No initial calendar date is fabricated.
-/
def currentCoverageAtCorrectionFrontierEffectiveRoutingWithReplacement?
    (capacity : CapacityMemory)
    (effective : CapacityEffectiveMemory Time)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory Time)
    (actualRouting : RoutingHistory LocusId (RoutingEffective Time))
    (scheduled : ScheduledMemory Time)
    (completions : ScheduledCompletionMemory)
    (retirements : ScheduledRetirementMemory)
    (replacements : ScheduledReplacementMemory)
    (roles : AccountingRoleMap)
    (scheduledRouting : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (currentWindowStart observedAt endExclusive : Time) : Option CurrentCoverageView := do
  let consumption ←
    consumptionAtCorrectionFrontierEffectiveRoutingThrough?
      events corrections validities actualRouting currentWindowStart observedAt purpose measure
  let commitment ←
    currentScheduledCommitmentWithReplacement?
      scheduled completions retirements replacements events roles scheduledRouting
      purpose measure observedAt endExclusive
  let entitlement ← entitlementAtEffectiveThrough?
    capacity effective currentWindowStart observedAt purpose measure
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
