import Loam.Tests.ActualWorldFixture
import Loam.ActualAuthority
import Loam.ActualReview
import Loam.ActualReversalPublisher
import Loam.MovementPublisher
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Tui.ActualReversal

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def emptyWorld : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? [] | throw (IO.userError "empty events")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci? [⟨"paypay"⟩, ⟨"coffee"⟩]
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

private def emptyLifecycle : IO Loam.Persistence.ScheduledLifecycleImage := do
  let some scheduled := ScheduledMemory.ofOccurrences? []
    | throw (IO.userError "empty Scheduled memory")
  let some terminals := ScheduledTerminalMemory.ofTerminals? []
    | throw (IO.userError "empty Scheduled terminal memory")
  return { scheduled, terminals }

private def recordDraft : Loam.MovementAdmission.Draft := {
  validOn := "2026-09-07"
  description := some "coffee"
  effects :=
    [ Effect.ofQuantity ⟨"effect-1"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-640))
    , Effect.ofQuantity ⟨"effect-2"⟩ ⟨"coffee"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 640) ]
  relations := []
  discharges := []
  total := 640 }

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let root := dataDir
  let scheduledFile := dataDir / "scheduled.loam"
  let initial ← emptyWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root initial
    | throw (IO.userError "initialize Actual fixture")
  let lifecycle ← emptyLifecycle
  expect (← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile lifecycle)
    "initialize Scheduled lifecycle"
  let .ok recorded ← Loam.MovementPublisher.publishDraft root.toString recordDraft
    | throw (IO.userError "record target fixture")

  let .ok records ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "load target Actual review")
  let record ← requireSome (Loam.ActualReview.select records (.day "2026-09-07")).head?
    "selected Actual fixture disappeared"
  let .ok editor := Loam.Tui.ActualReversal.initial? record "2026-09-08"
    | throw (IO.userError "reversal editor rejected practical Actual")
  expect (editor.target == recorded.eventId && editor.inputDate == "2026-09-08")
    "reversal editor did not keep selected target and today as independent coordinates"

  let inverse := Loam.Tui.ActualReversal.inversePreview editor
  expect (inverse.length == 2)
    "reversal preview lost postings"
  expect (inverse.any fun (locus, quantity, _) => locus.token == "paypay" && quantity.quanta == 640)
    "reversal preview did not negate PayPay posting"
  expect (inverse.any fun (locus, quantity, _) => locus.token == "coffee" && quantity.quanta == -640)
    "reversal preview did not negate coffee posting"

  let preview := Loam.Tui.ActualReversal.update editor .enter
  expect (preview.state.mode == .preview && preview.publish.isNone)
    "reversal did not require explicit preview before publication"
  let publish := Loam.Tui.ActualReversal.update preview.state .enter
  let draft ← requireSome publish.publish "reversal preview did not emit publication intent"
  expect (draft.target == recorded.eventId && draft.validOn == "2026-09-08")
    "reversal intent changed target or occurrence date"

  let .ok receipt ← Loam.ActualReversalPublisher.publishReversal
      scheduledFile.toString root.toString draft
    | throw (IO.userError "shared reversal publisher refused TUI intent")
  expect (receipt.reversal == ⟨"actual-reversal:" ++ recorded.eventId.token⟩)
    "TUI reversal did not reach deterministic shared publisher endpoint"

  let .ok fresh ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "fresh Actual review after reversal")
  expect (fresh.any fun item => item.event.id == recorded.eventId)
    "reversal removed the original Actual"
  expect (fresh.any fun item => item.event.id == receipt.reversal && item.date == some "2026-09-08")
    "fresh Actual review did not expose the reversal occurrence"

  let cancelled := Loam.Tui.ActualReversal.update editor .escape
  expect (cancelled.cancel && cancelled.publish.isNone)
    "Esc from reversal editor emitted publication"

  IO.println "TUI Actual reversal: today-seeded date, exact inverse preview, shared publication and retained original passed."
