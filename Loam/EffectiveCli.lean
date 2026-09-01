import Loam.Application.QuantityInspection
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

/--
Print the recorded-mode answers supplied by the production Application boundary.
The caller has already selected the no-correction presentation heading; this
helper does not recompute quantity semantics directly from Core.
-/
private def printRecorded
    (memory : Loam.Core.EventMemory)
    (corrections : Loam.Core.EventCorrectionMemory)
    (coordinates : List Loam.Core.EffectCoordinate) : IO Bool := do
  for coordinate in coordinates do
    match Loam.Application.inspectQuantity
        memory corrections coordinate.locus coordinate.measure with
    | .recorded quantity =>
        if quantity.quanta ≠ 0 then
          IO.println
            ("  " ++ coordinate.locus.token ++ ": " ++
              toString quantity.quanta ++ " " ++ coordinate.measure.token)
    | _ => return false
  return true

/--
Print the single-correction answers supplied by the production Application
boundary. A missing endpoint remains an explicit refusal instead of being
reinterpreted by the CLI.
-/
private def printSingleCorrection
    (memory : Loam.Core.EventMemory)
    (corrections : Loam.Core.EventCorrectionMemory)
    (coordinates : List Loam.Core.EffectCoordinate) : IO Bool := do
  for coordinate in coordinates do
    match Loam.Application.inspectQuantity
        memory corrections coordinate.locus coordinate.measure with
    | .singleCorrectionEffective quantity =>
        if quantity.quanta ≠ 0 then
          IO.println
            ("  " ++ coordinate.locus.token ++ ": " ++
              toString quantity.quanta ++ " " ++ coordinate.measure.token)
    | .missingCorrectionEndpoint => return false
    | _ => return false
  return true

/--
Show the narrow practical effective-quantity projection already earned by the
Application quantity-inspection boundary. Zero-valued coordinates remain part
of the computed projection but are omitted from this ordinary human-facing
view.

The correction-count branch here selects presentation and prevents partial
output for the unsupported multi-correction frontier. Per-coordinate quantity
and refusal semantics come from `Loam.Application.inspectQuantity` rather than
being recomputed in the CLI.
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
                if ← printRecorded memory corrections coordinates then
                  return 0
                else
                  IO.eprintln "loam: application quantity inspection disagreed with recorded mode"
                  return 2
            | [_] =>
                IO.println "Effective quantities (single-correction projection; zero coordinates omitted):"
                if ← printSingleCorrection memory corrections coordinates then
                  return 0
                else
                  IO.eprintln "loam: correction references are not closed in event memory"
                  return 2
            | _ =>
                IO.eprintln
                  "loam: effective quantities unavailable: multiple corrections require a frontier projection"
                return 1

end Loam.EffectiveCli
