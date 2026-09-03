import Loam.ActualDate
import Loam.Core.ActualValidity
import Loam.Persistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-- Version marker for practical Event occurrence-date evidence. -/
def actualValidityMemoryHeader : String := "LOAM-ACTUAL-VALIDITY-MEMORY\t1"

/--
Keep the practical date stream adjacent to its Event memory without adding a
second user-facing path argument.
-/
def actualValidityPathForEventMemory (memoryPath : System.FilePath) : System.FilePath :=
  System.FilePath.mk (memoryPath.toString ++ ".actual-validity")

private def encodeActualValidityRow?
    (entry : ActualValidity String) : Option String :=
  if validToken entry.event.token && Loam.ActualDate.validIsoDate entry.validOn then
    some ("VALIDITY\t" ++ entry.event.token ++ "\t" ++ entry.validOn)
  else
    none

private def decodeActualValidityRow?
    (row : String) : Option (ActualValidity String) :=
  match row.splitOn "\t" with
  | ["VALIDITY", eventToken, validOn] =>
      if validToken eventToken && Loam.ActualDate.validIsoDate validOn then
        some { event := ⟨eventToken⟩, validOn := validOn }
      else
        none
  | _ => none

/-- Encode date evidence without giving row order chronological meaning. -/
def encodeActualValidityMemory?
    (memory : ActualValidityMemory String) : Option String := do
  let rows ← memory.entries.mapM encodeActualValidityRow?
  pure (String.intercalate "\n" (actualValidityMemoryHeader :: rows) ++ "\n")

/--
Decode date evidence and fail closed on malformed dates or duplicate EventId
coordinates.
-/
def decodeActualValidityMemory?
    (input : String) : Option (ActualValidityMemory String) :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header = actualValidityMemoryHeader then
        match rows.reverse with
        | "" :: reversedRows => do
            let entries ← reversedRows.reverse.mapM decodeActualValidityRow?
            ActualValidityMemory.ofEntries? entries
        | _ => none
      else
        none
  | _ => none

private def actualValidityStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/-- Publish one independently replaced occurrence-date evidence stream. -/
def saveActualValidityMemory?
    (path : System.FilePath)
    (memory : ActualValidityMemory String) : IO Bool := do
  match encodeActualValidityMemory? memory with
  | none => return false
  | some text =>
      let stagePath := actualValidityStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
      return true

/-- Load one occurrence-date stream; malformed content fails closed. -/
def loadActualValidityMemory?
    (path : System.FilePath) : IO (Option (ActualValidityMemory String)) := do
  let input ← IO.FS.readFile path
  return decodeActualValidityMemory? input

/-- Missing date storage means no retained practical date evidence yet. -/
def loadActualValidityMemoryOrEmpty?
    (path : System.FilePath) : IO (Option (ActualValidityMemory String)) := do
  if ← path.pathExists then
    loadActualValidityMemory? path
  else
    return ActualValidityMemory.ofEntries? []

end Loam.Persistence
