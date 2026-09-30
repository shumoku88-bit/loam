import Loam.CapacityEvidence
import Loam.Persistence.NormalizedCapacityPersistence

namespace Loam.CapacityAuthority

open Loam.Core

set_option autoImplicit false

/-!
# Capacity authority boundary

CapacityMovement and CapacityEffective remain distinct retained meanings. This
module owns only their physical publication topology.

The production authority is one normalized `capacity.loam` image. Readers and
writers operate only on this normalized single-file image via `CapacityEvidence`.

This keeps semantic separation while replacing the old effective-first
two-write protocol with one staged, typed, atomic authority switch.
-/

/-- The persistence-neutral complete Capacity image exposed to callers. -/
abbrev Image := Loam.CapacityEvidence String

private def loadExisting (capacityPath : System.FilePath) : IO (Except String Image) := do
  let input ← IO.FS.readFile capacityPath
  match Loam.Persistence.decodeNormalizedCapacity? input with
  | some image => return .ok image
  | none => return .error "loam: malformed or unsupported Capacity authority"

/--
Load the practical optional Capacity authority used by the writer and current
readers. Missing storage means an empty complete image. Existing malformed
storage fails closed.
-/
def loadOrEmpty (capacityPath : System.FilePath) : IO (Except String Image) := do
  if ← capacityPath.pathExists then
    loadExisting capacityPath
  else
    return .ok Loam.CapacityEvidence.empty

/--
Load required Capacity evidence. A normalized single-file authority needs no companion.
-/
def loadRequired (capacityPath : System.FilePath) : IO (Except String Image) := do
  if !(← capacityPath.pathExists) then
    return .error ("loam: required Capacity authority not found: " ++ capacityPath.toString)
  loadExisting capacityPath

/--
Publish one complete normalized Capacity image through off-authority staging,
typed re-decoding, and one filesystem rename.
-/
def publishImage? (capacityPath : System.FilePath) (image : Image) : IO (Except String Unit) := do
  let text ←
    match Loam.Persistence.encodeNormalizedCapacity? image with
    | some text => pure text
    | none => return .error "loam: normalized Capacity encoder rejected evidence"
  if let some parent := capacityPath.parent then
    IO.FS.createDirAll parent
  let stage := System.FilePath.mk (capacityPath.toString ++ ".loam-stage")
  IO.FS.writeFile stage text
  let staged ← IO.FS.readFile stage
  if staged != text then
    return .error s!"loam: staged Capacity mismatch: {stage}"
  match Loam.Persistence.decodeNormalizedCapacity? staged with
  | some _ => pure ()
  | none => return .error "loam: staged Capacity failed typed decoding"
  IO.FS.rename stage capacityPath
  return .ok ()

end Loam.CapacityAuthority
