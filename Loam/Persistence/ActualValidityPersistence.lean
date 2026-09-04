import Loam.ActualDate
import Loam.ActualValidityV2Identity
import Loam.Core.ActualValidityHistory
import Loam.Persistence

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

private def isReplacementId
    (history : ActualValidityHistory String)
    (id : ActualValidityFactId) : Bool :=
  history.corrections.any fun correction => decide (correction.replacement = id)

private def idForCanonicalFact
    (history : ActualValidityHistory String)
    (fact : ActualValidityFact String) : ActualValidityFactId :=
  if isReplacementId history fact.id then
    fact.id
  else
    Loam.ActualValidityV2.rootFactId fact.event

private def idForCanonicalExisting?
    (history : ActualValidityHistory String)
    (id : ActualValidityFactId) : Option ActualValidityFactId := do
  let fact ← history.findFactById? id
  pure (idForCanonicalFact history fact)

/--
Normalize only identity representation before persistence. Initial/source facts
receive Event-derived adapter ids; replacement facts keep their actual revision
ids. No current-date winner is inferred here and list order has no authority.
-/
private def normalizeHistoryForStorage?
    (history : ActualValidityHistory String) : Option (ActualValidityHistory String) := do
  let facts := history.facts.map fun fact =>
    { fact with id := idForCanonicalFact history fact }
  let corrections ← history.corrections.mapM fun correction => do
    let target ← idForCanonicalExisting? history correction.target
    let replacement ← idForCanonicalExisting? history correction.replacement
    pure {
      id := correction.id
      target := target
      replacement := replacement
    }
  ActualValidityHistory.ofParts? facts corrections

private def storageCompatible (history : ActualValidityHistory String) : Bool :=
  history.facts.all fun fact =>
    if isReplacementId history fact.id then
      !Loam.ActualValidityV2.isRootFact fact
    else
      Loam.ActualValidityV2.isRootFact fact

private def encodeActualValidityFactRow?
    (fact : ActualValidityFact String) : Option String :=
  if !validToken fact.event.token || !Loam.ActualDate.validIsoDate fact.validOn then
    none
  else if Loam.ActualValidityV2.isRootFact fact then
    some ("BASE\t" ++ fact.event.token ++ "\t" ++ fact.validOn)
  else if validToken fact.id.token then
    some
      ("REVISION\t" ++ fact.id.token ++ "\t" ++ fact.event.token ++ "\t" ++ fact.validOn)
  else
    none

private def encodeActualValidityCorrectionRow?
    (history : ActualValidityHistory String)
    (correction : ActualValidityCorrection) : Option String := do
  if !validToken correction.id.token || !validToken correction.replacement.token then
    none
  else
    let targetFact ← history.findFactById? correction.target
    let replacementFact ← history.findFactById? correction.replacement
    if Loam.ActualValidityV2.isRootFact replacementFact then
      none
    else if Loam.ActualValidityV2.isRootFact targetFact then
      if validToken targetFact.event.token then
        pure
          ("CORRECTION\t" ++ correction.id.token ++ "\tROOT\t" ++
            targetFact.event.token ++ "\t" ++ correction.replacement.token)
      else
        none
    else if validToken correction.target.token then
      pure
        ("CORRECTION\t" ++ correction.id.token ++ "\tREVISION\t" ++
          correction.target.token ++ "\t" ++ correction.replacement.token)
    else
      none

private def encodeNormalizedActualValidityHistory?
    (history : ActualValidityHistory String) : Option String := do
  if !storageCompatible history then
    none
  else
    let factRows ← history.facts.mapM encodeActualValidityFactRow?
    let correctionRows ← history.corrections.mapM (encodeActualValidityCorrectionRow? history)
    pure
      (String.intercalate "\n"
        (actualValidityHistoryHeader :: (factRows ++ correctionRows)) ++ "\n")

/--
Encode the canonical Event-rooted occurrence-date stream. Practical writers may
still supply compatibility fact ids in memory; source ids are normalized away
before bytes are produced, while correction-created revision identity remains.
-/
def encodeActualValidityHistory?
    (history : ActualValidityHistory String) : Option String := do
  let normalized ← normalizeHistoryForStorage? history
  encodeNormalizedActualValidityHistory? normalized

private def decodeHistoryRows :
    List String → Option (List (ActualValidityFact String) × List ActualValidityCorrection)
  | [] => some ([], [])
  | row :: rest => do
      let (facts, corrections) ← decodeHistoryRows rest
      match row.splitOn "\t" with
      | ["BASE", eventToken, validOn] =>
          if validToken eventToken && Loam.ActualDate.validIsoDate validOn then
            let event : EventId := ⟨eventToken⟩
            pure
              ({ id := Loam.ActualValidityV2.rootFactId event
                 event := event
                 validOn := validOn } :: facts,
                corrections)
          else
            none
      | ["REVISION", revisionToken, eventToken, validOn] =>
          if validToken revisionToken && validToken eventToken &&
              Loam.ActualDate.validIsoDate validOn then
            pure
              ({ id := ⟨revisionToken⟩, event := ⟨eventToken⟩, validOn := validOn } :: facts,
                corrections)
          else
            none
      | ["CORRECTION", correctionIdToken, "ROOT", eventToken, replacementToken] =>
          if validToken correctionIdToken && validToken eventToken &&
              validToken replacementToken then
            let event : EventId := ⟨eventToken⟩
            pure
              (facts,
                { id := ⟨correctionIdToken⟩
                  target := Loam.ActualValidityV2.rootFactId event
                  replacement := ⟨replacementToken⟩ } :: corrections)
          else
            none
      | ["CORRECTION", correctionIdToken, "REVISION", targetToken, replacementToken] =>
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
      if header = actualValidityHistoryHeader then do
        let history ← decodeRows rows
        if storageCompatible history then pure history else none
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
