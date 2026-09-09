import Loam.MovementManifestAuthority
import Loam.Sha256

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

def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated manifest root")
  let root := System.FilePath.mk rootPath
  let firstWorld ← worldWith ["cash"]
  let secondWorld ← worldWith ["cash", "bank"]

  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root firstWorld
    | throw (IO.userError "publish first Movement generation")
  let firstText ← IO.FS.readFile (root / "CURRENT")
  let firstDigest := Loam.Sha256.hash firstText.toUTF8
  let recoveryPath := root / "recovery" / "manifests" / (firstDigest ++ ".loam")
  expect (!(← recoveryPath.pathExists))
    "first generation was retained before any authority switch"

  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root secondWorld
    | throw (IO.userError "publish second Movement generation")
  expect (← recoveryPath.pathExists)
    "validated pre-switch CURRENT was not retained"
  expect ((← IO.FS.readFile recoveryPath) == firstText)
    "recovery candidate did not preserve exact CURRENT bytes"

  let secondText ← IO.FS.readFile (root / "CURRENT")
  expect (secondText != firstText)
    "second generation did not become CURRENT"
  let .ok selected ← Loam.MovementManifestAuthority.loadSelectedWorld? root
    | throw (IO.userError "load selected second generation")
  expect (selected.locusAdmission.approved.length == 2)
    "recovery candidate interfered with selected authority"

  IO.FS.writeFile (root / "CURRENT") "broken-current\n"
  let refused ← Loam.MovementManifestAuthority.publishWorld? root firstWorld
  expect (!refused.isOk)
    "malformed existing CURRENT was overwritten instead of failing closed"
  expect ((← IO.FS.readFile (root / "CURRENT")) == "broken-current\n")
    "failed recovery-retention preflight changed malformed CURRENT"

  IO.println "Movement recovery retention: validated pre-switch manifest retained off authority."
