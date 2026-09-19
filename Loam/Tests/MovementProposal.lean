import Loam.Tests.ActualWorldFixture
import Loam.Cli.Movement.Proposal
import Loam.MovementDraftReview

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

private def idempotentProposal : String :=
  "LOAM-MOVEMENT-PROPOSAL\t2\n" ++
  "operation\tai-proposal-20260916-1\n" ++
  "date\t2026-09-16\n" ++
  "description\tidempotent proposal\n" ++
  "effect\t-\tpaypay\tjpy\t-300\n" ++
  "effect\t-\tbooks\tjpy\t300\n"

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
  let overlayKeys := (overlay.effects.filterMap Effect.key).map EffectKey.token
  expect (overlayKeys == ["effect-1", "effect-2"])
    "explicit proposal EffectKeys were not preserved for overlay references"

  let .ok idempotent := Loam.MovementProposal.parseRecord? idempotentProposal
    | throw (IO.userError "parse idempotent proposal")
  expect (idempotent.operation == some ⟨"ai-proposal-20260916-1"⟩)
    "v2 proposal lost explicit Movement operation identity"
  expect (idempotent.draft.total == 300)
    "v2 proposal changed Movement draft semantics"
  let .ok reviewedIdempotent := Loam.MovementProposal.parse? idempotentProposal
    | throw (IO.userError "read-only parse idempotent proposal")
  expect (reviewedIdempotent.total == 300)
    "read-only v2 review did not preserve Movement draft"

  expect (!(Loam.MovementProposal.parseRecord?
    "LOAM-MOVEMENT-PROPOSAL\t2\ndate\t2026-09-16\neffect\t-\tpaypay\tjpy\t-1\neffect\t-\tbooks\tjpy\t1\n").isOk)
    "v2 proposal without operation identity was accepted"
  expect (!(Loam.MovementProposal.parseRecord?
    (ordinaryProposal ++ "operation\tunearned-in-v1\n")).isOk)
    "v1 proposal unexpectedly accepted operation identity"
  expect (!(Loam.MovementProposal.parse?
    (ordinaryProposal ++ "total\t2470\n")).isOk)
    "derived Movement total was accepted as duplicated transport input"
  expect (!(Loam.MovementProposal.parse?
    (ordinaryProposal ++ "source-id\tbank-row-7\n")).isOk)
    "unearned external source identity entered proposal transport"

  let proposalFile := root / "proposal.loam-movement"
  IO.FS.writeFile proposalFile ordinaryProposal
  let fileText ← IO.FS.readFile proposalFile
  let .ok fileDraft := Loam.MovementProposal.parse? fileText
    | throw (IO.userError "parse proposal file")
  let before ← IO.FS.readFile (root / "actual.loam")
  let .ok () ← Loam.MovementDraftReview.check root fileDraft
    | throw (IO.userError "review proposal against current household world")
  expect ((← IO.FS.readFile (root / "actual.loam")) == before)
    "proposal review changed Actual authority"

  IO.println "Movement proposal transport: v1 compatibility, explicit v2 operation identity, derived total, overlay references and read-only review passed."
