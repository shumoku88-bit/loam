import Loam.MovementManifestAuthority
import Loam.Persistence
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Persistence.OpenRelationPersistence
import Loam.Persistence.RelationDischargePersistence
import Loam.WriterOwnership

namespace Loam.Cli.MovementManifestCutoverCli

set_option autoImplicit false

private def usage : String :=
  "Movement sidecar -> generation-manifest cutover\n\n" ++
  "  loamMovementManifestCutover prepare MEMORY_FILE MANIFEST_ROOT\n" ++
  "  loamMovementManifestCutover cutover MEMORY_FILE MANIFEST_ROOT\n"

private def fail (message : String) : IO UInt32 := do
  IO.eprintln ("loam-movement-manifest-cutover: " ++ message)
  return 1

private def usageFail : IO UInt32 := do
  IO.eprintln usage
  return 2

private def boolNat (value : Bool) : Nat := if value then 1 else 0

private structure SidecarWorld where
  world : Loam.MovementAdmission.World
  storedExact : Nat
  absentEmpty : Nat

/--
Require every physically present sidecar image to be exactly the production
re-encoding of its decoded typed value. An absent optional family is admitted
only when the caller supplied the production empty value for that family.
-/
private def verifySourceImage?
    (path : System.FilePath)
    (encoded : String)
    (allowAbsent : Bool) : IO (Except String Bool) := do
  if ← path.pathExists then
    let raw ← IO.FS.readFile path
    if raw == encoded then
      return .ok true
    else
      return .error s!"production re-encode changed source bytes: {path}"
  else if allowAbsent then
    return .ok false
  else
    return .error s!"required source sidecar is missing: {path}"

private def loadDescriptionsOrEmpty?
    (path : System.FilePath) : IO (Option Loam.Core.EventDescriptionMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventDescriptionMemory? path
  else
    return some Loam.Core.EventDescriptionMemory.empty

private def loadRelationsOrEmpty?
    (path : System.FilePath) : IO (Option (List Loam.Core.RelationUnit)) := do
  if ← path.pathExists then
    Loam.Persistence.loadOpenRelationUnits? path
  else
    return some []

private def loadDischargesOrEmpty?
    (path : System.FilePath) : IO (Option (List Loam.Core.RelationDischarge)) := do
  if ← path.pathExists then
    Loam.Persistence.loadRelationDischarges? path
  else
    return some []

/--
Read the legacy Movement authority using only production codecs.

Event is required. The four adjacent families retain their existing practical
missing-is-empty behavior. For every family that is physically present, exact
raw byte equality with the production re-encoding is mandatory before it may be
used to seed a manifest generation.
-/
private def loadSidecarWorld?
    (memoryFile : System.FilePath) : IO (Except String SidecarWorld) := do
  if !(← memoryFile.pathExists) then
    return .error s!"required source sidecar is missing: {memoryFile}"
  let some events ← Loam.Persistence.loadEventMemory? memoryFile
    | return .error "malformed or unsupported event-memory sidecar"
  let some eventBytes := Loam.Persistence.encodeEventMemory? events
    | return .error "production Event encoder rejected decoded source"
  let eventStored ←
    match ← verifySourceImage? memoryFile eventBytes false with
    | .error message => return .error message
    | .ok stored => pure stored

  let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
  let some validity ← Loam.Persistence.loadActualValidityHistoryOrEmpty? validityFile
    | return .error "malformed or unsupported actual-validity sidecar"
  let some validityBytes := Loam.Persistence.encodeActualValidityHistory? validity
    | return .error "production ActualValidity encoder rejected decoded source"
  let validityStored ←
    match ← verifySourceImage? validityFile validityBytes true with
    | .error message => return .error message
    | .ok stored => pure stored

  let descriptionFile := Loam.Persistence.eventDescriptionPathForEventMemory memoryFile
  let some descriptions ← loadDescriptionsOrEmpty? descriptionFile
    | return .error "malformed or unsupported event-description sidecar"
  let some descriptionBytes := Loam.Persistence.encodeEventDescriptionMemory? descriptions
    | return .error "production EventDescription encoder rejected decoded source"
  let descriptionStored ←
    match ← verifySourceImage? descriptionFile descriptionBytes true with
    | .error message => return .error message
    | .ok stored => pure stored

  let relationFile := Loam.Persistence.openRelationUnitPathForEventMemory memoryFile
  let some relations ← loadRelationsOrEmpty? relationFile
    | return .error "malformed or unsupported open-relation sidecar"
  let some relationBytes := Loam.Persistence.encodeOpenRelationUnits? relations
    | return .error "production RelationUnit encoder rejected decoded source"
  let relationStored ←
    match ← verifySourceImage? relationFile relationBytes true with
    | .error message => return .error message
    | .ok stored => pure stored

  let dischargeFile := Loam.Persistence.relationDischargePathForEventMemory memoryFile
  let some discharges ← loadDischargesOrEmpty? dischargeFile
    | return .error "malformed or unsupported relation-discharge sidecar"
  let some dischargeBytes := Loam.Persistence.encodeRelationDischarges? discharges
    | return .error "production RelationDischarge encoder rejected decoded source"
  let dischargeStored ←
    match ← verifySourceImage? dischargeFile dischargeBytes true with
    | .error message => return .error message
    | .ok stored => pure stored

  let storedExact :=
    boolNat eventStored + boolNat validityStored + boolNat descriptionStored +
      boolNat relationStored + boolNat dischargeStored
  return .ok {
    world := {
      events := events
      validity := validity
      descriptions := descriptions
      relations := relations
      discharges := discharges
    }
    storedExact := storedExact
    absentEmpty := 5 - storedExact
  }

private def sameEncodedWorld?
    (left right : Loam.MovementAdmission.World) : Bool :=
  match Loam.Persistence.encodeEventMemory? left.events,
      Loam.Persistence.encodeEventMemory? right.events,
      Loam.Persistence.encodeActualValidityHistory? left.validity,
      Loam.Persistence.encodeActualValidityHistory? right.validity,
      Loam.Persistence.encodeEventDescriptionMemory? left.descriptions,
      Loam.Persistence.encodeEventDescriptionMemory? right.descriptions,
      Loam.Persistence.encodeOpenRelationUnits? left.relations,
      Loam.Persistence.encodeOpenRelationUnits? right.relations,
      Loam.Persistence.encodeRelationDischarges? left.discharges,
      Loam.Persistence.encodeRelationDischarges? right.discharges with
  | some le, some re, some lv, some rv, some ld, some rd,
      some lr, some rr, some lq, some rq =>
      le == re && lv == rv && ld == rd && lr == rr && lq == rq
  | _, _, _, _, _, _, _, _, _, _ => false

private def preparedPath (root : System.FilePath) : System.FilePath :=
  root / "PREPARED"

private def writePrepared?
    (root : System.FilePath)
    (prepared : Loam.MovementManifestAuthority.Prepared) : IO (Except String Unit) := do
  IO.FS.createDirAll root
  let stage := root / "PREPARED.loam-stage"
  IO.FS.writeFile stage prepared.manifestText
  let staged ← IO.FS.readFile stage
  if staged != prepared.manifestText then
    return .error "staged PREPARED manifest changed bytes"
  IO.FS.rename stage (preparedPath root)
  return .ok ()

private def prepareUnderOwnership
    (memoryFile root : System.FilePath) : IO UInt32 := do
  if ← (root / "CURRENT").pathExists then
    return ← fail "CURRENT already exists; one-time sidecar cutover refuses to replace selected authority"
  let source ←
    match ← loadSidecarWorld? memoryFile with
    | .error message => return ← fail message
    | .ok source => pure source
  let prepared ←
    match ← Loam.MovementManifestAuthority.prepareWorld? root source.world with
    | .error message => return ← fail message
    | .ok prepared => pure prepared
  match ← writePrepared? root prepared with
  | .error message => return ← fail message
  | .ok () =>
      IO.println s!"stored_exact_families={source.storedExact}"
      IO.println s!"absent_empty_families={source.absentEmpty}"
      IO.println s!"prepared_objects_reused={prepared.reusedObjects}"
      IO.println "selected_authority_changed=0"
      return 0

private def cutoverUnderOwnership
    (memoryFile root : System.FilePath) : IO UInt32 := do
  if ← (root / "CURRENT").pathExists then
    return ← fail "CURRENT already exists; one-time sidecar cutover refuses to replace selected authority"
  let preparedFile := preparedPath root
  if !(← preparedFile.pathExists) then
    return ← fail "PREPARED manifest is missing; run prepare first"
  let approvedManifest ← IO.FS.readFile preparedFile
  let source ←
    match ← loadSidecarWorld? memoryFile with
    | .error message => return ← fail message
    | .ok source => pure source
  let prepared ←
    match ← Loam.MovementManifestAuthority.prepareWorld? root source.world with
    | .error message => return ← fail message
    | .ok prepared => pure prepared
  if prepared.manifestText != approvedManifest then
    return ← fail "SOURCE-DRIFT: current sidecar world no longer matches PREPARED candidate"
  match ← Loam.MovementManifestAuthority.commitPrepared? root prepared with
  | .error message => return ← fail message
  | .ok () =>
      let selected ←
        match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
        | .error message => return ← fail ("selected generation did not reload: " ++ message)
        | .ok world => pure world
      if !sameEncodedWorld? source.world selected then
        return ← fail "selected generation differs from source production images"
      let sourceAfter ←
        match ← loadSidecarWorld? memoryFile with
        | .error message => return ← fail ("frozen sidecars changed during cutover: " ++ message)
        | .ok source => pure source
      if !sameEncodedWorld? source.world sourceAfter.world then
        return ← fail "frozen sidecars changed during cutover"
      IO.println s!"stored_exact_families={source.storedExact}"
      IO.println s!"absent_empty_families={source.absentEmpty}"
      IO.println s!"prepared_objects_reused={prepared.reusedObjects}"
      IO.println "selected_generation_matches_source=1"
      IO.println "frozen_sidecars_unchanged=1"
      IO.println "authority_switches=1"
      return 0

private def runOwned
    (operation memoryPath rootPath : String) : IO UInt32 := do
  if rootPath.isEmpty then
    return ← fail "manifest root must not be empty"
  let memoryFile := System.FilePath.mk memoryPath
  let root := System.FilePath.mk rootPath
  Loam.WriterOwnership.withOwnership memoryFile <|
    match operation with
    | "prepare" => prepareUnderOwnership memoryFile root
    | "cutover" => cutoverUnderOwnership memoryFile root
    | _ => usageFail

def run (args : List String) : IO UInt32 :=
  match args with
  | [operation, memoryPath, rootPath] => runOwned operation memoryPath rootPath
  | _ => usageFail

end Loam.Cli.MovementManifestCutoverCli

def main (args : List String) : IO UInt32 :=
  Loam.Cli.MovementManifestCutoverCli.run args
