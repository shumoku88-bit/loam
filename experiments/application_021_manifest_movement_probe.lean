import Loam.Persistence
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Persistence.OpenRelationPersistence
import Loam.Persistence.RelationDischargePersistence
import Loam.Sha256
import Std

namespace Loam.Application021

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
  routing : FamilyRef
  deriving Repr, BEq

private structure MovementImages where
  events : String
  validity : String
  descriptions : String
  relations : String
  discharges : String
  deriving Repr, BEq

private def manifestHeader : String := "LOAM-GENERATION-MANIFEST\t1"

private def manifestRow (name : String) (ref : FamilyRef) : String :=
  name ++ "\t" ++ ref.path ++ "\t" ++ ref.sha256

private def encodeManifest (manifest : Manifest) : String :=
  String.intercalate "\n" [
    manifestHeader,
    manifestRow "Event" manifest.events,
    manifestRow "ActualValidity" manifest.validity,
    manifestRow "EventDescription" manifest.descriptions,
    manifestRow "RelationUnit" manifest.relations,
    manifestRow "RelationDischarge" manifest.discharges,
    manifestRow "ActualRouting" manifest.routing
  ] ++ "\n"

private def decodeManifestRow? (expected row : String) : Option FamilyRef :=
  match row.splitOn "\t" with
  | [name, path, digest] =>
      if name == expected && !path.isEmpty && digest.length == 64 then
        some { path := path, sha256 := digest }
      else
        none
  | _ => none

private def decodeManifest? (input : String) : Option Manifest :=
  match input.splitOn "\n" with
  | [header, eventRow, validityRow, descriptionRow, relationRow,
      dischargeRow, routingRow, trailing] =>
      if header != manifestHeader || trailing != "" then
        none
      else do
        let events ← decodeManifestRow? "Event" eventRow
        let validity ← decodeManifestRow? "ActualValidity" validityRow
        let descriptions ← decodeManifestRow? "EventDescription" descriptionRow
        let relations ← decodeManifestRow? "RelationUnit" relationRow
        let discharges ← decodeManifestRow? "RelationDischarge" dischargeRow
        let routing ← decodeManifestRow? "ActualRouting" routingRow
        some {
          events := events
          validity := validity
          descriptions := descriptions
          relations := relations
          discharges := discharges
          routing := routing
        }
  | _ => none

private def objectRelativePath (family digest : String) : String :=
  "objects/" ++ family ++ "/" ++ digest ++ ".loam"

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
  decodeManifest? <$> IO.FS.readFile target

private def loadReferenced? (root : System.FilePath) (ref : FamilyRef) : IO (Option String) := do
  let target := root / ref.path
  if !(← target.pathExists) then
    return none
  let text ← IO.FS.readFile target
  if Loam.Sha256.hash text.toUTF8 == ref.sha256 then
    return some text
  else
    return none

private def canonicalizeMovement? (images : MovementImages) : Option MovementImages := do
  let events ← Loam.Persistence.decodeEventMemory? images.events
  let validity ← Loam.Persistence.decodeActualValidityHistory? images.validity
  let descriptions ← Loam.Persistence.decodeEventDescriptionMemory? images.descriptions
  let relations ← Loam.Persistence.decodeOpenRelationUnits? images.relations
  let discharges ← Loam.Persistence.decodeRelationDischarges? images.discharges
  let eventText ← Loam.Persistence.encodeEventMemory? events
  let validityText ← Loam.Persistence.encodeActualValidityHistory? validity
  let descriptionText ← Loam.Persistence.encodeEventDescriptionMemory? descriptions
  let relationText ← Loam.Persistence.encodeOpenRelationUnits? relations
  let dischargeText ← Loam.Persistence.encodeRelationDischarges? discharges
  some {
    events := eventText
    validity := validityText
    descriptions := descriptionText
    relations := relationText
    discharges := dischargeText
  }

-- APPLICATION021_PUBLISH_START
private def publishAdmittedMovement
    (root : System.FilePath)
    (current : Manifest)
    (images : MovementImages) : IO Manifest := do
  let events ← ensureObject root "event" images.events
  let validity ← ensureObject root "actual-validity" images.validity
  let descriptions ← ensureObject root "event-description" images.descriptions
  let relations ← ensureObject root "relation-unit" images.relations
  let discharges ← ensureObject root "relation-discharge" images.discharges
  let next : Manifest := {
    events := events
    validity := validity
    descriptions := descriptions
    relations := relations
    discharges := discharges
    routing := current.routing
  }
  publishManifest root next
  pure next
-- APPLICATION021_PUBLISH_END

private def fixture : MovementImages := {
  events :=
    "LOAM-EVENT-MEMORY\t1\n" ++
    "EVENT\trecord-2\n" ++
    "EFFECT\teffect-from\twallet\tjpy\t-500\n" ++
    "EFFECT\teffect-to\tmerchant\tjpy\t500\n"
  validity :=
    "LOAM-ACTUAL-VALIDITY-HISTORY\t2\n" ++
    "BASE\trecord-2\t2026-09-05\n"
  descriptions :=
    "LOAM-EVENT-DESCRIPTION-MEMORY\t1\n" ++
    "DESC\trecord-2\tpublic manifest movement\n"
  relations :=
    "LOAM-RELATION-UNIT-MEMORY\t1\n" ++
    "RELATION\trelation-2\trecord-2\teffect-to\tE\tfriend-public\tH\t\t500\n"
  discharges :=
    "LOAM-RELATION-DISCHARGE-MEMORY\t1\n" ++
    "DISCHARGE\trecord-2\trelation-1\t250\n"
}

private def seedManifest (root : System.FilePath) : IO Manifest := do
  let events ← ensureObject root "event" "old-event-image\n"
  let validity ← ensureObject root "actual-validity" "old-validity-image\n"
  let descriptions ← ensureObject root "event-description" "old-description-image\n"
  let relations ← ensureObject root "relation-unit" "old-relation-image\n"
  let discharges ← ensureObject root "relation-discharge" "old-discharge-image\n"
  let routing ← ensureObject root "actual-routing" "routing-generation-1\n"
  let manifest : Manifest := {
    events := events
    validity := validity
    descriptions := descriptions
    relations := relations
    discharges := discharges
    routing := routing
  }
  publishManifest root manifest
  pure manifest

private def everyOldRefStillExists (root : System.FilePath) (manifest : Manifest) : IO Bool := do
  let refs := [manifest.events, manifest.validity, manifest.descriptions,
    manifest.relations, manifest.discharges, manifest.routing]
  let mut allPresent := true
  for ref in refs do
    if !(← (root / ref.path).pathExists) then
      allPresent := false
  pure allPresent

def main : IO Unit := do
  let root := System.FilePath.mk "scratch/application-021-manifest-movement"
  if ← root.pathExists then
    IO.FS.removeDirAll root
  IO.FS.createDirAll root

  let initial ← seedManifest root
  let canonical ← requireSome (canonicalizeMovement? fixture)
    "Movement fixture was not accepted by production persistence codecs"
  expect (canonical == fixture)
    "Production codecs changed the scratch Movement fixture"

  let published ← publishAdmittedMovement root initial canonical
  let selected ← requireSome (← loadManifest? root)
    "Published CURRENT manifest could not be loaded"
  expect (selected == published)
    "Reader did not select the newly published generation"
  expect (selected.routing == initial.routing)
    "Movement publication rewrote the unchanged ActualRouting reference"
  expect
    (selected.events != initial.events && selected.validity != initial.validity &&
      selected.descriptions != initial.descriptions && selected.relations != initial.relations &&
      selected.discharges != initial.discharges)
    "Movement publication failed to replace all five changed family references"

  expect ((← loadReferenced? root selected.events) == some canonical.events)
    "Selected Event image failed digest-checked read"
  expect ((← loadReferenced? root selected.validity) == some canonical.validity)
    "Selected ActualValidity image failed digest-checked read"
  expect ((← loadReferenced? root selected.descriptions) == some canonical.descriptions)
    "Selected EventDescription image failed digest-checked read"
  expect ((← loadReferenced? root selected.relations) == some canonical.relations)
    "Selected RelationUnit image failed digest-checked read"
  expect ((← loadReferenced? root selected.discharges) == some canonical.discharges)
    "Selected RelationDischarge image failed digest-checked read"
  expect ((← loadReferenced? root selected.routing) == some "routing-generation-1\n")
    "Unchanged ActualRouting image was not reused"
  expect (← everyOldRefStillExists root initial)
    "Publication deleted an older immutable family image"

  IO.FS.removeDirAll root
  IO.println "Application 021 manifest Movement probe PASS"
  IO.println "changed_family_objects=5"
  IO.println "authority_switches=1"
  IO.println "unchanged_routing_rewrites=0"

end Loam.Application021
