import Loam.MovementManifestAuthority

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def fixtureWorld : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? []
    | throw (IO.userError "empty Event memory")
  let some locusAdmission := LocusAdmissionVocabulary.ofLoci? [⟨"cash"⟩]
    | throw (IO.userError "fixture Locus vocabulary")
  return {
    events := events
    validity := {
      facts := []
      factIdNodup := by simp
      corrections := []
      correctionIdNodup := by simp }
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := locusAdmission }

private def locusPolicyObjectPath?
    (root : System.FilePath) : IO (Option System.FilePath) := do
  let current := root / "CURRENT"
  let text ← IO.FS.readFile current
  let some row := (text.splitOn "\n").find? (fun row => row.startsWith "LocusAdmission\t")
    | return none
  match row.splitOn "\t" with
  | ["LocusAdmission", relative, _digest] => return some (root / relative)
  | _ => return none

def main (args : List String) : IO Unit := do
  let [rootPath] := args
    | throw (IO.userError "supply isolated Movement manifest root")
  let root := System.FilePath.mk rootPath
  let world ← fixtureWorld
  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root world
    | throw (IO.userError "publish Movement fixture")

  let .ok beforeEvidence ← Loam.MovementManifestAuthority.loadSelectedEvidence? root
    | throw (IO.userError "selected household evidence was not readable before policy failure")
  let .ok _ ← Loam.MovementManifestAuthority.loadSelectedWorld? root
    | throw (IO.userError "selected full Movement world was not readable before policy failure")

  let some policyPath ← locusPolicyObjectPath? root
    | throw (IO.userError "selected manifest did not expose its LocusAdmission object")
  let hiddenPath := System.FilePath.mk (policyPath.toString ++ ".hidden")
  if ← hiddenPath.pathExists then IO.FS.removeFile hiddenPath
  IO.FS.rename policyPath hiddenPath

  let evidenceAfterFailure ← Loam.MovementManifestAuthority.loadSelectedEvidence? root
  let worldAfterFailure ← Loam.MovementManifestAuthority.loadSelectedWorld? root
  expect evidenceAfterFailure.isOk
    "policy-only object failure made household Movement evidence unavailable"
  expect (!worldAfterFailure.isOk)
    "policy-only object failure did not keep quantity-bearing writes fail-closed"

  let .ok afterEvidence := evidenceAfterFailure
    | throw (IO.userError "unreachable evidence failure")
  expect (Loam.Persistence.encodeEventMemory? afterEvidence.events ==
      Loam.Persistence.encodeEventMemory? beforeEvidence.events)
    "policy-only failure changed selected Event evidence"
  expect (Loam.Persistence.encodeActualValidityHistory? afterEvidence.validity ==
      Loam.Persistence.encodeActualValidityHistory? beforeEvidence.validity)
    "policy-only failure changed selected ActualValidity evidence"
  expect (Loam.Persistence.encodeEventDescriptionMemory? afterEvidence.descriptions ==
      Loam.Persistence.encodeEventDescriptionMemory? beforeEvidence.descriptions)
    "policy-only failure changed selected EventDescription evidence"
  expect (Loam.Persistence.encodeOpenRelationUnits? afterEvidence.relations ==
      Loam.Persistence.encodeOpenRelationUnits? beforeEvidence.relations)
    "policy-only failure changed selected RelationUnit evidence"
  expect (Loam.Persistence.encodeRelationDischarges? afterEvidence.discharges ==
      Loam.Persistence.encodeRelationDischarges? beforeEvidence.discharges)
    "policy-only failure changed selected RelationDischarge evidence"

  IO.FS.rename hiddenPath policyPath
  let .ok _ ← Loam.MovementManifestAuthority.loadSelectedWorld? root
    | throw (IO.userError "restored policy object did not restore the full Movement world")

  IO.println "Movement evidence availability: policy-only failure preserves reads and closes writes."
