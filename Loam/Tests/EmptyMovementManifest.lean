import Loam.MovementManifestAuthority

open Loam.Core

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

def main (args : List String) : IO Unit := do
  let rootPath :: locusTokens := args
    | throw (IO.userError "supply Movement manifest root, optionally followed by admitted Locus tokens")
  let world ← emptyWorldWithLoci locusTokens
  match ← Loam.MovementManifestAuthority.publishWorld?
      (System.FilePath.mk rootPath) world with
  | .ok _ =>
      IO.println "Empty Movement manifest fixture published."
  | .error message =>
      throw (IO.userError message)
