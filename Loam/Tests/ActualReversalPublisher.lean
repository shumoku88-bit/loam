import Loam.ActualAuthority
import Loam.ActualReversalPublisher
import Loam.CorrectionPublisher
import Loam.Persistence.ScheduledLifecyclePersistence

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def emptyLifecycle : IO Loam.Persistence.ScheduledLifecycleImage := do
  let some scheduled := ScheduledMemory.ofOccurrences? []
    | throw (IO.userError "empty Scheduled memory")
  let some terminals := ScheduledTerminalMemory.ofTerminals? []
    | throw (IO.userError "empty Scheduled terminal memory")
  return { scheduled, terminals }

private def initialWorld : IO Loam.MovementAdmission.World := do
  let effects :=
    [ Effect.ofQuantity ⟨"actual-1-effect-1"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-700))
    , Effect.ofQuantity ⟨"actual-1-effect-2"⟩ ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 700)
    ]
  let some event := Event.ofEffects? ⟨"actual-1"⟩ effects
    | throw (IO.userError "initial Event")
  let some events := EventMemory.ofEvents? [event]
    | throw (IO.userError "initial Event memory")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci? [⟨"paypay"⟩, ⟨"food"⟩]
    | throw (IO.userError "initial Locus vocabulary")
  return {
    events := events
    validity := {
      facts := [.base event.id "2026-09-07"]
      factRefNodup := by simp
      corrections := []
      correctionIdNodup := by simp }
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := vocabulary }

private def quantityFor (event : Event) (locus : String) : Int :=
  event.effects.foldl
    (fun total effect => if effect.locus.token = locus then total + effect.quantity.quanta else total)
    0

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let root := dataDir / "movement-authority"
  let scheduledFile := dataDir / "scheduled.loam"
  let correctionFile := dataDir / "corrections.loam"

  let world ← initialWorld
  let .ok _ ← Loam.ActualAuthority.publishWorld? root world
    | throw (IO.userError "publish initial Movement world")
  let lifecycle ← emptyLifecycle
  expect (← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile lifecycle)
    "publish explicit empty Scheduled lifecycle"

  let draft : Loam.ActualReversalPublisher.Draft := {
    target := ⟨"actual-1"⟩
    validOn := "2026-09-08" }
  let .ok receipt ← Loam.ActualReversalPublisher.publishManifestReversal
      scheduledFile.toString root.toString correctionFile.toString "" draft
    | throw (IO.userError "publish Actual reversal")
  expect (receipt.target = ⟨"actual-1"⟩ && receipt.reversal = ⟨"actual-reversal:actual-1"⟩)
    "reversal receipt changed deterministic endpoint identities"
  expect (!receipt.resumed)
    "fresh reversal was reported as interrupted-publication resume"

  let .ok fresh ← Loam.ActualAuthority.loadSelectedWorld? root
    | throw (IO.userError "reload selected Movement world")
  let target ←
    match EventMemory.findById? fresh.events receipt.target with
    | some event => pure event
    | none => throw (IO.userError "target Actual disappeared after reversal")
  let inverse ←
    match EventMemory.findById? fresh.events receipt.reversal with
    | some event => pure event
    | none => throw (IO.userError "reversal Actual not selected after publication")
  expect (quantityFor target "paypay" + quantityFor inverse "paypay" == 0)
    "reversal did not exactly cancel target PayPay quantity"
  expect (quantityFor target "food" + quantityFor inverse "food" == 0)
    "reversal did not exactly cancel target food quantity"
  expect (fresh.events.events.length == 2)
    "reversal rewrote the target instead of retaining both Actual Events"

  let .ok actualEvidence ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload actual authority")
  let relation ←
    match actualEvidence.reversals.findByTarget? receipt.target with
    | some relation => pure relation
    | none => throw (IO.userError "reversal provenance relation missing")
  expect (relation.reversal = receipt.reversal)
    "reversal provenance does not name the inverse Actual"

  let correctionEffects :=
    [ Effect.ofQuantity ⟨"corrected-1"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-710))
    , Effect.ofQuantity ⟨"corrected-2"⟩ ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 710) ]
  let correctTarget ← Loam.CorrectionPublisher.publishManifestCorrection
    root.toString correctionFile.toString {
      target := receipt.target, effects := correctionEffects, description := none }
  expect (!correctTarget.isOk)
    "Correction changed a Reversal target and invalidated exact inverse provenance"
  let correctInverse ← Loam.CorrectionPublisher.publishManifestCorrection
    root.toString correctionFile.toString {
      target := receipt.reversal, effects := correctionEffects, description := none }
  expect (!correctInverse.isOk)
    "Correction changed a Reversal inverse and invalidated exact inverse provenance"

  let second ← Loam.ActualReversalPublisher.publishManifestReversal
    scheduledFile.toString root.toString correctionFile.toString "" draft
  expect (!second.isOk)
    "a second reversal of the same Actual was not rejected"

  let reverseAgain : Loam.ActualReversalPublisher.Draft := {
    target := receipt.reversal
    validOn := "2026-09-08" }
  let reverseAgainResult ← Loam.ActualReversalPublisher.publishManifestReversal
    scheduledFile.toString root.toString correctionFile.toString "" reverseAgain
  expect (!reverseAgainResult.isOk)
    "reversal-of-reversal chain was admitted before its semantics were qualified"

  IO.println "Actual reversal publisher: retained target + exact inverse + explicit provenance + cross-writer Correction refusal + fail-closed repeat passed."
