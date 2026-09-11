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
      factRefNodup := by simp
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

private def expectEvidenceMatches
    (evidence : Loam.MovementManifestAuthority.EvidenceWorld)
    (world : Loam.MovementAdmission.World)
    (context : String) : IO Unit := do
  expect (Loam.Persistence.encodeEventMemory? evidence.events ==
      Loam.Persistence.encodeEventMemory? world.events)
    (context ++ " changed Event evidence")
  expect (Loam.Persistence.encodeActualValidityHistory? evidence.validity ==
      Loam.Persistence.encodeActualValidityHistory? world.validity)
    (context ++ " changed ActualValidity evidence")
  expect (Loam.Persistence.encodeEventDescriptionMemory? evidence.descriptions ==
      Loam.Persistence.encodeEventDescriptionMemory? world.descriptions)
    (context ++ " changed EventDescription evidence")
  expect (Loam.Persistence.encodeOpenRelationUnits? evidence.relations ==
      Loam.Persistence.encodeOpenRelationUnits? world.relations)
    (context ++ " changed RelationUnit evidence")
  expect (Loam.Persistence.encodeRelationDischarges? evidence.discharges ==
      Loam.Persistence.encodeRelationDischarges? world.discharges)
    (context ++ " changed RelationDischarge evidence")

private def verifyPolicyObjectIndependentRead
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
  expectEvidenceMatches evidence world "policy-only object failure"
  let .ok _ ← Loam.MovementManifestAuthority.loadSelectedWorld? root
    | throw (IO.userError "restored LocusAdmission object did not restore the full Movement world")

private def verifyPolicyRowIndependentRead
    (root : System.FilePath)
    (world : Loam.MovementAdmission.World) : IO Unit := do
  let current := root / "CURRENT"
  let original ← IO.FS.readFile current
  let malformed ←
    match original.splitOn "\n" with
    | [header, eventRow, validityRow, descriptionRow, relationRow, dischargeRow,
        _policyRow, trailing] =>
        pure (String.intercalate "\n" [
          header,
          eventRow,
          validityRow,
          descriptionRow,
          relationRow,
          dischargeRow,
          "malformed-policy-row",
          trailing
        ])
    | _ => throw (IO.userError "selected Movement fixture is not a version-2 manifest")
  IO.FS.writeFile current malformed

  let evidenceResult ← Loam.MovementManifestAuthority.loadSelectedEvidence? root
  let fullWorldResult ← Loam.MovementManifestAuthority.loadSelectedWorld? root

  IO.FS.writeFile current original

  let .ok evidence := evidenceResult
    | throw (IO.userError "policy-row failure made household Movement evidence unavailable")
  expect (!fullWorldResult.isOk)
    "policy-row failure did not keep policy-inclusive Movement state fail-closed"
  expectEvidenceMatches evidence world "policy-row failure"
  let .ok _ ← Loam.MovementManifestAuthority.loadSelectedWorld? root
    | throw (IO.userError "restored LocusAdmission row did not restore the full Movement world")

def main (args : List String) : IO Unit := do
  let rootPath :: locusTokens := args
    | throw (IO.userError "supply Movement manifest root, optionally followed by admitted Locus tokens")
  let world ← emptyWorldWithLoci locusTokens
  let root := System.FilePath.mk rootPath
  match ← Loam.MovementManifestAuthority.publishWorld? root world with
  | .ok _ =>
      verifyPolicyObjectIndependentRead root world
      verifyPolicyRowIndependentRead root world
      IO.println "Empty Movement manifest fixture published."
  | .error message =>
      throw (IO.userError message)