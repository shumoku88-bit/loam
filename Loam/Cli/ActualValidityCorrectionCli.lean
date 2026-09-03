import Loam.ActualDate
import Loam.Persistence.ActualValidityPersistence
import Loam.Application.ActualValidityFrontier
import Loam.Application.CorrectionFrontier
import Loam.Persistence
import Loam.WriterOwnership

namespace Loam.ActualValidityCorrectionCli

set_option autoImplicit false

private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString

private def getAt? {α : Type} : List α → Nat → Option α
  | [], _ => none
  | item :: _, 0 => some item
  | _ :: rest, index + 1 => getAt? rest index

private def loadEventCorrectionMemoryOrEmpty?
    (path : System.FilePath) : IO (Option Loam.Core.EventCorrectionMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventCorrectionMemory? path
  else
    return Loam.Core.EventCorrectionMemory.ofCorrections? []

private def currentFactForEvent? :
    List (Loam.Core.ActualValidityFact String) →
    Loam.Core.EventId → Option (Loam.Core.ActualValidityFact String)
  | [], _ => none
  | fact :: rest, eventId =>
      if fact.event = eventId then some fact else currentFactForEvent? rest eventId

private def renderCurrentDate
    (facts : List (Loam.Core.ActualValidityFact String))
    (eventId : Loam.Core.EventId) : String :=
  match currentFactForEvent? facts eventId with
  | some fact => fact.validOn
  | none => "date unknown"

private def printCandidates
    (facts : List (Loam.Core.ActualValidityFact String)) :
    Nat → List Loam.Core.Event → IO Unit
  | _, [] => pure ()
  | index, event :: rest => do
      IO.println
        (toString index ++ ". " ++ renderCurrentDate facts event.id ++
          "  [" ++ event.id.token ++ "]")
      for effect in event.effects do
        IO.println
          ("    " ++ effect.locus.token ++ ": " ++
            toString effect.quantity.quanta ++ " " ++ effect.measure.token)
      printCandidates facts (index + 1) rest

private def freshFactIdFrom
    (history : Loam.Core.ActualValidityHistory String) :
    Nat → Nat → Option Loam.Core.ActualValidityFactId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : Loam.Core.ActualValidityFactId := ⟨"validity-" ++ toString index⟩
      match history.findFactById? candidate with
      | none => some candidate
      | some _ => freshFactIdFrom history (index + 1) fuel

private def freshFactId?
    (history : Loam.Core.ActualValidityHistory String) : Option Loam.Core.ActualValidityFactId :=
  freshFactIdFrom history 1 (history.facts.length + 1)

private def freshCorrectionIdFrom
    (history : Loam.Core.ActualValidityHistory String) :
    Nat → Nat → Option Loam.Core.ActualValidityCorrectionId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : Loam.Core.ActualValidityCorrectionId :=
        ⟨"validity-correction-" ++ toString index⟩
      match history.findCorrectionById? candidate with
      | none => some candidate
      | some _ => freshCorrectionIdFrom history (index + 1) fuel

private def freshCorrectionId?
    (history : Loam.Core.ActualValidityHistory String) :
    Option Loam.Core.ActualValidityCorrectionId :=
  freshCorrectionIdFrom history 1 (history.corrections.length + 1)

private def appendDateChange?
    (history : Loam.Core.ActualValidityHistory String)
    (event : Loam.Core.Event)
    (currentFact? : Option (Loam.Core.ActualValidityFact String))
    (validOn : String) : Option (Loam.Core.ActualValidityHistory String) := do
  let factId ← freshFactId? history
  let replacement : Loam.Core.ActualValidityFact String := {
    id := factId
    event := event.id
    validOn := validOn
  }
  let withFact ← history.addFact? replacement
  match currentFact? with
  | none => pure withFact
  | some currentFact => do
      let correctionId ← freshCorrectionId? history
      let correction : Loam.Core.ActualValidityCorrection := {
        id := correctionId
        target := currentFact.id
        replacement := replacement.id
      }
      withFact.addCorrection? correction

private def correctDateUnderOwnership
    (memoryPath correctionPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let eventCorrectionFile := System.FilePath.mk correctionPath
  let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
  if !(← memoryFile.pathExists) then
    IO.println "Nothing recorded yet."
    return 0
  else
    match ← Loam.Persistence.loadEventMemory? memoryFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported event-memory file"
        return 2
    | some events =>
        match ← loadEventCorrectionMemoryOrEmpty? eventCorrectionFile with
        | none =>
            IO.eprintln "loam: malformed or unsupported correction-memory file"
            return 2
        | some eventCorrections =>
            match Loam.Application.correctionFrontierMemory? events eventCorrections with
            | none =>
                IO.eprintln "loam: movement corrections do not justify one current record frontier"
                return 2
            | some currentEvents =>
                match ← Loam.Persistence.loadActualValidityHistoryOrEmpty? validityFile with
                | none =>
                    IO.eprintln "loam: malformed or unsupported actual-validity history"
                    return 2
                | some history =>
                    match Loam.Application.admittedActualValidityFacts? history with
                    | none =>
                        IO.eprintln
                          "loam: actual-validity corrections do not justify one current date per event"
                        return 2
                    | some currentFacts =>
                        match currentEvents.events with
                        | [] =>
                            IO.println "No current records are available to date."
                            return 0
                        | candidates =>
                            IO.println "Which record needs a date correction?"
                            printCandidates currentFacts 1 candidates
                            let selectionText ← promptLine "Select number: "
                            match selectionText.toNat? with
                            | none =>
                                IO.eprintln "loam: choose one of the displayed numbers"
                                return 2
                            | some 0 =>
                                IO.eprintln "loam: choose one of the displayed numbers"
                                return 2
                            | some selection =>
                                match getAt? candidates (selection - 1) with
                                | none =>
                                    IO.eprintln "loam: choose one of the displayed numbers"
                                    return 2
                                | some event =>
                                    let currentFact? := currentFactForEvent? currentFacts event.id
                                    let currentLabel := renderCurrentDate currentFacts event.id
                                    let entered ← promptLine ("Correct date [" ++ currentLabel ++ "]: ")
                                    if !Loam.ActualDate.validIsoDate entered then
                                      IO.eprintln
                                        "loam: date must be a real calendar date in YYYY-MM-DD form"
                                      return 2
                                    else
                                      match currentFact? with
                                      | some currentFact =>
                                          if currentFact.validOn = entered then
                                            IO.println "Date is already current; nothing changed."
                                            return 0
                                          else
                                            match appendDateChange? history event currentFact? entered with
                                            | none =>
                                                IO.eprintln "loam: could not append date correction facts"
                                                return 2
                                            | some updatedHistory =>
                                                if ← Loam.Persistence.saveActualValidityHistory?
                                                    validityFile updatedHistory then
                                                  IO.println
                                                    ("Date corrected: " ++ currentFact.validOn ++
                                                      " -> " ++ entered ++ ".")
                                                  return 0
                                                else
                                                  IO.eprintln "loam: date correction could not be published"
                                                  return 2
                                      | none =>
                                          match appendDateChange? history event none entered with
                                          | none =>
                                              IO.eprintln "loam: could not append first date fact"
                                              return 2
                                          | some updatedHistory =>
                                              if ← Loam.Persistence.saveActualValidityHistory?
                                                  validityFile updatedHistory then
                                                IO.println ("Date recorded: " ++ entered ++ ".")
                                                return 0
                                              else
                                                IO.eprintln "loam: date evidence could not be published"
                                                return 2

/--
Set or correct one current Event occurrence date without rewriting Event payload.

The entrance owns the Event-memory writer boundary itself, so direct and primary
CLI callers cannot accidentally bypass serialization. When a current validity
fact exists, one replacement fact and one correction relation are appended in
one validity-history publication. An older pre-date Event simply receives its
first identified validity fact.
-/
def correctDate (memoryPath correctionPath : String) : IO UInt32 :=
  Loam.WriterOwnership.withOwnership
    (System.FilePath.mk memoryPath)
    (correctDateUnderOwnership memoryPath correctionPath)

private def usage : String :=
  "Correct one occurrence date append-only:\n" ++
  "  ./tools/loam correct-date MEMORY_FILE CORRECTION_FILE"

def run (args : List String) : IO UInt32 :=
  match args with
  | [memoryPath, correctionPath] => correctDate memoryPath correctionPath
  | _ => do
      IO.eprintln usage
      return 2

end Loam.ActualValidityCorrectionCli
