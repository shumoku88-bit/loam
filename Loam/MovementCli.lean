import Loam.MovementEntry
import Loam.Persistence
import Loam.WriterOwnership

namespace Loam.MovementCli

set_option autoImplicit false

/--
Search the same bounded operational Event-id namespace used by the practical CLI.
The numeric suffix is collision avoidance only and has no temporal meaning.
-/
private def freshRecordEventIdFrom
    (memory : Loam.Core.EventMemory) : Nat → Nat → Option Loam.Core.EventId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : Loam.Core.EventId := ⟨"record-" ++ toString index⟩
      match Loam.Core.EventMemory.findById? memory candidate with
      | none => some candidate
      | some _ => freshRecordEventIdFrom memory (index + 1) fuel

private def freshRecordEventId? (memory : Loam.Core.EventMemory) : Option Loam.Core.EventId :=
  freshRecordEventIdFrom memory 1 (memory.events.length + 1)

private def loadEventMemoryForEntry?
    (path : System.FilePath) : IO (Option Loam.Core.EventMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventMemory? path
  else
    return Loam.Core.EventMemory.ofEvents? []

/--
Record one balanced human-facing JPY movement with one or more FROM loci and one
or more TO loci.

The entrance requires the two entered totals to agree, then persists one generic
Event containing negative Effects for the FROM side and positive Effects for the
TO side. This is an adapter-level shape only. It does not add Account,
ExpenseCategory, EventKind, debit/credit, Transfer, or a global conservation law
to Core.

The command is intentionally additive beside the existing `spend`, `income`, and
`transfer` entrances while split-payment dogfood establishes whether those
specialized verbs can later become thin shortcuts over this shape.
-/
def recordMovement (memoryPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  match ← loadEventMemoryForEntry? memoryFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported event-memory file"
      return 2
  | some memory =>
      IO.println "Record one movement. Add FROM entries, then TO entries."
      let knownLoci := Loam.CompletionPrompt.knownLoci memory
      match ← Loam.MovementEntry.collectMovementEffects knownLoci with
      | Except.error message =>
          IO.eprintln message
          return 2
      | Except.ok (effects, total) =>
          match freshRecordEventId? memory with
          | none =>
              IO.eprintln "loam: could not generate a fresh event identity"
              return 2
          | some eventId =>
              match Loam.Core.Event.ofEffects? eventId effects with
              | none =>
                  IO.eprintln "loam: could not admit generated movement event"
                  return 2
              | some event =>
                  match Loam.Core.EventMemory.add? memory event with
                  | none =>
                      IO.eprintln "loam: generated event identity already remembered"
                      return 2
                  | some updated =>
                      if ← Loam.Persistence.saveEventMemory? memoryFile updated then
                        IO.println ("Recorded movement: " ++ toString total ++ " jpy.")
                        return 0
                      else
                        IO.eprintln "loam: recorded event contains an unrepresentable identity token"
                        return 2

private def usage : String :=
  "Record one balanced JPY movement:\n" ++
  "  ./tools/loam-movement MEMORY_FILE\n\n" ++
  "Enter one or more FROM loci and amounts, blank the next FROM locus, then\n" ++
  "enter one or more TO loci and amounts and blank the next TO locus.\n" ++
  "The FROM and TO totals must match exactly."

def run (args : List String) : IO UInt32 :=
  match args with
  | [memoryPath] =>
      Loam.WriterOwnership.withOwnership
        (System.FilePath.mk memoryPath)
        (recordMovement memoryPath)
  | _ => do
      IO.eprintln usage
      return 2

end Loam.MovementCli

def main (args : List String) : IO UInt32 :=
  Loam.MovementCli.run args
