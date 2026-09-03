import Loam.Persistence
import Loam.Cli.ReviewCli
import Loam.WriterOwnership
import Loam.Cli.CorrectionCli
import Loam.Cli.ActualValidityCorrectionCli
import Loam.Cli.EffectiveCli
import Loam.Cli.CorrectionIntegrityCli
import Loam.Cli.ScheduledCli
import Loam.Cli.ScheduledLifecycleCli
import Std

namespace Loam.Cli

set_option autoImplicit false

/-- Render one admitted runtime amount without inventing display metadata. -/
def renderAmount (amount : Loam.Core.SomeAmount) : String :=
  amount.measure.token ++ "\t" ++ toString amount.quantity.quanta

private def practicalUsage : String :=
  "LOAM practical dogfood\n\n" ++
  "Daily recording uses the movement entrance:\n" ++
  "  ./tools/loam movement MEMORY_FILE\n\n" ++
  "Scheduled movements:\n" ++
  "  ./tools/loam scheduled SCHEDULED_FILE\n" ++
  "  ./tools/loam scheduled show SCHEDULED_FILE\n" ++
  "  ./tools/loam scheduled complete SCHEDULED_FILE MEMORY_FILE SCHEDULED_ID\n" ++
  "  ./tools/loam scheduled cancel SCHEDULED_FILE SCHEDULED_ID\n\n" ++
  "Review recorded facts:\n" ++
  "  ./tools/loam review MEMORY_FILE\n\n" ++
  "Show recorded quantities:\n" ++
  "  ./tools/loam summary MEMORY_FILE\n\n" ++
  "Correct a recorded movement append-only:\n" ++
  "  ./tools/loam correct MEMORY_FILE CORRECTION_FILE\n\n" ++
  "Correct a recorded occurrence date append-only:\n" ++
  "  ./tools/loam correct-date MEMORY_FILE CORRECTION_FILE\n\n" ++
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

/-- Create one complete Event from caller-supplied effect tuples. -/
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
          else if ← Loam.Persistence.saveEvent? filePath event then
            return 0
          else
            IO.eprintln "loam: event contains an unrepresentable identity token"
            return 2

/-- Project exact quanta from one persisted Event at an explicit coordinate. -/
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

/-- Retrieve one remembered Event by stable identity. -/
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

/-- Project the exact aggregate of all recorded facts at one coordinate. -/
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
  if coordinate ∈ coordinates then coordinates else coordinates ++ [coordinate]

private def recordedCoordinates
    (memory : Loam.Core.EventMemory) : List Loam.Core.EffectCoordinate :=
  memory.events.foldl
    (fun coordinates event =>
      event.effects.foldl
        (fun current effect => addCoordinateIfAbsent current effect.coordinate)
        coordinates)
    []

/-- Show recorded quantities without adding correction or balance semantics. -/
def showRecordedQuantitySummary (path : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk path
  if ← memoryFile.pathExists then
    match ← Loam.Persistence.loadEventMemory? memoryFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported event-memory file"
        return 2
    | some memory =>
        match recordedCoordinates memory with
        | [] =>
            IO.println "No recorded quantities."
            return 0
        | coordinates =>
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

/-- Show all remembered Events without interpreting representation order as time. -/
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

/-- Add one already-complete persisted Event under caller-held writer ownership. -/
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

private def withMemoryOwnership
    (memoryPath : String)
    (action : IO UInt32) : IO UInt32 :=
  Loam.WriterOwnership.withOwnership (System.FilePath.mk memoryPath) action

/-- Command dispatcher below the separate movement recording entrance. -/
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
  | ["scheduled", scheduledPath] =>
      Loam.ScheduledCli.recordScheduled scheduledPath
  | ["scheduled", "show", scheduledPath] =>
      Loam.ScheduledCli.showScheduled scheduledPath
  | ["scheduled", "complete", scheduledPath, memoryPath, scheduledToken] =>
      Loam.ScheduledLifecycleCli.completeScheduled scheduledPath memoryPath scheduledToken
  | ["scheduled", "cancel", scheduledPath, scheduledToken] =>
      Loam.ScheduledLifecycleCli.cancelScheduled scheduledPath scheduledToken
  | ["review", memoryPath] => Loam.ReviewCli.reviewRememberedEvents memoryPath
  | ["summary", memoryPath] => showRecordedQuantitySummary memoryPath
  | ["correct", memoryPath, correctionPath] =>
      withMemoryOwnership memoryPath
        (Loam.CorrectionCli.correctSpend memoryPath correctionPath)
  | ["correct-date", memoryPath, correctionPath] =>
      Loam.ActualValidityCorrectionCli.correctDate memoryPath correctionPath
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