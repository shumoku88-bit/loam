import Loam.Core.ScheduledCompletion
import Loam.Persistence.TokenSyntax
import Loam.Persistence.VersionedRows

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Scheduled completion codec

Completion remains a distinct relation between expected Scheduled identity and
Actual Event identity. Observation 226 retired an independently published
completion sidecar: this module now supplies only the typed inner codec embedded
in the complete Scheduled lifecycle authority image.

The codec still permits an Actual endpoint whose Event has not been published
yet. Completion publication crosses into Movement authority, so the lifecycle
image may retain the relation first and remain inert until that Actual endpoint
appears.
-/

/-- Version marker for the first raw Scheduled-completion relation format. -/
def scheduledCompletionMemoryHeader : String :=
  "LOAM-SCHEDULED-COMPLETION-MEMORY\t1"

private def encodeCompletionRow? (completion : ScheduledCompletion) : Option String :=
  if validToken completion.scheduled.token && validToken completion.actual.token then
    some
      ("COMPLETION\t" ++ completion.scheduled.token ++ "\t" ++ completion.actual.token)
  else
    none

/-- Encode one-to-one completion relations without assigning row-order meaning. -/
def encodeScheduledCompletionMemory?
    (memory : ScheduledCompletionMemory) : Option String := do
  let rows ← memory.completions.mapM encodeCompletionRow?
  pure (encodeVersionedRows scheduledCompletionMemoryHeader rows)

private def decodeCompletionRow? (row : String) : Option ScheduledCompletion :=
  match row.splitOn "\t" with
  | ["COMPLETION", scheduledToken, actualToken] =>
      if validToken scheduledToken && validToken actualToken then
        some { scheduled := ⟨scheduledToken⟩, actual := ⟨actualToken⟩ }
      else
        none
  | _ => none

/-- Decode completion relations and recheck one-to-one endpoint uniqueness. -/
def decodeScheduledCompletionMemory?
    (input : String) : Option ScheduledCompletionMemory := do
  let rows ← decodeVersionedRows? scheduledCompletionMemoryHeader input
  let completions ← rows.mapM decodeCompletionRow?
  ScheduledCompletionMemory.ofCompletions? completions

end Loam.Persistence
