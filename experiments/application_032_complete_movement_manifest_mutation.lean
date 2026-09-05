import Loam.Application.RelationDischargeFrontier
import Loam.Persistence
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Persistence.OpenRelationPersistence
import Loam.Persistence.RelationDischargePersistence
import Loam.Sha256
import Std

namespace Loam.Application032

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

private structure Projection where
  eventCount : Nat
  effectCount : Nat
  paypay : Int
  travel : Int
  friendIn : Int
  relationCount : Nat
  dischargeCount : Nat
  relationOutstanding : Option Int
  deriving Repr, BEq

private def manifestHeader : String := "LOAM-APPLICATION032-MANIFEST\t1"

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

private def ensureObject
    (root : System.FilePath) (family text : String) : IO (FamilyRef × Bool) := do
  let digest := Loam.Sha256.hash text.toUTF8
  let relative := objectRelativePath family digest
  let target := root / relative
  if let some parent := target.parent then
    IO.FS.createDirAll parent
  let existed ← target.pathExists
  if existed then
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
  pure ({ path := relative, sha256 := digest }, existed)

private def publishManifest (root : System.FilePath) (manifest : Manifest) : IO Unit := do
  IO.FS.createDirAll root
  let target := root / "CURRENT"
  let stage := root / "CURRENT.loam-stage"
  let text := encodeManifest manifest
  IO.FS.writeFile stage text
  let decoded ← requireSome (decodeManifest? (← IO.FS.readFile stage))
    "staged CURRENT failed Application 032 manifest decoding"
  expect (decoded == manifest) "staged CURRENT changed typed references"
  IO.FS.rename stage target

private def writeCandidate (root : System.FilePath) (manifest : Manifest) : IO Unit := do
  IO.FS.createDirAll root
  IO.FS.writeFile (root / "CANDIDATE") (encodeManifest manifest)

private def readCandidate (root : System.FilePath) : IO Manifest := do
  let path := root / "CANDIDATE"
  if !(← path.pathExists) then
    throw <| IO.userError "CANDIDATE is missing"
  requireSome (decodeManifest? (← IO.FS.readFile path)) "CANDIDATE is malformed"

private def loadManifest (root : System.FilePath) : IO Manifest := do
  let path := root / "CURRENT"
  if !(← path.pathExists) then
    throw <| IO.userError "CURRENT is missing"
  requireSome (decodeManifest? (← IO.FS.readFile path)) "CURRENT is malformed"

private def loadReferenced (root : System.FilePath) (ref : FamilyRef) : IO String := do
  let target := root / ref.path
  if !(← target.pathExists) then
    throw <| IO.userError s!"selected object is missing: {ref.path}"
  let text ← IO.FS.readFile target
  unless Loam.Sha256.hash text.toUTF8 == ref.sha256 do
    throw <| IO.userError s!"selected object failed digest verification: {ref.path}"
  pure text

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

private def readCurrentTyped (root : System.FilePath) : IO TypedWorld := do
  let manifest ← loadManifest root
  let events ← loadReferenced root manifest.events
  let validity ← loadReferenced root manifest.validity
  let descriptions ← loadReferenced root manifest.descriptions
  let relations ← loadReferenced root manifest.relations
  let discharges ← loadReferenced root manifest.discharges
  requireSome (decodeWorld? { events, validity, descriptions, relations, discharges })
    "selected generation failed production typed decoding"

private def loadDirectWorld? (memoryFile : System.FilePath) : IO (Option TypedWorld) := do
  let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
  let descriptionFile := Loam.Persistence.eventDescriptionPathForEventMemory memoryFile
  let relationFile := Loam.Persistence.openRelationUnitPathForEventMemory memoryFile
  let dischargeFile := Loam.Persistence.relationDischargePathForEventMemory memoryFile
  if !(← memoryFile.pathExists) || !(← validityFile.pathExists) ||
      !(← descriptionFile.pathExists) || !(← relationFile.pathExists) ||
      !(← dischargeFile.pathExists) then
    return none
  return decodeWorld? {
    events := ← IO.FS.readFile memoryFile
    validity := ← IO.FS.readFile validityFile
    descriptions := ← IO.FS.readFile descriptionFile
    relations := ← IO.FS.readFile relationFile
    discharges := ← IO.FS.readFile dischargeFile
  }

private def prepareWorld
    (root : System.FilePath) (world : TypedWorld) : IO (Manifest × Nat) := do
  let bytes ← requireSome (encodeWorld? world) "production encoders rejected typed Movement world"
  let (events, reusedEvents) ← ensureObject root "Event" bytes.events
  let (validity, reusedValidity) ← ensureObject root "ActualValidity" bytes.validity
  let (descriptions, reusedDescriptions) ← ensureObject root "EventDescription" bytes.descriptions
  let (relations, reusedRelations) ← ensureObject root "RelationUnit" bytes.relations
  let (discharges, reusedDischarges) ← ensureObject root "RelationDischarge" bytes.discharges
  let manifest : Manifest := { events, validity, descriptions, relations, discharges }
  let reused := boolNat reusedEvents + boolNat reusedValidity + boolNat reusedDescriptions +
    boolNat reusedRelations + boolNat reusedDischarges
  pure (manifest, reused)

private def emptyWorld : IO TypedWorld := do
  let events ← requireSome (EventMemory.ofEvents? []) "empty Event memory failed construction"
  let validity ← requireSome
    (ActualValidityHistory.ofParts? ([] : List (ActualValidityFact String)) [])
    "empty ActualValidity history failed construction"
  pure {
    events := events
    validity := validity
    descriptions := EventDescriptionMemory.empty
    relations := []
    discharges := []
  }

private def writeWorldToSidecars
    (memoryFile : System.FilePath) (world : TypedWorld) : IO Unit := do
  let bytes ← requireSome (encodeWorld? world) "selected world failed production re-encoding"
  if let some parent := memoryFile.parent then
    IO.FS.createDirAll parent
  IO.FS.writeFile memoryFile bytes.events
  IO.FS.writeFile (Loam.Persistence.actualValidityPathForEventMemory memoryFile) bytes.validity
  IO.FS.writeFile (Loam.Persistence.eventDescriptionPathForEventMemory memoryFile) bytes.descriptions
  IO.FS.writeFile (Loam.Persistence.openRelationUnitPathForEventMemory memoryFile) bytes.relations
  IO.FS.writeFile (Loam.Persistence.relationDischargePathForEventMemory memoryFile) bytes.discharges

private def projection (world : TypedWorld) : Projection :=
  let effectCount := world.events.events.foldl (fun total event => total + event.effects.length) 0
  let outstanding :=
    (Loam.Application.relationOutstandingQuantity?
      world.events world.relations [] world.discharges ⟨"relation-1"⟩).map
      (fun quantity => quantity.quanta)
  {
    eventCount := world.events.events.length
    effectCount := effectCount
    paypay := (EventMemory.quantityAtRecorded world.events ⟨"paypay"⟩ ⟨"jpy"⟩).quanta
    travel := (EventMemory.quantityAtRecorded world.events ⟨"travel"⟩ ⟨"jpy"⟩).quanta
    friendIn := (EventMemory.quantityAtRecorded world.events ⟨"friend-in"⟩ ⟨"jpy"⟩).quanta
    relationCount := world.relations.length
    dischargeCount := world.discharges.length
    relationOutstanding := outstanding
  }

private def printProjection (value : Projection) : IO Unit := do
  IO.println s!"event_count={value.eventCount}"
  IO.println s!"effect_count={value.effectCount}"
  IO.println s!"recorded_paypay={value.paypay}"
  IO.println s!"recorded_travel={value.travel}"
  IO.println s!"recorded_friend_in={value.friendIn}"
  IO.println s!"relation_count={value.relationCount}"
  IO.println s!"discharge_count={value.dischargeCount}"
  match value.relationOutstanding with
  | some quantity => IO.println s!"relation_outstanding={quantity}"
  | none => IO.println "relation_outstanding=NONE"

private def runSeed (rootPath : String) : IO UInt32 := do
  let root := System.FilePath.mk rootPath
  if ← root.pathExists then
    IO.FS.removeDirAll root
  IO.FS.createDirAll root
  let world ← emptyWorld
  let (manifest, _) ← prepareWorld root world
  publishManifest root manifest
  IO.println "Application 032 empty selected generation seeded"
  return 0

private def runMaterialize (rootPath memoryPath : String) : IO UInt32 := do
  let root := System.FilePath.mk rootPath
  let memoryFile := System.FilePath.mk memoryPath
  let world ← readCurrentTyped root
  writeWorldToSidecars memoryFile world
  IO.println "Application 032 selected generation materialized as non-authoritative staging"
  return 0

private def runPrepare (memoryPath rootPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let root := System.FilePath.mk rootPath
  let world ← requireSome (← loadDirectWorld? memoryFile)
    "staging Movement sidecars could not be loaded as one typed world"
  let (manifest, reused) ← prepareWorld root world
  writeCandidate root manifest
  IO.println "Application 032 candidate object preparation PASS"
  IO.println s!"reused_objects={reused}"
  IO.println "authority_switches=0"
  return 0

private def runCommit (rootPath : String) : IO UInt32 := do
  let root := System.FilePath.mk rootPath
  let manifest ← readCandidate root
  publishManifest root manifest
  IO.println "Application 032 CURRENT authority switch PASS"
  IO.println "authority_switches=1"
  return 0

private def runVerify (rootPath : String) : IO UInt32 := do
  let world ← readCurrentTyped (System.FilePath.mk rootPath)
  IO.println "Application 032 generation-scoped typed read PASS"
  printProjection (projection world)
  return 0

private def runCompare (memoryPath rootPath : String) : IO UInt32 := do
  let direct ← requireSome (← loadDirectWorld? (System.FilePath.mk memoryPath))
    "staging Movement world disappeared before parity comparison"
  let selected ← readCurrentTyped (System.FilePath.mk rootPath)
  let directBytes ← requireSome (encodeWorld? direct) "staging world failed production encoding"
  let selectedBytes ← requireSome (encodeWorld? selected) "selected world failed production encoding"
  expect (directBytes == selectedBytes) "selected generation changed canonical family bytes"
  expect (projection direct == projection selected) "selected generation changed household projection"
  IO.println "Application 032 staging/manifest parity PASS"
  IO.println "canonical_family_byte_matches=5"
  IO.println "semantic_projection_match=1"
  return 0

end Loam.Application032

def main (args : List String) : IO UInt32 :=
  match args with
  | ["seed", rootPath] => Loam.Application032.runSeed rootPath
  | ["materialize", rootPath, memoryPath] =>
      Loam.Application032.runMaterialize rootPath memoryPath
  | ["prepare", memoryPath, rootPath] =>
      Loam.Application032.runPrepare memoryPath rootPath
  | ["commit", rootPath] => Loam.Application032.runCommit rootPath
  | ["verify", rootPath] => Loam.Application032.runVerify rootPath
  | ["compare", memoryPath, rootPath] =>
      Loam.Application032.runCompare memoryPath rootPath
  | _ => do
      IO.eprintln "Usage: application_032_complete_movement_manifest_mutation (seed ROOT | materialize ROOT MEMORY | prepare MEMORY ROOT | commit ROOT | verify ROOT | compare MEMORY ROOT)"
      return 2
