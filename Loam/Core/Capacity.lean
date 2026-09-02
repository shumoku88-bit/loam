import Loam.Core.BalancedMovement

namespace Loam.Core

set_option autoImplicit false

/-!
# Capacity evidence

Capacity records household allocation / spending authority rather than physical
holdings. Observation 106 allows it to reuse the same exact balanced movement
algebra as other movement-shaped entrances, but requires the semantic coordinate
to remain distinct from physical `LocusId`.

This file therefore introduces no `Plane` enum and does not reuse `LocusId` as a
Purpose by convention. The shared part is the algebra underneath the typed
wrapper.
-/

/-- Stable identity for one household purpose coordinate. -/
structure PurposeId where
  token : String
deriving Repr, DecidableEq

/--
The current minimal capacity coordinate.

`unallocated` is the capacity boundary outside named purposes. It is not a
physical Account or Locus. A Purpose is likewise not silently a physical Locus,
even if an interface later chooses to display the same text token for both.
-/
inductive CapacityCoordinate where
  | unallocated
  | purpose (purpose : PurposeId)
deriving Repr, DecidableEq

/-- Stable identity for one retained capacity movement. -/
structure CapacityMovementId where
  token : String
deriving Repr, DecidableEq

/--
One capacity-authority occurrence over the shared balanced movement algebra.

The wrapper is semantically significant: forgetting it must not make this value
contribute to physical Event holdings. Admission rules for narrower user
operations such as grant / reallocation / release remain projection / writer
questions rather than stored operation-kind fields.
-/
structure CapacityMovement where
  id : CapacityMovementId
  movement : BalancedMovement CapacityCoordinate

namespace CapacityMovement

/-- Recover the exact Measure without exposing the wrapper's representation at call sites. -/
def measure (movement : CapacityMovement) : MeasureId :=
  movement.movement.measure

/-- Project one exact signed capacity quantity at an explicit capacity coordinate. -/
def quantityAt (movement : CapacityMovement) (coordinate : CapacityCoordinate) : Quantity :=
  BalancedMovement.quantityAt movement.movement coordinate

end CapacityMovement

end Loam.Core
