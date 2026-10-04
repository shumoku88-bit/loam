import Loam.Core.CapacityEvidence
import Loam.Authority.HouseholdAuthority
import Loam.Persistence.NormalizedCapacityPersistence

namespace Loam.CapacityAuthority

open Loam.Core

set_option autoImplicit false

/-!
# Capacity authority boundary

CapacityMovement and CapacityEffective remain distinct retained meanings. This
module owns only their physical publication topology.

The normalized Capacity codec remains the semantic payload boundary. Explicit
file APIs retain standalone/legacy qualification, while production household
reads after cutover obtain that same normalized payload from the `Capacity`
section of `household.loam`.

This keeps semantic separation while allowing physical authority to move without
changing `CapacityEvidence`.
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


private def decodeHouseholdBody (body : String) : Except String Image :=
  match Loam.Persistence.decodeNormalizedCapacity? body with
  | some image => .ok image
  | none => .error "loam: malformed or unsupported Capacity authority"

/--
Load Capacity from the installed HouseholdImage. A physically absent section
keeps the established optional-Capacity meaning of empty retained history.
-/
def loadHouseholdOrEmpty
    (root : System.FilePath) : IO (Except String Image) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  match Loam.Persistence.HouseholdImage.body? generation.image "Capacity" with
  | none => return .ok Loam.CapacityEvidence.empty
  | some body => return decodeHouseholdBody body

/--
Load required Capacity from the installed HouseholdImage.

This preserves callers whose answer requires configured Capacity rather than
the optional empty-history entrance.
-/
def loadHouseholdRequired
    (root : System.FilePath) : IO (Except String Image) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  match Loam.Persistence.HouseholdImage.body? generation.image "Capacity" with
  | none => return .error "loam: required HouseholdImage Capacity section is missing"
  | some body => return decodeHouseholdBody body

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
