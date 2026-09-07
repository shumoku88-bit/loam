import Loam.Application.CapacityInspection
import Loam.Persistence.CapacityPersistence

namespace Loam.CapacityReview

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Shared Capacity review

This module is the surface-independent all-retained Capacity read boundary used
by line and terminal frontends. It preserves the existing practical policy that
an absent Capacity stream means no retained Capacity movements yet.

It does not choose a cycle or time window. Windowed household questions remain
explicit callers of `CapacityWindowInspection`.
-/

structure Row where
  purpose : PurposeId
  entitlement : Quantity
  deriving Repr, DecidableEq

structure Snapshot where
  rows : List Row
  deriving Repr, DecidableEq

private def addPurposeIfAbsent (purposes : List PurposeId) (purpose : PurposeId) : List PurposeId :=
  if purpose ∈ purposes then purposes else purposes ++ [purpose]

/-- Purpose identities in first retained representation appearance order only. -/
def rememberedPurposes (memory : CapacityMemory) : List PurposeId :=
  memory.movements.foldl
    (fun purposes movement =>
      movement.movement.changes.foldl
        (fun current change =>
          match change.coordinate with
          | .unallocated => current
          | .purpose purpose => addPurposeIfAbsent current purpose)
        purposes)
    []

/-- Current all-retained JPY entitlement projection for every remembered Purpose. -/
def snapshot (memory : CapacityMemory) : Snapshot :=
  let yen : MeasureId := ⟨"jpy"⟩
  { rows := (rememberedPurposes memory).map fun purpose =>
      { purpose := purpose
        entitlement := entitlementAt memory.movements purpose yen } }

/--
Load the practical all-retained view. Missing storage follows the existing
Capacity entrance/view policy and is the empty retained movement history;
malformed configured evidence still refuses.
-/
def loadSnapshot (path : System.FilePath) : IO (Except String Snapshot) := do
  let memory ←
    if ← path.pathExists then
      match ← Loam.Persistence.loadCapacityMemory? path with
      | some memory => pure memory
      | none => return .error "loam: malformed or unsupported capacity file"
    else
      match CapacityMemory.ofMovements? [] with
      | some memory => pure memory
      | none => return .error "loam: internal empty Capacity memory refusal"
  return .ok (snapshot memory)

end Loam.CapacityReview
