import Loam.Core.CorrectionQuantity
import Loam.Persistence
import Std

namespace Loam.EffectiveCli

set_option autoImplicit false

private def addCoordinateIfAbsent
    (coordinates : List Loam.Core.EffectCoordinate)
    (coordinate : Loam.Core.EffectCoordinate) : List Loam.Core.EffectCoordinate :=
  if coordinate ∈ coordinates then
    coordinates
  else
    coordinates ++ [coordinate]

private def recordedCoordinates
    (memory : Loam.Core.EventMemory) : List Loam.Core.EffectCoordinate :=
  memory.events.foldl
    (fun coordinates event =>
      event.effects.foldl
        (fun current effect => addCoordinateIfAbsent current effect.coordinate)
        coordinates)
    []

private def loadCorrectionMemoryForView?
    (path : System.FilePath) : IO (Option Loam.Core.EventCorrectionMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventCorrectionMemory? path
  else
    return Loam.Core.EventCorrectionMemory.ofCorrections? []

private def printRecorded
    (memory : Loam.Core.EventMemory)
    (coordinates : List Loam.Core.EffectCoordinate) : IO Unit := do
  for coordinate in coordinates do
    let quantity :=
      Loam.Core.EventMemory.quantityAtRecorded
        memory coordinate.locus coordinate.measure
    if quantity.quanta ≠ 0 then
      IO.println
        ("  " ++ coordinate.locus.token ++ ": " ++
          toString quantity.quanta ++ " " ++ coordinate.measure.token)

private def printSingleCorrection
    (memory : Loam.Core.EventMemory)
    (correction : Loam.Core.EventCorrection)
    (coordinates : List Loam.Core.EffectCoordinate) : IO Bool := do
  for coordinate in coordinates do
    match Loam.Core.EventCorrection.quantityAtEffective?
        memory correction coordinate.locus coordinate.measure with
    | none => return false
    | some quantity =>
        if quantity.quanta ≠ 0 then
          IO.println
            ("  " ++ coordinate.locus.token ++ ": " ++
              toString quantity.quanta ++ " " ++ coordinate.measure.token)
  return true

/--
Show the narrow practical effective-quantity projection already earned by the
single-correction Core law. Zero-valued coordinates remain part of the computed
projection but are omitted from this ordinary human-facing view.
-/
def showEffectiveQuantities (memoryPath correctionPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let correctionFile := System.FilePath.mk correctionPath
  if !(← memoryFile.pathExists) then
    IO.println "No recorded quantities."
    return 0
  else
    match ← Loam.Persistence.loadEventMemory? memoryFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported event-memory file"
        return 2
    | some memory =>
        match ← loadCorrectionMemoryForView? correctionFile with
        | none =>
            IO.eprintln "loam: malformed or unsupported correction-memory file"
            return 2
        | some corrections =>
            let coordinates := recordedCoordinates memory
            match corrections.corrections with
            | [] =>
                IO.println "Effective quantities (zero coordinates omitted):"
                printRecorded memory coordinates
                return 0
            | [correction] =>
                IO.println "Effective quantities (single-correction projection; zero coordinates omitted):"
                if ← printSingleCorrection memory correction coordinates then
                  return 0
                else
                  IO.eprintln "loam: correction references are not closed in event memory"
                  return 2
            | _ =>
                IO.eprintln
                  "loam: effective quantities unavailable: multiple corrections require a frontier projection"
                return 1

end Loam.EffectiveCli
