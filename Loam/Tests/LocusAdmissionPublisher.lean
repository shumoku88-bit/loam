import Loam.Tests.ActualWorldFixture
import Loam.ActualAuthority
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
      factRefNodup := by simp
      corrections := []
      correctionIdNodup := by simp }
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := vocabulary }

def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated data root")
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
  match ← Loam.Tests.ActualWorldFixture.publishWorld? root w with
  | .error message => throw (IO.userError message)
  | .ok _ => pure ()

  let currentPolicy ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? root with
    | .ok vocabulary => pure vocabulary
    | .error message => throw (IO.userError message)
  expect (currentPolicy.approved.map (fun locus => locus.token) == ["book", "misc"])
    "local authority did not expose the selected admission policy"

  let published ←
    match ← Loam.LocusAdmissionPublisher.publishAdmission
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
    match ← Loam.ActualAuthority.loadSelectedWorld? root with
    | .ok world => pure world
    | .error message => throw (IO.userError message)
  expect (loaded.locusAdmission.approved == policyAfter.approved)
    "Actual world disagreed with the local policy authority"
  expect (loaded.events.events.isEmpty)
    "admission publication changed Event evidence"
  expect (loaded.validity.facts.isEmpty && loaded.validity.corrections.isEmpty)
    "admission publication changed ActualValidity evidence"
  expect (loaded.descriptions.entries.isEmpty)
    "admission publication changed description evidence"
  expect (loaded.relations.isEmpty)
    "admission publication changed relation evidence"
  expect (loaded.discharges.isEmpty)
    "admission publication changed discharge evidence"

  expect (!(← Loam.LocusAdmissionPublisher.publishAdmission
      rootPath { token := "stationery" }).isOk)
    "duplicate Locus admission was accepted"

  IO.println "Locus admission publisher: local policy authority and Actual isolation passed."
