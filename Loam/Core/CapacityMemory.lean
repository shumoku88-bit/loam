import Loam.Core.Capacity

namespace Loam.Core

set_option autoImplicit false

/-!
# Capacity movement memory

Retained capacity authority needs stable movement identity once it crosses the
runtime persistence boundary. Representation order remains deterministic storage
only: it does not become temporal, causal, priority, or winner semantics.
-/

/--
Append-oriented memory for retained Capacity movements.

Only movement identity is unique here. Coordinate-level meaning is derived from
the signed movement evidence itself.
-/
structure CapacityMemory where
  movements : List CapacityMovement
  idNodup : (movements.map CapacityMovement.id).Nodup

namespace CapacityMemory

/-- Admit runtime capacity movements only when stable movement identity is unique. -/
def ofMovements? (movements : List CapacityMovement) : Option CapacityMemory :=
  if h : (movements.map CapacityMovement.id).Nodup then
    some { movements := movements, idNodup := h }
  else
    none

/-- Append one retained capacity movement, rejecting repeated identity. -/
def add? (memory : CapacityMemory) (movement : CapacityMovement) : Option CapacityMemory :=
  ofMovements? (memory.movements ++ [movement])

private def findMovementById? :
    List CapacityMovement → CapacityMovementId → Option CapacityMovement
  | [], _ => none
  | movement :: rest, id =>
      if movement.id = id then
        some movement
      else
        findMovementById? rest id

/-- Find one retained capacity movement by stable identity. -/
def findById?
    (memory : CapacityMemory)
    (id : CapacityMovementId) : Option CapacityMovement :=
  findMovementById? memory.movements id

@[simp] theorem ofMovements?_nil :
    ofMovements? [] = some { movements := [], idNodup := by simp } := by
  simp [ofMovements?]

@[simp] theorem ofMovements?_singleton (movement : CapacityMovement) :
    ofMovements? [movement] = some { movements := [movement], idNodup := by simp } := by
  simp [ofMovements?]

@[simp] theorem add?_empty (movement : CapacityMovement) :
    add? { movements := [], idNodup := by simp } movement =
      some { movements := [movement], idNodup := by simp } := by
  simp [add?, ofMovements?]

end CapacityMemory

end Loam.Core
