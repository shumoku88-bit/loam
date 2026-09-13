import Loam.Core.OpeningSupport
import Loam.Persistence.TokenSyntax
import Loam.Persistence.SiblingStage
import Loam.Persistence.VersionedRows

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Opening support persistence

The persisted family carries only the partial
`EffectCoordinate -> EventId` relation qualified by Observation 245.
The opening quantity remains in the referenced Actual Event; this format does
not duplicate it or infer support from Event content.
-/

private def openingSupportHeader : String := "LOAM-OPENING-SUPPORT\t1"

private def decodeOpeningSupportRow? (row : String) : Option OpeningSupport :=
  match row.splitOn "\t" with
  | ["OPENING", locusToken, measureToken, eventToken] => do
      if !validToken locusToken || !validToken measureToken || !validToken eventToken then
        none
      else
        some {
          coordinate := ⟨⟨locusToken⟩, ⟨measureToken⟩⟩
          openingEvent := ⟨eventToken⟩
        }
  | _ => none

private def encodeOpeningSupportRow? (support : OpeningSupport) : Option String := do
  let locus := support.coordinate.locus.token
  let measure := support.coordinate.measure.token
  let event := support.openingEvent.token
  if !validToken locus || !validToken measure || !validToken event then none else
  pure ("OPENING\t" ++ locus ++ "\t" ++ measure ++ "\t" ++ event)

/-- Decode one version-1 partial opening-support relation. Duplicate coordinates fail closed. -/
def decodeOpeningSupportMap? (input : String) : Option OpeningSupportMap := do
  let rows ← decodeVersionedRows? openingSupportHeader input
  let supports ← rows.mapM decodeOpeningSupportRow?
  OpeningSupportMap.ofSupports? supports

/-- Encode one already-admitted complete opening-support relation. -/
def encodeOpeningSupportMap? (supportMap : OpeningSupportMap) : Option String := do
  let rows ← supportMap.supports.mapM encodeOpeningSupportRow?
  pure (encodeVersionedRows openingSupportHeader rows)

/-- Publish one complete opening-support image through the shared sibling stage. -/
def saveOpeningSupportMap?
    (path : System.FilePath) (supportMap : OpeningSupportMap) : IO Bool := do
  match encodeOpeningSupportMap? supportMap with
  | none => return false
  | some text =>
      replaceTextViaSiblingStage path text
      return true

/-- Read and fail-closed decode one configured opening-support image. -/
def loadOpeningSupportMap? (path : System.FilePath) : IO (Option OpeningSupportMap) := do
  let input ← IO.FS.readFile path
  return decodeOpeningSupportMap? input

end Loam.Persistence
