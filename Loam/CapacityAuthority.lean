import Loam.CapacityEvidence
import Loam.Persistence.CapacityEffectivePersistence
import Loam.Persistence.CapacityPersistence
import Loam.Persistence.NormalizedCapacityPersistence

namespace Loam.CapacityAuthority

open Loam.Core

set_option autoImplicit false

/-!
# Capacity authority boundary

CapacityMovement and CapacityEffective remain distinct retained meanings. This
module owns only their physical publication topology.

The production authority is now one normalized `capacity.loam` image. For a
migration window, readers also accept the historical `capacity.loam` plus
`capacity.loam.effective` pair and admit it through `CapacityEvidence` before
returning it. Writers publish only the normalized single-file image.

This keeps semantic separation while replacing the old effective-first
two-write protocol with one staged, typed, atomic authority switch.
-/

/-- The persistence-neutral complete Capacity image exposed to callers. -/
abbrev Image := Loam.CapacityEvidence

private def effectivePath (capacityPath : System.FilePath) : System.FilePath :=
  Loam.Persistence.capacityEffectivePathForMemory capacityPath

private def loadLegacyRequired (capacityPath : System.FilePath) : IO (Except String Image) := do
  let companion := effectivePath capacityPath
  if !(← companion.pathExists) then
    return .error ("loam: required legacy Capacity effective evidence not found: " ++ companion.toString)
  let movements ←
    match ← Loam.Persistence.loadCapacityMemory? capacityPath with
    | some memory => pure memory
    | none => return .error "loam: malformed or unsupported Capacity authority"
  let effective ←
    match ← Loam.Persistence.loadCapacityEffectiveMemory? companion with
    | some memory => pure memory
    | none => return .error "loam: malformed or unsupported Capacity effective evidence"
  match Loam.CapacityEvidence.ofParts? movements effective with
  | some image => return .ok image
  | none => return .error "loam: incomplete legacy Capacity evidence"

private def loadExisting (capacityPath : System.FilePath) : IO (Except String Image) := do
  let input ← IO.FS.readFile capacityPath
  match Loam.Persistence.decodeNormalizedCapacity? input with
  | some image => return .ok image
  | none => loadLegacyRequired capacityPath

/--
Load the practical optional Capacity authority used by the writer and current
readers. Missing storage means an empty complete image. Existing malformed or
incomplete storage still fails closed. Historical two-file storage is accepted
only when both families form one complete `CapacityEvidence` image.
-/
def loadOrEmpty (capacityPath : System.FilePath) : IO (Except String Image) := do
  if ← capacityPath.pathExists then
    loadExisting capacityPath
  else
    return .ok Loam.CapacityEvidence.empty

/--
Load required Capacity evidence. A normalized single-file authority needs no
companion. Historical storage is admitted only when its adjacent effective
stream exists and is cross-family complete.
-/
def loadRequired (capacityPath : System.FilePath) : IO (Except String Image) := do
  if !(← capacityPath.pathExists) then
    return .error ("loam: required Capacity authority not found: " ++ capacityPath.toString)
  loadExisting capacityPath

/--
Publish one complete normalized Capacity image through off-authority staging,
typed re-decoding, and one filesystem rename.

An existing historical `.effective` companion is deliberately ignored after the
primary file becomes normalized; canonical-data migration may remove that stale
compatibility artifact separately.
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
