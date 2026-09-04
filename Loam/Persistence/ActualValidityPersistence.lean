import Loam.ActualDate
import Loam.ActualValidityV2Identity
import Loam.Core.ActualValidityHistory
import Loam.Persistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-- Physical generation of the retained Actual-validity stream. -/
inductive ActualValidityStorageVersion
  | v1
  | v2
  deriving Repr, DecidableEq

/-- Historical identified-fact format retained only for explicit compatibility. -/
def actualValidityHistoryHeaderV1 : String := "LOAM-ACTUAL-VALIDITY-HISTORY\t1"

/-- Event-rooted format: initial dates have no independently stored identity. -/
def actualValidityHistoryHeaderV2 : String := "LOAM-ACTUAL-VALIDITY-HISTORY\t2"

/-- Backward-compatible name for code that intentionally reasons about V1 text. -/
def actualValidityHistoryHeader : String := actualValidityHistoryHeaderV1

/--
Keep practical date provenance adjacent to its Event memory without adding a
second user-facing path argument.
-/
def actualValidityPathForEventMemory (memoryPath : System.FilePath) : System.FilePath :=
  System.FilePath.mk (memoryPath.toString ++ ".actual-validity")

private def encodeActualValidityFactRowV1?
    (fact : ActualValidityFact String) : Option String :=
  if validToken fact.id.token && validToken fact.event.token &&
      Loam.ActualDate.validIsoDate fact.validOn then
    some
      ("FACT\t" ++ fact.id.token ++ "\t" ++ fact.event.token ++ "\t" ++ fact.validOn)
  else
    none

private def encodeActualValidityCorrectionRowV1?
    (correction : ActualValidityCorrection) : Option String :=
  if validToken correction.id.token && validToken correction.target.token &&
      validToken correction.replacement.token then
    some
      ("CORRECTION\t" ++ correction.id.token ++ "\t" ++
        correction.target.token ++ "\t" ++ correction.replacement.token)
  else
    none

/-- Encode the historical V1 identified-fact image. -/
def encodeActualValidityHistoryV1?
    (history : ActualValidityHistory String) : Option String := do
  let factRows ← history.facts.mapM encodeActualValidityFactRowV1?
  let correctionRows ← history.corrections.mapM encodeActualValidityCorrectionRowV1?
  pure
    (String.intercalate "\n"
      (actualValidityHistoryHeaderV1 :: (factRows ++ correctionRows)) ++ "\n")

/-- Backward-compatible V1 encoder. -/
def encodeActualValidityHistory? := encodeActualValidityHistoryV1?

private def decodeHistoryRowsV1 :
    List String → Option (List (ActualValidityFact String) × List ActualValidityCorrection)
  | [] => some ([], [])
  | row :: rest => do
      let (facts, corrections) ← decodeHistoryRowsV1 rest
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

private def isReplacementId
    (history : ActualValidityHistory String)
    (id : ActualValidityFactId) : Bool :=
  history.corrections.any fun correction => decide (correction.replacement = id)

private def idForV2Fact
    (history : ActualValidityHistory String)
    (fact : ActualValidityFact String) : ActualValidityFactId :=
  if isReplacementId history fact.id then
    fact.id
  else
    Loam.ActualValidityV2.rootFactId fact.event

private def idForV2Existing?
    (history : ActualValidityHistory String)
    (id : ActualValidityFactId) : Option ActualValidityFactId := do
  let fact ← history.findFactById? id
  pure (idForV2Fact history fact)

/--
Normalize only identity representation before a V2 write. Initial/source facts
receive Event-derived adapter ids; replacement facts keep their actual revision
ids. No current-date winner is inferred here and list order has no authority.
-/
private def normalizeHistoryForV2?
    (history : ActualValidityHistory String) : Option (ActualValidityHistory String) := do
  let facts := history.facts.map fun fact =>
    { fact with id := idForV2Fact history fact }
  let corrections ← history.corrections.mapM fun correction => do
    let target ← idForV2Existing? history correction.target
    let replacement ← idForV2Existing? history correction.replacement
    pure {
      id := correction.id
      target := target
      replacement := replacement
    }
  ActualValidityHistory.ofParts? facts corrections

private def v2Compatible (history : ActualValidityHistory String) : Bool :=
  history.facts.all fun fact =>
    if isReplacementId history fact.id then
      !Loam.ActualValidityV2.isRootFact fact
    else
      Loam.ActualValidityV2.isRootFact fact

private def encodeActualValidityFactRowV2?
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

private def encodeActualValidityCorrectionRowV2?
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

/--
Encode Event-rooted V2 provenance. Source facts are serialized as `BASE Event Date`
without their derived compatibility id. Only correction-created revisions retain
independent identity.
-/
def encodeActualValidityHistoryV2?
    (history : ActualValidityHistory String) : Option String := do
  if !v2Compatible history then
    none
  else
    let factRows ← history.facts.mapM encodeActualValidityFactRowV2?
    let correctionRows ← history.corrections.mapM (encodeActualValidityCorrectionRowV2? history)
    pure
      (String.intercalate "\n"
        (actualValidityHistoryHeaderV2 :: (factRows ++ correctionRows)) ++ "\n")

private def decodeHistoryRowsV2 :
    List String → Option (List (ActualValidityFact String) × List ActualValidityCorrection)
  | [] => some ([], [])
  | row :: rest => do
      let (facts, corrections) ← decodeHistoryRowsV2 rest
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

private def decodeRowsWith
    (decoder : List String → Option (List (ActualValidityFact String) × List ActualValidityCorrection))
    (rows : List String) : Option (ActualValidityHistory String) :=
  match rows.reverse with
  | "" :: reversedRows => do
      let (facts, corrections) ← decoder reversedRows.reverse
      ActualValidityHistory.ofParts? facts corrections
  | _ => none

/-- Decode retained V1 or V2 provenance and report its physical generation. -/
def decodeActualValidityHistoryWithVersion?
    (input : String) : Option (ActualValidityStorageVersion × ActualValidityHistory String) :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header = actualValidityHistoryHeaderV1 then do
        let history ← decodeRowsWith decodeHistoryRowsV1 rows
        pure (.v1, history)
      else if header = actualValidityHistoryHeaderV2 then do
        let history ← decodeRowsWith decodeHistoryRowsV2 rows
        if v2Compatible history then pure (.v2, history) else none
      else
        none
  | _ => none

/-- Decode either supported generation, projecting V2 roots through derived adapter identities. -/
def decodeActualValidityHistory?
    (input : String) : Option (ActualValidityHistory String) := do
  let (_, history) ← decodeActualValidityHistoryWithVersion? input
  pure history

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

/-- Explicit historical V1 writer used only when the selected physical generation is V1. -/
def saveActualValidityHistoryV1?
    (path : System.FilePath)
    (history : ActualValidityHistory String) : IO Bool :=
  saveEncoded path (encodeActualValidityHistoryV1? history)

/--
Publish one complete Event-rooted V2 image through the existing stage+rename
boundary. Source ids supplied by old practical writers are normalized away;
only correction-created replacement identity survives serialization.
-/
def saveActualValidityHistoryV2?
    (path : System.FilePath)
    (history : ActualValidityHistory String) : IO Bool := do
  match normalizeHistoryForV2? history with
  | none => return false
  | some normalized =>
      saveEncoded path (encodeActualValidityHistoryV2? normalized)

/-- Load retained occurrence-date provenance and physical generation. -/
def loadActualValidityHistoryWithVersion?
    (path : System.FilePath) : IO (Option (ActualValidityStorageVersion × ActualValidityHistory String)) := do
  let input ← IO.FS.readFile path
  return decodeActualValidityHistoryWithVersion? input

private def storageVersionAt?
    (path : System.FilePath) : IO (Option ActualValidityStorageVersion) := do
  if ← path.pathExists then
    match ← loadActualValidityHistoryWithVersion? path with
    | none => return none
    | some (version, _) => return some version
  else
    return some .v2

/-- Preserve an explicitly selected physical generation. -/
def saveActualValidityHistoryForVersion?
    (version : ActualValidityStorageVersion)
    (path : System.FilePath)
    (history : ActualValidityHistory String) : IO Bool :=
  match version with
  | .v1 => saveActualValidityHistoryV1? path history
  | .v2 => saveActualValidityHistoryV2? path history

/--
Ordinary practical writer boundary.

Existing V1 stays V1 until the explicit converter runs. Existing V2 stays V2.
A missing stream starts directly as V2. This keeps migration authority explicit
while allowing all existing practical entrances to preserve the selected format
without carrying V1/V2 branches themselves.
-/
def saveActualValidityHistory?
    (path : System.FilePath)
    (history : ActualValidityHistory String) : IO Bool := do
  match ← storageVersionAt? path with
  | none => return false
  | some version => saveActualValidityHistoryForVersion? version path history

/-- Load retained occurrence-date provenance; malformed content fails closed. -/
def loadActualValidityHistory?
    (path : System.FilePath) : IO (Option (ActualValidityHistory String)) := do
  match ← loadActualValidityHistoryWithVersion? path with
  | none => return none
  | some (_, history) => return some history

/--
Missing storage starts in V2. Existing V1 remains V1 until an explicit converter
rewrites the single canonical stream, so ordinary writes do not silently perform
a migration cutover.
-/
def loadActualValidityHistoryWithVersionOrEmpty?
    (path : System.FilePath) : IO (Option (ActualValidityStorageVersion × ActualValidityHistory String)) := do
  if ← path.pathExists then
    loadActualValidityHistoryWithVersion? path
  else
    match ActualValidityHistory.ofParts? ([] : List (ActualValidityFact String)) [] with
    | none => return none
    | some empty => return some (.v2, empty)

/-- Missing date storage means no retained practical date provenance yet. -/
def loadActualValidityHistoryOrEmpty?
    (path : System.FilePath) : IO (Option (ActualValidityHistory String)) := do
  match ← loadActualValidityHistoryWithVersionOrEmpty? path with
  | none => return none
  | some (_, history) => return some history

end Loam.Persistence
