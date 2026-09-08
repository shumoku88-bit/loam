import Loam.Persistence.ScheduledLifecyclePersistence

namespace Loam.ScheduledCli

open Loam.Core

set_option autoImplicit false

private def printOccurrence (occurrence : ScheduledOccurrence String) : IO Unit := do
  IO.println (occurrence.scheduledOn ++ "  [" ++ occurrence.id.token ++ "]")
  for change in occurrence.movement.changes do
    IO.println
      ("  " ++ change.coordinate.token ++ ": " ++
        toString change.quantity.quanta ++ " " ++ occurrence.measure.token)

/--
Show retained Scheduled occurrences from the complete lifecycle authority.

This command is intentionally read-only. The pre-Observation-226 mutation CLI
had its own Scheduled writer and recovery semantics; production mutation now goes
through the shared publishers used by the TUI instead of maintaining that second
writer boundary.
-/
def showScheduled (scheduledPath : String) : IO UInt32 := do
  let scheduledFile := System.FilePath.mk scheduledPath
  match ← Loam.Persistence.loadScheduledLifecycleImage? scheduledFile with
  | none =>
      IO.eprintln "loam: Scheduled lifecycle authority is missing, malformed, or unsupported"
      return 2
  | some lifecycle =>
      match lifecycle.scheduled.occurrences with
      | [] =>
          IO.println "No retained Scheduled movements."
          return 0
      | occurrences =>
          IO.println "Retained Scheduled movements (storage order has no time meaning):"
          for occurrence in occurrences do
            printOccurrence occurrence
          return 0

end Loam.ScheduledCli
