import Loam.Application.RelationDischargeFrontier
import Loam.MovementAdmission
import Loam.MovementManifestAuthority
import Loam.Persistence
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Persistence.OpenRelationPersistence
import Loam.Persistence.RelationDischargePersistence
import Std

namespace Loam.Application035

open Loam.Core

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private def requireOk {α : Type} (value : Except String α) : IO α :=
  match value with
  | Except.ok result => pure result
  | Except.error message => throw <| IO.userError message

private def emptyWorld : IO Loam.MovementAdmission.World := do
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

private def effect (key locus : String) (quanta : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ ⟨locus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quanta)

private def firstDraft : Loam.MovementAdmission.Draft := {
  validOn := "2026-09-05"
  description := some "manifest source movement"
  effects := [
    effect "effect-1" "paypay" (-100),
    effect "effect-2" "travel" 100
  ]
  relations := [{
    sourceEffect := ⟨"effect-1"⟩
    debtor := .external ⟨"friend"⟩
    creditor := .household
    quantity := Quantity.ofQuanta 100
  }]
  discharges := []
  total := 100
}

private def runSeedEmpty (rootPath : String) : IO UInt32 := do
  let root := System.FilePath.mk rootPath
  if ← root.pathExists then
    IO.FS.removeDirAll root
  let world ← emptyWorld
  let _ ← requireOk (← Loam.MovementManifestAuthority.publishWorld? root world)
  let selected ← requireOk (← Loam.MovementManifestAuthority.loadSelectedWorld? root)
  expect (selected.events.events.length == 0) "seeded selected world was not empty"
  IO.println "Application 035 empty Movement manifest seed PASS"
  IO.println "selected_authority_switches=1"
  return 0

private def runRetryProbe (rootPath : String) : IO UInt32 := do
  let root := System.FilePath.mk rootPath
  let before ← requireOk (← Loam.MovementManifestAuthority.loadSelectedWorld? root)
  expect (before.events.events.length == 0) "retry probe requires empty selected authority"
  let admittedFirst ← requireOk (Loam.MovementAdmission.admit? before firstDraft)
  let preparedFirst ← requireOk
    (← Loam.MovementManifestAuthority.prepareWorld? root admittedFirst.world)

  let selectedAfterPrepare ← requireOk (← Loam.MovementManifestAuthority.loadSelectedWorld? root)
  expect (selectedAfterPrepare.events.events.length == 0)
    "off-authority prepare changed selected Movement generation"

  let admittedRetry ← requireOk (Loam.MovementAdmission.admit? selectedAfterPrepare firstDraft)
  expect (admittedRetry.event.id.token == admittedFirst.event.id.token)
    "orphan prepared object reserved Event identity"
  let preparedRetry ← requireOk
    (← Loam.MovementManifestAuthority.prepareWorld? root admittedRetry.world)
  expect (preparedRetry.reusedObjects == 5)
    "retry did not reuse all five prepared Movement objects"
  let _ ← requireOk (← Loam.MovementManifestAuthority.commitPrepared? root preparedRetry)
  let selected ← requireOk (← Loam.MovementManifestAuthority.loadSelectedWorld? root)
  expect (selected.events.events.length == 1) "retry commit did not select one Event"
  IO.println "Application 035 interrupted production-tail retry PASS"
  IO.println s!"event={admittedRetry.event.id.token}"
  IO.println s!"retry_reused_prepared_objects={preparedRetry.reusedObjects}"
  IO.println "interrupted_candidate_authority_changes=0"
  IO.println "orphan_event_id_reservations=0"
  IO.println "manifest_partial_authority_prefixes=0"
  return 0

private def runVerifyTwo (rootPath : String) : IO UInt32 := do
  let world ← requireOk
    (← Loam.MovementManifestAuthority.loadSelectedWorld? (System.FilePath.mk rootPath))
  let effectCount := world.events.events.foldl (fun total event => total + event.effects.length) 0
  let outstanding :=
    (Loam.Application.relationOutstandingQuantity?
      world.events world.relations [] world.discharges ⟨"relation-1"⟩).map
      (fun quantity => quantity.quanta)
  expect (world.events.events.length == 2) "selected manifest did not contain two Events"
  expect (effectCount == 4) "selected manifest did not contain four Effects"
  expect ((EventMemory.quantityAtRecorded world.events ⟨"paypay"⟩ ⟨"jpy"⟩).quanta == -60)
    "selected manifest changed paypay projection"
  expect ((EventMemory.quantityAtRecorded world.events ⟨"travel"⟩ ⟨"jpy"⟩).quanta == 100)
    "selected manifest changed travel projection"
  expect ((EventMemory.quantityAtRecorded world.events ⟨"friend-in"⟩ ⟨"jpy"⟩).quanta == -40)
    "selected manifest changed friend-in projection"
  expect (world.relations.length == 1) "selected manifest relation count changed"
  expect (world.discharges.length == 1) "selected manifest discharge count changed"
  expect (outstanding == some 60) "selected manifest relation outstanding changed"
  IO.println "Application 035 production loamMovement manifest projection PASS"
  IO.println "event_count=2"
  IO.println "effect_count=4"
  IO.println "recorded_paypay=-60"
  IO.println "recorded_travel=100"
  IO.println "recorded_friend_in=-40"
  IO.println "relation_count=1"
  IO.println "discharge_count=1"
  IO.println "relation_outstanding=60"
  return 0

private def runDump (rootPath outPath : String) : IO UInt32 := do
  let root := System.FilePath.mk rootPath
  let out := System.FilePath.mk outPath
  let world ← requireOk (← Loam.MovementManifestAuthority.loadSelectedWorld? root)
  let events ← requireSome (Loam.Persistence.encodeEventMemory? world.events)
    "Event encoder rejected selected manifest world"
  let validity ← requireSome (Loam.Persistence.encodeActualValidityHistory? world.validity)
    "ActualValidity encoder rejected selected manifest world"
  let descriptions ← requireSome (Loam.Persistence.encodeEventDescriptionMemory? world.descriptions)
    "EventDescription encoder rejected selected manifest world"
  let relations ← requireSome (Loam.Persistence.encodeOpenRelationUnits? world.relations)
    "RelationUnit encoder rejected selected manifest world"
  let discharges ← requireSome (Loam.Persistence.encodeRelationDischarges? world.discharges)
    "RelationDischarge encoder rejected selected manifest world"
  IO.FS.createDirAll out
  IO.FS.writeFile (out / "Event.loam") events
  IO.FS.writeFile (out / "ActualValidity.loam") validity
  IO.FS.writeFile (out / "EventDescription.loam") descriptions
  IO.FS.writeFile (out / "RelationUnit.loam") relations
  IO.FS.writeFile (out / "RelationDischarge.loam") discharges
  IO.println "Application 035 selected canonical family dump PASS"
  IO.println "canonical_families=5"
  return 0

end Loam.Application035

def main (args : List String) : IO UInt32 :=
  match args with
  | ["seed-empty", rootPath] => Loam.Application035.runSeedEmpty rootPath
  | ["retry-probe", rootPath] => Loam.Application035.runRetryProbe rootPath
  | ["verify-two", rootPath] => Loam.Application035.runVerifyTwo rootPath
  | ["dump", rootPath, outPath] => Loam.Application035.runDump rootPath outPath
  | _ => do
      IO.eprintln "usage: application_035_production_movement_manifest_tail.lean seed-empty ROOT | retry-probe ROOT | verify-two ROOT | dump ROOT OUT"
      return 2
