import Loam.CurrentQuantityAnchor
import Loam.Persistence.SiblingStage
import Loam.Persistence.TokenSyntax
import Loam.Persistence.VersionedRows

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Current quantity anchor persistence

The file is one replaceable current-support image, not append-only history.

Version 1 stored one shared reflected-root cut plus assertions.

Version 2 stores zero or more anonymous reconciliation groups. Each group carries
its own reflected-root cut and assertions. Group order and boundaries are
representation only; no stable anchor/group identity is introduced.

Version-1 images remain readable and are lifted into one version-2 semantic
group. New writes use version 2.
-/

private def currentQuantityAnchorHeaderV1 : String := "LOAM-CURRENT-QUANTITY-ANCHOR	1"
private def currentQuantityAnchorHeaderV2 : String := "LOAM-CURRENT-QUANTITY-ANCHOR	2"

private def decodePayloadRows?
    (rows : List String) : Option (List EventId × List Loam.CurrentQuantityAnchor.Assertion) := do
  let mut roots : List EventId := []
  let mut assertions : List Loam.CurrentQuantityAnchor.Assertion := []
  for row in rows do
    match row.splitOn "	" with
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
  pure ("ROOT	" ++ root.token)

private def encodeAssertionRow?
    (assertion : Loam.CurrentQuantityAnchor.Assertion) : Option String := do
  let locus := assertion.coordinate.locus.token
  let measure := assertion.coordinate.measure.token
  if !validToken locus || !validToken measure then none else
  pure ("ASSERT	" ++ locus ++ "	" ++ measure ++ "	" ++ toString assertion.quantity.quanta)

private def decodeV1?
    (input : String) : Option Loam.CurrentQuantityAnchor.Evidence := do
  let rows ← decodeVersionedRows? currentQuantityAnchorHeaderV1 input
  let (roots, assertions) ← decodePayloadRows? rows
  Loam.CurrentQuantityAnchor.Evidence.ofLists? roots assertions

private def takeGroupRows :
    List String → List String → Option (List String × List String)
  | [], _ => none
  | "END" :: rest, reversed => some (reversed.reverse, rest)
  | row :: rest, reversed => takeGroupRows rest (row :: reversed)

private def decodeGroups? :
    List String → Option (List Loam.CurrentQuantityAnchor.Group)
  | [] => some []
  | "GROUP" :: rest => do
      let (groupRows, remaining) ← takeGroupRows rest []
      let (roots, assertions) ← decodePayloadRows? groupRows
      let group ← Loam.CurrentQuantityAnchor.Group.ofLists? roots assertions
      let later ← decodeGroups? remaining
      pure (group :: later)
  | _ => none

private def decodeV2?
    (input : String) : Option Loam.CurrentQuantityAnchor.Evidence := do
  let rows ← decodeVersionedRows? currentQuantityAnchorHeaderV2 input
  let groups ← decodeGroups? rows
  Loam.CurrentQuantityAnchor.Evidence.ofGroups? groups

/-- Decode one supported current reconciliation image; malformed content fails closed. -/
def decodeCurrentQuantityAnchor?
    (input : String) : Option Loam.CurrentQuantityAnchor.Evidence :=
  match decodeV2? input with
  | some evidence => some evidence
  | none => decodeV1? input

private def encodeGroupRows?
    (group : Loam.CurrentQuantityAnchor.Group) : Option (List String) := do
  let rootRows ← group.reflectedRoots.mapM encodeRootRow?
  let assertionRows ← group.assertions.mapM encodeAssertionRow?
  pure (["GROUP"] ++ rootRows ++ assertionRows ++ ["END"])

/-- Encode one already-admitted replaceable current-support image as version 2. -/
def encodeCurrentQuantityAnchor?
    (evidence : Loam.CurrentQuantityAnchor.Evidence) : Option String := do
  let groupedRows ← evidence.groups.mapM encodeGroupRows?
  pure (encodeVersionedRows currentQuantityAnchorHeaderV2 groupedRows.flatten)

/-- Atomically replace one complete current-support image. -/
def saveCurrentQuantityAnchor?
    (path : System.FilePath)
    (evidence : Loam.CurrentQuantityAnchor.Evidence) : IO Bool := do
  match encodeCurrentQuantityAnchor? evidence with
  | none => return false
  | some text =>
      replaceTextViaSiblingStage path text
      return true

/-- Read one current-support image; malformed or unsupported content returns `none`. -/
def loadCurrentQuantityAnchor?
    (path : System.FilePath) : IO (Option Loam.CurrentQuantityAnchor.Evidence) := do
  let input ← IO.FS.readFile path
  return decodeCurrentQuantityAnchor? input

end Loam.Persistence
