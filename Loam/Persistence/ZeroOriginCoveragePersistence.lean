import Loam.Core.ZeroOriginCoverage
import Loam.Persistence.TokenSyntax
import Loam.Persistence.SiblingStage
import Loam.Persistence.VersionedRows

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Zero-origin coverage persistence

The persisted family carries exactly one explicit finite set of neutral
`Locus × Measure` coordinates known complete from zero for the selected retained
Event world. It does not derive membership from Event activity, balance-view
selection, Locus admission, or any other authority.
-/

/-- Version marker for the first explicit zero-origin coverage format. -/
def zeroOriginCoverageHeader : String := "LOAM-ZERO-ORIGIN-COVERAGE\t1"

private def encodeCoordinateRow? (coordinate : EffectCoordinate) : Option String :=
  let locus := coordinate.locus.token
  let measure := coordinate.measure.token
  if validToken locus && validToken measure then
    some ("COORDINATE\t" ++ locus ++ "\t" ++ measure)
  else
    none

/-- Encode one explicit finite zero-origin evidence set. -/
def encodeZeroOriginCoverage? (coverage : ZeroOriginCoverage) : Option String := do
  let rows ← coverage.coordinates.mapM encodeCoordinateRow?
  some (encodeVersionedRows zeroOriginCoverageHeader rows)

private def decodeCoordinateRow? (row : String) : Option EffectCoordinate :=
  match row.splitOn "\t" with
  | [kind, locusToken, measureToken] =>
      if kind = "COORDINATE" && validToken locusToken && validToken measureToken then
        some ⟨⟨locusToken⟩, ⟨measureToken⟩⟩
      else
        none
  | _ => none

/--
Decode exactly one version-1 zero-origin coverage file. Duplicate coordinates
fail closed rather than being normalized silently.
-/
def decodeZeroOriginCoverage? (input : String) : Option ZeroOriginCoverage := do
  let rows ← decodeVersionedRows? zeroOriginCoverageHeader input
  let coordinates ← rows.mapM decodeCoordinateRow?
  ZeroOriginCoverage.ofCoordinates? coordinates

/-- Atomically replace one explicitly reconstructed zero-origin evidence set. -/
def saveZeroOriginCoverage?
    (path : System.FilePath)
    (coverage : ZeroOriginCoverage) : IO Bool := do
  match encodeZeroOriginCoverage? coverage with
  | none => return false
  | some text =>
      replaceTextViaSiblingStage path text
      return true

/-- Read one explicit zero-origin evidence set; malformed content returns `none`. -/
def loadZeroOriginCoverage?
    (path : System.FilePath) : IO (Option ZeroOriginCoverage) := do
  let input ← IO.FS.readFile path
  return decodeZeroOriginCoverage? input

end Loam.Persistence
