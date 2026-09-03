import Loam.Core.ScheduledCompletion
import Loam.Persistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Scheduled completion persistence

Completion remains a separate relation between expected Scheduled identity and
Actual Event identity. The raw stream deliberately permits an Actual endpoint
whose Event has not been published yet so relation-first publication can fail
closed and resume after interruption.
-/

/-- Version marker for the first raw Scheduled-completion relation format. -/
def scheduledCompletionMemoryHeader : String :=
  "LOAM-SCHEDULED-COMPLETION-MEMORY\t1"

/-- Keep completion evidence adjacent to the Scheduled stream. -/
def scheduledCompletionPathForScheduledMemory
    (scheduledPath : System.FilePath) : System.FilePath :=
  System.FilePath.mk (scheduledPath.toString ++ ".completions")

private def encodeCompletionRow? (completion : ScheduledCompletion) : Option String :=
  if validToken completion.scheduled.token && validToken completion.actual.token then
    some
      ("COMPLETION\t" ++ completion.scheduled.token ++ "\t" ++ completion.actual.token)
  else
    none

/-- Encode one-to-one raw completion relations without assigning row-order meaning. -/
def encodeScheduledCompletionMemory?
    (memory : ScheduledCompletionMemory) : Option String := do
  let rows ← memory.completions.mapM encodeCompletionRow?
  pure
    (String.intercalate "\n" (scheduledCompletionMemoryHeader :: rows) ++ "\n")

private def decodeCompletionRow? (row : String) : Option ScheduledCompletion :=
  match row.splitOn "\t" with
  | ["COMPLETION", scheduledToken, actualToken] =>
      if validToken scheduledToken && validToken actualToken then
        some { scheduled := ⟨scheduledToken⟩, actual := ⟨actualToken⟩ }
      else
        none
  | _ => none

/-- Decode raw completion relations and recheck one-to-one endpoint uniqueness. -/
def decodeScheduledCompletionMemory?
    (input : String) : Option ScheduledCompletionMemory :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header = scheduledCompletionMemoryHeader then
        match rows.reverse with
        | "" :: reversedRows => do
            let completions ← reversedRows.reverse.mapM decodeCompletionRow?
            ScheduledCompletionMemory.ofCompletions? completions
        | _ => none
      else
        none
  | _ => none

private def scheduledCompletionStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/-- Publish one completion-relation stream through sibling staging plus rename. -/
def saveScheduledCompletionMemory?
    (path : System.FilePath)
    (memory : ScheduledCompletionMemory) : IO Bool := do
  match encodeScheduledCompletionMemory? memory with
  | none => return false
  | some text =>
      let stagePath := scheduledCompletionStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
      return true

/-- Read and fail-closed decode one Scheduled-completion stream. -/
def loadScheduledCompletionMemory?
    (path : System.FilePath) : IO (Option ScheduledCompletionMemory) := do
  let input ← IO.FS.readFile path
  return decodeScheduledCompletionMemory? input

/-- Missing completion storage means no retained completion relations yet. -/
def loadScheduledCompletionMemoryOrEmpty?
    (path : System.FilePath) : IO (Option ScheduledCompletionMemory) := do
  if ← path.pathExists then
    loadScheduledCompletionMemory? path
  else
    return ScheduledCompletionMemory.ofCompletions? []

end Loam.Persistence
