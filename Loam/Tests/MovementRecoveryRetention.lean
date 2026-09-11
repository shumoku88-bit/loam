import Loam.MovementManifestAuthority
import Loam.MovementRecoveryPublisher
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
      factRefNodup := by simp
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
  let firstRecoveryPath := root / "recovery" / "manifests" / (firstDigest ++ ".loam")
  expect (!(← firstRecoveryPath.pathExists))
    "first generation was retained before any authority switch"

  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root secondWorld
    | throw (IO.userError "publish second Movement generation")
  expect (← firstRecoveryPath.pathExists)
    "validated pre-switch CURRENT was not retained"
  expect ((← IO.FS.readFile firstRecoveryPath) == firstText)
    "recovery candidate did not preserve exact CURRENT bytes"

  let secondText ← IO.FS.readFile (root / "CURRENT")
  let secondDigest := Loam.Sha256.hash secondText.toUTF8
  let secondRecoveryPath := root / "recovery" / "manifests" / (secondDigest ++ ".loam")
  expect (secondText != firstText)
    "second generation did not become CURRENT"
  let .ok selectedSecond ← Loam.MovementManifestAuthority.loadSelectedWorld? root
    | throw (IO.userError "load selected second generation")
  expect (selectedSecond.locusAdmission.approved.length == 2)
    "recovery candidate interfered with selected authority"

  let .ok () ← Loam.MovementRecoveryPublisher.restore root.toString firstDigest
    | throw (IO.userError "restore first verified recovery generation")
  expect ((← IO.FS.readFile (root / "CURRENT")) == firstText)
    "explicit recovery did not select the requested retained manifest"
  expect (← secondRecoveryPath.pathExists)
    "explicit recovery did not retain the previously valid CURRENT for reversal"
  let .ok selectedFirst ← Loam.MovementManifestAuthority.loadSelectedWorld? root
    | throw (IO.userError "load restored first generation")
  expect (selectedFirst.locusAdmission.approved.length == 1)
    "restored generation did not recover its typed household world"

  let brokenCurrent := "broken-current\n"
  let brokenDigest := Loam.Sha256.hash brokenCurrent.toUTF8
  let failedCurrentPath := root / "recovery" / "failed-current" / (brokenDigest ++ ".loam")
  IO.FS.writeFile (root / "CURRENT") brokenCurrent
  let refusedPublish ← Loam.MovementManifestAuthority.publishWorld? root secondWorld
  expect (!refusedPublish.isOk)
    "malformed existing CURRENT was overwritten by ordinary publication"
  expect ((← IO.FS.readFile (root / "CURRENT")) == brokenCurrent)
    "failed ordinary publication changed malformed CURRENT"

  let .ok () ← Loam.MovementRecoveryPublisher.restore root.toString secondDigest
    | throw (IO.userError "recover from malformed CURRENT")
  expect ((← IO.FS.readFile (root / "CURRENT")) == secondText)
    "verified recovery did not replace malformed CURRENT"
  expect (← failedCurrentPath.pathExists)
    "malformed CURRENT bytes were not preserved as diagnostic evidence"
  expect ((← IO.FS.readFile failedCurrentPath) == brokenCurrent)
    "failed-current diagnostic evidence changed bytes"
  let .ok recoveredSecond ← Loam.MovementManifestAuthority.loadSelectedWorld? root
    | throw (IO.userError "load recovered second generation")
  expect (recoveredSecond.locusAdmission.approved.length == 2)
    "recovery from malformed CURRENT selected the wrong typed world"

  let currentBeforeTamperedAttempt ← IO.FS.readFile (root / "CURRENT")
  IO.FS.writeFile firstRecoveryPath "tampered-recovery\n"
  let refusedRestore ← Loam.MovementRecoveryPublisher.restore root.toString firstDigest
  expect (!refusedRestore.isOk)
    "tampered recovery manifest was selected"
  expect ((← IO.FS.readFile (root / "CURRENT")) == currentBeforeTamperedAttempt)
    "refused recovery changed CURRENT"

  IO.println "Movement recovery: retained generations restore explicitly after full verification."
