import Loam.MovementManifestAuthority

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def emptyWorldWithLoci
    (locusTokens : List String) : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? []
    | throw (IO.userError "empty Event memory")
  let loci := locusTokens.map fun token => (⟨token⟩ : LocusId)
  let some locusAdmission := LocusAdmissionVocabulary.ofLoci? loci
    | throw (IO.userError "fixture Locus vocabulary contains duplicate identities")
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
  let text ← IO.FS.readFile (root / "CURRENT")
  let some row := (text.splitOn "\n").find? (fun row => row.startsWith "LocusAdmission\t")
    | return none
  match row.splitOn "\t" with
  | ["LocusAdmission", relative, _digest] => return some (root / relative)
  | _ => return none

private def verifyPolicyIndependentRead
    (root : System.FilePath)
    (world : Loam.MovementAdmission.World) : IO Unit := do
  let some policyPath ← locusPolicyObjectPath? root
    | throw (IO.userError "selected Movement fixture lacks a LocusAdmission reference")
  let hiddenPath := System.FilePath.mk (policyPath.toString ++ ".hidden")
  if ← hiddenPath.pathExists then IO.FS.removeFile hiddenPath
  IO.FS.rename policyPath hiddenPath

  let evidenceResult ← Loam.MovementManifestAuthority.loadSelectedEvidence? root
  let fullWorldResult ← Loam.MovementManifestAuthority.loadSelectedWorld? root

  IO.FS.rename hiddenPath policyPath

  let .ok evidence := evidenceResult
    | throw (IO.userError "policy-only object failure made household Movement evidence unavailable")
  expect (!fullWorldResult.isOk)
    "policy-only object failure did not keep policy-inclusive Movement state fail-closed"
  expect (Loam.Persistence.encodeEventMemory? evidence.events ==
      Loam.Persistence.encodeEventMemory? world.events)
    "policy-only failure changed Event evidence"
  expect (Loam.Persistence.encodeActualValidityHistory? evidence.validity ==
      Loam.Persistence.encodeActualValidityHistory? world.validity)
    "policy-only failure changed ActualValidity evidence"
  expect (Loam.Persistence.encodeEventDescriptionMemory? evidence.descriptions ==
      Loam.Persistence.encodeEventDescriptionMemory? world.descriptions)
    "policy-only failure changed EventDescription evidence"
  expect (Loam.Persistence.encodeOpenRelationUnits? evidence.relations ==
      Loam.Persistence.encodeOpenRelationUnits? world.relations)
    "policy-only failure changed RelationUnit evidence"
  expect (Loam.Persistence.encodeRelationDischarges? evidence.discharges ==
      Loam.Persistence.encodeRelationDischarges? world.discharges)
    "policy-only failure changed RelationDischarge evidence"
  let .ok _ ← Loam.MovementManifestAuthority.loadSelectedWorld? root
    | throw (IO.userError "restored LocusAdmission object did not restore the full Movement world")

def main (args : List String) : IO Unit := do
  let rootPath :: locusTokens := args
    | throw (IO.userError "supply Movement manifest root, optionally followed by admitted Locus tokens")
  let world ← emptyWorldWithLoci locusTokens
  let root := System.FilePath.mk rootPath
  match ← Loam.MovementManifestAuthority.publishWorld? root world with
  | .ok _ =>
      verifyPolicyIndependentRead root world
      IO.println "Empty Movement manifest fixture published."
  | .error message =>
      throw (IO.userError message)
