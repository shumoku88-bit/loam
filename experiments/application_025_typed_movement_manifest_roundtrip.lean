import Loam.Application.ActualValidityFrontier
import Loam.Application.RelationDischargeFrontier
import Loam.Persistence
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Persistence.OpenRelationPersistence
import Loam.Persistence.RelationDischargePersistence
import Loam.Sha256
import Std

namespace Loam.Application025

open Loam.Core

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

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

private structure TypedWorld where
  events : EventMemory
  validity : ActualValidityHistory String
  descriptions : EventDescriptionMemory
  relations : List RelationUnit
  discharges : List RelationDischarge

private structure ProductionProjection where
  eventCount : Nat
  effectCount : Nat
  paypay : Int
  travel : Int
  friendIn : Int
  firstDate : Option String
  secondDate : Option String
  firstDescription : Option String
  secondDescription : Option String
  relationCount : Nat
  dischargeCount : Nat
  relationCurrent : Bool
  relationOutstanding : Option Int
  deriving Repr, BEq

private def manifestHeader : String := "LOAM-APPLICATION025-MANIFEST\t1"

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

private def ensureObject
    (root : System.FilePath) (family text : String) : IO FamilyRef := do
  let digest := Loam.Sha256.hash text.toUTF8
  let relative := objectRelativePath family digest
  let target := root / relative
  if let some parent := target.parent then
    IO.FS.createDirAll parent
  if ← target.pathExists then
    let existing ← IO.FS.readFile target
    unless existing == text do
      throw <| IO.userError s!"content-addressed object mismatch: {relative}"
  else
    let stage := System.FilePath.mk (target.toString ++ ".loam-stage")
    IO.FS.writeFile stage text
    let staged ← IO.FS.readFile stage
    unless staged == text do
      throw <| IO.userError s!"staged object mismatch: {relative}"
    IO.FS.rename stage target
  pure { path := relative, sha256 := digest }

private def publishManifest (root : System.FilePath) (manifest : Manifest) : IO Unit := do
  let target := root / "CURRENT"
  let stage := root / "CURRENT.loam-stage"
  let text := encodeManifest manifest
  IO.FS.writeFile stage text
  let staged ← IO.FS.readFile stage
  match decodeManifest? staged with
  | some decoded =>
      unless decoded == manifest do
        throw <| IO.userError "staged manifest changed typed references"
  | none => throw <| IO.userError "staged manifest failed its own decoder"
  IO.FS.rename stage target

private def loadManifest? (root : System.FilePath) : IO (Option Manifest) := do
  let target := root / "CURRENT"
  if !(← target.pathExists) then
    return none
  return decodeManifest? (← IO.FS.readFile target)

private def loadReferenced? (root : System.FilePath) (ref : FamilyRef) : IO (Option String) := do
  let target := root / ref.path
  if !(← target.pathExists) then
    return none
  let text ← IO.FS.readFile target
  if Loam.Sha256.hash text.toUTF8 == ref.sha256 then
    return some text
  else
    return none

private def decodeWorld? (bytes : WorldBytes) : Option TypedWorld := do
  let events ← Loam.Persistence.decodeEventMemory? bytes.events
  let validity ← Loam.Persistence.decodeActualValidityHistory? bytes.validity
  let descriptions ← Loam.Persistence.decodeEventDescriptionMemory? bytes.descriptions
  let relations ← Loam.Persistence.decodeOpenRelationUnits? bytes.relations
  let discharges ← Loam.Persistence.decodeRelationDischarges? bytes.discharges
  some { events, validity, descriptions, relations, discharges }

private def encodeWorld? (world : TypedWorld) : Option WorldBytes := do
  let events ← Loam.Persistence.encodeEventMemory? world.events
  let validity ← Loam.Persistence.encodeActualValidityHistory? world.validity
  let descriptions ← Loam.Persistence.encodeEventDescriptionMemory? world.descriptions
  let relations ← Loam.Persistence.encodeOpenRelationUnits? world.relations
  let discharges ← Loam.Persistence.encodeRelationDischarges? world.discharges
  some { events, validity, descriptions, relations, discharges }

private def loadDirectWorld? (memoryFile : System.FilePath) : IO (Option TypedWorld) := do
  let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
  let descriptionFile := Loam.Persistence.eventDescriptionPathForEventMemory memoryFile
  let relationFile := Loam.Persistence.openRelationUnitPathForEventMemory memoryFile
  let dischargeFile := Loam.Persistence.relationDischargePathForEventMemory memoryFile
  if !(← memoryFile.pathExists) || !(← validityFile.pathExists) ||
      !(← descriptionFile.pathExists) || !(← relationFile.pathExists) ||
      !(← dischargeFile.pathExists) then
    return none
  let bytes : WorldBytes := {
    events := ← IO.FS.readFile memoryFile
    validity := ← IO.FS.readFile validityFile
    descriptions := ← IO.FS.readFile descriptionFile
    relations := ← IO.FS.readFile relationFile
    discharges := ← IO.FS.readFile dischargeFile
  }
  return decodeWorld? bytes

private def publishTypedWorld (root : System.FilePath) (world : TypedWorld) : IO Manifest := do
  let bytes ← requireSome (encodeWorld? world) "production encoders rejected typed Movement world"
  let events ← ensureObject root "Event" bytes.events
  let validity ← ensureObject root "ActualValidity" bytes.validity
  let descriptions ← ensureObject root "EventDescription" bytes.descriptions
  let relations ← ensureObject root "RelationUnit" bytes.relations
  let discharges ← ensureObject root "RelationDischarge" bytes.discharges
  let manifest : Manifest := { events, validity, descriptions, relations, discharges }
  publishManifest root manifest
  pure manifest

private def readCurrentTyped? (root : System.FilePath) : IO (Option TypedWorld) := do
  let some manifest ← loadManifest? root | return none
  let some events ← loadReferenced? root manifest.events | return none
  let some validity ← loadReferenced? root manifest.validity | return none
  let some descriptions ← loadReferenced? root manifest.descriptions | return none
  let some relations ← loadReferenced? root manifest.relations | return none
  let some discharges ← loadReferenced? root manifest.discharges | return none
  return decodeWorld? { events, validity, descriptions, relations, discharges }

private def productionProjection? (world : TypedWorld) : Option ProductionProjection := do
  let validity ← Loam.Application.admittedActualValidityMemory? world.validity
  let relationCurrent :=
    (Loam.Application.currentAdmittedRelationById?
      world.events world.relations [] ⟨"relation-1"⟩).isSome
  let relationOutstanding :=
    (Loam.Application.relationOutstandingQuantity?
      world.events world.relations [] world.discharges ⟨"relation-1"⟩).map
      (fun quantity => quantity.quanta)
  let effectCount :=
    world.events.events.foldl (fun total event => total + event.effects.length) 0
  some {
    eventCount := world.events.events.length
    effectCount := effectCount
    paypay := (EventMemory.quantityAtRecorded world.events ⟨"paypay"⟩ ⟨"jpy"⟩).quanta
    travel := (EventMemory.quantityAtRecorded world.events ⟨"travel"⟩ ⟨"jpy"⟩).quanta
    friendIn := (EventMemory.quantityAtRecorded world.events ⟨"friend-in"⟩ ⟨"jpy"⟩).quanta
    firstDate := validity.findByEventId? ⟨"record-1"⟩
    secondDate := validity.findByEventId? ⟨"record-2"⟩
    firstDescription := world.descriptions.findText? ⟨"record-1"⟩
    secondDescription := world.descriptions.findText? ⟨"record-2"⟩
    relationCount := world.relations.length
    dischargeCount := world.discharges.length
    relationCurrent := relationCurrent
    relationOutstanding := relationOutstanding
  }

private def expectPracticalProjection (projection : ProductionProjection) : IO Unit := do
  expect (projection.eventCount == 2) "practical Movement Event count changed"
  expect (projection.effectCount == 4) "practical Movement Effect count changed"
  expect (projection.paypay == -60) "recorded paypay projection changed"
  expect (projection.travel == 100) "recorded travel projection changed"
  expect (projection.friendIn == -40) "recorded friend-in projection changed"
  expect (projection.firstDate == some "2026-09-05") "first occurrence date changed"
  expect (projection.secondDate == some "2026-09-06") "second occurrence date changed"
  expect (projection.firstDescription == some "manifest source movement")
    "first EventDescription changed"
  expect (projection.secondDescription == some "manifest discharge movement")
    "second EventDescription changed"
  expect (projection.relationCount == 1) "RelationUnit count changed"
  expect (projection.dischargeCount == 1) "RelationDischarge count changed"
  expect projection.relationCurrent "relation-1 no longer projects as current"
  expect (projection.relationOutstanding == some 60)
    "relation-1 outstanding quantity changed"

private def runPublish (memoryPath rootPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let root := System.FilePath.mk rootPath
  if ← root.pathExists then
    IO.FS.removeDirAll root
  IO.FS.createDirAll root
  let direct ← requireSome (← loadDirectWorld? memoryFile)
    "production Movement sidecars could not be loaded as one typed world"
  let projection ← requireSome (productionProjection? direct)
    "production Movement world failed semantic projection before manifest publication"
  expectPracticalProjection projection
  let _ ← publishTypedWorld root direct
  IO.println "Application 025 typed Movement manifest publish PASS"
  IO.println "typed_families=5"
  IO.println "positive_authority_switches=1"
  return 0

private def runVerify (memoryPath rootPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let root := System.FilePath.mk rootPath
  let direct ← requireSome (← loadDirectWorld? memoryFile)
    "production Movement sidecars could not be reloaded after process restart"
  let selected ← requireSome (← readCurrentTyped? root)
    "CURRENT did not reconstruct one production-decoded typed Movement world"
  let directProjection ← requireSome (productionProjection? direct)
    "direct production world failed semantic projection after restart"
  let selectedProjection ← requireSome (productionProjection? selected)
    "manifest-selected production world failed semantic projection after restart"
  expectPracticalProjection directProjection
  expectPracticalProjection selectedProjection
  expect (selectedProjection == directProjection)
    "manifest authority changed the production household projection"
  let directBytes ← requireSome (encodeWorld? direct)
    "direct typed world failed production re-encoding"
  let selectedBytes ← requireSome (encodeWorld? selected)
    "manifest-selected typed world failed production re-encoding"
  expect (selectedBytes == directBytes)
    "manifest authority changed canonical production family bytes"

  let manifest ← requireSome (← loadManifest? root)
    "valid CURRENT disappeared before typed negative check"
  let malformedEvent ← ensureObject root "Event" "LOAM-EVENT-MEMORY\t99\n"
  publishManifest root { manifest with events := malformedEvent }
  expect (← readCurrentTyped? root).isNone
    "digest-valid but semantically malformed Event bypassed the production decoder"

  IO.println "Application 025 typed Movement manifest round-trip PASS"
  IO.println "practical_events=2"
  IO.println "typed_families=5"
  IO.println "canonical_family_byte_matches=5"
  IO.println "semantic_projection_match=1"
  IO.println "recorded_paypay=-60"
  IO.println "relation_outstanding=60"
  IO.println "typed_fail_closed_cases=1"
  return 0

end Loam.Application025

def main (args : List String) : IO UInt32 :=
  match args with
  | ["publish", memoryPath, rootPath] =>
      Loam.Application025.runPublish memoryPath rootPath
  | ["verify", memoryPath, rootPath] =>
      Loam.Application025.runVerify memoryPath rootPath
  | _ => do
      IO.eprintln "Usage: application_025_typed_movement_manifest_roundtrip (publish|verify) MEMORY_FILE MANIFEST_ROOT"
      return 2
