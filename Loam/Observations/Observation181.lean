import Loam.Application.CapacityWindowInspection
import Loam.Observations.Observation180

namespace Loam.Observation181

open Loam.Core
open Loam.Application

set_option autoImplicit false

variable {Time : Type}
  [LE Time]
  [DecidableRel (· ≤ · : Time → Time → Prop)]
  [Std.IsLinearOrder Time]

/-!
# Observation 181 — Budget Window derived projection redundancy

Observation 180 distinguished independent observations from useful derived
observations. The practical Budget Window report is the first production-facing
field trial: it displays Entitlement, Consumption, and Remaining even though the
Application definition already specifies Remaining as Entitlement minus
Consumption.

This observation does not remove Remaining from the report. It asks the smaller
question needed for a safe follow-up implementation change: once the first two
projection results have already been obtained from one immutable loaded
snapshot, is a second call through `remainingAtEffectiveWindow?` semantically
necessary?
-/

/-- The exact arithmetic used by the production Remaining projection. -/
def remainingFromComponents
    (entitlement consumption : Quantity) : Quantity :=
  Quantity.ofQuanta (entitlement.quanta - consumption.quanta)

/--
If the two production component queries resolve, production Remaining is exactly
their derived difference. No third independent observation exists at this
boundary.
-/
theorem remaining_of_resolved_components
    (capacity : CapacityMemory)
    (effective : CapacityEffectiveMemory Time)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory Time)
    (routing : RoutingHistory LocusId (RoutingEffective Time))
    (start end_ : Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (entitlement consumption : Quantity)
    (hEntitlement :
      entitlementAtEffectiveWindow?
        capacity effective start end_ purpose measure = some entitlement)
    (hConsumption :
      consumptionAtCorrectionFrontierEffectiveRoutingWindow?
        events corrections validities routing start end_ purpose measure =
          some consumption) :
    remainingAtEffectiveWindow?
      capacity effective events corrections validities routing
      start end_ purpose measure =
        some (remainingFromComponents entitlement consumption) := by
  simp [remainingAtEffectiveWindow?, hEntitlement, hConsumption,
    remainingFromComponents]

/--
If Entitlement is unresolved, Remaining is unresolved too. Remaining cannot
supply an independent answer beyond the component frontier.
-/
theorem remaining_none_if_entitlement_none
    (capacity : CapacityMemory)
    (effective : CapacityEffectiveMemory Time)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory Time)
    (routing : RoutingHistory LocusId (RoutingEffective Time))
    (start end_ : Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (hEntitlement :
      entitlementAtEffectiveWindow?
        capacity effective start end_ purpose measure = none) :
    remainingAtEffectiveWindow?
      capacity effective events corrections validities routing
      start end_ purpose measure = none := by
  simp [remainingAtEffectiveWindow?, hEntitlement]

/--
Likewise, once Entitlement resolves, unresolved Consumption forces unresolved
Remaining. The third report field has no wider success domain than the first two
combined.
-/
theorem remaining_none_if_consumption_none
    (capacity : CapacityMemory)
    (effective : CapacityEffectiveMemory Time)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory Time)
    (routing : RoutingHistory LocusId (RoutingEffective Time))
    (start end_ : Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (entitlement : Quantity)
    (hEntitlement :
      entitlementAtEffectiveWindow?
        capacity effective start end_ purpose measure = some entitlement)
    (hConsumption :
      consumptionAtCorrectionFrontierEffectiveRoutingWindow?
        events corrections validities routing start end_ purpose measure = none) :
    remainingAtEffectiveWindow?
      capacity effective events corrections validities routing
      start end_ purpose measure = none := by
  simp [remainingAtEffectiveWindow?, hEntitlement, hConsumption]

/-! ## Concrete report arithmetic -/

/-- The existing practical Budget Window fixture is 100 - 30 = 70. -/
theorem practical_fixture_remaining :
    remainingFromComponents
      (Quantity.ofQuanta 100) (Quantity.ofQuanta 30) =
        Quantity.ofQuanta 70 := by
  decide

/-- Entitlement alone is insufficient to determine Remaining. -/
theorem entitlement_alone_does_not_determine_remaining :
    remainingFromComponents
        (Quantity.ofQuanta 100) (Quantity.ofQuanta 30) ≠
      remainingFromComponents
        (Quantity.ofQuanta 100) (Quantity.ofQuanta 40) := by
  decide

/-- Consumption alone is likewise insufficient to determine Remaining. -/
theorem consumption_alone_does_not_determine_remaining :
    remainingFromComponents
        (Quantity.ofQuanta 100) (Quantity.ofQuanta 30) ≠
      remainingFromComponents
        (Quantity.ofQuanta 110) (Quantity.ofQuanta 30) := by
  decide

/-!
The practical classification is therefore:

* Entitlement: independent component observation for this report;
* Consumption: independent component observation for this report;
* Remaining: derived observation, useful to display but determined by the two
  components once both resolve.

A later production change may compute Remaining from the already-resolved CLI
component values instead of invoking `remainingAtEffectiveWindow?` a second
time. That change must preserve the existing fail-closed component frontier and
must not turn this observation into a universal rule for unrelated reports.
-/

end Loam.Observation181
