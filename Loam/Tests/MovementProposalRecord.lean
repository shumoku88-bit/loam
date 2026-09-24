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

private def idempotentProposal : String :=
  "LOAM-MOVEMENT-PROPOSAL\t2\n" ++
  "operation\tai-book-20260917-1\n" ++
  "date\t2026-09-17\n" ++
  "description\tAI idempotent book purchase\n" ++
  "effect\t-\tpaypay\tjpy\t-500\n" ++
  "effect\t-\tbooks\tjpy\t500\n"

private def driftedIdempotentProposal : String :=
  "LOAM-MOVEMENT-PROPOSAL\t2\n" ++
  "operation\tai-book-20260917-1\n" ++
  "date\t2026-09-18\n" ++
  "description\tDRIFTED RETRY PAYLOAD\n" ++
  "effect\t-\tpaypay\tjpy\t-700\n" ++
  "effect\t-\tbooks\tjpy\t700\n"

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

  IO.FS.writeFile proposalFile idempotentProposal
  let firstIdempotent ← IO.Process.output {
    cmd := ".lake/build/bin/loamMovementProposalRecord"
    args := #[proposalFile.toString, root.toString]
  }
  expect (firstIdempotent.exitCode == 0)
    s!"first idempotent proposal failed with code {firstIdempotent.exitCode}: {firstIdempotent.stderr}"
  expect (firstIdempotent.stdout.contains "[ok] Event and operation evidence atomically published")
    "first idempotent proposal did not report a new atomic publication"

  let .ok afterFirstIdempotent ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload first idempotent proposal")
  expect (afterFirstIdempotent.events.events.length == 2)
    "first idempotent proposal did not add exactly one Event"
  let some idempotentEvent :=
      afterFirstIdempotent.movementOperations.findEvent? ⟨"ai-book-20260917-1"⟩
    | throw (IO.userError "idempotent proposal operation mapping missing")
  expect (idempotentEvent.token == "record-2")
    "first idempotent proposal did not retain the produced Event identity"

  let secondIdempotent ← IO.Process.output {
    cmd := ".lake/build/bin/loamMovementProposalRecord"
    args := #[proposalFile.toString, root.toString]
  }
  expect (secondIdempotent.exitCode == 0)
    s!"idempotent retry failed with code {secondIdempotent.exitCode}: {secondIdempotent.stderr}"
  expect (secondIdempotent.stdout.contains "[ok] operation already applied; original Event reused")
    "idempotent retry did not report reuse of the original Event"

  let .ok afterSecondIdempotent ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload idempotent retry")
  expect (afterSecondIdempotent.events.events.length == 2)
    "idempotent retry published a duplicate Event"
  expect (afterSecondIdempotent.movementOperations.findEvent? ⟨"ai-book-20260917-1"⟩ ==
      some idempotentEvent)
    "idempotent retry changed the retained OperationId to EventId mapping"

  let actualPath := root / "actual.loam"
  let acceptedSnapshot ← IO.FS.readFile actualPath

  IO.FS.writeFile proposalFile driftedIdempotentProposal
  let driftedRetry ← IO.Process.output {
    cmd := ".lake/build/bin/loamMovementProposalRecord"
    args := #[proposalFile.toString, root.toString]
  }
  expect (driftedRetry.exitCode == 0)
    s!"drifted idempotent retry failed with code {driftedRetry.exitCode}: {driftedRetry.stderr}"
  expect (driftedRetry.stdout.contains "[ok] operation already applied; original Event reused")
    "drifted retry did not report reuse of the original Event"
  expect (driftedRetry.stdout.contains "[ok] retry payload not displayed as retained Event evidence")
    "drifted retry did not report the replay presentation boundary"
  expect (driftedRetry.stdout.contains "event: record-2")
    "drifted retry did not identify the original retained Event"
  expect (!(driftedRetry.stdout.contains "date: 2026-09-18"))
    "drifted retry displayed the retry date as retained Event evidence"
  expect (!(driftedRetry.stdout.contains "description: DRIFTED RETRY PAYLOAD"))
    "drifted retry displayed the retry description as retained Event evidence"
  expect (!(driftedRetry.stdout.contains "movement: 700 jpy"))
    "drifted retry displayed the retry amount as retained Event evidence"
  expect ((← IO.FS.readFile actualPath) == acceptedSnapshot)
    "drifted idempotent retry modified canonical Actual authority"

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

  IO.println "Movement proposal record: v1 compatibility, v2 idempotent replay presentation, canonical writer reread, sparse identity, and refusal atomicity passed."
