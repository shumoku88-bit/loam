import Loam.ActualDate
import Loam.Application.ScheduledOpenWorldInspection
import Loam.Persistence
import Loam.Persistence.ScheduledCompletionPersistence
import Loam.Persistence.ScheduledPersistence
import Loam.Persistence.ScheduledReplacementPersistence
import Loam.Persistence.ScheduledRetirementPersistence

namespace Loam.ScheduledDayEvidenceCli

open Loam.Core
open Loam.Application

set_option autoImplicit false

private def loadScheduledMemoryOrEmpty?
    (path : System.FilePath) : IO (Option (ScheduledMemory String)) := do
  if ← path.pathExists then
    Loam.Persistence.loadScheduledMemory? path
  else
    return ScheduledMemory.ofOccurrences? []

private def loadEventMemoryOrEmpty?
    (path : System.FilePath) : IO (Option EventMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventMemory? path
  else
    return EventMemory.ofEvents? []

private def printOccurrence (occurrence : ScheduledOccurrence String) : IO Unit := do
  IO.println
    ("SCHEDULED\t" ++ occurrence.id.token ++ "\t" ++ occurrence.scheduledOn ++
      "\t" ++ occurrence.measure.token)
  for change in occurrence.movement.changes do
    IO.println
      ("CHANGE\t" ++ change.coordinate.token ++ "\t" ++
        toString change.quantity.quanta)

private def printDue
    (day : String)
    (first : ScheduledOccurrence String)
    (rest : List (ScheduledOccurrence String)) : IO UInt32 := do
  IO.println ("DUE\t" ++ day)
  printOccurrence first
  for occurrence in rest do
    printOccurrence occurrence
  return 0

/--
Print one exact-day open-world Scheduled answer for machine or AI consumers.

`UNKNOWN` means only that no explicit current-open Scheduled occurrence is
retained for the queried day. It is intentionally not `NOT_DUE`.
-/
def report (scheduledPath memoryPath day : String) : IO UInt32 := do
  if !Loam.ActualDate.validIsoDate day then
    IO.eprintln "loam: Scheduled day evidence requires a real YYYY-MM-DD calendar date"
    return 2
  else
    let scheduledFile := System.FilePath.mk scheduledPath
    let memoryFile := System.FilePath.mk memoryPath
    let completionFile :=
      Loam.Persistence.scheduledCompletionPathForScheduledMemory scheduledFile
    let retirementFile :=
      Loam.Persistence.scheduledRetirementPathForScheduledMemory scheduledFile
    let replacementFile :=
      Loam.Persistence.scheduledReplacementPathForScheduledMemory scheduledFile

    match ← loadScheduledMemoryOrEmpty? scheduledFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported scheduled file"
        return 2
    | some scheduledMemory =>
        match ← Loam.Persistence.loadScheduledCompletionMemoryOrEmpty? completionFile with
        | none =>
            IO.eprintln "loam: malformed or unsupported scheduled-completion file"
            return 2
        | some completionMemory =>
            match ← Loam.Persistence.loadScheduledRetirementMemoryOrEmpty? retirementFile with
            | none =>
                IO.eprintln "loam: malformed or unsupported scheduled-retirement file"
                return 2
            | some retirementMemory =>
                match ← Loam.Persistence.loadScheduledReplacementMemoryOrEmpty? replacementFile with
                | none =>
                    IO.eprintln "loam: malformed or unsupported scheduled-replacement file"
                    return 2
                | some replacementMemory =>
                    match ← loadEventMemoryOrEmpty? memoryFile with
                    | none =>
                        IO.eprintln "loam: malformed or unsupported event-memory file"
                        return 2
                    | some eventMemory =>
                        match currentScheduledDayEvidenceWithReplacement
                            scheduledMemory completionMemory retirementMemory replacementMemory
                            eventMemory day with
                        | .due first rest => printDue day first rest
                        | .unknown =>
                            IO.println ("UNKNOWN\t" ++ day)
                            IO.println
                              "No explicit current-open Scheduled evidence is retained for this day."
                            IO.println
                              "This does not establish NOT_DUE; unmaterialized future obligations remain unknown."
                            return 0
                        | .unknownCompletionScheduled =>
                            IO.eprintln
                              "loam: scheduled-completion file refers to an unknown Scheduled identity"
                            return 2
                        | .unknownRetirementScheduled =>
                            IO.eprintln
                              "loam: scheduled-retirement file refers to an unknown Scheduled identity"
                            return 2
                        | .unknownReplacementScheduled =>
                            IO.eprintln
                              "loam: scheduled-replacement file refers to an unknown Scheduled identity"
                            return 2
                        | .invalidReplacementGraph =>
                            IO.eprintln
                              "loam: scheduled-replacement graph is cyclic or otherwise invalid"
                            return 2
                        | .conflictingTerminalEvidence =>
                            IO.eprintln
                              "loam: Scheduled terminal evidence conflicts across completion, retirement, or replacement"
                            return 2

end Loam.ScheduledDayEvidenceCli
