import Loam.Core.ScheduledRetirement
import Loam.Persistence.TokenSyntax
import Loam.Persistence.VersionedRows

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Scheduled retirement codec

Retirement remains explicit evidence separate from the Scheduled occurrence at
the semantic level. Observation 226 retired an independently published
retirement sidecar: this module now supplies only the typed inner codec embedded
in the complete Scheduled lifecycle authority image.
-/

/-- Version marker for the first Scheduled-retirement evidence format. -/
def scheduledRetirementMemoryHeader : String :=
  "LOAM-SCHEDULED-RETIREMENT-MEMORY\t1"

private def encodeRetirementRow? (retirement : ScheduledRetirement) : Option String :=
  if validToken retirement.scheduled.token then
    some ("RETIREMENT\t" ++ retirement.scheduled.token)
  else
    none

/-- Encode retirement evidence without assigning time meaning to row order. -/
def encodeScheduledRetirementMemory?
    (memory : ScheduledRetirementMemory) : Option String := do
  let rows ← memory.retirements.mapM encodeRetirementRow?
  pure (encodeVersionedRows scheduledRetirementMemoryHeader rows)

private def decodeRetirementRow? (row : String) : Option ScheduledRetirement :=
  match row.splitOn "\t" with
  | ["RETIREMENT", scheduledToken] =>
      if validToken scheduledToken then
        some { scheduled := ⟨scheduledToken⟩ }
      else
        none
  | _ => none

/-- Decode retirement evidence and recheck Scheduled-identity uniqueness. -/
def decodeScheduledRetirementMemory?
    (input : String) : Option ScheduledRetirementMemory := do
  let rows ← decodeVersionedRows? scheduledRetirementMemoryHeader input
  let retirements ← rows.mapM decodeRetirementRow?
  ScheduledRetirementMemory.ofRetirements? retirements

end Loam.Persistence
