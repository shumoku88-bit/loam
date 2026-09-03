import Loam.Core.Capacity

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Capacity inspection

Retained `CapacityMovement` evidence owns allocation authority. Household-facing
Entitlement and the practical current-source admission question are projections
over that evidence; neither introduces mutable balance state.

No Envelope object, mutable balance field, grant/reallocation/release kind, or
physical holding mutation is introduced here.
-/

/--
Sum retained capacity evidence at one capacity coordinate and Measure.

Movements in another Measure do not contribute. The complete movement stays
balanced, while a selected Purpose coordinate can have a non-zero capacity
quantity, just as a selected physical holding projection can change inside a
closed value movement.
-/
def capacityAt
    (movements : List CapacityMovement)
    (coordinate : CapacityCoordinate)
    (measure : MeasureId) : Quantity :=
  Quantity.ofQuanta <|
    movements.foldr
      (fun movement total =>
        if movement.measure = measure then
          (movement.quantityAt coordinate).quanta + total
        else
          total)
      0

/-- Household-facing entitlement is the capacity projection at one Purpose. -/
def entitlementAt
    (movements : List CapacityMovement)
    (purpose : PurposeId)
    (measure : MeasureId) : Quantity :=
  capacityAt movements (.purpose purpose) measure

/--
Whether the practical current Capacity entrance may provide `quanta` from one
source coordinate.

`unallocated` is an outside balancing boundary and is therefore not treated as
a finite stock. A named Purpose, by contrast, may provide only a positive
quantity no larger than its currently derived Entitlement.

This is deliberately a current-writer question. It does not claim that untimed
retained Capacity history can reconstruct historical admission; Observation 112
keeps that temporal question separate.
-/
def canMoveCapacityFrom
    (movements : List CapacityMovement)
    (source : CapacityCoordinate)
    (measure : MeasureId)
    (quanta : Int) : Bool :=
  if quanta <= 0 then
    false
  else
    match source with
    | .unallocated => true
    | .purpose purpose =>
        if quanta <= (entitlementAt movements purpose measure).quanta then
          true
        else
          false

/-- With no retained capacity evidence, one Purpose has exact zero entitlement. -/
@[simp] theorem entitlementAt_nil (purpose : PurposeId) (measure : MeasureId) :
    entitlementAt [] purpose measure = 0 := by
  rfl

end Loam.Application
