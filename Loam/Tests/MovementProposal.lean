import Loam.Tests.ActualWorldFixture
import Loam.Cli.Movement.Proposal
import Loam.Cli.MovementProposalCli

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def world : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? [] | throw (IO.userError "empty events")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci? [⟨"paypay"⟩, ⟨"books"⟩]
    | throw (IO.userError "proposal vocabulary")
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

private def ordinaryProposal : String :=
  "LOAM-MOVEMENT-PROPOSAL\t1\n" ++
  "date\t2026-09-16\n" ++
  "description\tmachine-readable proposal\n" ++
  "effect\t-\tpaypay\tjpy\t-2470\n" ++
  "effect\t-\tbooks\tjpy\t2470\n"

private def overlayProposal : String :=
  "LOAM-MOVEMENT-PROPOSAL\t1\n" ++
  "date\t2026-09-16\n" ++
  "effect\teffect-1\tpaypay\tjpy\t-2470\n" ++
  "effect\teffect-2\tbooks\tjpy\t2470\n" ++
  "relation\teffect-2\tH2E\tbookshop\t2470\n" ++
  "discharge\trelation-1\t100\n"

def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated data root")
  let root := System.FilePath.mk rootPath
  let w ← world
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root w
    | throw (IO.userError "initialize proposal fixture")

  let .ok draft := Loam.MovementProposal.parse? ordinaryProposal
    | throw (IO.userError "parse ordinary proposal")
  expect (draft.validOn == "2026-09-16") "proposal lost occurrence date"
  expect (draft.description == some "machine-readable proposal") "proposal lost description"
  expect (draft.effects.map (fun effect => effect.quantity.quanta) == [-2470, 2470])
    "proposal lost signed Effects"
  expect (draft.effects.all (fun effect => effect.key.isNone))
    "anonymous proposal Effects gained stable identity"
  expect (draft.total == 2470) "proposal total was not derived from positive Effects"
  expect (draft.relations.isEmpty && draft.discharges.isEmpty)
    "ordinary proposal gained overlay evidence"

  let .ok overlay := Loam.MovementProposal.parse? overlayProposal
    | throw (IO.userError "parse overlay proposal")
  expect (overlay.relations.length == 1) "relation row was not parsed"
  expect (overlay.discharges.length == 1) "discharge row was not parsed"
  expect (overlay.effects.filterMap Effect.key |>.map EffectKey.token == ["effect-1", "effect-2"])
    "explicit proposal EffectKeys were not preserved for overlay references"

  expect (!(Loam.MovementProposal.parse?
    "LOAM-MOVEMENT-PROPOSAL\t2\ndate\t2026-09-16\neffect\t-\tpaypay\tjpy\t-1\neffect\t-\tbooks\tjpy\t1\n").isOk)
    "unsupported proposal version was accepted"
  expect (!(Loam.MovementProposal.parse?
    (ordinaryProposal ++ "total\t2470\n")).isOk)
    "derived Movement total was accepted as duplicated transport input"
  expect (!(Loam.MovementProposal.parse?
    (ordinaryProposal ++ "source-id\tbank-row-7\n")).isOk)
    "unearned external source identity entered proposal transport"

  let proposalFile := root / "proposal.loam-movement"
  IO.FS.writeFile proposalFile ordinaryProposal
  let before ← IO.FS.readFile (root / "actual.loam")
  let code ← Loam.MovementProposalCli.reviewFile proposalFile.toString root.toString
  expect (code == 0) "proposal CLI refused an admissible proposal"
  expect ((← IO.FS.readFile (root / "actual.loam")) == before)
    "proposal CLI changed Actual authority"

  IO.println "Movement proposal transport: versioned parsing, derived total, explicit overlay references and read-only current-world review passed."
