import Loam.Core.EventCorrectionMemory
import Loam.Persistence.SiblingStage
import Loam.Persistence.TokenSyntax
import Loam.Persistence.VersionedRows
import Std

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Event correction persistence

This module owns the raw `EventCorrectionMemory` wire stream. It deliberately
does not require referenced Events to be present and does not perform
referential admission. Correction row order is deterministic representation
only and carries no temporal, causal, priority, or authority meaning.
-/

/-- Version marker for the first persisted raw Event-correction memory format. -/
def eventCorrectionMemoryHeader : String := "LOAM-EVENT-CORRECTION-MEMORY\t1"

/-- Encode one raw Event-correction row without checking Event availability. -/
private def encodeEventCorrectionRow? (correction : EventCorrection) : Option String :=
  let correctionToken := correction.id.token
  let targetToken := correction.target.token
  let replacementToken := correction.replacement.token
  if validToken correctionToken && validToken targetToken && validToken replacementToken then
    some ("CORRECTION\t" ++ correctionToken ++ "\t" ++ targetToken ++ "\t" ++ replacementToken)
  else
    none

/-- Decode one raw Event-correction row without performing referential admission. -/
private def decodeEventCorrectionRow? (row : String) : Option EventCorrection :=
  match row.splitOn "\t" with
  | ["CORRECTION", correctionToken, targetToken, replacementToken] =>
      if validToken correctionToken && validToken targetToken && validToken replacementToken then
        some {
          id := ⟨correctionToken⟩
          target := ⟨targetToken⟩
          replacement := ⟨replacementToken⟩
        }
      else
        none
  | _ => none

/--
Encode raw correction memory as its own physical stream.

Correction row order is deterministic representation only. Referenced Event
identity is preserved even when an endpoint is not present in any current
`EventMemory`; referential admission remains a later Core projection.
-/
def encodeEventCorrectionMemory? (memory : EventCorrectionMemory) : Option String :=
  match memory.corrections.mapM encodeEventCorrectionRow? with
  | some rows => some (encodeVersionedRows eventCorrectionMemoryHeader rows)
  | none => none

/--
Decode one version-1 raw correction memory. Repeated `EventCorrectionId` is
rejected through `EventCorrectionMemory.ofCorrections?`; missing target or
replacement Events are deliberately not checked at this persistence boundary.
-/
def decodeEventCorrectionMemory? (input : String) : Option EventCorrectionMemory :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header = eventCorrectionMemoryHeader then
        match rows.reverse with
        | "" :: reversedRows =>
            match reversedRows.reverse.mapM decodeEventCorrectionRow? with
            | some corrections => EventCorrectionMemory.ofCorrections? corrections
            | none => none
        | _ => none
      else
        none
  | _ => none

/--
Publish one raw Event-correction memory as one independently replaced stream.

This helper deliberately knows nothing about the Event stream. Callers that
coordinate both streams must preserve the observed relation-first publication
protocol themselves. This function does not create a cross-stream transaction,
serialize concurrent writers, or claim power-loss durability.
-/
def saveEventCorrectionMemory?
    (path : System.FilePath)
    (memory : EventCorrectionMemory) : IO Bool := do
  match encodeEventCorrectionMemory? memory with
  | some text =>
      replaceTextViaSiblingStage path text
      return true
  | none =>
      return false

/--
Read and decode one raw Event-correction-memory file. Missing Event endpoints do
not make the raw relation stream malformed; referential admission remains a
separate Core operation.
-/
def loadEventCorrectionMemory?
    (path : System.FilePath) : IO (Option EventCorrectionMemory) := do
  let input ← IO.FS.readFile path
  return decodeEventCorrectionMemory? input

end Loam.Persistence
