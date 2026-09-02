import Loam.Core.Capacity

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Capacity inspection

The first capacity application operation is deliberately read-only. Retained
`CapacityMovement` evidence owns allocation authority; `entitlementAt` is only a
projection over that evidence.

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

/-- With no retained capacity evidence, one Purpose has exact zero entitlement. -/
@[simp] theorem entitlementAt_nil (purpose : PurposeId) (measure : MeasureId) :
    entitlementAt [] purpose measure = 0 := by
  rfl

end Loam.Application
