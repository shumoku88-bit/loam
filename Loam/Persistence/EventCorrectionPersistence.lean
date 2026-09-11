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

Version 2 stores only the semantically selected `target -> replacement` edge.
Version 1 remains readable: its former correction-fact token is validated as
legacy syntax and then discarded rather than reintroduced into Core semantics.
-/

/-- Current endpoint-only Event-correction wire format. -/
def eventCorrectionMemoryHeader : String := "LOAM-EVENT-CORRECTION-MEMORY\t2"

private def legacyEventCorrectionMemoryHeader : String :=
  "LOAM-EVENT-CORRECTION-MEMORY\t1"

/-- Encode one raw Event-correction edge without checking Event availability. -/
private def encodeEventCorrectionRow? (correction : EventCorrection) : Option String :=
  let targetToken := correction.target.token
  let replacementToken := correction.replacement.token
  if validToken targetToken && validToken replacementToken then
    some ("CORRECTION\t" ++ targetToken ++ "\t" ++ replacementToken)
  else
    none

/-- Decode one current endpoint-only correction row. -/
private def decodeEventCorrectionRow? (row : String) : Option EventCorrection :=
  match row.splitOn "\t" with
  | ["CORRECTION", targetToken, replacementToken] =>
      if validToken targetToken && validToken replacementToken then
        some { target := ⟨targetToken⟩, replacement := ⟨replacementToken⟩ }
      else
        none
  | _ => none

/-- Decode one V1 row while discarding its no-longer-semantic fact token. -/
private def decodeLegacyEventCorrectionRow? (row : String) : Option EventCorrection :=
  match row.splitOn "\t" with
  | ["CORRECTION", correctionToken, targetToken, replacementToken] =>
      if validToken correctionToken && validToken targetToken && validToken replacementToken then
        some { target := ⟨targetToken⟩, replacement := ⟨replacementToken⟩ }
      else
        none
  | _ => none

private def decodeRows?
    (decodeRow : String → Option EventCorrection)
    (rows : List String) : Option EventCorrectionMemory := do
  let corrections ← rows.mapM decodeRow
  EventCorrectionMemory.ofCorrections? corrections

/--
Encode raw correction memory as its own physical stream.

Correction row order is deterministic representation only. Referenced Event
identity is preserved even when an endpoint is not present in any current
`EventMemory`; referential admission remains a later Application projection.
-/
def encodeEventCorrectionMemory?
    (memory : EventCorrectionMemory) : Option String :=
  match memory.corrections.mapM encodeEventCorrectionRow? with
  | some rows => some (encodeVersionedRows eventCorrectionMemoryHeader rows)
  | none => none

/--
Decode current V2 or legacy V1 correction memory and re-admit semantic edges.
Missing target or replacement Events are deliberately not checked at this
persistence boundary. Exact duplicate endpoint edges are rejected regardless
of how V1 happened to label their former fact identities.
-/
def decodeEventCorrectionMemory?
    (input : String) : Option EventCorrectionMemory :=
  match input.splitOn "\n" with
  | header :: rows =>
      match rows.reverse with
      | "" :: reversedRows =>
          let payload := reversedRows.reverse
          if header = eventCorrectionMemoryHeader then
            decodeRows? decodeEventCorrectionRow? payload
          else if header = legacyEventCorrectionMemoryHeader then
            decodeRows? decodeLegacyEventCorrectionRow? payload
          else
            none
      | _ => none
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
separate Application operation.
-/
def loadEventCorrectionMemory?
    (path : System.FilePath) : IO (Option EventCorrectionMemory) := do
  let input ← IO.FS.readFile path
  return decodeEventCorrectionMemory? input

/--
Load optional Event-correction evidence. A missing side stream means no retained
Correction evidence yet; malformed existing bytes still fail closed.
-/
def loadEventCorrectionMemoryOrEmpty?
    (path : System.FilePath) : IO (Option EventCorrectionMemory) := do
  if ← path.pathExists then
    loadEventCorrectionMemory? path
  else
    return EventCorrectionMemory.ofCorrections? []

end Loam.Persistence
