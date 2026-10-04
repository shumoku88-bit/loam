import Loam.Application.AttentionInspection
import Loam.Authority.HouseholdAuthority
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

private def projectEvidence
    (items : AttentionMemory String)
    (closures : AttentionClosureMemory String) :
    Except String Availability := do
  let some openItems := Loam.Application.openAttentions? items closures
    | throw "loam: Attention closure evidence references an unknown identity"
  pure (.available { openItems := openItems })

/-- Load one configured legacy Attention image and fail closed on malformed/dangling closure evidence. -/
def loadEvidence (path : System.FilePath) : IO (Except String Availability) := do
  if !(← path.pathExists) then
    return .ok .unavailable
  let some pair ← Loam.Persistence.loadAttentionMemory? path
    | return .error "loam: malformed or unsupported Attention memory"
  let (items, closures) := pair
  return projectEvidence items closures

/--
Project Attention from one already-qualified HouseholdGeneration.

A physically absent Attention section remains unavailable, matching the legacy
missing-file contract. An explicitly present empty Attention document is
available with zero open items.
-/
def fromGeneration
    (generation : Loam.HouseholdAuthority.Generation) :
    Except String Availability := do
  match Loam.Persistence.HouseholdImage.body? generation.image "Attention" with
  | none => pure .unavailable
  | some body =>
      let some (items, closures) := Loam.Persistence.decodeAttentionMemory? body
        | throw "loam: malformed or unsupported Attention memory"
      projectEvidence items closures

/--
Load current HouseholdImage and project its Attention availability.

This is a compatibility path for P4. Frontends still select the legacy
Attention path until a later authority-cutover change.
-/
def loadHouseholdEvidence
    (root : System.FilePath) : IO (Except String Availability) := do
  match ← Loam.HouseholdAuthority.loadCurrent? root with
  | .error message => return .error message
  | .ok generation => return fromGeneration generation

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
