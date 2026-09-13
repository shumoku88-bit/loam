import Loam.CurrentQuantityAnchor
import Loam.Persistence.SiblingStage
import Loam.Persistence.TokenSyntax
import Loam.Persistence.VersionedRows

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Current quantity anchor persistence

The file is one replaceable reconciliation image, not append-only history. It
stores exactly the shared reflected-root cut and the coordinate quantities
asserted together at that boundary. Semantic admission and publication live
outside this persistence module.
-/

private def currentQuantityAnchorHeader : String := "LOAM-CURRENT-QUANTITY-ANCHOR\t1"

private def decodeRows?
    (rows : List String) : Option (List EventId × List Loam.CurrentQuantityAnchor.Assertion) := do
  let mut roots : List EventId := []
  let mut assertions : List Loam.CurrentQuantityAnchor.Assertion := []
  for row in rows do
    match row.splitOn "\t" with
    | ["ROOT", eventToken] =>
        if !validToken eventToken then none else
        roots := roots ++ [⟨eventToken⟩]
    | ["ASSERT", locusToken, measureToken, quantityToken] =>
        if !validToken locusToken || !validToken measureToken then none else
        let quantity ← quantityToken.toInt?
        assertions := assertions ++ [{
          coordinate := ⟨⟨locusToken⟩, ⟨measureToken⟩⟩
          quantity := Quantity.ofQuanta quantity
        }]
    | _ => none
  pure (roots, assertions)

private def encodeRootRow? (root : EventId) : Option String := do
  if !validToken root.token then none else
  pure ("ROOT\t" ++ root.token)

private def encodeAssertionRow?
    (assertion : Loam.CurrentQuantityAnchor.Assertion) : Option String := do
  let locus := assertion.coordinate.locus.token
  let measure := assertion.coordinate.measure.token
  if !validToken locus || !validToken measure then none else
  pure ("ASSERT\t" ++ locus ++ "\t" ++ measure ++ "\t" ++ toString assertion.quantity.quanta)

/-- Decode one complete version-1 reconciliation image; duplicates fail closed. -/
def decodeCurrentQuantityAnchor?
    (input : String) : Option Loam.CurrentQuantityAnchor.Evidence := do
  let rows ← decodeVersionedRows? currentQuantityAnchorHeader input
  let (roots, assertions) ← decodeRows? rows
  Loam.CurrentQuantityAnchor.Evidence.ofLists? roots assertions

/-- Encode one already-admitted complete reconciliation image. -/
def encodeCurrentQuantityAnchor?
    (evidence : Loam.CurrentQuantityAnchor.Evidence) : Option String := do
  let rootRows ← evidence.reflectedRoots.mapM encodeRootRow?
  let assertionRows ← evidence.assertions.mapM encodeAssertionRow?
  pure (encodeVersionedRows currentQuantityAnchorHeader (rootRows ++ assertionRows))

/-- Atomically replace one complete current reconciliation image. -/
def saveCurrentQuantityAnchor?
    (path : System.FilePath)
    (evidence : Loam.CurrentQuantityAnchor.Evidence) : IO Bool := do
  match encodeCurrentQuantityAnchor? evidence with
  | none => return false
  | some text =>
      replaceTextViaSiblingStage path text
      return true

/-- Read one current reconciliation image; malformed content returns `none`. -/
def loadCurrentQuantityAnchor?
    (path : System.FilePath) : IO (Option Loam.CurrentQuantityAnchor.Evidence) := do
  let input ← IO.FS.readFile path
  return decodeCurrentQuantityAnchor? input

end Loam.Persistence
