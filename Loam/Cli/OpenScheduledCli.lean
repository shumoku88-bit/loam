import Loam.Cli.ScheduledCli
import Loam.Cli.ScheduledLifecycleCli
import Loam.Persistence
import Loam.Persistence.ScheduledCompletionPersistence
import Loam.Persistence.ScheduledPersistence
import Loam.Persistence.ScheduledRetirementPersistence
import Std

namespace Loam.OpenScheduledCli

open Loam.Core

set_option autoImplicit false

private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString

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

private def fromChanges
    (occurrence : ScheduledOccurrence String) :
    List (MovementChange LocusId) :=
  occurrence.movement.changes.filter fun change => change.quantity.quanta < 0

private def toChanges
    (occurrence : ScheduledOccurrence String) :
    List (MovementChange LocusId) :=
  occurrence.movement.changes.filter fun change => change.quantity.quanta > 0

private def zeroChanges
    (occurrence : ScheduledOccurrence String) :
    List (MovementChange LocusId) :=
  occurrence.movement.changes.filter fun change => change.quantity.quanta = 0

private def printMagnitude
    (indent : String)
    (change : MovementChange LocusId)
    (amount : Int)
    (measure : MeasureId) : IO Unit := do
  IO.println
    (indent ++ change.coordinate.token ++ ": " ++
      toString amount ++ " " ++ measure.token)

/-!
The practical view may translate signed quantities into FROM / TO language
without adding Account, income, expense, debit, credit, or transaction-kind
semantics to Core. Negative and positive are already explicit in the admitted
BalancedMovement.

A simple one-source / one-destination movement gets a compact arrow. Any split
movement keeps every coordinate visible in separate FROM / TO groups. Zero
changes, if retained, are shown explicitly rather than silently discarded.
-/
private def printMovement (occurrence : ScheduledOccurrence String) : IO Unit := do
  let sources := fromChanges occurrence
  let destinations := toChanges occurrence
  let zeros := zeroChanges occurrence
  match sources, destinations, zeros with
  | [source], [destination], [] =>
      IO.println
        ("  " ++ source.coordinate.token ++ " -> " ++ destination.coordinate.token ++ ": " ++
          toString destination.quantity.quanta ++ " " ++ occurrence.measure.token)
  | _, _, _ =>
      if !sources.isEmpty then
        IO.println "  FROM"
        for change in sources do
          printMagnitude "    " change (-change.quantity.quanta) occurrence.measure
      if !destinations.isEmpty then
        IO.println "  TO"
        for change in destinations do
          printMagnitude "    " change change.quantity.quanta occurrence.measure
      if !zeros.isEmpty then
        IO.println "  ZERO"
        for change in zeros do
          printMagnitude "    " change 0 occurrence.measure
      if occurrence.movement.changes.isEmpty then
        IO.println "  (no quantity changes)"

private def printOccurrence (occurrence : ScheduledOccurrence String) : IO Unit := do
  IO.println (occurrence.scheduledOn ++ "  [" ++ occurrence.id.token ++ "]")
  printMovement occurrence

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

/-!
Interactive Scheduled workbench for daily dogfood.

The workbench deliberately asks only which Scheduled occurrences remain open.
Observation 122 showed that answering a stronger question such as "which later
occurrence is the next one?" would require independent continuation provenance.
This UI does not retain that new fact yet. After add, realization, or
cancellation it simply re-renders the open set, so pre-created future
occurrences remain visible without forcing automatic replenishment or a Series
model.
-/
partial def scheduledMenu (scheduledPath memoryPath : String) : IO UInt32 := do
  IO.println ""
  IO.println "Scheduled movements"
  let status ← showOpenScheduled scheduledPath memoryPath
  if status != 0 then
    return status
  else
    IO.println ""
    IO.println "What do you want to do?"
    IO.println "a. Add scheduled movement"
    IO.println "r. Record what actually happened"
    IO.println "x. Cancel scheduled movement"
    IO.println "b. Back"
    let choice ← promptLine "> "
    match choice with
    | "a" =>
        let _ ← Loam.ScheduledCli.recordScheduled scheduledPath
        scheduledMenu scheduledPath memoryPath
    | "A" =>
        let _ ← Loam.ScheduledCli.recordScheduled scheduledPath
        scheduledMenu scheduledPath memoryPath
    | "r" =>
        let scheduledId ← promptLine "Scheduled id: "
        if scheduledId.isEmpty then
          scheduledMenu scheduledPath memoryPath
        else
          let _ ← Loam.ScheduledLifecycleCli.completeScheduled
            scheduledPath memoryPath scheduledId
          scheduledMenu scheduledPath memoryPath
    | "R" =>
        let scheduledId ← promptLine "Scheduled id: "
        if scheduledId.isEmpty then
          scheduledMenu scheduledPath memoryPath
        else
          let _ ← Loam.ScheduledLifecycleCli.completeScheduled
            scheduledPath memoryPath scheduledId
          scheduledMenu scheduledPath memoryPath
    | "x" =>
        let scheduledId ← promptLine "Scheduled id: "
        if scheduledId.isEmpty then
          scheduledMenu scheduledPath memoryPath
        else
          let _ ← Loam.ScheduledLifecycleCli.cancelScheduled scheduledPath scheduledId
          scheduledMenu scheduledPath memoryPath
    | "X" =>
        let scheduledId ← promptLine "Scheduled id: "
        if scheduledId.isEmpty then
          scheduledMenu scheduledPath memoryPath
        else
          let _ ← Loam.ScheduledLifecycleCli.cancelScheduled scheduledPath scheduledId
          scheduledMenu scheduledPath memoryPath
    | "b" => return 0
    | "B" => return 0
    | "q" => return 0
    | "Q" => return 0
    | _ =>
        IO.eprintln "loam: Scheduled choice not understood"
        scheduledMenu scheduledPath memoryPath

end Loam.OpenScheduledCli

def main (args : List String) : IO UInt32 :=
  match args with
  | ["menu", scheduledPath, memoryPath] =>
      Loam.OpenScheduledCli.scheduledMenu scheduledPath memoryPath
  | [scheduledPath, memoryPath] => do
      let stdin ← IO.getStdin
      let stdout ← IO.getStdout
      let inputInteractive ← stdin.isTty
      let outputInteractive ← stdout.isTty
      if inputInteractive && outputInteractive then
        Loam.OpenScheduledCli.scheduledMenu scheduledPath memoryPath
      else
        Loam.OpenScheduledCli.showOpenScheduled scheduledPath memoryPath
  | _ => do
      IO.eprintln "Usage: loamOpenScheduled [menu] SCHEDULED_FILE MEMORY_FILE"
      return 2