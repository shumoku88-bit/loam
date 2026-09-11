import Loam.ActualDate
import Loam.Core.ActualValidityHistory
import Loam.Persistence.TokenSyntax
import Loam.Persistence.VersionedRows

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-- Current Event-rooted format with endpoint-only validity corrections. -/
def actualValidityHistoryHeader : String := "LOAM-ACTUAL-VALIDITY-HISTORY\t3"

/-- Previous Event-rooted format whose correction rows carried a redundant fact token. -/
private def legacyActualValidityHistoryHeader : String :=
  "LOAM-ACTUAL-VALIDITY-HISTORY\t2"

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
  if !validToken correction.replacement.token then
    none
  else
    let _ ← history.findFactByRef? correction.target
    let _ ← history.findFactByRef? (.revision correction.replacement)
    match correction.target with
    | .root event =>
        if validToken event.token then
          pure
            ("CORRECTION\tROOT\t" ++ event.token ++ "\t" ++
              correction.replacement.token)
        else
          none
    | .revision target =>
        if validToken target.token then
          pure
            ("CORRECTION\tREVISION\t" ++ target.token ++ "\t" ++
              correction.replacement.token)
        else
          none

/-- Encode the current Event-rooted occurrence-date stream. -/
def encodeActualValidityHistory?
    (history : ActualValidityHistory String) : Option String := do
  let factRows ← history.facts.mapM encodeActualValidityFactRow?
  let correctionRows ← history.corrections.mapM (encodeActualValidityCorrectionRow? history)
  pure (encodeVersionedRows actualValidityHistoryHeader (factRows ++ correctionRows))

private def decodeFactRow? (row : String) : Option (ActualValidityFact String) :=
  match row.splitOn "\t" with
  | ["BASE", eventToken, validOn] =>
      if validToken eventToken && Loam.ActualDate.validIsoDate validOn then
        some (.base ⟨eventToken⟩ validOn)
      else
        none
  | ["REVISION", revisionToken, eventToken, validOn] =>
      if validToken revisionToken && validToken eventToken &&
          Loam.ActualDate.validIsoDate validOn then
        some (.revision ⟨revisionToken⟩ ⟨eventToken⟩ validOn)
      else
        none
  | _ => none

private def decodeCurrentCorrectionRow? (row : String) : Option ActualValidityCorrection :=
  match row.splitOn "\t" with
  | ["CORRECTION", "ROOT", eventToken, replacementToken] =>
      if validToken eventToken && validToken replacementToken then
        some { target := .root ⟨eventToken⟩, replacement := ⟨replacementToken⟩ }
      else
        none
  | ["CORRECTION", "REVISION", targetToken, replacementToken] =>
      if validToken targetToken && validToken replacementToken then
        some { target := .revision ⟨targetToken⟩, replacement := ⟨replacementToken⟩ }
      else
        none
  | _ => none

/-- Decode one V2 correction row while discarding its no-longer-semantic fact token. -/
private def decodeLegacyCorrectionRow? (row : String) : Option ActualValidityCorrection :=
  match row.splitOn "\t" with
  | ["CORRECTION", correctionToken, "ROOT", eventToken, replacementToken] =>
      if validToken correctionToken && validToken eventToken && validToken replacementToken then
        some { target := .root ⟨eventToken⟩, replacement := ⟨replacementToken⟩ }
      else
        none
  | ["CORRECTION", correctionToken, "REVISION", targetToken, replacementToken] =>
      if validToken correctionToken && validToken targetToken && validToken replacementToken then
        some { target := .revision ⟨targetToken⟩, replacement := ⟨replacementToken⟩ }
      else
        none
  | _ => none

private def decodeHistoryRows
    (decodeCorrection : String → Option ActualValidityCorrection) :
    List String → Option (List (ActualValidityFact String) × List ActualValidityCorrection)
  | [] => some ([], [])
  | row :: rest => do
      let (facts, corrections) ← decodeHistoryRows decodeCorrection rest
      if row.startsWith "CORRECTION\t" then
        let correction ← decodeCorrection row
        pure (facts, correction :: corrections)
      else
        let fact ← decodeFactRow? row
        pure (fact :: facts, corrections)

private def decodeRows
    (decodeCorrection : String → Option ActualValidityCorrection)
    (rows : List String) : Option (ActualValidityHistory String) :=
  match rows.reverse with
  | "" :: reversedRows => do
      let (facts, corrections) ←
        decodeHistoryRows decodeCorrection reversedRows.reverse
      ActualValidityHistory.ofParts? facts corrections
  | _ => none

/--
Decode current V3 and legacy Event-rooted V2 history. V2 correction fact tokens
are syntax-checked and discarded. Historical V1 remains retired and fails closed.
-/
def decodeActualValidityHistory?
    (input : String) : Option (ActualValidityHistory String) :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header = actualValidityHistoryHeader then
        decodeRows decodeCurrentCorrectionRow? rows
      else if header = legacyActualValidityHistoryHeader then
        decodeRows decodeLegacyCorrectionRow? rows
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
Publish one complete current Event-rooted image through stage+rename.

Existing V2 is admitted and will be rewritten as V3 on the next intentional
publication. Retired V1 or malformed bytes still fail closed rather than being
silently overwritten.
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
