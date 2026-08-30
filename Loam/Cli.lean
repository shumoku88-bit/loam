import Loam.Persistence
import Std

namespace Loam.Cli

set_option autoImplicit false

/-- Render one admitted runtime amount without inventing display metadata. -/
def renderAmount (amount : Loam.Core.SomeAmount) : String :=
  amount.measure.token ++ "\t" ++ toString amount.quantity.quanta

private def usage : String :=
  "usage:\n  loam amount show FILE\n  loam event create FILE EVENT [KEY LOCUS MEASURE QUANTA]...\n  loam event quantity FILE LOCUS MEASURE\n  loam event-memory get FILE EVENT\n  loam event-memory add MEMORY_FILE EVENT_FILE"

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

/-- Command dispatcher for the practical CLI surface. -/
def run (args : List String) : IO UInt32 :=
  match args with
  | ["amount", "show", path] => showAmount path
  | "event" :: "create" :: path :: eventToken :: effectArgs =>
      createEvent path eventToken effectArgs
  | ["event", "quantity", path, locus, measure] =>
      showEventQuantity path locus measure
  | ["event-memory", "get", path, eventToken] =>
      showRememberedEvent path eventToken
  | ["event-memory", "add", memoryPath, eventPath] =>
      addRememberedEvent memoryPath eventPath
  | _ => do
      IO.eprintln usage
      return 2

end Loam.Cli

def main (args : List String) : IO UInt32 :=
  Loam.Cli.run args
