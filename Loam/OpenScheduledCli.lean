import Loam.Persistence
import Loam.ScheduledCompletionPersistence
import Loam.ScheduledPersistence
import Loam.ScheduledRetirementPersistence
import Std

namespace Loam.OpenScheduledCli

open Loam.Core

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

private def completionReferencesKnownScheduled
    (scheduledMemory : ScheduledMemory String)
    (completionMemory : ScheduledCompletionMemory) : Bool :=
  completionMemory.completions.all fun completion =>
    (ScheduledMemory.findById? scheduledMemory completion.scheduled).isSome

private def retirementReferencesKnownScheduled
    (scheduledMemory : ScheduledMemory String)
    (retirementMemory : ScheduledRetirementMemory) : Bool :=
  retirementMemory.retirements.all fun retirement =>
    (ScheduledMemory.findById? scheduledMemory retirement.scheduled).isSome

private def terminalEvidenceCompatible
    (completionMemory : ScheduledCompletionMemory)
    (retirementMemory : ScheduledRetirementMemory) : Bool :=
  retirementMemory.retirements.all fun retirement =>
    (ScheduledCompletionMemory.findByScheduled?
      completionMemory retirement.scheduled).isNone

private def hasEffectiveCompletion
    (completionMemory : ScheduledCompletionMemory)
    (eventMemory : EventMemory)
    (scheduled : ScheduledId) : Bool :=
  match ScheduledCompletionMemory.findByScheduled? completionMemory scheduled with
  | none => false
  | some completion => (EventMemory.findById? eventMemory completion.actual).isSome

private def isOpen
    (completionMemory : ScheduledCompletionMemory)
    (retirementMemory : ScheduledRetirementMemory)
    (eventMemory : EventMemory)
    (occurrence : ScheduledOccurrence String) : Bool :=
  (ScheduledRetirementMemory.findByScheduled?
      retirementMemory occurrence.id).isNone &&
    !hasEffectiveCompletion completionMemory eventMemory occurrence.id

private def insertByScheduledDay
    (occurrence : ScheduledOccurrence String) :
    List (ScheduledOccurrence String) → List (ScheduledOccurrence String)
  | [] => [occurrence]
  | current :: rest =>
      match compare occurrence.scheduledOn current.scheduledOn with
      | Ordering.gt => current :: insertByScheduledDay occurrence rest
      | _ => occurrence :: current :: rest

private def sortByScheduledDay
    (occurrences : List (ScheduledOccurrence String)) :
    List (ScheduledOccurrence String) :=
  occurrences.foldr insertByScheduledDay []

private def printOccurrence (occurrence : ScheduledOccurrence String) : IO Unit := do
  IO.println (occurrence.scheduledOn ++ "  [" ++ occurrence.id.token ++ "]")
  for change in occurrence.movement.changes do
    IO.println
      ("  " ++ change.coordinate.token ++ ": " ++
        toString change.quantity.quanta ++ " " ++ occurrence.measure.token)

/--
Show Scheduled occurrences whose expectation remains open.

Retirement evidence closes an occurrence. Completion closes it only when the
referenced Actual Event is present, preserving the existing interrupted-
publication rule that a raw completion relation alone is inert to readers.
The result is ordered by explicit scheduled day for presentation only; retained
storage order gains no temporal meaning. Past-due open occurrences remain
visible rather than being silently dropped.
-/
def showOpenScheduled (scheduledPath memoryPath : String) : IO UInt32 := do
  let scheduledFile := System.FilePath.mk scheduledPath
  let memoryFile := System.FilePath.mk memoryPath
  let completionFile :=
    Loam.Persistence.scheduledCompletionPathForScheduledMemory scheduledFile
  let retirementFile :=
    Loam.Persistence.scheduledRetirementPathForScheduledMemory scheduledFile

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
              match ← loadEventMemoryOrEmpty? memoryFile with
              | none =>
                  IO.eprintln "loam: malformed or unsupported event-memory file"
                  return 2
              | some eventMemory =>
                  if !completionReferencesKnownScheduled scheduledMemory completionMemory then
                    IO.eprintln
                      "loam: scheduled-completion file refers to an unknown Scheduled identity"
                    return 2
                  else if !retirementReferencesKnownScheduled scheduledMemory retirementMemory then
                    IO.eprintln
                      "loam: scheduled-retirement file refers to an unknown Scheduled identity"
                    return 2
                  else if !terminalEvidenceCompatible completionMemory retirementMemory then
                    IO.eprintln
                      "loam: Scheduled terminal evidence conflicts between completion and retirement"
                    return 2
                  else
                    let openOccurrences :=
                      sortByScheduledDay
                        (scheduledMemory.occurrences.filter
                          (isOpen completionMemory retirementMemory eventMemory))
                    match openOccurrences with
                    | [] =>
                        IO.println "No open scheduled movements."
                        return 0
                    | occurrences =>
                        IO.println "Open scheduled movements (ordered by scheduled date):"
                        for occurrence in occurrences do
                          printOccurrence occurrence
                        return 0

end Loam.OpenScheduledCli

def main (args : List String) : IO UInt32 :=
  match args with
  | [scheduledPath, memoryPath] =>
      Loam.OpenScheduledCli.showOpenScheduled scheduledPath memoryPath
  | _ => do
      IO.eprintln "Usage: loamOpenScheduled SCHEDULED_FILE MEMORY_FILE"
      return 2
