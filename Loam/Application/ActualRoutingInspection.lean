import Init.Data.Order
import Loam.Application.ConsumptionInspection
import Loam.Application.CorrectionFrontier
import Loam.Core.AccountingRole
import Loam.Core.RoutingEffective

namespace Loam.Application

open Loam.Core
open Std (IsLinearOrder)

set_option autoImplicit false

variable {Time : Type}
  [LE Time]
  [DecidableRel (· ≤ · : Time → Time → Prop)]
  [Std.IsLinearOrder Time]

/-!
# Actual routing inspection with an initial effective coordinate

Actual validity remains an ordinary `Time`. Historical routing may additionally
retain one `initial` coordinate that precedes every dated route. The selected
Actual occurrence is therefore queried at `.dated validOn` without fabricating a
calendar date for the initial policy.

The quantity arithmetic remains owned by `ConsumptionInspection`; this module is
only the composition boundary between ordinary Actual validity and the
routing-specific effective coordinate selected by Observation 156.
-/

/-- One explicit current-window Effect whose Locus has no visible Actual route. -/
structure UnroutedActualRow (Time : Type) where
  event : EventId
  validOn : Time
  locus : LocusId
  measure : MeasureId
  quantity : Quantity
  role : Option AccountingRole
deriving Repr, DecidableEq

private def inClosed (start observedAt value : Time) : Bool :=
  decide (start ≤ value) && decide (value ≤ observedAt)

/--
Derive every nonzero Effect in one Measure whose Locus is unrouted at the
Event's current valid coordinate inside the closed current window.

The row preserves signed quantity and optional AccountingRole only as evidence.
This function does not decide whether the row should block or warn at a higher
household surface.
-/
def unroutedActualRows?
    (events : EventMemory)
    (validities : ActualValidityMemory Time)
    (routing : RoutingHistory LocusId (RoutingEffective Time))
    (roles : AccountingRoleMap)
    (start observedAt : Time)
    (measure : MeasureId) : Option (List (UnroutedActualRow Time)) := do
  if !(decide (start ≤ observedAt)) then
    none
  else
    events.events.foldlM
      (fun rows event => do
        let validOn ← validities.findByEventId? event.id
        if !inClosed start observedAt validOn then
          return rows
        let eventRows :=
          event.effects.filterMap fun effect =>
            if effect.measure != measure || effect.quantity.quanta == 0 then
              none
            else if routing.statusAt effect.locus (.dated validOn) != .unrouted then
              none
            else
              some {
                event := event.id
                validOn := validOn
                locus := effect.locus
                measure := effect.measure
                quantity := effect.quantity
                role := roles.roleOf? effect.locus
              }
        return rows ++ eventRows)
      []

/-- Project one Event's Consumption while preserving an explicit initial route. -/
def eventConsumptionAtEffectiveRouting
    (event : Event)
    (validOn : Time)
    (routing : RoutingHistory LocusId (RoutingEffective Time))
    (purpose : PurposeId)
    (measure : MeasureId) : Quantity :=
  eventConsumptionAt event (.dated validOn) routing purpose measure

/--
Project recorded Actual Consumption with initial-aware historical routing.
Fails closed when any retained Event lacks its ordinary Actual-valid coordinate.
-/
def consumptionAtRecordedEffectiveRouting?
    (events : EventMemory)
    (validities : ActualValidityMemory Time)
    (routing : RoutingHistory LocusId (RoutingEffective Time))
    (purpose : PurposeId)
    (measure : MeasureId) : Option Quantity :=
  foldRecordedConsumptionWhere? events validities
    (fun _ => true)
    (fun event validOn =>
      eventConsumptionAtEffectiveRouting event validOn routing purpose measure)

/-- Apply the admitted Event-correction frontier before initial-aware Consumption. -/
def consumptionAtCorrectionFrontierEffectiveRouting?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory Time)
    (routing : RoutingHistory LocusId (RoutingEffective Time))
    (purpose : PurposeId)
    (measure : MeasureId) : Option Quantity := do
  let frontier ← correctionFrontierMemory? events corrections
  consumptionAtRecordedEffectiveRouting? frontier validities routing purpose measure

/--
Project Remaining from Capacity authority and recorded Actuals using
initial-aware historical routing.
-/
def remainingAtRecordedEffectiveRouting?
    (movements : List CapacityMovement)
    (events : EventMemory)
    (validities : ActualValidityMemory Time)
    (routing : RoutingHistory LocusId (RoutingEffective Time))
    (purpose : PurposeId)
    (measure : MeasureId) : Option Quantity := do
  let consumption ←
    consumptionAtRecordedEffectiveRouting? events validities routing purpose measure
  let entitlement := entitlementAt movements purpose measure
  return Quantity.ofQuanta (entitlement.quanta - consumption.quanta)

/--
Project correction-aware Remaining while preserving initial historical routing.
Capacity remains independent authority evidence.
-/
def remainingAtCorrectionFrontierEffectiveRouting?
    (movements : List CapacityMovement)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory Time)
    (routing : RoutingHistory LocusId (RoutingEffective Time))
    (purpose : PurposeId)
    (measure : MeasureId) : Option Quantity := do
  let consumption ←
    consumptionAtCorrectionFrontierEffectiveRouting?
      events corrections validities routing purpose measure
  let entitlement := entitlementAt movements purpose measure
  return Quantity.ofQuanta (entitlement.quanta - consumption.quanta)

end Loam.Application
