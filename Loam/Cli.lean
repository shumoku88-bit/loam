import Loam.Persistence
import Loam.WriterOwnership
import Loam.CorrectionCli
import Loam.EffectiveCli
import Loam.CorrectionIntegrityCli
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
  "Record JPY income:\n" ++
  "  ./tools/loam income scratch/dogfood/memory.loam\n\n" ++
  "Move JPY between loci:\n" ++
  "  ./tools/loam transfer scratch/dogfood/memory.loam\n\n" ++
  "Review recorded facts:\n" ++
  "  ./tools/loam review scratch/dogfood/memory.loam\n\n" ++
  "Show recorded quantities:\n" ++
  "  ./tools/loam summary scratch/dogfood/memory.loam\n\n" ++
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

private def addCoordinateIfAbsent
    (coordinates : List Loam.Core.EffectCoordinate)
    (coordinate : Loam.Core.EffectCoordinate) : List Loam.Core.EffectCoordinate :=
  if coordinate ∈ coordinates then
    coordinates
  else
    coordinates ++ [coordinate]

/--
Collect every locus/measure coordinate that is actually represented in memory.
The retained list order is only a display convenience inherited from the current
persistence representation and carries no time, priority, or accounting meaning.
-/
private def recordedCoordinates
    (memory : Loam.Core.EventMemory) : List Loam.Core.EffectCoordinate :=
  memory.events.foldl
    (fun coordinates event =>
      event.effects.foldl
        (fun current effect => addCoordinateIfAbsent current effect.coordinate)
        coordinates)
    []

/--
Show one small report-like projection of EventMemory without introducing an
Account, Balance, Report, or other accounting primitive.

For each coordinate that occurs in recorded Effects, the displayed value is
exactly `EventMemory.quantityAtRecorded`. Zero totals remain visible. No
correction, reversal, effective-state, valuation, or temporal semantics are
applied. Display row order is not semantic.
-/
def showRecordedQuantitySummary (path : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk path
  if ← memoryFile.pathExists then
    match ← Loam.Persistence.loadEventMemory? memoryFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported event-memory file"
        return 2
    | some memory =>
        let coordinates := recordedCoordinates memory
        match coordinates with
        | [] =>
            IO.println "No recorded quantities."
            return 0
        | _ =>
            IO.println "Recorded quantities (all recorded facts; display order has no time meaning):"
            for coordinate in coordinates do
              let quantity :=
                Loam.Core.EventMemory.quantityAtRecorded
                  memory coordinate.locus coordinate.measure
              IO.println
                ("  " ++ coordinate.locus.token ++ ": " ++
                  toString quantity.quanta ++ " " ++ coordinate.measure.token)
            return 0
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
beside the target and then replaces the target with one filesystem rename. This
helper itself does not acquire process ownership; the production command
dispatcher holds EventMemory-anchored writer ownership across the complete
load/prepare/admit/publish operation.
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
The production command dispatcher acquires EventMemory-anchored writer
ownership before calling this entrance.
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

/--
Human-facing entrance for ordinary JPY income received at one locus.

`income` is an interface verb only. The retained Core fact is one positive JPY
Effect at the selected locus; no Income account, event-kind tag, or accounting
role is promoted into the Practical Core. A later typed fact family may add
such interpretation without changing this Event shape if daily use earns it.
-/
def incomeJpy (memoryPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  match ← loadEventMemoryForEntry? memoryFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported event-memory file"
      return 2
  | some memory =>
      let locusToken ← promptLine "Received into? "
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
                      (Loam.Core.Quantity.ofQuanta amount)
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
                              ("Recorded: received " ++ toString amount ++ " jpy into " ++ locusToken ++ ".")
                            return 0
                          else
                            IO.eprintln "loam: recorded event contains an unrepresentable identity token"
                            return 2
            else
              IO.eprintln "loam: amount must be a positive integer"
              return 2
      else
        IO.eprintln "loam: income destination must be a nonempty single-line token"
        return 2

/--
Human-facing entrance for moving one positive JPY amount between two distinct
loci.

The adapter records one generic Event with two distinct Effects:

`source -q` and `destination +q`.

The equal-and-opposite shape is an entrance-level promise for this verb, not a
new global conservation law for every LOAM Event. The Core still contains no
primitive Transfer object, no debit/credit side, and no accounting role. The
entrance also does not impose a nonnegative-source rule because LOAM has not yet
earned a universal backing or overdraft policy.
-/
def transferJpy (memoryPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  match ← loadEventMemoryForEntry? memoryFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported event-memory file"
      return 2
  | some memory =>
      let sourceToken ← promptLine "Move from? "
      if Loam.Persistence.validToken sourceToken then
        let destinationToken ← promptLine "Move to? "
        if Loam.Persistence.validToken destinationToken then
          if sourceToken = destinationToken then
            IO.eprintln "loam: transfer source and destination must differ"
            return 2
          else
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
                      let sourceEffect :=
                        Loam.Core.Effect.ofQuantity
                          ⟨"effect-1"⟩ ⟨sourceToken⟩ ⟨"jpy"⟩
                          (Loam.Core.Quantity.ofQuanta (-amount))
                      let destinationEffect :=
                        Loam.Core.Effect.ofQuantity
                          ⟨"effect-2"⟩ ⟨destinationToken⟩ ⟨"jpy"⟩
                          (Loam.Core.Quantity.ofQuanta amount)
                      match Loam.Core.Event.ofEffects?
                          eventId [sourceEffect, destinationEffect] with
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
                                  ("Recorded: moved " ++ toString amount ++ " jpy from " ++
                                    sourceToken ++ " to " ++ destinationToken ++ ".")
                                return 0
                              else
                                IO.eprintln "loam: recorded event contains an unrepresentable identity token"
                                return 2
                else
                  IO.eprintln "loam: amount must be a positive integer"
                  return 2
        else
          IO.eprintln "loam: transfer destination must be a nonempty single-line token"
          return 2
      else
        IO.eprintln "loam: transfer source must be a nonempty single-line token"
        return 2

private def withMemoryOwnership
    (memoryPath : String)
    (action : IO UInt32) : IO UInt32 :=
  Loam.WriterOwnership.withOwnership (System.FilePath.mk memoryPath) action

/--
Command dispatcher for the practical CLI surface.

Writer commands acquire one EventMemory-anchored cross-process ownership scope
before their existing implementation observes canonical state. For correction,
that same ownership remains held across the complete relation-first
Correction-then-Event publication sequence.
-/
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
  | ["spend", memoryPath] =>
      withMemoryOwnership memoryPath (spendJpy memoryPath)
  | ["income", memoryPath] =>
      withMemoryOwnership memoryPath (incomeJpy memoryPath)
  | ["transfer", memoryPath] =>
      withMemoryOwnership memoryPath (transferJpy memoryPath)
  | ["review", memoryPath] => reviewRememberedEvents memoryPath
  | ["summary", memoryPath] => showRecordedQuantitySummary memoryPath
  | ["correct", memoryPath, correctionPath] =>
      withMemoryOwnership memoryPath
        (Loam.CorrectionCli.correctSpend memoryPath correctionPath)
  | ["effective", memoryPath, correctionPath] =>
      Loam.EffectiveCli.showEffectiveQuantities memoryPath correctionPath
  | ["correction-integrity", memoryPath, correctionPath] =>
      Loam.CorrectionIntegrityCli.showCorrectionIntegrity memoryPath correctionPath
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
      withMemoryOwnership memoryPath
        (addRememberedEvent memoryPath eventPath)
  | _ => do
      IO.eprintln "loam: command not understood"
      IO.eprintln practicalUsage
      return 2

end Loam.Cli

def main (args : List String) : IO UInt32 :=
  Loam.Cli.run args