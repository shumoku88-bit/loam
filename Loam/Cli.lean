import Loam.Persistence
import Std

namespace Loam.Cli

set_option autoImplicit false

/-- Render one admitted runtime amount without inventing display metadata. -/
def renderAmount (amount : Loam.Core.SomeAmount) : String :=
  amount.measure.token ++ "\t" ++ toString amount.quantity.quanta

private def usage : String :=
  "usage:\n  loam record MEMORY_FILE\n  loam amount show FILE\n  loam event create FILE EVENT [KEY LOCUS MEASURE QUANTA]...\n  loam event quantity FILE LOCUS MEASURE\n  loam event-memory get FILE EVENT\n  loam event-memory quantity FILE LOCUS MEASURE\n  loam event-memory add MEMORY_FILE EVENT_FILE"

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
  match ← Loam.Persistence.load? (System.FilePath.mk path) with
  | some amount =>
      IO.println (renderAmount amount)
      return 0
  | none =>
      IO.eprintln "loam: malformed or unsupported amount file"
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
  match ← Loam.Persistence.loadEvent? (System.FilePath.mk path) with
  | some event =>
      let quantity := Loam.Core.Event.quantityAt event ⟨locusToken⟩ ⟨measureToken⟩
      IO.println (toString quantity.quanta)
      return 0
  | none =>
      IO.eprintln "loam: malformed or unsupported event file"
      return 2

/--
Read one persisted Event memory and retrieve one Event by stable identity.
The command exposes no storage index and therefore adds no `first`, `latest`,
temporal, causal, priority, authority, or posting-order semantics.
-/
def showRememberedEvent (path : String) (eventToken : String) : IO UInt32 := do
  match ← Loam.Persistence.loadEventMemory? (System.FilePath.mk path) with
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

/--
Read one persisted Event memory and project the exact aggregate of all recorded
facts at one explicit locus/measure coordinate.

This command deliberately exposes `EventMemory.quantityAtRecorded`. It does not
claim correction, reversal, current-state, effective-state, temporal, or
accounting semantics, and therefore is not named `balance`.
-/
def showRememberedQuantity
    (path : String) (locusToken : String) (measureToken : String) : IO UInt32 := do
  match ← Loam.Persistence.loadEventMemory? (System.FilePath.mk path) with
  | some memory =>
      let quantity :=
        Loam.Core.EventMemory.quantityAtRecorded memory ⟨locusToken⟩ ⟨measureToken⟩
      IO.println (toString quantity.quanta)
      return 0
  | none =>
      IO.eprintln "loam: malformed or unsupported event-memory file"
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

/-- Prompt for one line while keeping the practical record surface interactive. -/
private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimRight

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
Load an existing Event memory for recording, or begin from the already-admitted
empty memory when the target does not yet exist. A malformed existing target is
never silently replaced.
-/
private def loadEventMemoryForRecord?
    (path : System.FilePath) : IO (Option Loam.Core.EventMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventMemory? path
  else
    return Loam.Core.EventMemory.ofEvents? []

/--
Human-facing entrance for one single-coordinate recorded fact.

The caller supplies only where, signed change, and measure. Event identity and
Effect identity are operational details generated by this CLI; no intermediate
Event file is exposed. The command still records the same neutral Event/Effect
facts as the lower-level surface and does not infer expense, income, transfer,
account, debit/credit, or current-balance semantics.
-/
def recordQuantity (memoryPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  match ← loadEventMemoryForRecord? memoryFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported event-memory file"
      return 2
  | some memory =>
      let locusToken ← promptLine "Where? "
      if Loam.Persistence.validToken locusToken then
        let quantaText ← promptLine "Change? "
        match quantaText.toInt? with
        | none =>
            IO.eprintln "loam: change must be a signed integer quantity"
            return 2
        | some quanta =>
            let measureToken ← promptLine "Measure? "
            if Loam.Persistence.validToken measureToken then
              match freshRecordEventId? memory with
              | none =>
                  IO.eprintln "loam: could not generate a fresh event identity"
                  return 2
              | some eventId =>
                  let effect :=
                    Loam.Core.Effect.ofQuantity
                      ⟨"effect-1"⟩ ⟨locusToken⟩ ⟨measureToken⟩
                      (Loam.Core.Quantity.ofQuanta quanta)
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
                            let total :=
                              Loam.Core.EventMemory.quantityAtRecorded
                                updated ⟨locusToken⟩ ⟨measureToken⟩
                            IO.println
                              ("Recorded total at " ++ locusToken ++ " / " ++ measureToken ++
                                ": " ++ toString total.quanta)
                            return 0
                          else
                            IO.eprintln "loam: recorded event contains an unrepresentable identity token"
                            return 2
            else
              IO.eprintln "loam: measure must be a nonempty single-line token"
              return 2
      else
        IO.eprintln "loam: where must be a nonempty single-line token"
        return 2

/-- Command dispatcher for the practical CLI surface. -/
def run (args : List String) : IO UInt32 :=
  match args with
  | ["record", memoryPath] => recordQuantity memoryPath
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
      IO.eprintln usage
      return 2

end Loam.Cli

def main (args : List String) : IO UInt32 :=
  Loam.Cli.run args
