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

Unlike the first experiment, the admitted aggregate now carries that closure as
a proof field. Downstream code that receives a `CapacityEvidence` therefore does
not need to rescan both memories merely to rediscover the same cross-family fact.
-/

/-- Whether both retained families refer to exactly the same movement identities. -/
def capacityReferencesComplete
    (movements : CapacityMemory)
    (effective : CapacityEffectiveMemory Time) : Bool :=
  movements.movements.all
      (fun movement => (effective.findByMovementId? movement.id).isSome) &&
    effective.entries.all
      (fun entry => (movements.findById? entry.movement).isSome)

/-- One complete admitted Capacity image. -/
structure CapacityEvidence (Time : Type) where
  movements : CapacityMemory
  effective : CapacityEffectiveMemory Time
  complete : capacityReferencesComplete movements effective = true

namespace CapacityEvidence

/-- Public name for the carried cross-family completeness predicate. -/
def referencesComplete
    (movements : CapacityMemory)
    (effective : CapacityEffectiveMemory Time) : Bool :=
  capacityReferencesComplete movements effective

/--
Admit one persistence-neutral Capacity image only when every movement has one
effective coordinate and every effective coordinate names a retained movement.
Uniqueness inside each family remains owned by the two existing memory types.
-/
def ofParts?
    (movements : CapacityMemory)
    (effective : CapacityEffectiveMemory Time) : Option (CapacityEvidence Time) :=
  if h : capacityReferencesComplete movements effective = true then
    some {
      movements := movements
      effective := effective
      complete := h
    }
  else
    none

/-- The empty pair is a complete Capacity image. -/
def empty : CapacityEvidence Time := {
  movements := { movements := [], idNodup := by simp }
  effective := { entries := [], movementNodup := by simp }
  complete := by rfl
}

/-- Every admitted Capacity image carries the complete-reference law. -/
theorem complete_references (evidence : CapacityEvidence Time) :
    referencesComplete evidence.movements evidence.effective = true := by
  exact evidence.complete

end CapacityEvidence

end Loam
