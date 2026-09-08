import Loam.Core.ScheduledReplacement
import Loam.Persistence
import Loam.Persistence.VersionedRows

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Scheduled replacement codec

Replacement remains explicit `Scheduled -> Scheduled` provenance. Observation
226 retired an independently published replacement sidecar: this module now
supplies only the typed inner codec embedded in the complete Scheduled lifecycle
authority image. Row order has no lifecycle, priority, or chronology authority.
-/

/-- Version marker for the first raw Scheduled-replacement relation format. -/
def scheduledReplacementMemoryHeader : String :=
  "LOAM-SCHEDULED-REPLACEMENT-MEMORY\t1"

private def encodeReplacementRow?
    (replacement : ScheduledReplacement) : Option String :=
  if validToken replacement.source.token && validToken replacement.replacement.token then
    some
      ("REPLACEMENT\t" ++ replacement.source.token ++ "\t" ++
        replacement.replacement.token)
  else
    none

/-- Encode one-to-one replacement relations without assigning row-order meaning. -/
def encodeScheduledReplacementMemory?
    (memory : ScheduledReplacementMemory) : Option String := do
  let rows ← memory.replacements.mapM encodeReplacementRow?
  pure (encodeVersionedRows scheduledReplacementMemoryHeader rows)

private def decodeReplacementRow? (row : String) : Option ScheduledReplacement :=
  match row.splitOn "\t" with
  | ["REPLACEMENT", sourceToken, replacementToken] =>
      if validToken sourceToken && validToken replacementToken then
        some { source := ⟨sourceToken⟩, replacement := ⟨replacementToken⟩ }
      else
        none
  | _ => none

/-- Decode replacement relations and recheck one-to-one endpoint uniqueness. -/
def decodeScheduledReplacementMemory?
    (input : String) : Option ScheduledReplacementMemory := do
  let rows ← decodeVersionedRows? scheduledReplacementMemoryHeader input
  let replacements ← rows.mapM decodeReplacementRow?
  ScheduledReplacementMemory.ofReplacements? replacements

end Loam.Persistence
