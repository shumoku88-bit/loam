import Loam.ActualDate
import Loam.Core.CapacityEffective
import Loam.Persistence.TokenSyntax
import Loam.Persistence.SiblingStage
import Loam.Persistence.VersionedRows

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Capacity effective-coordinate persistence

Capacity authority remains in the adjacent `CapacityMemory` stream. This file
persists only the independently observable effective coordinate earned by
Observations 112 and 158:

```text
CapacityMovementId -> ISO effective day
```

No BudgetPeriod, Cycle, Envelope, current Entitlement, or Remaining value is
stored here. Representation order has no temporal or priority meaning.
-/

/-- Version marker for the first Capacity effective-coordinate stream. -/
def capacityEffectiveHeader : String := "LOAM-CAPACITY-EFFECTIVE\t1"

/-- Keep practical effective evidence adjacent to its Capacity authority file. -/
def capacityEffectivePathForMemory (capacityPath : System.FilePath) : System.FilePath :=
  System.FilePath.mk (capacityPath.toString ++ ".effective")

private def encodeCapacityEffectiveRow?
    (entry : CapacityEffective String) : Option String :=
  if validToken entry.movement.token && Loam.ActualDate.validIsoDate entry.effectiveOn then
    some ("EFFECTIVE\t" ++ entry.movement.token ++ "\t" ++ entry.effectiveOn)
  else
    none

private def decodeCapacityEffectiveRow?
    (row : String) : Option (CapacityEffective String) :=
  match row.splitOn "\t" with
  | ["EFFECTIVE", movementToken, effectiveOn] =>
      if validToken movementToken && Loam.ActualDate.validIsoDate effectiveOn then
        some { movement := ⟨movementToken⟩, effectiveOn := effectiveOn }
      else
        none
  | _ => none

/-- Encode effective evidence without assigning meaning to list order. -/
def encodeCapacityEffectiveMemory?
    (memory : CapacityEffectiveMemory String) : Option String := do
  let rows ← memory.entries.mapM encodeCapacityEffectiveRow?
  return encodeVersionedRows capacityEffectiveHeader rows

/-- Decode one version-1 stream and recheck movement-identity uniqueness. -/
def decodeCapacityEffectiveMemory?
    (input : String) : Option (CapacityEffectiveMemory String) := do
  let rows ← decodeVersionedRows? capacityEffectiveHeader input
  let entries ← rows.mapM decodeCapacityEffectiveRow?
  CapacityEffectiveMemory.ofEntries? entries

/-- Publish one complete effective-evidence image through sibling staging + rename. -/
def saveCapacityEffectiveMemory?
    (path : System.FilePath)
    (memory : CapacityEffectiveMemory String) : IO Bool := do
  match encodeCapacityEffectiveMemory? memory with
  | none => return false
  | some text =>
      replaceTextViaSiblingStage path text
      return true

/-- Read and fail-closed decode one Capacity effective-coordinate stream. -/
def loadCapacityEffectiveMemory?
    (path : System.FilePath) : IO (Option (CapacityEffectiveMemory String)) := do
  let input ← IO.FS.readFile path
  return decodeCapacityEffectiveMemory? input

/-- Missing adjacent storage means no retained effective evidence yet. -/
def loadCapacityEffectiveMemoryOrEmpty?
    (path : System.FilePath) : IO (Option (CapacityEffectiveMemory String)) := do
  if ← path.pathExists then
    loadCapacityEffectiveMemory? path
  else
    return CapacityEffectiveMemory.ofEntries? []

end Loam.Persistence
