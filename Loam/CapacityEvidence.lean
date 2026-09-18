import Loam.Core.CapacityEffective
import Loam.Core.CapacityMemory

namespace Loam

open Loam.Core

set_option autoImplicit false

/-!
# Capacity evidence aggregate

Persistence-neutral composition of the two independently retained Capacity
meanings: balanced Capacity movements and their effective coordinates.

This aggregate does not make effective time a field of CapacityMovement.
It only states the same-generation closure required when both families are
published as one complete image.
-/

/-- One complete candidate Capacity image, before cross-family admission. -/
structure CapacityEvidence where
  movements : CapacityMemory
  effective : CapacityEffectiveMemory String

namespace CapacityEvidence

/-- Whether both retained families refer to exactly the same movement identities. -/
def referencesComplete
    (movements : CapacityMemory)
    (effective : CapacityEffectiveMemory String) : Bool :=
  movements.movements.all
      (fun movement => (effective.findByMovementId? movement.id).isSome) &&
    effective.entries.all
      (fun entry => (movements.findById? entry.movement).isSome)

/--
Admit one persistence-neutral Capacity image only when every movement has one
effective coordinate and every effective coordinate names a retained movement.
Uniqueness inside each family remains owned by the two existing memory types.
-/
def ofParts?
    (movements : CapacityMemory)
    (effective : CapacityEffectiveMemory String) : Option CapacityEvidence :=
  if referencesComplete movements effective then
    some { movements := movements, effective := effective }
  else
    none

/-- The empty pair is a complete Capacity image. -/
def empty : CapacityEvidence := {
  movements := { movements := [], idNodup := by simp }
  effective := { entries := [], movementNodup := by simp }
}

@[simp] theorem ofParts?_empty :
    ofParts? empty.movements empty.effective = some empty := by
  rfl

end CapacityEvidence

end Loam
