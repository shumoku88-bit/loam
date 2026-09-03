import Loam.ActualDate
import Loam.MovementEntry
import Loam.ScheduledPersistence
import Loam.WriterOwnership
import Std

namespace Loam.ScheduledCli

open Loam.Core

set_option autoImplicit false

private def usage : String :=
  "LOAM scheduled movements\n\n" ++
  "Add one balanced JPY scheduled movement:\n" ++
  "  ./tools/loam scheduled <scheduled-file>\n\n" ++
  "Show retained scheduled movements:\n" ++
  "  ./tools/loam scheduled show <scheduled-file>"

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

private def freshScheduledIdFrom
    (memory : ScheduledMemory String) : Nat → Nat → Option ScheduledId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : ScheduledId := ⟨"scheduled-" ++ toString index⟩
      match ScheduledMemory.findById? memory candidate with
      | none => some candidate
      | some _ => freshScheduledIdFrom memory (index + 1) fuel

private def freshScheduledId?
    (memory : ScheduledMemory String) : Option ScheduledId :=
  freshScheduledIdFrom memory 1 (memory.occurrences.length + 1)

private def addLocusIfAbsent (loci : List String) (locus : String) : List String :=
  if locus ∈ loci then loci else loci ++ [locus]

private def knownScheduledLoci (memory : ScheduledMemory String) : List String :=
  memory.occurrences.foldl
    (fun loci occurrence =>
      occurrence.movement.changes.foldl
        (fun current change => addLocusIfAbsent current change.coordinate.token)
        loci)
    []

private def scheduledFromEffects?
    (id : ScheduledId)
    (scheduledOn : String)
    (effects : List Effect) : Option (ScheduledOccurrence String) := do
  if !Loam.ActualDate.validIsoDate scheduledOn then
    none
  else if effects.any (fun effect => effect.measure != ⟨"jpy"⟩) then
    none
  else
    let changes : List (MovementChange LocusId) :=
      effects.map fun effect =>
        { coordinate := effect.locus, quantity := effect.quantity }
    let movement ← BalancedMovement.ofChanges? ⟨"jpy"⟩ changes
    pure { id := id, scheduledOn := scheduledOn, movement := movement }

private def recordScheduledUnlocked (scheduledPath : String) : IO UInt32 := do
  let scheduledFile := System.FilePath.mk scheduledPath
  match ← loadScheduledMemoryOrEmpty? scheduledFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported scheduled file"
      return 2
  | some memory =>
      let day ← promptLine "Scheduled date (YYYY-MM-DD): "
      if !Loam.ActualDate.validIsoDate day then
        IO.eprintln "loam: scheduled date must be a real calendar date in YYYY-MM-DD form"
        return 2
      else
        IO.println "Enter the expected movement. Add FROM entries, then TO entries."
        match ← Loam.MovementEntry.collectMovementEffects (knownScheduledLoci memory) with
        | Except.error message =>
            IO.eprintln message
            return 2
        | Except.ok (effects, total) =>
            match freshScheduledId? memory with
            | none =>
                IO.eprintln "loam: could not generate a fresh scheduled identity"
                return 2
            | some scheduledId =>
                match scheduledFromEffects? scheduledId day effects with
                | none =>
                    IO.eprintln "loam: expected movement could not be admitted"
                    return 2
                | some occurrence =>
                    match ScheduledMemory.add? memory occurrence with
                    | none =>
                        IO.eprintln "loam: generated scheduled identity already remembered"
                        return 2
                    | some updated =>
                        if ← Loam.Persistence.saveScheduledMemory? scheduledFile updated then
                          IO.println
                            ("Scheduled movement recorded: " ++ scheduledId.token ++
                              " on " ++ day ++ " = " ++ toString total ++ " jpy.")
                          return 0
                        else
                          IO.eprintln "loam: scheduled movement could not be published"
                          return 2

/-- Add one Scheduled occurrence under scheduled-file writer ownership. -/
def recordScheduled (scheduledPath : String) : IO UInt32 :=
  Loam.WriterOwnership.withOwnership
    (System.FilePath.mk scheduledPath)
    (recordScheduledUnlocked scheduledPath)

private def printOccurrence (occurrence : ScheduledOccurrence String) : IO Unit := do
  IO.println (occurrence.scheduledOn ++ "  [" ++ occurrence.id.token ++ "]")
  for change in occurrence.movement.changes do
    IO.println
      ("  " ++ change.coordinate.token ++ ": " ++
        toString change.quantity.quanta ++ " " ++ occurrence.measure.token)

/-- Show retained Scheduled occurrences without treating file order as chronology. -/
def showScheduled (scheduledPath : String) : IO UInt32 := do
  let scheduledFile := System.FilePath.mk scheduledPath
  match ← loadScheduledMemoryOrEmpty? scheduledFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported scheduled file"
      return 2
  | some memory =>
      match memory.occurrences with
      | [] =>
          IO.println "No scheduled movements."
          return 0
      | occurrences =>
          IO.println "Scheduled movements (each date is explicit; display order has no time meaning):"
          for occurrence in occurrences do
            printOccurrence occurrence
          return 0

/-- Command dispatcher for the first practical Scheduled entrance. -/
def run (args : List String) : IO UInt32 :=
  match args with
  | [scheduledPath] => recordScheduled scheduledPath
  | ["show", scheduledPath] => showScheduled scheduledPath
  | _ => do
      IO.eprintln usage
      return 2

end Loam.ScheduledCli

def main (args : List String) : IO UInt32 :=
  Loam.ScheduledCli.run args
