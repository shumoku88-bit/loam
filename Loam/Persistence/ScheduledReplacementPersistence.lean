import Loam.Core.ScheduledReplacement
import Loam.Persistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Scheduled replacement persistence

Replacement is retained separately from the Scheduled occurrence stream. The
format stores only the explicit `Scheduled -> Scheduled` provenance selected by
Observation 105. Row order has no lifecycle, priority, or chronology authority.
-/

/-- Version marker for the first raw Scheduled-replacement relation format. -/
def scheduledReplacementMemoryHeader : String :=
  "LOAM-SCHEDULED-REPLACEMENT-MEMORY\t1"

/-- Keep replacement evidence adjacent to the Scheduled stream. -/
def scheduledReplacementPathForScheduledMemory
    (scheduledPath : System.FilePath) : System.FilePath :=
  System.FilePath.mk (scheduledPath.toString ++ ".replacements")

private def encodeReplacementRow?
    (replacement : ScheduledReplacement) : Option String :=
  if validToken replacement.source.token && validToken replacement.replacement.token then
    some
      ("REPLACEMENT\t" ++ replacement.source.token ++ "\t" ++
        replacement.replacement.token)
  else
    none

/-- Encode one-to-one raw replacement relations without assigning row-order meaning. -/
def encodeScheduledReplacementMemory?
    (memory : ScheduledReplacementMemory) : Option String := do
  let rows ← memory.replacements.mapM encodeReplacementRow?
  pure
    (String.intercalate "\n" (scheduledReplacementMemoryHeader :: rows) ++ "\n")

private def decodeReplacementRow? (row : String) : Option ScheduledReplacement :=
  match row.splitOn "\t" with
  | ["REPLACEMENT", sourceToken, replacementToken] =>
      if validToken sourceToken && validToken replacementToken then
        some { source := ⟨sourceToken⟩, replacement := ⟨replacementToken⟩ }
      else
        none
  | _ => none

/-- Decode raw replacement relations and recheck one-to-one endpoint uniqueness. -/
def decodeScheduledReplacementMemory?
    (input : String) : Option ScheduledReplacementMemory :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header = scheduledReplacementMemoryHeader then
        match rows.reverse with
        | "" :: reversedRows => do
            let replacements ← reversedRows.reverse.mapM decodeReplacementRow?
            ScheduledReplacementMemory.ofReplacements? replacements
        | _ => none
      else
        none
  | _ => none

private def scheduledReplacementStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/-- Publish one replacement-relation stream through sibling staging plus rename. -/
def saveScheduledReplacementMemory?
    (path : System.FilePath)
    (memory : ScheduledReplacementMemory) : IO Bool := do
  match encodeScheduledReplacementMemory? memory with
  | none => return false
  | some text =>
      let stagePath := scheduledReplacementStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
      return true

/-- Read and fail-closed decode one Scheduled-replacement stream. -/
def loadScheduledReplacementMemory?
    (path : System.FilePath) : IO (Option ScheduledReplacementMemory) := do
  let input ← IO.FS.readFile path
  return decodeScheduledReplacementMemory? input

/-- Missing replacement storage means no retained replacement relations yet. -/
def loadScheduledReplacementMemoryOrEmpty?
    (path : System.FilePath) : IO (Option ScheduledReplacementMemory) := do
  if ← path.pathExists then
    loadScheduledReplacementMemory? path
  else
    return ScheduledReplacementMemory.ofReplacements? []

end Loam.Persistence
