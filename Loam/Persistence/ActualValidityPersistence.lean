import Loam.ActualDate
import Loam.Core.ActualValidityHistory
import Loam.Persistence.TokenSyntax
import Loam.Persistence.VersionedRows

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-- Event-rooted canonical format: initial dates have no independently stored identity. -/
def actualValidityHistoryHeader : String := "LOAM-ACTUAL-VALIDITY-HISTORY\t2"

/--
Keep practical date provenance adjacent to its Event memory without adding a
second user-facing path argument.
-/
def actualValidityPathForEventMemory (memoryPath : System.FilePath) : System.FilePath :=
  System.FilePath.mk (memoryPath.toString ++ ".actual-validity")

private def encodeActualValidityFactRow? :
    ActualValidityFact String → Option String
  | .base event validOn =>
      if !validToken event.token || !Loam.ActualDate.validIsoDate validOn then
        none
      else
        some ("BASE\t" ++ event.token ++ "\t" ++ validOn)
  | .revision revision event validOn =>
      if !validToken revision.token || !validToken event.token ||
          !Loam.ActualDate.validIsoDate validOn then
        none
      else
        some
          ("REVISION\t" ++ revision.token ++ "\t" ++ event.token ++ "\t" ++ validOn)

private def encodeActualValidityCorrectionRow?
    (history : ActualValidityHistory String)
    (correction : ActualValidityCorrection) : Option String := do
  if !validToken correction.id.token || !validToken correction.replacement.token then
    none
  else
    let _ ← history.findFactByRef? correction.target
    let _ ← history.findFactByRef? (.revision correction.replacement)
    match correction.target with
    | .root event =>
        if validToken event.token then
          pure
            ("CORRECTION\t" ++ correction.id.token ++ "\tROOT\t" ++
              event.token ++ "\t" ++ correction.replacement.token)
        else
          none
    | .revision target =>
        if validToken target.token then
          pure
            ("CORRECTION\t" ++ correction.id.token ++ "\tREVISION\t" ++
              target.token ++ "\t" ++ correction.replacement.token)
        else
          none

/-- Encode the canonical Event-rooted occurrence-date stream without identity adapters. -/
def encodeActualValidityHistory?
    (history : ActualValidityHistory String) : Option String := do
  let factRows ← history.facts.mapM encodeActualValidityFactRow?
  let correctionRows ← history.corrections.mapM (encodeActualValidityCorrectionRow? history)
  pure (encodeVersionedRows actualValidityHistoryHeader (factRows ++ correctionRows))

private def decodeHistoryRows :
    List String → Option (List (ActualValidityFact String) × List ActualValidityCorrection)
  | [] => some ([], [])
  | row :: rest => do
      let (facts, corrections) ← decodeHistoryRows rest
      match row.splitOn "\t" with
      | ["BASE", eventToken, validOn] =>
          if validToken eventToken && Loam.ActualDate.validIsoDate validOn then
            pure
              (.base ⟨eventToken⟩ validOn :: facts, corrections)
          else
            none
      | ["REVISION", revisionToken, eventToken, validOn] =>
          if validToken revisionToken && validToken eventToken &&
              Loam.ActualDate.validIsoDate validOn then
            pure
              (.revision ⟨revisionToken⟩ ⟨eventToken⟩ validOn :: facts, corrections)
          else
            none
      | ["CORRECTION", correctionIdToken, "ROOT", eventToken, replacementToken] =>
          if validToken correctionIdToken && validToken eventToken &&
              validToken replacementToken then
            pure
              (facts,
                { id := ⟨correctionIdToken⟩
                  target := .root ⟨eventToken⟩
                  replacement := ⟨replacementToken⟩ } :: corrections)
          else
            none
      | ["CORRECTION", correctionIdToken, "REVISION", targetToken, replacementToken] =>
          if validToken correctionIdToken && validToken targetToken &&
              validToken replacementToken then
            pure
              (facts,
                { id := ⟨correctionIdToken⟩
                  target := .revision ⟨targetToken⟩
                  replacement := ⟨replacementToken⟩ } :: corrections)
          else
            none
      | _ => none

private def decodeRows
    (rows : List String) : Option (ActualValidityHistory String) :=
  match rows.reverse with
  | "" :: reversedRows => do
      let (facts, corrections) ← decodeHistoryRows reversedRows.reverse
      ActualValidityHistory.ofParts? facts corrections
  | _ => none

/--
Decode only the canonical Event-rooted generation. Historical V1 bytes are no
longer a supported production input and therefore fail closed here.
-/
def decodeActualValidityHistory?
    (input : String) : Option (ActualValidityHistory String) :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header = actualValidityHistoryHeader then
        decodeRows rows
      else
        none
  | _ => none

private def actualValidityStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

private def saveEncoded
    (path : System.FilePath)
    (encoded : Option String) : IO Bool := do
  match encoded with
  | none => return false
  | some text =>
      let stagePath := actualValidityStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
      return true

/-- Load retained occurrence-date provenance; malformed or retired content fails closed. -/
def loadActualValidityHistory?
    (path : System.FilePath) : IO (Option (ActualValidityHistory String)) := do
  let input ← IO.FS.readFile path
  return decodeActualValidityHistory? input

private def existingStorageAdmitted?
    (path : System.FilePath) : IO Bool := do
  if ← path.pathExists then
    return (← loadActualValidityHistory? path).isSome
  else
    return true

/--
Publish one complete canonical Event-rooted image through stage+rename.

An existing stream must first decode under the current canonical format. This
prevents a normal practical write from silently overwriting retired V1 or other
unknown bytes and accidentally becoming a migration mechanism.
-/
def saveActualValidityHistory?
    (path : System.FilePath)
    (history : ActualValidityHistory String) : IO Bool := do
  if !(← existingStorageAdmitted? path) then
    return false
  saveEncoded path (encodeActualValidityHistory? history)

/-- Missing date storage means no retained practical date provenance yet. -/
def loadActualValidityHistoryOrEmpty?
    (path : System.FilePath) : IO (Option (ActualValidityHistory String)) := do
  if ← path.pathExists then
    loadActualValidityHistory? path
  else
    return ActualValidityHistory.ofParts? ([] : List (ActualValidityFact String)) []

end Loam.Persistence
