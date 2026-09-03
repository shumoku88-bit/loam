import Loam.ActualValidityPersistence
import Loam.Persistence

namespace Loam.ReviewCli

set_option autoImplicit false

private def renderDate
    (validities : Loam.Core.ActualValidityMemory String)
    (eventId : Loam.Core.EventId) : String :=
  match Loam.Core.ActualValidityMemory.findByEventId? validities eventId with
  | some validOn => validOn
  | none => "date unknown"

/--
Review remembered Events together with separately retained occurrence dates.

Event-memory representation order remains non-temporal. The date label comes
only from `ActualValidity` evidence; older pre-date practical records remain
visible as `date unknown` rather than acquiring a guessed date.
-/
def reviewRememberedEvents (memoryPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
  if !(← memoryFile.pathExists) then
    IO.eprintln ("loam: file not found: " ++ memoryPath)
    return 2
  else
    match ← Loam.Persistence.loadEventMemory? memoryFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported event-memory file"
        return 2
    | some memory =>
        match ← Loam.Persistence.loadActualValidityMemoryOrEmpty? validityFile with
        | none =>
            IO.eprintln "loam: malformed or unsupported actual-validity file"
            return 2
        | some validities =>
            match memory.events with
            | [] =>
                IO.println "No recorded events."
                return 0
            | events =>
                IO.println "Recorded facts (date comes from ActualValidity; display order has no time meaning):"
                for event in events do
                  IO.println
                    (renderDate validities event.id ++ "  [" ++ event.id.token ++ "]")
                  match event.effects with
                  | [] => IO.println "  (no quantity effects)"
                  | effects =>
                      for effect in effects do
                        IO.println
                          ("  " ++ effect.locus.token ++ ": " ++
                            toString effect.quantity.quanta ++ " " ++ effect.measure.token)
                return 0

end Loam.ReviewCli
