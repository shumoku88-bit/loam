import Init.Data.Order
import Loam.Application.ActualRoutingInspection
import Loam.Application.CorrectionFrontier
import Loam.Core.CapacityEffective
import Loam.Core.CapacityMemory

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

variable {Time : Type}
  [LE Time]
  [DecidableRel (· ≤ · : Time → Time → Prop)]
  [Std.IsLinearOrder Time]

/-!
# Coordinate-window Capacity inspection

Observation 158 qualified the current household budget pressure as a coordinate
selection problem rather than evidence for a retained BudgetPeriod identity.
This module therefore introduces no Period / Cycle / Envelope object. Callers
supply a half-open `[start, end)` query window directly.

Capacity effective coordinates and Actual valid coordinates remain independent
evidence. Missing temporal evidence fails closed rather than being guessed from
storage order or current time.
-/

private def strictBefore (left right : Time) : Bool :=
  decide (left ≤ right) && !(decide (right ≤ left))

private def inHalfOpen (start end_ value : Time) : Bool :=
  decide (start ≤ value) && !(decide (end_ ≤ value))

/-- A query window must have a strictly earlier start coordinate. -/
def validCapacityWindow (start end_ : Time) : Bool :=
  strictBefore start end_

private def effectiveEvidenceComplete
    (capacity : CapacityMemory)
    (effective : CapacityEffectiveMemory Time) : Bool :=
  capacity.movements.all
      (fun movement => (effective.findByMovementId? movement.id).isSome) &&
    effective.entries.all
      (fun entry => (capacity.findById? entry.movement).isSome)

/--
Project Capacity at one coordinate inside `[start, end)`.

The projection refuses an invalid window, missing effective coordinates, and
orphan effective evidence. Representation order never supplies missing time.
-/
def capacityAtEffectiveWindow?
    (capacity : CapacityMemory)
    (effective : CapacityEffectiveMemory Time)
    (start end_ : Time)
    (coordinate : CapacityCoordinate)
    (measure : MeasureId) : Option Quantity := do
  if !validCapacityWindow start end_ then
    none
  else if !effectiveEvidenceComplete capacity effective then
    none
  else
    let quanta ← capacity.movements.foldlM
      (fun total movement => do
        let effectiveOn ← effective.findByMovementId? movement.id
        if inHalfOpen start end_ effectiveOn && movement.measure = measure then
          return total + (movement.quantityAt coordinate).quanta
        else
          return total)
      0
    return Quantity.ofQuanta quanta

/-- Household-facing Entitlement selected by Purpose and half-open time window. -/
def entitlementAtEffectiveWindow?
    (capacity : CapacityMemory)
    (effective : CapacityEffectiveMemory Time)
    (start end_ : Time)
    (purpose : PurposeId)
    (measure : MeasureId) : Option Quantity :=
  capacityAtEffectiveWindow? capacity effective start end_ (.purpose purpose) measure

/--
Project recorded Actual Consumption whose valid coordinates fall in `[start, end)`.
Every retained Event still requires validity evidence, even if it might turn out
to be outside the window; otherwise membership would be guessed.
-/
def consumptionAtRecordedEffectiveRoutingWindow?
    (events : EventMemory)
    (validities : ActualValidityMemory Time)
    (routing : RoutingHistory LocusId (RoutingEffective Time))
    (start end_ : Time)
    (purpose : PurposeId)
    (measure : MeasureId) : Option Quantity := do
  if !validCapacityWindow start end_ then
    none
  else
    let quanta ← events.events.foldlM
      (fun total event => do
        let validOn ← validities.findByEventId? event.id
        if inHalfOpen start end_ validOn then
          let eventQuantity :=
            eventConsumptionAtEffectiveRouting event validOn routing purpose measure
          return total + eventQuantity.quanta
        else
          return total)
      0
    return Quantity.ofQuanta quanta

/-- Apply Event correction authority before windowed Actual Consumption. -/
def consumptionAtCorrectionFrontierEffectiveRoutingWindow?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory Time)
    (routing : RoutingHistory LocusId (RoutingEffective Time))
    (start end_ : Time)
    (purpose : PurposeId)
    (measure : MeasureId) : Option Quantity := do
  let frontier ← correctionFrontierMemory? events corrections
  consumptionAtRecordedEffectiveRoutingWindow?
    frontier validities routing start end_ purpose measure

/--
Remaining is a projection, not retained state:
windowed Entitlement minus windowed correction-aware Actual Consumption.
-/
def remainingAtEffectiveWindow?
    (capacity : CapacityMemory)
    (effective : CapacityEffectiveMemory Time)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory Time)
    (routing : RoutingHistory LocusId (RoutingEffective Time))
    (start end_ : Time)
    (purpose : PurposeId)
    (measure : MeasureId) : Option Quantity := do
  let entitlement ←
    entitlementAtEffectiveWindow? capacity effective start end_ purpose measure
  let consumption ←
    consumptionAtCorrectionFrontierEffectiveRoutingWindow?
      events corrections validities routing start end_ purpose measure
  return Quantity.ofQuanta (entitlement.quanta - consumption.quanta)

end Loam.Application
