import Loam.Application.AttentionInspection
import Loam.Persistence.AttentionPersistence

namespace Loam.AttentionReview

open Loam.Core

set_option autoImplicit false

/-!
# Shared Attention review boundary

The TUI and future report surfaces consume this current open-item answer instead
of rebuilding lifecycle logic. Missing configuration is kept distinct from an
explicitly configured empty stream.
-/

/-- Current open Attention projection after shared Application validation. -/
structure Snapshot where
  openItems : List (Attention String)

/-- Filesystem/source availability is not household lifecycle meaning. -/
inductive Availability where
  | unavailable
  | available (snapshot : Snapshot)

/-- Load one configured Attention image and fail closed on malformed/dangling closure evidence. -/
def loadEvidence (path : System.FilePath) : IO (Except String Availability) := do
  if !(← path.pathExists) then
    return .ok .unavailable
  let some pair ← Loam.Persistence.loadAttentionMemory? path
    | return .error "loam: malformed or unsupported Attention memory"
  let (items, closures) := pair
  let some openItems := Loam.Application.openAttentions? items closures
    | return .error "loam: Attention closure evidence references an unknown identity"
  return .ok (.available { openItems := openItems })

/-- Preserve the three qualified due meanings in human-facing text. -/
def dueLabel (due : AttentionDue String) : String :=
  match due with
  | .dueOn time => "due " ++ time
  | .noDueDate => "no due date"
  | .dueUndetermined => "due unknown"

/-- Compact recognition text for an open Attention row. -/
def summary (item : Attention String) : String :=
  dueLabel item.due ++ "  " ++ item.context

end Loam.AttentionReview
