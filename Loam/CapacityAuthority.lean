import Loam.Core.CapacityEffective
import Loam.Core.CapacityMemory
import Loam.Persistence.CapacityEffectivePersistence
import Loam.Persistence.CapacityPersistence

namespace Loam.CapacityAuthority

open Loam.Core

set_option autoImplicit false

/-!
# Capacity authority boundary

CapacityMovement and CapacityEffective remain distinct retained meanings. This
module owns only their current physical placement.

Callers receive one Capacity authority handle (`capacityPath`) and never derive
the adjacent `.effective` path themselves. The current two-file representation
therefore remains replaceable without changing Application, review, CLI, or TUI
semantics.

This is deliberately local rather than a generic repository abstraction.
-/

/-- One decoded view of the two currently retained Capacity semantic families. -/
structure Image where
  movements : CapacityMemory
  effective : CapacityEffectiveMemory String

private def effectivePath (capacityPath : System.FilePath) : System.FilePath :=
  Loam.Persistence.capacityEffectivePathForMemory capacityPath

private def emptyMovements : CapacityMemory :=
  { movements := [], idNodup := by simp }

private def emptyEffective : CapacityEffectiveMemory String :=
  { entries := [], movementNodup := by simp }

/--
Load the practical optional Capacity authority used by the existing writer and
line `show-window` entrance. Missing storage means an empty retained family;
malformed existing storage still fails closed.
-/
def loadOrEmpty (capacityPath : System.FilePath) : IO (Except String Image) := do
  let movements ←
    if ← capacityPath.pathExists then
      match ← Loam.Persistence.loadCapacityMemory? capacityPath with
      | some memory => pure memory
      | none => return .error "Malformed or unsupported Capacity authority."
    else
      pure emptyMovements

  let companion := effectivePath capacityPath
  let effective ←
    if ← companion.pathExists then
      match ← Loam.Persistence.loadCapacityEffectiveMemory? companion with
      | some memory => pure memory
      | none => return .error "Malformed or unsupported Capacity effective evidence."
    else
      pure emptyEffective

  return .ok { movements := movements, effective := effective }

/--
Load both required Capacity families for production projections that require an
explicit complete authority. Missing and malformed states remain distinguishable
through the existing user-facing errors, while callers no longer know the
companion filename.
-/
def loadRequired (capacityPath : System.FilePath) : IO (Except String Image) := do
  if !(← capacityPath.pathExists) then
    return .error ("loam: required Capacity authority not found: " ++ capacityPath.toString)

  let companion := effectivePath capacityPath
  if !(← companion.pathExists) then
    return .error ("loam: required Capacity effective evidence not found: " ++ companion.toString)

  let movements ←
    match ← Loam.Persistence.loadCapacityMemory? capacityPath with
    | some memory => pure memory
    | none => return .error "loam: malformed or unsupported Capacity authority"
  let effective ←
    match ← Loam.Persistence.loadCapacityEffectiveMemory? companion with
    | some memory => pure memory
    | none => return .error "loam: malformed or unsupported Capacity effective evidence"

  return .ok { movements := movements, effective := effective }

/-- Publish the dependent effective family at its current hidden physical location. -/
def saveEffective?
    (capacityPath : System.FilePath)
    (memory : CapacityEffectiveMemory String) : IO Bool :=
  Loam.Persistence.saveCapacityEffectiveMemory? (effectivePath capacityPath) memory

/-- Publish the activating Capacity movement family at the public authority handle. -/
def saveMovements?
    (capacityPath : System.FilePath)
    (memory : CapacityMemory) : IO Bool :=
  Loam.Persistence.saveCapacityMemory? capacityPath memory

end Loam.CapacityAuthority
