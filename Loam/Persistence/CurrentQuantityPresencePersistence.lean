import Loam.CurrentQuantityPresence
import Loam.Persistence.SiblingStage
import Loam.Persistence.TokenSyntax
import Loam.Persistence.VersionedRows

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Current quantity presence persistence

One replaceable observation image records a shared reflected-root cut plus the
coordinates known to be nonzero at that boundary while their exact Quantity is
unknown. No estimate, range, sign inference, or arithmetic value is stored.
-/

private def currentQuantityPresenceHeader : String :=
  "LOAM-CURRENT-QUANTITY-PRESENCE\t1"

private def decodeRows?
    (rows : List String) : Option (List EventId × List EffectCoordinate) := do
  let mut roots : List EventId := []
  let mut coordinates : List EffectCoordinate := []
  for row in rows do
    match row.splitOn "\t" with
    | ["ROOT", eventToken] =>
        if !validToken eventToken then none else
        roots := roots ++ [⟨eventToken⟩]
    | ["PRESENT", locusToken, measureToken] =>
        if !validToken locusToken || !validToken measureToken then none else
        coordinates := coordinates ++ [⟨⟨locusToken⟩, ⟨measureToken⟩⟩]
    | _ => none
  pure (roots, coordinates)

private def encodeRootRow? (root : EventId) : Option String := do
  if !validToken root.token then none else
  pure ("ROOT\t" ++ root.token)

private def encodeCoordinateRow? (coordinate : EffectCoordinate) : Option String := do
  let locus := coordinate.locus.token
  let measure := coordinate.measure.token
  if !validToken locus || !validToken measure then none else
  pure ("PRESENT\t" ++ locus ++ "\t" ++ measure)

def decodeCurrentQuantityPresence?
    (input : String) : Option Loam.CurrentQuantityPresence.Evidence := do
  let rows ← decodeVersionedRows? currentQuantityPresenceHeader input
  let (roots, coordinates) ← decodeRows? rows
  Loam.CurrentQuantityPresence.Evidence.ofLists? roots coordinates

def encodeCurrentQuantityPresence?
    (evidence : Loam.CurrentQuantityPresence.Evidence) : Option String := do
  let rootRows ← evidence.reflectedRoots.mapM encodeRootRow?
  let coordinateRows ← evidence.coordinates.mapM encodeCoordinateRow?
  pure (encodeVersionedRows currentQuantityPresenceHeader (rootRows ++ coordinateRows))

def saveCurrentQuantityPresence?
    (path : System.FilePath)
    (evidence : Loam.CurrentQuantityPresence.Evidence) : IO Bool := do
  match encodeCurrentQuantityPresence? evidence with
  | none => return false
  | some text =>
      replaceTextViaSiblingStage path text
      return true

def loadCurrentQuantityPresence?
    (path : System.FilePath) : IO (Option Loam.CurrentQuantityPresence.Evidence) := do
  let input ← IO.FS.readFile path
  return decodeCurrentQuantityPresence? input

end Loam.Persistence
