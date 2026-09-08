import Loam.MovementManifestAuthority

open Loam.Core

private def emptyWorld : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? []
    | throw (IO.userError "empty Event memory")
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
    locusAdmission := LocusAdmissionVocabulary.empty }

def main (args : List String) : IO Unit := do
  let [rootPath] := args
    | throw (IO.userError "supply Movement manifest root")
  let world ← emptyWorld
  match ← Loam.MovementManifestAuthority.publishWorld?
      (System.FilePath.mk rootPath) world with
  | .ok _ =>
      IO.println "Empty Movement manifest fixture published."
  | .error message =>
      throw (IO.userError message)
