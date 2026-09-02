import Loam.Persistence
import Loam.WriterOwnership
import Std

namespace Loam.MovementCli

set_option autoImplicit false

/-- Prompt for one line while keeping the movement entrance interactive. -/
private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString

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
Collect one nonempty side of a human-entered movement.

`negative` only controls the interface-level sign assigned to the Effects created
by this entrance. No source/destination role is retained in Core beyond the
ordinary signed quantity Effects themselves.
-/
private partial def collectSide
    (label : String)
    (negative : Bool)
    (nextIndex : Nat)
    (effects : List Loam.Core.Effect)
    (total : Int)
    (count : Nat) :
    IO (Except String (Nat × List Loam.Core.Effect × Int)) := do
  let locusToken ← promptLine (label ++ " locus (blank when done)? ")
  if locusToken.isEmpty then
    if count = 0 then
      return Except.error ("loam: at least one " ++ label.toLower ++ " locus is required")
    else
      return Except.ok (nextIndex, effects, total)
  else if !Loam.Persistence.validToken locusToken then
    return Except.error ("loam: " ++ label.toLower ++ " locus must be a nonempty single-line token")
  else
    let amountText ← promptLine (label ++ " amount? ")
    match amountText.toInt? with
    | none =>
        return Except.error "loam: movement amount must be a positive integer"
    | some amount =>
        if amount <= 0 then
          return Except.error "loam: movement amount must be a positive integer"
        else
          let signedAmount := if negative then -amount else amount
          let effect :=
            Loam.Core.Effect.ofQuantity
              ⟨"effect-" ++ toString nextIndex⟩ ⟨locusToken⟩ ⟨"jpy"⟩
              (Loam.Core.Quantity.ofQuanta signedAmount)
          collectSide label negative (nextIndex + 1)
            (effects ++ [effect]) (total + amount) (count + 1)

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
      match ← collectSide "From" true 1 [] 0 0 with
      | Except.error message =>
          IO.eprintln message
          return 2
      | Except.ok (nextIndex, fromEffects, fromTotal) =>
          match ← collectSide "To" false nextIndex fromEffects 0 0 with
          | Except.error message =>
              IO.eprintln message
              return 2
          | Except.ok (_, effects, toTotal) =>
              if fromTotal != toTotal then
                IO.eprintln
                  ("loam: movement totals differ: from " ++ toString fromTotal ++
                    " jpy, to " ++ toString toTotal ++ " jpy")
                return 2
              else
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
                              IO.println ("Recorded movement: " ++ toString fromTotal ++ " jpy.")
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
