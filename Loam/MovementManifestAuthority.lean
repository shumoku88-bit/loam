import Loam.MovementAdmission
import Loam.Persistence
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Persistence.OpenRelationPersistence
import Loam.Persistence.RelationDischargePersistence
import Loam.Sha256
import Std

namespace Loam.MovementManifestAuthority

set_option autoImplicit false

/-!
# Movement generation-manifest authority

This is a Movement-specific physical authority boundary for the five canonical
fact families needed by the practical Movement writer. It deliberately does not
merge those meanings into one semantic family and does not perform Movement
admission.

A selected generation is named only by `CURRENT`. Family images are immutable,
content-addressed objects. Preparing objects does not make them authoritative;
`commitPrepared?` changes authority through one `CURRENT` replacement.

The module is intentionally narrower than a generic repository or transaction
framework. Application 035 uses it behind an explicit experimental production
mode before any default sidecar -> manifest cutover is considered.
-/

private structure FamilyRef where
  path : String
  sha256 : String
  deriving Repr, BEq

private structure Manifest where
  events : FamilyRef
  validity : FamilyRef
  descriptions : FamilyRef
  relations : FamilyRef
  discharges : FamilyRef
  deriving Repr, BEq

private structure WorldBytes where
  events : String
  validity : String
  descriptions : String
  relations : String
  discharges : String
  deriving Repr, BEq

/--
An off-authority Movement generation whose referenced objects have already been
prepared and verified. `reusedObjects` is observational only and has no semantic
or authority meaning.
-/
structure Prepared where
  manifestText : String
  reusedObjects : Nat
  deriving Repr, BEq

private def manifestHeader : String := "LOAM-MOVEMENT-MANIFEST\t1"

private def objectRelativePath (family digest : String) : String :=
  "objects/" ++ family ++ "/" ++ digest ++ ".loam"

private def manifestRow (family : String) (ref : FamilyRef) : String :=
  family ++ "\t" ++ ref.path ++ "\t" ++ ref.sha256

private def encodeManifest (manifest : Manifest) : String :=
  String.intercalate "\n" [
    manifestHeader,
    manifestRow "Event" manifest.events,
    manifestRow "ActualValidity" manifest.validity,
    manifestRow "EventDescription" manifest.descriptions,
    manifestRow "RelationUnit" manifest.relations,
    manifestRow "RelationDischarge" manifest.discharges
  ] ++ "\n"

private def decodeManifestRow? (expected : String) (row : String) : Option FamilyRef :=
  match row.splitOn "\t" with
  | [family, path, digest] =>
      if family == expected && digest.length == 64 &&
          path == objectRelativePath expected digest then
        some { path := path, sha256 := digest }
      else
        none
  | _ => none

private def decodeManifest? (input : String) : Option Manifest :=
  match input.splitOn "\n" with
  | [header, eventRow, validityRow, descriptionRow, relationRow, dischargeRow, trailing] =>
      if header != manifestHeader || trailing != "" then
        none
      else do
        let events ← decodeManifestRow? "Event" eventRow
        let validity ← decodeManifestRow? "ActualValidity" validityRow
        let descriptions ← decodeManifestRow? "EventDescription" descriptionRow
        let relations ← decodeManifestRow? "RelationUnit" relationRow
        let discharges ← decodeManifestRow? "RelationDischarge" dischargeRow
        some { events, validity, descriptions, relations, discharges }
  | _ => none

private def boolNat (value : Bool) : Nat := if value then 1 else 0

private def encodeWorld?
    (world : Loam.MovementAdmission.World) : Option WorldBytes := do
  let events ← Loam.Persistence.encodeEventMemory? world.events
  let validity ← Loam.Persistence.encodeActualValidityHistory? world.validity
  let descriptions ← Loam.Persistence.encodeEventDescriptionMemory? world.descriptions
  let relations ← Loam.Persistence.encodeOpenRelationUnits? world.relations
  let discharges ← Loam.Persistence.encodeRelationDischarges? world.discharges
  some { events, validity, descriptions, relations, discharges }

private def decodeWorld? (bytes : WorldBytes) : Option Loam.MovementAdmission.World := do
  let events ← Loam.Persistence.decodeEventMemory? bytes.events
  let validity ← Loam.Persistence.decodeActualValidityHistory? bytes.validity
  let descriptions ← Loam.Persistence.decodeEventDescriptionMemory? bytes.descriptions
  let relations ← Loam.Persistence.decodeOpenRelationUnits? bytes.relations
  let discharges ← Loam.Persistence.decodeRelationDischarges? bytes.discharges
  some { events, validity, descriptions, relations, discharges }

private def ensureObject?
    (root : System.FilePath) (family text : String) : IO (Except String (FamilyRef × Bool)) := do
  let digest := Loam.Sha256.hash text.toUTF8
  let relative := objectRelativePath family digest
  let target := root / relative
  if let some parent := target.parent then
    IO.FS.createDirAll parent
  let existed ← target.pathExists
  if existed then
    let existing ← IO.FS.readFile target
    if existing == text then
      return Except.ok ({ path := relative, sha256 := digest }, true)
    else
      return Except.error s!"loam: content-addressed Movement object mismatch: {relative}"
  else
    let stage := System.FilePath.mk (target.toString ++ ".loam-stage")
    IO.FS.writeFile stage text
    let staged ← IO.FS.readFile stage
    if staged != text then
      return Except.error s!"loam: staged Movement object mismatch: {relative}"
    IO.FS.rename stage target
    return Except.ok ({ path := relative, sha256 := digest }, false)

private def loadReferenced?
    (root : System.FilePath) (ref : FamilyRef) : IO (Except String String) := do
  let target := root / ref.path
  if !(← target.pathExists) then
    return Except.error s!"loam: selected Movement object is missing: {ref.path}"
  let text ← IO.FS.readFile target
  if Loam.Sha256.hash text.toUTF8 != ref.sha256 then
    return Except.error s!"loam: selected Movement object failed digest verification: {ref.path}"
  return Except.ok text

/--
Load exactly one selected Movement generation. There is no sidecar discovery or
legacy fallback: missing, malformed, unsupported, or digest-invalid selected
authority fails closed.
-/
def loadSelectedWorld?
    (root : System.FilePath) : IO (Except String Loam.MovementAdmission.World) := do
  let current := root / "CURRENT"
  if !(← current.pathExists) then
    return Except.error "loam: selected Movement manifest CURRENT is missing"
  let manifest ←
    match decodeManifest? (← IO.FS.readFile current) with
    | some manifest => pure manifest
    | none => return Except.error "loam: selected Movement manifest CURRENT is malformed or unsupported"
  let events ←
    match ← loadReferenced? root manifest.events with
    | Except.ok text => pure text
    | Except.error message => return Except.error message
  let validity ←
    match ← loadReferenced? root manifest.validity with
    | Except.ok text => pure text
    | Except.error message => return Except.error message
  let descriptions ←
    match ← loadReferenced? root manifest.descriptions with
    | Except.ok text => pure text
    | Except.error message => return Except.error message
  let relations ←
    match ← loadReferenced? root manifest.relations with
    | Except.ok text => pure text
    | Except.error message => return Except.error message
  let discharges ←
    match ← loadReferenced? root manifest.discharges with
    | Except.ok text => pure text
    | Except.error message => return Except.error message
  match decodeWorld? { events, validity, descriptions, relations, discharges } with
  | some world => return Except.ok world
  | none => return Except.error "loam: selected Movement generation failed production typed decoding"

/--
Prepare all five typed family images off authority. Existing byte-identical
content-addressed objects are reused. No `CURRENT` change occurs here.
-/
def prepareWorld?
    (root : System.FilePath)
    (world : Loam.MovementAdmission.World) : IO (Except String Prepared) := do
  let bytes ←
    match encodeWorld? world with
    | some bytes => pure bytes
    | none => return Except.error "loam: production encoders rejected admitted Movement world"
  IO.FS.createDirAll root
  let (events, reusedEvents) ←
    match ← ensureObject? root "Event" bytes.events with
    | Except.ok value => pure value
    | Except.error message => return Except.error message
  let (validity, reusedValidity) ←
    match ← ensureObject? root "ActualValidity" bytes.validity with
    | Except.ok value => pure value
    | Except.error message => return Except.error message
  let (descriptions, reusedDescriptions) ←
    match ← ensureObject? root "EventDescription" bytes.descriptions with
    | Except.ok value => pure value
    | Except.error message => return Except.error message
  let (relations, reusedRelations) ←
    match ← ensureObject? root "RelationUnit" bytes.relations with
    | Except.ok value => pure value
    | Except.error message => return Except.error message
  let (discharges, reusedDischarges) ←
    match ← ensureObject? root "RelationDischarge" bytes.discharges with
    | Except.ok value => pure value
    | Except.error message => return Except.error message
  let manifest : Manifest := { events, validity, descriptions, relations, discharges }
  let reused := boolNat reusedEvents + boolNat reusedValidity + boolNat reusedDescriptions +
    boolNat reusedRelations + boolNat reusedDischarges
  return Except.ok {
    manifestText := encodeManifest manifest
    reusedObjects := reused
  }

/--
Atomically select one already-prepared Movement generation by replacing only
`CURRENT`. The staged manifest is decoded and compared before authority changes.
-/
def commitPrepared?
    (root : System.FilePath) (prepared : Prepared) : IO (Except String Unit) := do
  let expected ←
    match decodeManifest? prepared.manifestText with
    | some manifest => pure manifest
    | none => return Except.error "loam: prepared Movement manifest is malformed"
  IO.FS.createDirAll root
  let target := root / "CURRENT"
  let stage := root / "CURRENT.loam-stage"
  IO.FS.writeFile stage prepared.manifestText
  let staged ←
    match decodeManifest? (← IO.FS.readFile stage) with
    | some manifest => pure manifest
    | none => return Except.error "loam: staged Movement CURRENT failed decoding"
  if staged != expected then
    return Except.error "loam: staged Movement CURRENT changed typed references"
  IO.FS.rename stage target
  return Except.ok ()

/-- Prepare immutable objects and then perform one Movement authority switch. -/
def publishWorld?
    (root : System.FilePath)
    (world : Loam.MovementAdmission.World) : IO (Except String Nat) := do
  match ← prepareWorld? root world with
  | Except.error message => return Except.error message
  | Except.ok prepared =>
      match ← commitPrepared? root prepared with
      | Except.error message => return Except.error message
      | Except.ok () => return Except.ok prepared.reusedObjects

end Loam.MovementManifestAuthority
