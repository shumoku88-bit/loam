import Loam.Application.CapacityWindowInspection

namespace Loam.Observations.Observation243

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
Observation 243

Global canonical-basis witness for Capacity effective-coordinate evidence.

Two worlds retain exactly the same Capacity movement and differ only in the
movement's effective coordinate. A current production window query distinguishes
the worlds.
-/

private def food : PurposeId := ⟨"food"⟩
private def jpy : MeasureId := ⟨"jpy"⟩

private def grantMovement : CapacityMovement :=
  {
    id := ⟨"capacity-witness"⟩
    movement := {
      measure := jpy
      changes := [
        { coordinate := .unallocated, quantity := Quantity.ofQuanta (-100) },
        { coordinate := .purpose food, quantity := Quantity.ofQuanta 100 }
      ]
      balanced := by decide
    }
  }

private def capacity : CapacityMemory :=
  { movements := [grantMovement], idNodup := by simp }

private def effectiveInside : CapacityEffectiveMemory Nat :=
  {
    entries := [{ movement := grantMovement.id, effectiveOn := 1 }]
    movementNodup := by simp
  }

private def effectiveOutside : CapacityEffectiveMemory Nat :=
  {
    entries := [{ movement := grantMovement.id, effectiveOn := 3 }]
    movementNodup := by simp
  }

/-- The movement contributes when its independent effective coordinate is inside `[0, 2)`. -/
theorem inside_world_has_entitlement :
    entitlementAtEffectiveWindow? capacity effectiveInside 0 2 food jpy =
      some (Quantity.ofQuanta 100) := by
  decide

/-- The identical movement does not contribute when only its effective coordinate moves outside `[0, 2)`. -/
theorem outside_world_has_zero_entitlement :
    entitlementAtEffectiveWindow? capacity effectiveOutside 0 2 food jpy =
      some (Quantity.ofQuanta 0) := by
  decide

/--
Erasing effective-coordinate evidence identifies two worlds that the current
windowed Capacity operation vocabulary can distinguish.
-/
theorem capacity_effective_is_q_observable :
    entitlementAtEffectiveWindow? capacity effectiveInside 0 2 food jpy ≠
      entitlementAtEffectiveWindow? capacity effectiveOutside 0 2 food jpy := by
  rw [inside_world_has_entitlement, outside_world_has_zero_entitlement]
  decide

end Loam.Observations.Observation243
