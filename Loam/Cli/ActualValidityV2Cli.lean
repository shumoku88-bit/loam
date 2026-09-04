import Loam.Application.ActualValidityV2Conversion
import Loam.Persistence.ActualValidityPersistence
import Loam.WriterOwnership

namespace Loam.ActualValidityV2Cli

set_option autoImplicit false

private def checkFile (memoryPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
  if !(← validityFile.pathExists) then
    IO.println "ActualValidity storage is absent; the next practical write will start as V2."
    return 0
  else
    match ← Loam.Persistence.loadActualValidityHistoryWithVersion? validityFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported actual-validity history"
        return 2
    | some (.v2, _) =>
        IO.println "ActualValidity storage is already V2."
        return 0
    | some (.v1, history) =>
        match Loam.Application.compressActualValidityV1ToV2? history with
        | none =>
            IO.eprintln
              "loam: V1 actual-validity history is not admissible for root compression"
            return 2
        | some compressed =>
            match Loam.Persistence.encodeActualValidityHistoryV2? compressed with
            | none =>
                IO.eprintln "loam: V1 history could not be represented as V2"
                return 2
            | some _ =>
                IO.println
                  ("ActualValidity V1 is convertible to V2: " ++
                    toString history.facts.length ++ " retained date facts -> " ++
                    toString compressed.corrections.length ++
                    " correction relations with Event-rooted initial dates.")
                return 0

private def convertUnderOwnership (memoryPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
  if !(← validityFile.pathExists) then
    match Loam.Core.ActualValidityHistory.ofParts?
        ([] : List (Loam.Core.ActualValidityFact String)) [] with
    | none =>
        IO.eprintln "loam: could not construct empty ActualValidity V2 state"
        return 2
    | some empty =>
        if ← Loam.Persistence.saveActualValidityHistoryV2? validityFile empty then
          IO.println "Created empty Event-rooted ActualValidity V2 storage."
          return 0
        else
          IO.eprintln "loam: empty ActualValidity V2 storage could not be published"
          return 2
  else
    match ← Loam.Persistence.loadActualValidityHistoryWithVersion? validityFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported actual-validity history"
        return 2
    | some (.v2, _) =>
        IO.println "ActualValidity storage is already V2; nothing changed."
        return 0
    | some (.v1, history) =>
        match Loam.Application.compressActualValidityV1ToV2? history with
        | none =>
            IO.eprintln
              "loam: V1 actual-validity history is not admissible for root compression"
            return 2
        | some compressed =>
            if !(← Loam.Persistence.saveActualValidityHistoryV2? validityFile compressed) then
              IO.eprintln "loam: ActualValidity V2 image could not be published"
              return 2
            else
              match ← Loam.Persistence.loadActualValidityHistoryWithVersion? validityFile with
              | some (.v2, reloaded) =>
                  match Loam.Application.admittedActualValidityMemory? compressed,
                      Loam.Application.admittedActualValidityMemory? reloaded with
                  | some expected, some actual =>
                      if expected.entries = actual.entries then
                        IO.println
                          ("Converted ActualValidity to V2: initial date identity is now EventId; " ++
                            toString reloaded.corrections.length ++
                            " correction relations retain later revision identity.")
                        return 0
                      else
                        IO.eprintln
                          "loam: V2 reload parity failed after publication"
                        return 2
                  | _, _ =>
                      IO.eprintln
                        "loam: V2 reload no longer admits one current date per Event"
                      return 2
              | _ =>
                  IO.eprintln "loam: published ActualValidity V2 image could not be reloaded"
                  return 2

private def convertFile (memoryPath : String) : IO UInt32 :=
  Loam.WriterOwnership.withOwnership
    (System.FilePath.mk memoryPath)
    (convertUnderOwnership memoryPath)

private def usage : String :=
  "Qualify or convert the sibling ActualValidity stream:\n" ++
  "  loamActualValidityV2 check MEMORY_FILE\n" ++
  "  loamActualValidityV2 convert MEMORY_FILE"

def run (args : List String) : IO UInt32 :=
  match args with
  | ["check", memoryPath] => checkFile memoryPath
  | ["convert", memoryPath] => convertFile memoryPath
  | _ => do
      IO.eprintln usage
      return 2

end Loam.ActualValidityV2Cli

def main (args : List String) : IO UInt32 :=
  Loam.ActualValidityV2Cli.run args
