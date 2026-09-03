import Loam.Core.ScheduledRetirement
import Loam.Persistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Scheduled retirement persistence

Retirement remains explicit evidence separate from the Scheduled occurrence.
The stream has no row-order chronology and does not mutate or delete the
original expectation.
-/

/-- Version marker for the first Scheduled-retirement evidence format. -/
def scheduledRetirementMemoryHeader : String :=
  "LOAM-SCHEDULED-RETIREMENT-MEMORY\t1"

/-- Keep retirement evidence adjacent to the Scheduled stream. -/
def scheduledRetirementPathForScheduledMemory
    (scheduledPath : System.FilePath) : System.FilePath :=
  System.FilePath.mk (scheduledPath.toString ++ ".retirements")

private def encodeRetirementRow? (retirement : ScheduledRetirement) : Option String :=
  if validToken retirement.scheduled.token then
    some ("RETIREMENT\t" ++ retirement.scheduled.token)
  else
    none

/-- Encode retirement evidence without assigning time meaning to row order. -/
def encodeScheduledRetirementMemory?
    (memory : ScheduledRetirementMemory) : Option String := do
  let rows ← memory.retirements.mapM encodeRetirementRow?
  pure
    (String.intercalate "\n" (scheduledRetirementMemoryHeader :: rows) ++ "\n")

private def decodeRetirementRow? (row : String) : Option ScheduledRetirement :=
  match row.splitOn "\t" with
  | ["RETIREMENT", scheduledToken] =>
      if validToken scheduledToken then
        some { scheduled := ⟨scheduledToken⟩ }
      else
        none
  | _ => none

/-- Decode retirement evidence and recheck Scheduled-identity uniqueness. -/
def decodeScheduledRetirementMemory?
    (input : String) : Option ScheduledRetirementMemory :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header = scheduledRetirementMemoryHeader then
        match rows.reverse with
        | "" :: reversedRows => do
            let retirements ← reversedRows.reverse.mapM decodeRetirementRow?
            ScheduledRetirementMemory.ofRetirements? retirements
        | _ => none
      else
        none
  | _ => none

private def scheduledRetirementStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/-- Publish one retirement-evidence stream through sibling staging plus rename. -/
def saveScheduledRetirementMemory?
    (path : System.FilePath)
    (memory : ScheduledRetirementMemory) : IO Bool := do
  match encodeScheduledRetirementMemory? memory with
  | none => return false
  | some text =>
      let stagePath := scheduledRetirementStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
      return true

/-- Read and fail-closed decode one Scheduled-retirement stream. -/
def loadScheduledRetirementMemory?
    (path : System.FilePath) : IO (Option ScheduledRetirementMemory) := do
  let input ← IO.FS.readFile path
  return decodeScheduledRetirementMemory? input

/-- Missing retirement storage means no retained retirement evidence yet. -/
def loadScheduledRetirementMemoryOrEmpty?
    (path : System.FilePath) : IO (Option ScheduledRetirementMemory) := do
  if ← path.pathExists then
    loadScheduledRetirementMemory? path
  else
    return ScheduledRetirementMemory.ofRetirements? []

end Loam.Persistence
