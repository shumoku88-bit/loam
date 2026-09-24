import Loam.HouseholdPaths
import Loam.Application.CapacityInspection
import Loam.CapacityAuthority

namespace Loam.CapacityReview

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Shared Capacity review

This module is a surface-independent all-retained Capacity read boundary for the
production TUI and future frontends. It preserves the practical policy that an
absent Capacity authority means no retained movements yet, while delegated
loading accepts either the normalized single-file image or a complete historical
two-file pair during migration. Entitlement itself remains the same Application
`entitlementAt` projection used by the line CLI.

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
  let image ←
    match ← Loam.CapacityAuthority.loadOrEmpty path with
    | .ok image => pure image
    | .error message => return .error message
  return .ok (snapshot image.movements)

/--
Load canonical Capacity evidence from one household root. High-level frontends
use this entrance so canonical physical file selection remains owned by the
shared review boundary. Explicit-path diagnostic callers keep `loadSnapshot`.
-/
def loadSnapshotFromHouseholdRoot
    (root : System.FilePath) : IO (Except String Snapshot) :=
  loadSnapshot (Loam.HouseholdPaths.capacity root)

end Loam.CapacityReview
