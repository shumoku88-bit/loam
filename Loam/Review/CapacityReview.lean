import Loam.HouseholdPaths
import Loam.Application.CapacityInspection
import Loam.Authority.CapacityAuthority
import Loam.Authority.HouseholdAuthority

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
  measure : MeasureId := ⟨"jpy"⟩
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

/-- Current all-retained entitlement projection for one explicit Measure. -/
def snapshotForMeasure (measure : MeasureId) (memory : CapacityMemory) : Snapshot :=
  { measure := measure
    rows := (rememberedPurposes memory).map fun purpose =>
      { purpose := purpose
        entitlement := entitlementAt memory.movements purpose measure } }

/-- Backward-compatible all-retained view for the current JPY household. -/
def snapshot (memory : CapacityMemory) : Snapshot :=
  snapshotForMeasure ⟨"jpy"⟩ memory

/--
Load the practical all-retained view. Missing storage follows the existing
Capacity entrance/view policy and is the empty retained movement history;
malformed configured evidence still refuses.
-/
def loadSnapshotForMeasure
    (measure : MeasureId) (path : System.FilePath) : IO (Except String Snapshot) := do
  let image ←
    match ← Loam.CapacityAuthority.loadOrEmpty path with
    | .ok image => pure image
    | .error message => return .error message
  return .ok (snapshotForMeasure measure image.movements)

/-- Backward-compatible loader for the current JPY household. -/
def loadSnapshot (path : System.FilePath) : IO (Except String Snapshot) :=
  loadSnapshotForMeasure ⟨"jpy"⟩ path


/--
Project Capacity from the installed HouseholdImage without changing production
frontend selection yet.

A physically missing Capacity section keeps the existing Capacity contract:
empty retained history. A present malformed section refuses.
-/
def loadHouseholdSnapshotForMeasure
    (measure : MeasureId)
    (root : System.FilePath) : IO (Except String Snapshot) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  match Loam.Persistence.HouseholdImage.body? generation.image "Capacity" with
  | none => return .ok (snapshotForMeasure measure Loam.CapacityEvidence.empty.movements)
  | some body =>
      let some image := Loam.Persistence.decodeNormalizedCapacity? body
        | return .error "loam: malformed or unsupported Capacity authority"
      return .ok (snapshotForMeasure measure image.movements)

/-- Backward-compatible HouseholdImage loader for the current JPY household. -/
def loadHouseholdSnapshot
    (root : System.FilePath) : IO (Except String Snapshot) :=
  loadHouseholdSnapshotForMeasure ⟨"jpy"⟩ root

/--
Load canonical Capacity evidence from one household root. High-level frontends
use this entrance so canonical physical file selection remains owned by the
shared review boundary. Explicit-path diagnostic callers keep `loadSnapshot`.
-/
def loadSnapshotFromHouseholdRootForMeasure
    (measure : MeasureId) (root : System.FilePath) : IO (Except String Snapshot) :=
  loadSnapshotForMeasure measure (Loam.HouseholdPaths.capacity root)

/-- Backward-compatible household-root loader for the current JPY household. -/
def loadSnapshotFromHouseholdRoot
    (root : System.FilePath) : IO (Except String Snapshot) :=
  loadSnapshotFromHouseholdRootForMeasure ⟨"jpy"⟩ root

end Loam.CapacityReview
