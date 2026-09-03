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

private def quantityLine
    (coordinate : Loam.Core.EffectCoordinate)
    (quantity : Loam.Core.Quantity) : String :=
  "  " ++ coordinate.locus.token ++ ": " ++
    toString quantity.quanta ++ " " ++ coordinate.measure.token

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
          IO.println (quantityLine coordinate quantity)
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
          IO.println (quantityLine coordinate quantity)
    | .missingCorrectionEndpoint => return false
    | _ => return false
  return true

/--
Collect a qualified multi-correction frontier before printing anything.

The Application frontier decision is coordinate-independent, but collecting all
lines first keeps the CLI from producing a partial human-facing view even if an
unexpected disagreement were introduced later.
-/
private def frontierLines?
    (memory : Loam.Core.EventMemory)
    (corrections : Loam.Core.EventCorrectionMemory) :
    List Loam.Core.EffectCoordinate → Option (List String)
  | [] => some []
  | coordinate :: rest => do
      match Loam.Application.inspectQuantity
          memory corrections coordinate.locus coordinate.measure with
      | .frontierEffective quantity =>
          let later ← frontierLines? memory corrections rest
          if quantity.quanta ≠ 0 then
            return quantityLine coordinate quantity :: later
          else
            return later
      | _ => none

/--
Show the narrow practical effective-quantity projection already earned by the
Application quantity-inspection boundary. Zero-valued coordinates remain part
of the computed projection but are omitted from this ordinary human-facing
view.

Zero and one correction preserve the previously qualified presentation paths.
Two or more corrections are shown only when the Application boundary can derive
one correction frontier without using list position as authority. Unsupported
branching, merging, cyclic, or referentially open shapes fail closed before any
frontier quantities are printed.
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
                match frontierLines? memory corrections coordinates with
                | none =>
                    IO.eprintln
                      "loam: effective quantities unavailable: corrections do not justify one current frontier"
                    return 1
                | some lines =>
                    IO.println
                      "Effective quantities (correction-frontier projection; zero coordinates omitted):"
                    for line in lines do
                      IO.println line
                    return 0

end Loam.EffectiveCli
