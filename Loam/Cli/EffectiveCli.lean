import Loam.Application.QuantityInspection
import Loam.ActualAuthority
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
Collect correction-frontier answers before printing anything. The frontier
admission decision is coordinate-independent, but collecting first keeps the CLI
from producing a partial human-facing view if an unexpected disagreement is ever
introduced between the inspection and frontier boundaries.
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

Zero corrections use the recorded presentation. Any nonempty correction set
uses the same Correction frontier, independent of correction count. Missing
references retain their specific diagnostic; branching, merging and cyclic
shapes fail closed as unsupported frontier topology.
-/
def showEffectiveQuantities (actualPath : String) (_correctionPath : Option String := none) : IO UInt32 := do
  let actualFile := System.FilePath.mk actualPath
  let evidence ←
    match ← Loam.ActualAuthority.loadActualFile? actualFile with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok ev => pure ev
  let memory := evidence.events
  let corrections := evidence.corrections
  let coordinates := recordedCoordinates memory
  match corrections.corrections with
            | [] =>
                IO.println "Effective quantities (zero coordinates omitted):"
                if ← printRecorded memory corrections coordinates then
                  return 0
                else
                  IO.eprintln "loam: application quantity inspection disagreed with recorded mode"
                  return 2
            | _ =>
                if !Loam.Application.correctionReferencesClosed memory corrections then
                  IO.eprintln "loam: correction references are not closed in event memory"
                  return 2
                else if !Loam.Application.correctionFrontierAdmissible memory corrections then
                  IO.eprintln
                    "loam: effective quantities unavailable: corrections do not justify one current frontier"
                  return 1
                else
                  match frontierLines? memory corrections coordinates with
                  | none =>
                      IO.eprintln "loam: application quantity inspection disagreed with admitted frontier"
                      return 2
                  | some lines =>
                      IO.println
                        "Effective quantities (correction-frontier projection; zero coordinates omitted):"
                      for line in lines do
                        IO.println line
                      return 0

end Loam.EffectiveCli
