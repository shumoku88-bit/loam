import Loam.Persistence
import Std

namespace Loam.Cli

set_option autoImplicit false

/-- Render one admitted runtime amount without inventing display metadata. -/
def renderAmount (amount : Loam.Core.SomeAmount) : String :=
  amount.measure.token ++ "\t" ++ toString amount.quantity.quanta

private def practicalUsage : String :=
  "LOAM practical dogfood\n\n" ++
  "Record a JPY spend:\n" ++
  "  ./tools/loam spend scratch/dogfood/memory.loam\n\n" ++
  "Review recorded facts:\n" ++
  "  ./tools/loam review scratch/dogfood/memory.loam\n\n" ++
  "The final path is the memory file LOAM reads or writes.\n" ++
  "For lower-level commands:\n" ++
  "  ./tools/loam help low-level"

private def lowLevelUsage : String :=
  "Low-level commands\n" ++
  "Replace each word in <angle brackets> with your own value.\n" ++
  "Do not type the angle-bracket words literally.\n\n" ++
  "  ./tools/loam amount show <amount-file>\n" ++
  "  ./tools/loam event create <event-file> <event-id> [<effect-key> <locus> <measure> <quanta>]...\n" ++
  "  ./tools/loam event quantity <event-file> <locus> <measure>\n" ++
  "  ./tools/loam event-memory get <memory-file> <event-id>\n" ++
  "  ./tools/loam event-memory quantity <memory-file> <locus> <measure>\n" ++
  "  ./tools/loam event-memory add <memory-file> <event-file>"

/-- Parse caller-supplied effect tuples without assigning meaning to their order or sign. -/
private def parseEffects : List String → Option (List Loam.Core.Effect)
  | [] => some []
  | key :: locus :: measure :: quantaText :: rest =>
      match quantaText.toInt? with
      | none => none
      | some quanta =>
          match parseEffects rest with
          | none => none
          | some effects =>
              some
                (Loam.Core.Effect.ofQuantity
                  ⟨key⟩ ⟨locus⟩ ⟨measure⟩
                  (Loam.Core.Quantity.ofQuanta quanta) :: effects)
  | _ => none

/-- Read one persisted amount and print its stable measure token and exact quanta. -/
def showAmount (path : String) : IO UInt32 := do
  let filePath := System.FilePath.mk path
  if ← filePath.pathExists then
    match ← Loam.Persistence.load? filePath with
    | some amount =>
        IO.println (renderAmount amount)
        return 0
    | none =>
        IO.eprintln "loam: malformed or unsupported amount file"
        return 2
  else
    IO.eprintln ("loam: file not found: " ++ path)
    return 2

/--
Create one complete event from caller-supplied effect tuples and persist it in
one write. This command does not provide an incremental effect-append surface.
An already existing target path is refused rather than intentionally replaced.
-/
def createEvent
    (path : String) (eventToken : String) (effectArgs : List String) : IO UInt32 := do
  match parseEffects effectArgs with
  | none =>
      IO.eprintln "loam: event effects must be KEY LOCUS MEASURE QUANTA tuples"
      return 2
  | some effects =>
      match Loam.Core.Event.ofEffects? ⟨eventToken⟩ effects with
      | none =>
          IO.eprintln "loam: duplicate effect key in event"
          return 2
      | some event =>
          let filePath := System.FilePath.mk path
          if ← filePath.pathExists then
            IO.eprintln "loam: target event file already exists"
            return 2
          else
            if ← Loam.Persistence.saveEvent? filePath event then
              return 0
            else
              IO.eprintln "loam: event contains an unrepresentable identity token"
              return 2

/--
Read one persisted event and project exact quanta at an explicit locus/measure
coordinate. The source event remains detailed; this command only exposes the
read-only `Event.quantityAt` projection.
-/
def showEventQuantity
    (path : String) (locusToken : String) (measureToken : String) : IO UInt32 := do
  let filePath := System.FilePath.mk path
  if ← filePath.pathExists then
    match ← Loam.Persistence.loadEvent? filePath with
    | some event =>
        let quantity := Loam.Core.Event.quantityAt event ⟨locusToken⟩ ⟨measureToken⟩
        IO.println (toString quantity.quanta)
        return 0
    | none =>
        IO.eprintln "loam: malformed or unsupported event file"
        return 2
  else
    IO.eprintln ("loam: file not found: " ++ path)
    return 2

/--
Read one persisted Event memory and retrieve one Event by stable identity.
The command exposes no storage index and therefore adds no `first`, `latest`,
temporal, causal, priority, authority, or posting-order semantics.
-/
def showRememberedEvent (path : String) (eventToken : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk path
  if ← memoryFile.pathExists then
    match ← Loam.Persistence.loadEventMemory? memoryFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported event-memory file"
        return 2
    | some memory =>
        match Loam.Core.EventMemory.findById? memory ⟨eventToken⟩ with
        | none =>
            IO.eprintln "loam: event not found in memory"
            return 1
        | some event =>
            match Loam.Persistence.encodeEvent? event with
            | some text =>
                IO.print text
                return 0
            | none =>
                IO.eprintln "loam: remembered event cannot be represented"
                return 2
  else
    IO.eprintln ("loam: file not found: " ++ path)
    return 2

/--
Read one persisted Event memory and project the exact aggregate of all recorded
facts at one explicit locus/measure coordinate.

This command deliberately exposes `EventMemory.quantityAtRecorded`. It does not
claim correction, reversal, current-state, effective-state, temporal, or
accounting semantics, and therefore is not named `balance`.
-/
def showRememberedQuantity
    (path : String) (locusToken : String) (measureToken : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk path
  if ← memoryFile.pathExists then
    match ← Loam.Persistence.loadEventMemory? memoryFile with
    | some memory =>
        let quantity :=
          Loam.Core.EventMemory.quantityAtRecorded memory ⟨locusToken⟩ ⟨measureToken⟩
        IO.println (toString quantity.quanta)
        return 0
    | none =>
        IO.eprintln "loam: malformed or unsupported event-memory file"
        return 2
  else
    IO.eprintln ("loam: file not found: " ++ path)
    return 2

/--
Show every Event currently represented in one Event memory without interpreting
representation order as time, causality, priority, or authority.

This is a human-facing inspection entrance, not a chronological history. It
prints only facts the current Practical Core actually retains; descriptive
context such as merchant or purpose is therefore absent unless a future
observation earns a representation for it.
-/
def reviewRememberedEvents (path : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk path
  if ← memoryFile.pathExists then
    match ← Loam.Persistence.loadEventMemory? memoryFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported event-memory file"
        return 2
    | some memory =>
        match memory.events with
        | [] =>
            IO.println "No recorded events."
            return 0
        | events =>
            IO.println "Recorded facts (display order has no time meaning):"
            for event in events do
              IO.println ("Event " ++ event.id.token)
              match event.effects with
              | [] => IO.println "  (no quantity effects)"
              | effects =>
                  for effect in effects do
                    IO.println
                      ("  " ++ effect.locus.token ++ ": " ++
                        toString effect.quantity.quanta ++ " " ++ effect.measure.token)
            return 0
  else
    IO.eprintln ("loam: file not found: " ++ path)
    return 2

/--
Add one already-complete persisted Event to an existing Event memory.

Both files are fully admitted before publication. Duplicate Event identity
therefore fails without changing the memory target. The final list position is
persistence representation only and does not mean latest, later, causal, or
more authoritative. Successful publication stages the complete encoded memory
beside the target and then replaces the target with one filesystem rename; it
does not serialize concurrent writers or claim power-loss durability.
-/
def addRememberedEvent (memoryPath eventPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let eventFile := System.FilePath.mk eventPath
  if !(← memoryFile.pathExists) then
    IO.eprintln ("loam: file not found: " ++ memoryPath)
    return 2
  else if !(← eventFile.pathExists) then
    IO.eprintln ("loam: file not found: " ++ eventPath)
    return 2
  else
    match ← Loam.Persistence.loadEventMemory? memoryFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported event-memory file"
        return 2
    | some memory =>
        match ← Loam.Persistence.loadEvent? eventFile with
        | none =>
            IO.eprintln "loam: malformed or unsupported event file"
            return 2
        | some event =>
            match Loam.Core.EventMemory.add? memory event with
            | none =>
                IO.eprintln "loam: event identity already remembered"
                return 1
            | some updated =>
                if ← Loam.Persistence.saveEventMemory? memoryFile updated then
                  return 0
                else
                  IO.eprintln "loam: updated event memory contains an unrepresentable identity token"
                  return 2

/-- Prompt for one line while keeping the practical entrance interactive. -/
private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString

/--
Search a bounded deterministic namespace for an unused Event identity.

The numeric suffix is only an operational collision-avoidance device for the
CLI. It does not make Event-memory representation order temporal or semantic.
With `n` remembered Events, checking `n + 1` distinct candidates guarantees at
least one candidate is not already used.
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

/--
Load an existing Event memory for a human-facing entry, or begin from the
already-admitted empty memory when the target does not yet exist. A malformed
existing target is never silently replaced.
-/
private def loadEventMemoryForEntry?
    (path : System.FilePath) : IO (Option Loam.Core.EventMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventMemory? path
  else
    return Loam.Core.EventMemory.ofEvents? []

/--
Human-facing entrance for one ordinary JPY spend from one locus.

The user supplies the payment source and a positive amount. This adapter turns
that action into a negative JPY quantity at the selected locus, generates
Event/Effect identity internally, and records directly into EventMemory without
an intermediate Event file.

`spend` is deliberately an interface verb, not a new Practical Core primitive.
The resulting Core fact remains the same neutral signed Effect. This entrance
also does not pretend that the current Core can retain merchant, purpose, note,
or other descriptive provenance that dogfooding has now shown users may expect.
-/
def spendJpy (memoryPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  match ← loadEventMemoryForEntry? memoryFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported event-memory file"
      return 2
  | some memory =>
      let locusToken ← promptLine "Paid from? "
      if Loam.Persistence.validToken locusToken then
        let amountText ← promptLine "Amount? "
        match amountText.toInt? with
        | none =>
            IO.eprintln "loam: amount must be a positive integer"
            return 2
        | some amount =>
            if amount > 0 then
              match freshRecordEventId? memory with
              | none =>
                  IO.eprintln "loam: could not generate a fresh event identity"
                  return 2
              | some eventId =>
                  let effect :=
                    Loam.Core.Effect.ofQuantity
                      ⟨"effect-1"⟩ ⟨locusToken⟩ ⟨"jpy"⟩
                      (Loam.Core.Quantity.ofQuanta (-amount))
                  match Loam.Core.Event.ofEffects? eventId [effect] with
                  | none =>
                      IO.eprintln "loam: could not admit generated event"
                      return 2
                  | some event =>
                      match Loam.Core.EventMemory.add? memory event with
                      | none =>
                          IO.eprintln "loam: generated event identity already remembered"
                          return 2
                      | some updated =>
                          if ← Loam.Persistence.saveEventMemory? memoryFile updated then
                            IO.println
                              ("Recorded: spent " ++ toString amount ++ " jpy from " ++ locusToken ++ ".")
                            return 0
                          else
                            IO.eprintln "loam: recorded event contains an unrepresentable identity token"
                            return 2
            else
              IO.eprintln "loam: amount must be a positive integer"
              return 2
      else
        IO.eprintln "loam: payment source must be a nonempty single-line token"
        return 2

/-- Command dispatcher for the practical CLI surface. -/
def run (args : List String) : IO UInt32 :=
  match args with
  | [] => do
      IO.println practicalUsage
      return 0
  | ["help"] => do
      IO.println practicalUsage
      return 0
  | ["help", "low-level"] => do
      IO.println lowLevelUsage
      return 0
  | ["spend", memoryPath] => spendJpy memoryPath
  | ["review", memoryPath] => reviewRememberedEvents memoryPath
  | ["amount", "show", path] => showAmount path
  | "event" :: "create" :: path :: eventToken :: effectArgs =>
      createEvent path eventToken effectArgs
  | ["event", "quantity", path, locus, measure] =>
      showEventQuantity path locus measure
  | ["event-memory", "get", path, eventToken] =>
      showRememberedEvent path eventToken
  | ["event-memory", "quantity", path, locus, measure] =>
      showRememberedQuantity path locus measure
  | ["event-memory", "add", memoryPath, eventPath] =>
      addRememberedEvent memoryPath eventPath
  | _ => do
      IO.eprintln "loam: command not understood"
      IO.eprintln practicalUsage
      return 2

end Loam.Cli

def main (args : List String) : IO UInt32 :=
  Loam.Cli.run args
