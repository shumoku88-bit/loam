import Loam.Tests.ActualWorldFixture
import Loam.ActualAuthority

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def emptyWorld : IO Loam.MovementAdmission.World := do
  let some vocabulary := LocusAdmissionVocabulary.ofLoci? [⟨"paypay"⟩, ⟨"books"⟩]
    | throw (IO.userError "proposal-record vocabulary")
  return {
    events := { events := [], idNodup := by simp }
    validity := {
      facts := []
      factRefNodup := by simp
      corrections := []
      correctionIdNodup := by simp }
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := vocabulary
  }

private def ordinaryProposal : String :=
  "LOAM-MOVEMENT-PROPOSAL\t1\n" ++
  "date\t2026-09-16\n" ++
  "description\tAI accepted book purchase\n" ++
  "effect\t-\tpaypay\tjpy\t-2470\n" ++
  "effect\t-\tbooks\tjpy\t2470\n"

private def unadmittedLocusProposal : String :=
  "LOAM-MOVEMENT-PROPOSAL\t1\n" ++
  "date\t2026-09-16\n" ++
  "description\tshould refuse\n" ++
  "effect\t-\tpaypay\tjpy\t-100\n" ++
  "effect\t-\tgroceries\tjpy\t100\n"

def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated data root")
  let root := System.FilePath.mk rootPath
  let world ← emptyWorld
  let .ok () ← Loam.Tests.ActualWorldFixture.publishWorld? root world
    | throw (IO.userError "initialize proposal-record fixture")

  let proposalFile := root / "accepted.proposal"
  IO.FS.writeFile proposalFile ordinaryProposal

  let recorded ← IO.Process.output {
    cmd := ".lake/build/bin/loamMovementProposalRecord"
    args := #[proposalFile.toString, root.toString]
  }
  expect (recorded.exitCode == 0)
    s!"proposal record CLI failed with code {recorded.exitCode}: {recorded.stderr}"
  expect (recorded.stdout.contains "[ok] authoritative Movement admission re-run under writer ownership")
    "proposal record CLI did not report canonical writer admission"
  expect (recorded.stdout.contains "[ok] canonical Actual publication complete")
    "proposal record CLI did not report canonical publication"

  let .ok afterRecorded ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload proposal-record Actual")
  expect (afterRecorded.events.events.length == 1)
    "proposal record did not publish exactly one Event"
  let some event := afterRecorded.events.events.head?
    | throw (IO.userError "recorded Event missing")
  expect (event.effects.map (fun effect => effect.quantity.quanta) == [-2470, 2470])
    "proposal record changed signed Effects"
  expect (event.effects.all fun effect => effect.key.isNone)
    "ordinary proposal record retained unearned Effect identity"
  expect (afterRecorded.validity.facts.length == 1)
    "proposal record did not publish occurrence-date evidence"
  expect (afterRecorded.descriptions.entries.length == 1)
    "proposal record did not publish description evidence"

  let actualPath := root / "actual.loam"
  let acceptedSnapshot ← IO.FS.readFile actualPath

  IO.FS.writeFile proposalFile unadmittedLocusProposal
  let refused ← IO.Process.output {
    cmd := ".lake/build/bin/loamMovementProposalRecord"
    args := #[proposalFile.toString, root.toString]
  }
  expect (refused.exitCode == 2)
    s!"unadmitted Locus proposal unexpectedly returned {refused.exitCode}"
  expect (refused.stderr.contains "Locus not approved")
    "writer refusal did not expose current Locus policy failure"
  expect ((← IO.FS.readFile actualPath) == acceptedSnapshot)
    "refused proposal modified canonical Actual authority"

  IO.println "Movement proposal record: explicit write entrance, canonical writer reread, sparse identity, and refusal atomicity passed."
