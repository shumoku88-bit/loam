import Loam.Core.ZeroOriginCoverage
import Loam.Persistence

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

private def encodeCoordinateRows? : List EffectCoordinate → Option (List String)
  | [] => some []
  | coordinate :: rest => do
      let row ← encodeCoordinateRow? coordinate
      let rows ← encodeCoordinateRows? rest
      some (row :: rows)

/-- Encode one explicit finite zero-origin evidence set. -/
def encodeZeroOriginCoverage? (coverage : ZeroOriginCoverage) : Option String := do
  let rows ← encodeCoordinateRows? coverage.coordinates
  some (String.intercalate "\n" (zeroOriginCoverageHeader :: rows) ++ "\n")

private def decodeCoordinateRow? (row : String) : Option EffectCoordinate :=
  match row.splitOn "\t" with
  | [kind, locusToken, measureToken] =>
      if kind = "COORDINATE" && validToken locusToken && validToken measureToken then
        some ⟨⟨locusToken⟩, ⟨measureToken⟩⟩
      else
        none
  | _ => none

private def decodeCoordinateRows? : List String → Option (List EffectCoordinate)
  | [] => some []
  | row :: rest => do
      let coordinate ← decodeCoordinateRow? row
      let coordinates ← decodeCoordinateRows? rest
      some (coordinate :: coordinates)

/--
Decode exactly one version-1 zero-origin coverage file. Duplicate coordinates
fail closed rather than being normalized silently.
-/
def decodeZeroOriginCoverage? (input : String) : Option ZeroOriginCoverage :=
  match input.splitOn "\n" with
  | [] => none
  | header :: rowsWithTrailing =>
      if header != zeroOriginCoverageHeader then
        none
      else
        match rowsWithTrailing.reverse with
        | "" :: reversedRows => do
            let coordinates ← decodeCoordinateRows? reversedRows.reverse
            ZeroOriginCoverage.ofCoordinates? coordinates
        | _ => none

private def zeroOriginCoverageStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/-- Atomically replace one explicitly reconstructed zero-origin evidence set. -/
def saveZeroOriginCoverage?
    (path : System.FilePath)
    (coverage : ZeroOriginCoverage) : IO Bool := do
  match encodeZeroOriginCoverage? coverage with
  | none => return false
  | some text =>
      let stage := zeroOriginCoverageStagePath path
      IO.FS.writeFile stage text
      IO.FS.rename stage path
      return true

/-- Read one explicit zero-origin evidence set; malformed content returns `none`. -/
def loadZeroOriginCoverage?
    (path : System.FilePath) : IO (Option ZeroOriginCoverage) := do
  let input ← IO.FS.readFile path
  return decodeZeroOriginCoverage? input

end Loam.Persistence
