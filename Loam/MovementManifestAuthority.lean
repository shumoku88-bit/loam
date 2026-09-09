import Loam.MovementAdmission
import Loam.Persistence
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Persistence.LocusAdmissionPersistence
import Loam.Persistence.OpenRelationPersistence
import Loam.Persistence.RelationDischargePersistence
import Loam.Sha256
import Std

namespace Loam.MovementManifestAuthority

set_option autoImplicit false

/-!
# Movement generation-manifest authority

This is a Movement-specific physical authority boundary for the canonical fact
families needed by the practical Movement writer plus the independently meaningful
Locus new-write admission vocabulary earned by Observation 212. It deliberately
does not merge those meanings into one semantic family and does not perform
Movement admission.

A selected generation is named only by `CURRENT`. Family images are immutable,
content-addressed objects. Preparing objects does not make them authoritative;
`commitPrepared?` changes authority through one `CURRENT` replacement.

Validated pre-switch `CURRENT` manifests are retained as content-addressed recovery
candidates. Those copies are not authority and are never discovered as fallback
reads. `CURRENT` remains the only selected generation.

Version 1 manifests contained only the five historical Movement evidence families.
They remain readable so existing household history and read-only projections do
not disappear during migration. They decode with an empty Locus admission
vocabulary, which means every new quantity-bearing Movement fails closed until a
version 2 generation explicitly publishes the sixth policy family.
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
  locusAdmission : Option FamilyRef
  deriving Repr, BEq

private structure WorldBytes where
  events : String
  validity : String
  descriptions : String
  relations : String
  discharges : String
  locusAdmission : String
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

private def manifestHeaderV1 : String := "LOAM-MOVEMENT-MANIFEST\t1"
private def manifestHeaderV2 : String := "LOAM-MOVEMENT-MANIFEST\t2"

private def objectRelativePath (family digest : String) : String :=
  "objects/" ++ family ++ "/" ++ digest ++ ".loam"

private def manifestRow (family : String) (ref : FamilyRef) : String :=
  family ++ "\t" ++ ref.path ++ "\t" ++ ref.sha256

private def encodeManifest (manifest : Manifest) : String :=
  match manifest.locusAdmission with
  | none =>
      String.intercalate "\n" [
        manifestHeaderV1,
        manifestRow "Event" manifest.events,
        manifestRow "ActualValidity" manifest.validity,
        manifestRow "EventDescription" manifest.descriptions,
        manifestRow "RelationUnit" manifest.relations,
        manifestRow "RelationDischarge" manifest.discharges
      ] ++ "\n"
  | some locusAdmission =>
      String.intercalate "\n" [
        manifestHeaderV2,
        manifestRow "Event" manifest.events,
        manifestRow "ActualValidity" manifest.validity,
        manifestRow "EventDescription" manifest.descriptions,
        manifestRow "RelationUnit" manifest.relations,
        manifestRow "RelationDischarge" manifest.discharges,
        manifestRow "LocusAdmission" locusAdmission
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
      if header != manifestHeaderV1 || trailing != "" then
        none
      else do
        let events ← decodeManifestRow? "Event" eventRow
        let validity ← decodeManifestRow? "ActualValidity" validityRow
        let descriptions ← decodeManifestRow? "EventDescription" descriptionRow
        let relations ← decodeManifestRow? "RelationUnit" relationRow
        let discharges ← decodeManifestRow? "RelationDischarge" dischargeRow
        some { events, validity, descriptions, relations, discharges, locusAdmission := none }
  | [header, eventRow, validityRow, descriptionRow, relationRow, dischargeRow,
      locusAdmissionRow, trailing] =>
      if header != manifestHeaderV2 || trailing != "" then
        none
      else do
        let events ← decodeManifestRow? "Event" eventRow
        let validity ← decodeManifestRow? "ActualValidity" validityRow
        let descriptions ← decodeManifestRow? "EventDescription" descriptionRow
        let relations ← decodeManifestRow? "RelationUnit" relationRow
        let discharges ← decodeManifestRow? "RelationDischarge" dischargeRow
        let locusAdmission ← decodeManifestRow? "LocusAdmission" locusAdmissionRow
        some {
          events, validity, descriptions, relations, discharges,
          locusAdmission := some locusAdmission
        }
  | _ => none

private def recoveryManifestRelativePath (digest : String) : String :=
  "recovery/manifests/" ++ digest ++ ".loam"

/--
Retain one already-validated manifest as an immutable off-authority recovery
candidate. The caller is responsible for proving that its referenced generation is
currently readable before invoking this physical retention step.
-/
private def retainRecoveryManifest?
    (root : System.FilePath) (text : String) : IO (Except String String) := do
  match decodeManifest? text with
  | none => return .error "loam: recovery candidate manifest is malformed or unsupported"
  | some _ => pure ()
  let digest := Loam.Sha256.hash text.toUTF8
  let relative := recoveryManifestRelativePath digest
  let target := root / relative
  if let some parent := target.parent then
    IO.FS.createDirAll parent
  if ← target.pathExists then
    let existing ← IO.FS.readFile target
    if existing != text then
      return .error s!"loam: content-addressed recovery manifest mismatch: {relative}"
    return .ok digest
  let stage := System.FilePath.mk (target.toString ++ ".loam-stage")
  IO.FS.writeFile stage text
  let staged ← IO.FS.readFile stage
  if staged != text then
    return .error s!"loam: staged recovery manifest mismatch: {relative}"
  IO.FS.rename stage target
  return .ok digest

private def boolNat (value : Bool) : Nat := if value then 1 else 0

private def encodeWorld?
    (world : Loam.MovementAdmission.World) : Option WorldBytes := do
  let events ← Loam.Persistence.encodeEventMemory? world.events
  let validity ← Loam.Persistence.encodeActualValidityHistory? world.validity
  let descriptions ← Loam.Persistence.encodeEventDescriptionMemory? world.descriptions
  let relations ← Loam.Persistence.encodeOpenRelationUnits? world.relations
  let discharges ← Loam.Persistence.encodeRelationDischarges? world.discharges
  let locusAdmission ←
    Loam.Persistence.encodeLocusAdmissionVocabulary? world.locusAdmission
  some { events, validity, descriptions, relations, discharges, locusAdmission }

private def decodeWorld? (bytes : WorldBytes) : Option Loam.MovementAdmission.World := do
  let events ← Loam.Persistence.decodeEventMemory? bytes.events
  let validity ← Loam.Persistence.decodeActualValidityHistory? bytes.validity
  let descriptions ← Loam.Persistence.decodeEventDescriptionMemory? bytes.descriptions
  let relations ← Loam.Persistence.decodeOpenRelationUnits? bytes.relations
  let discharges ← Loam.Persistence.decodeRelationDischarges? bytes.discharges
  let locusAdmission ←
    Loam.Persistence.decodeLocusAdmissionVocabulary? bytes.locusAdmission
  some { events, validity, descriptions, relations, discharges, locusAdmission }

private def decodeLegacyWorld?
    (events validity descriptions relations discharges : String) :
    Option Loam.MovementAdmission.World := do
  let eventMemory ← Loam.Persistence.decodeEventMemory? events
  let validityHistory ← Loam.Persistence.decodeActualValidityHistory? validity
  let descriptionMemory ← Loam.Persistence.decodeEventDescriptionMemory? descriptions
  let relationUnits ← Loam.Persistence.decodeOpenRelationUnits? relations
  let relationDischarges ← Loam.Persistence.decodeRelationDischarges? discharges
  some {
    events := eventMemory
    validity := validityHistory
    descriptions := descriptionMemory
    relations := relationUnits
    discharges := relationDischarges
    locusAdmission := Loam.Core.LocusAdmissionVocabulary.empty
  }

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

A version 1 generation remains readable but receives the empty new-write
vocabulary. It can therefore support review/projection while refusing every new
Movement at `MovementAdmission.admit?` until an explicit version 2 cutover.
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
  match manifest.locusAdmission with
  | none =>
      match decodeLegacyWorld? events validity descriptions relations discharges with
      | some world => return Except.ok world
      | none => return Except.error "loam: selected Movement generation failed production typed decoding"
  | some locusAdmissionRef =>
      let locusAdmission ←
        match ← loadReferenced? root locusAdmissionRef with
        | Except.ok text => pure text
        | Except.error message => return Except.error message
      match decodeWorld? {
          events, validity, descriptions, relations, discharges, locusAdmission
        } with
      | some world => return Except.ok world
      | none => return Except.error "loam: selected Movement generation failed production typed decoding"

/--
Prepare all six typed family images off authority. Existing byte-identical
content-addressed objects are reused. No `CURRENT` change occurs here. Every new
prepared generation is version 2 and therefore carries explicit new-write policy.
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
  let (locusAdmission, reusedLocusAdmission) ←
    match ← ensureObject? root "LocusAdmission" bytes.locusAdmission with
    | Except.ok value => pure value
    | Except.error message => return Except.error message
  let manifest : Manifest := {
    events, validity, descriptions, relations, discharges,
    locusAdmission := some locusAdmission
  }
  let reused := boolNat reusedEvents + boolNat reusedValidity + boolNat reusedDescriptions +
    boolNat reusedRelations + boolNat reusedDischarges + boolNat reusedLocusAdmission
  return Except.ok {
    manifestText := encodeManifest manifest
    reusedObjects := reused
  }

/--
Atomically select one already-prepared Movement generation by replacing only
`CURRENT`. Before switching, an existing selected generation must fully validate and
its exact manifest is retained as an immutable off-authority recovery candidate.
A malformed or unreadable current authority therefore blocks the switch rather than
being overwritten and hidden.
-/
def commitPrepared?
    (root : System.FilePath) (prepared : Prepared) : IO (Except String Unit) := do
  let expected ←
    match decodeManifest? prepared.manifestText with
    | some manifest => pure manifest
    | none => return Except.error "loam: prepared Movement manifest is malformed"
  IO.FS.createDirAll root
  let target := root / "CURRENT"
  if ← target.pathExists then
    match ← loadSelectedWorld? root with
    | .error message =>
        return .error ("loam: existing Movement CURRENT cannot be retained for recovery: " ++ message)
    | .ok _ => pure ()
    let currentText ← IO.FS.readFile target
    match ← retainRecoveryManifest? root currentText with
    | .error message => return .error message
    | .ok _ => pure ()
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
