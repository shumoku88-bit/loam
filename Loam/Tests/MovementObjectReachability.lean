import Loam.MovementManifestAuthority
import Loam.MovementObjectReachability

open Loam.Core

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def worldWith (tokens : List String) : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? [] | throw (IO.userError "empty events")
  let loci := tokens.map fun token => (⟨token⟩ : LocusId)
  let some vocabulary := LocusAdmissionVocabulary.ofLoci? loci
    | throw (IO.userError "Locus admission vocabulary")
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
    locusAdmission := vocabulary }

private def orphanDigest : String :=
  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

private def orphanRelative : String :=
  "objects/Event/" ++ orphanDigest ++ ".loam"

def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated manifest root")
  let root := System.FilePath.mk rootPath
  let firstWorld ← worldWith ["cash"]
  let secondWorld ← worldWith ["cash", "bank"]

  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root firstWorld
    | throw (IO.userError "publish first Movement generation")
  let .ok firstAudit ← Loam.MovementObjectReachability.inspect root
    | throw (IO.userError "inspect first Movement generation")
  expect (firstAudit.current.length == 6) "first CURRENT did not root six Movement objects"
  expect (firstAudit.recoveryManifests == 0) "first generation unexpectedly had recovery roots"
  expect firstAudit.orphan.isEmpty "first generation produced an orphan object"

  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root secondWorld
    | throw (IO.userError "publish second Movement generation")
  let .ok retainedAudit ← Loam.MovementObjectReachability.inspect root
    | throw (IO.userError "inspect retained Movement generation")
  expect (retainedAudit.current.length == 6) "second CURRENT did not root six Movement objects"
  expect (retainedAudit.recoveryManifests == 1) "pre-switch CURRENT was not counted as one recovery root"
  expect (retainedAudit.recoveryOnly.length == 1) "recovery-only LocusAdmission object was not retained"
  expect retainedAudit.orphan.isEmpty "recovery-retained object was misclassified as orphan"

  let orphanPath := root / orphanRelative
  IO.FS.writeFile orphanPath "unreferenced-object\n"
  let .ok orphanAudit ← Loam.MovementObjectReachability.inspect root
    | throw (IO.userError "inspect injected orphan")
  expect (orphanAudit.orphan.contains orphanRelative) "unreferenced object was not classified as orphan"

  let recoveryDir := root / "recovery" / "manifests"
  let entries ← recoveryDir.readDir
  let recoveryEntry ←
    match entries.toList with
    | [entry] => pure entry
    | _ => throw (IO.userError "expected exactly one recovery manifest")
  IO.FS.writeFile recoveryEntry.path "tampered-recovery\n"
  let refused ← Loam.MovementObjectReachability.inspect root
  expect (!refused.isOk) "tampered recovery manifest was ignored by reachability audit"

  IO.println "Movement object reachability: CURRENT + verified recovery roots preserve objects; unreferenced objects remain read-only orphans."
