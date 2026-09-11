import Loam.LocusAdmissionPublisher

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def world : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? [] | throw (IO.userError "empty events")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci? [⟨"book"⟩, ⟨"misc"⟩]
    | throw (IO.userError "vocabulary")
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
  let w ← world

  let .ok (proposed, receipt) :=
      Loam.LocusAdmissionPublisher.propose? w.locusAdmission { token := "stationery" }
    | throw (IO.userError "valid admission proposal was rejected")
  expect (receipt.locus.token == "stationery") "receipt lost admitted identity"
  expect (receipt.previousCount == 2 && receipt.currentCount == 3)
    "receipt counts do not describe one additive admission"
  expect (proposed.approved.map (fun locus => locus.token) ==
      ["book", "misc", "stationery"])
    "proposal did not preserve existing admission and append one identity"
  expect (!(Loam.LocusAdmissionPublisher.propose?
      w.locusAdmission { token := "book" }).isOk)
    "duplicate admission was accepted"
  expect (!(Loam.LocusAdmissionPublisher.propose?
      w.locusAdmission { token := "bad\ttoken" }).isOk)
    "persistence-invalid stable token was accepted"

  let root := System.FilePath.mk rootPath
  match ← Loam.MovementManifestAuthority.publishWorld? root w with
  | .error message => throw (IO.userError message)
  | .ok _ => pure ()

  let currentPolicy ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? root with
    | .ok vocabulary => pure vocabulary
    | .error message => throw (IO.userError message)
  expect (currentPolicy.approved.map (fun locus => locus.token) == ["book", "misc"])
    "local authority did not expose the selected admission policy"

  let published ←
    match ← Loam.LocusAdmissionPublisher.publishManifestAdmission
        rootPath { token := "stationery" } with
    | .ok receipt => pure receipt
    | .error message => throw (IO.userError message)
  expect (published.currentCount == 3) "publisher receipt count mismatch"

  let policyAfter ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? root with
    | .ok vocabulary => pure vocabulary
    | .error message => throw (IO.userError message)
  expect (policyAfter.approved.map (fun locus => locus.token) ==
      ["book", "misc", "stationery"])
    "local authority did not retain the published admission vocabulary"

  let loaded ←
    match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
    | .ok world => pure world
    | .error message => throw (IO.userError message)
  expect (loaded.locusAdmission == policyAfter)
    "manifest-backed representation disagreed with the local policy authority"
  expect (Loam.Persistence.encodeEventMemory? loaded.events ==
      Loam.Persistence.encodeEventMemory? w.events)
    "admission publication changed Event evidence wire"
  expect (Loam.Persistence.encodeActualValidityHistory? loaded.validity ==
      Loam.Persistence.encodeActualValidityHistory? w.validity)
    "admission publication changed ActualValidity evidence wire"
  expect (Loam.Persistence.encodeEventDescriptionMemory? loaded.descriptions ==
      Loam.Persistence.encodeEventDescriptionMemory? w.descriptions)
    "admission publication changed description evidence wire"
  expect (Loam.Persistence.encodeOpenRelationUnits? loaded.relations ==
      Loam.Persistence.encodeOpenRelationUnits? w.relations)
    "admission publication changed relation evidence wire"
  expect (Loam.Persistence.encodeRelationDischarges? loaded.discharges ==
      Loam.Persistence.encodeRelationDischarges? w.discharges)
    "admission publication changed discharge evidence wire"

  expect (!(← Loam.LocusAdmissionPublisher.publishManifestAdmission
      rootPath { token := "stationery" }).isOk)
    "duplicate manifest admission was accepted"

  IO.println "Locus admission publisher: local policy authority and manifest isolation passed."
