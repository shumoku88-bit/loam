import Loam.Core.EventMemory
import Loam.Core.ActualValidity
import Loam.Core.HistoricalRouting
import Loam.Core.Capacity
import Loam.Application.CapacityInspection

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

variable {Time : Type}

/-!
# Consumption and Remaining inspection

Slice A2 completes the first vertical slice:
- Capacity evidence -> Entitlement
- Actual Event / Effect + Actual-valid coordinate + historical Locus routing -> Consumption
- Remaining = Entitlement - Consumption

Neither Consumption nor Remaining is stored state. Both are pure projections
over retained evidence.

If any remembered Event lacks valid coordinate evidence, consumption fails
closed (`none`). Route selection uses the route visible at each Event's valid
coordinate rather than current routing. Effects in different Measures are
isolated and do not mix.
-/

/--
Project consumption contributed by a single Event at an explicit valid coordinate.
Sums the signed quantity of effects matching the queried Measure whose Locus routes
to the queried Purpose at `validOn`.
-/
def eventConsumptionAt
    [LinearOrder Time]
    (event : Event)
    (validOn : Time)
    (routing : RoutingHistory LocusId Time)
    (purpose : PurposeId)
    (measure : MeasureId) : Quantity :=
  Quantity.ofQuanta <|
    event.effects.foldr
      (fun effect total =>
        if effect.measure = measure &&
           routing.statusAt effect.locus validOn = .managed purpose then
          effect.quantity.quanta + total
        else
          total)
      0

/--
Project recorded Actual consumption for one Purpose and Measure.

Fails closed (`none`) if any Event in `events` lacks valid coordinate evidence
in `validities`.
-/
def consumptionAtRecorded?
    [LinearOrder Time]
    (events : EventMemory)
    (validities : ActualValidityMemory Time)
    (routing : RoutingHistory LocusId Time)
    (purpose : PurposeId)
    (measure : MeasureId) : Option Quantity := do
  let quanta ← events.events.foldlM
    (fun total event => do
      let validOn ← validities.findByEventId? event.id
      let eventQuantity := eventConsumptionAt event validOn routing purpose measure
      return total + eventQuantity.quanta)
    0
  return Quantity.ofQuanta quanta

/--
Project remaining capacity authority:
  Remaining = Entitlement - Consumption

Combines retained capacity movements with recorded actual consumption.
Fails closed (`none`) if consumption cannot be determined.
-/
def remainingAtRecorded?
    [LinearOrder Time]
    (movements : List CapacityMovement)
    (events : EventMemory)
    (validities : ActualValidityMemory Time)
    (routing : RoutingHistory LocusId Time)
    (purpose : PurposeId)
    (measure : MeasureId) : Option Quantity := do
  let consumption ← consumptionAtRecorded? events validities routing purpose measure
  let entitlement := entitlementAt movements purpose measure
  return Quantity.ofQuanta (entitlement.quanta - consumption.quanta)

end Loam.Application
