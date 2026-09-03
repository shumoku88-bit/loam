import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Application.ActualValidityFrontier
import Loam.Persistence

namespace Loam.ReviewCli

set_option autoImplicit false

private def renderDate
    (validities : Loam.Core.ActualValidityMemory String)
    (eventId : Loam.Core.EventId) : String :=
  match Loam.Core.ActualValidityMemory.findByEventId? validities eventId with
  | some validOn => validOn
  | none => "date unknown"

private def loadEventDescriptionMemoryOrEmpty?
    (path : System.FilePath) : IO (Option Loam.Core.EventDescriptionMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventDescriptionMemory? path
  else
    return some Loam.Core.EventDescriptionMemory.empty

private def renderHeading
    (validities : Loam.Core.ActualValidityMemory String)
    (descriptions : Loam.Core.EventDescriptionMemory)
    (eventId : Loam.Core.EventId) : String :=
  let date := renderDate validities eventId
  match Loam.Core.EventDescriptionMemory.findText? descriptions eventId with
  | some text => date ++ "  " ++ text ++ "  [" ++ eventId.token ++ "]"
  | none => date ++ "  [" ++ eventId.token ++ "]"

/--
Review remembered Events together with admitted occurrence-date and optional
human-recognition description evidence.

Raw validity history remains append-only. Superseded dates leave the current
frontier only through explicit correction relations. Event descriptions remain
separate evidence keyed by EventId and do not alter quantity projections.
Event-memory representation order remains non-temporal, and older records with
missing date or description evidence remain visible without guessed values.
-/
def reviewRememberedEvents (memoryPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
  let descriptionFile := Loam.Persistence.eventDescriptionPathForEventMemory memoryFile
  if !(← memoryFile.pathExists) then
    IO.eprintln ("loam: file not found: " ++ memoryPath)
    return 2
  else
    match ← Loam.Persistence.loadEventMemory? memoryFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported event-memory file"
        return 2
    | some memory =>
        match ← Loam.Persistence.loadActualValidityHistoryOrEmpty? validityFile with
        | none =>
            IO.eprintln "loam: malformed or unsupported actual-validity history"
            return 2
        | some history =>
            match ← loadEventDescriptionMemoryOrEmpty? descriptionFile with
            | none =>
                IO.eprintln "loam: malformed or unsupported event-description memory"
                return 2
            | some descriptions =>
                match Loam.Application.admittedActualValidityMemory? history with
                | none =>
                    IO.eprintln
                      "loam: actual-validity corrections do not justify one current date per event"
                    return 2
                | some validities =>
                    match memory.events with
                    | [] =>
                        IO.println "No recorded events."
                        return 0
                    | events =>
                        IO.println
                          "Recorded facts (date and description come from adjacent evidence streams; display order has no time meaning):"
                        for event in events do
                          IO.println (renderHeading validities descriptions event.id)
                          match event.effects with
                          | [] => IO.println "  (no quantity effects)"
                          | effects =>
                              for effect in effects do
                                IO.println
                                  ("  " ++ effect.locus.token ++ ": " ++
                                    toString effect.quantity.quanta ++ " " ++ effect.measure.token)
                        return 0

end Loam.ReviewCli
