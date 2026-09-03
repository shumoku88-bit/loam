import Loam.ActualDate
import Loam.Core.ActualValidityHistory
import Loam.Persistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-- Version marker for append-only practical Event occurrence-date provenance. -/
def actualValidityHistoryHeader : String := "LOAM-ACTUAL-VALIDITY-HISTORY\t1"

/--
Keep practical date provenance adjacent to its Event memory without adding a
second user-facing path argument.
-/
def actualValidityPathForEventMemory (memoryPath : System.FilePath) : System.FilePath :=
  System.FilePath.mk (memoryPath.toString ++ ".actual-validity")

private def encodeActualValidityFactRow?
    (fact : ActualValidityFact String) : Option String :=
  if validToken fact.id.token && validToken fact.event.token &&
      Loam.ActualDate.validIsoDate fact.validOn then
    some
      ("FACT\t" ++ fact.id.token ++ "\t" ++ fact.event.token ++ "\t" ++ fact.validOn)
  else
    none

private def encodeActualValidityCorrectionRow?
    (correction : ActualValidityCorrection) : Option String :=
  if validToken correction.id.token && validToken correction.target.token &&
      validToken correction.replacement.token then
    some
      ("CORRECTION\t" ++ correction.id.token ++ "\t" ++
        correction.target.token ++ "\t" ++ correction.replacement.token)
  else
    none

/--
Encode raw validity facts and correction relations. Row order is deterministic
representation only and has no chronological or winner meaning.
-/
def encodeActualValidityHistory?
    (history : ActualValidityHistory String) : Option String := do
  let factRows ← history.facts.mapM encodeActualValidityFactRow?
  let correctionRows ← history.corrections.mapM encodeActualValidityCorrectionRow?
  pure
    (String.intercalate "\n"
      (actualValidityHistoryHeader :: (factRows ++ correctionRows)) ++ "\n")

private def decodeHistoryRows :
    List String → Option (List (ActualValidityFact String) × List ActualValidityCorrection)
  | [] => some ([], [])
  | row :: rest => do
      let (facts, corrections) ← decodeHistoryRows rest
      match row.splitOn "\t" with
      | ["FACT", factIdToken, eventToken, validOn] =>
          if validToken factIdToken && validToken eventToken &&
              Loam.ActualDate.validIsoDate validOn then
            pure
              ({ id := ⟨factIdToken⟩, event := ⟨eventToken⟩, validOn := validOn } :: facts,
                corrections)
          else
            none
      | ["CORRECTION", correctionIdToken, targetToken, replacementToken] =>
          if validToken correctionIdToken && validToken targetToken &&
              validToken replacementToken then
            pure
              (facts,
                { id := ⟨correctionIdToken⟩
                  target := ⟨targetToken⟩
                  replacement := ⟨replacementToken⟩ } :: corrections)
          else
            none
      | _ => none

/-- Decode retained validity provenance, failing closed on malformed or duplicate identities. -/
def decodeActualValidityHistory?
    (input : String) : Option (ActualValidityHistory String) :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header = actualValidityHistoryHeader then
        match rows.reverse with
        | "" :: reversedRows => do
            let (facts, corrections) ← decodeHistoryRows reversedRows.reverse
            ActualValidityHistory.ofParts? facts corrections
        | _ => none
      else
        none
  | _ => none

private def actualValidityStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/--
Publish the complete retained validity provenance through sibling staging and
rename. Logical facts and correction relations remain append-only even though
the small physical file is replaced as one image.
-/
def saveActualValidityHistory?
    (path : System.FilePath)
    (history : ActualValidityHistory String) : IO Bool := do
  match encodeActualValidityHistory? history with
  | none => return false
  | some text =>
      let stagePath := actualValidityStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
      return true

/-- Load retained occurrence-date provenance; malformed content fails closed. -/
def loadActualValidityHistory?
    (path : System.FilePath) : IO (Option (ActualValidityHistory String)) := do
  let input ← IO.FS.readFile path
  return decodeActualValidityHistory? input

/-- Missing date storage means no retained practical date provenance yet. -/
def loadActualValidityHistoryOrEmpty?
    (path : System.FilePath) : IO (Option (ActualValidityHistory String)) := do
  if ← path.pathExists then
    loadActualValidityHistory? path
  else
    return ActualValidityHistory.ofParts? [] []

end Loam.Persistence
