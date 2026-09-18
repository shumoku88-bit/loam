import Loam.ActualAuthority
import Std

namespace Loam.EffectiveCli

set_option autoImplicit false

private def recordedCoordinates
    (memory : Loam.Core.EventMemory) : List Loam.Core.EffectCoordinate :=
  (memory.events.flatMap fun event =>
    event.effects.map fun effect => effect.coordinate).eraseDups

private def quantityLine
    (coordinate : Loam.Core.EffectCoordinate)
    (quantity : Loam.Core.Quantity) : String :=
  "  " ++ coordinate.locus.token ++ ": " ++
    toString quantity.quanta ++ " " ++ coordinate.measure.token

/-- Print nonzero quantities from one already-admitted current Event basis. -/
private def printCurrent
    (basis : Loam.Core.EventMemory)
    (coordinates : List Loam.Core.EffectCoordinate) : IO Unit := do
  for coordinate in coordinates do
    let quantity :=
      Loam.Core.EventMemory.quantityAtRecorded
        basis coordinate.locus coordinate.measure
    if quantity.quanta ≠ 0 then
      IO.println (quantityLine coordinate quantity)

/--
Show the narrow practical effective-quantity projection already earned by the
Application quantity-inspection boundary. Zero-valued coordinates remain part
of the computed projection but are omitted from this ordinary human-facing
view.

Zero corrections use the recorded presentation heading. Any nonempty correction
set uses the admitted current Event basis carried by ActualAuthority.Image,
independent of correction count. Missing references, branching, merging and
cyclic correction shapes already fail closed while that normalized image is
loaded; this CLI does not re-admit the same topology per coordinate.
-/
def showEffectiveQuantities (actualPath : String) : IO UInt32 := do
  let actualFile := System.FilePath.mk actualPath
  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualFile with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok image => pure image
  let coordinates := recordedCoordinates image.currentEvents
  if image.evidence.corrections.corrections.isEmpty then
    IO.println "Effective quantities (zero coordinates omitted):"
  else
    IO.println
      "Effective quantities (correction-frontier projection; zero coordinates omitted):"
  printCurrent image.currentEvents coordinates
  return 0

end Loam.EffectiveCli
