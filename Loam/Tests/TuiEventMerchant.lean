import Loam.Tests.ActualWorldFixture
import Loam.ActualAuthority
import Loam.ActualReview
import Loam.HouseholdCommand
import Loam.Tui.Cli
import Loam.Tui.EventMerchant

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def emptyWorld : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? [] | throw (IO.userError "empty events")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci? [⟨"paypay"⟩, ⟨"food"⟩]
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

private def effects (amount : Int) : List Effect :=
  [ Effect.ofQuantity ⟨"effect-out"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount))
  , Effect.ofQuantity ⟨"effect-in"⟩ ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
  ]

private def draft (date description : String) (amount : Int) : Loam.MovementAdmission.Draft := {
  validOn := date
  description := some description
  effects := effects amount
  relations := []
  discharges := []
  total := amount }

private def typeText
    (state : Loam.Tui.EventMerchant.State) (text : String) : Loam.Tui.EventMerchant.State :=
  text.toList.foldl
    (fun current char => (Loam.Tui.EventMerchant.update current (.input char)).state)
    state

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let root := System.FilePath.mk dataPath
  let initial ← emptyWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root initial
    | throw (IO.userError "initialize Actual fixture")

  expect
    (Loam.Tui.Cli.selectedDayEventOfKey .actual (.input 'm') ==
      Loam.Tui.SelectedDay.Event.classifyMerchant)
    "SelectedDay m key does not enter Merchant classification"

  let .ok purchaseId ← Loam.HouseholdCommand.record root
      (draft "2026-09-17" "三和" 840)
    | throw (IO.userError "record Merchant target")
  let .ok records ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "load Merchant target review")
  let purchase ← requireSome
    ((Loam.ActualReview.select records (.day "2026-09-17")).find? fun record =>
      record.event.id == purchaseId)
    "Merchant target disappeared from selected day"

  let editor := Loam.Tui.EventMerchant.initial purchase
  expect (editor.target == purchaseId && editor.choice == .merchant && editor.partyInput.isEmpty)
    "Merchant editor did not start from selected Event with unresolved explicit input"

  let emptyAttempt := Loam.Tui.EventMerchant.update editor .enter
  expect (emptyAttempt.state.mode == .editing && emptyAttempt.publish.isNone &&
      !emptyAttempt.state.notice.isEmpty)
    "empty Merchant party id reached preview"

  let typed := typeText emptyAttempt.state "sanwa"
  let preview := Loam.Tui.EventMerchant.update typed .enter
  expect (preview.state.mode == .preview && preview.publish.isNone)
    "Merchant input did not require preview"
  let publish := Loam.Tui.EventMerchant.update preview.state .enter
  let merchantDraft ← requireSome publish.publish "Merchant preview did not emit publication intent"
  expect (merchantDraft.target == purchaseId)
    "Merchant editor changed selected Event identity"
  match merchantDraft.disposition with
  | .merchant party => expect (party.token == "sanwa") "Merchant party id changed"
  | .nonmerchant => throw (IO.userError "Merchant editor emitted Nonmerchant")

  let .ok () ← Loam.HouseholdCommand.classifyEventMerchant root merchantDraft
    | throw (IO.userError "HouseholdCommand refused Merchant TUI intent")
  let .ok afterMerchant ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload Merchant authority")
  match afterMerchant.merchants.findDisposition? purchaseId with
  | some (.merchant party) => expect (party.token == "sanwa") "retained Merchant id changed"
  | _ => throw (IO.userError "Merchant classification was not retained")

  let duplicate ← Loam.HouseholdCommand.classifyEventMerchant root merchantDraft
  expect (!duplicate.isOk) "TUI path bypassed first-classification-only publisher semantics"

  let .ok rentId ← Loam.HouseholdCommand.record root
      (draft "2026-09-17" "家賃" 50000)
    | throw (IO.userError "record Nonmerchant target")
  let .ok freshRecords ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "reload Nonmerchant target review")
  let rent ← requireSome
    ((Loam.ActualReview.select freshRecords (.day "2026-09-17")).find? fun record =>
      record.event.id == rentId)
    "Nonmerchant target disappeared from selected day"

  let nonmerchant0 := Loam.Tui.EventMerchant.initial rent
  let nonmerchant1 := (Loam.Tui.EventMerchant.update nonmerchant0 .tab).state
  expect (nonmerchant1.choice == .nonmerchant) "Tab did not select Nonmerchant"
  let ignored := (Loam.Tui.EventMerchant.update nonmerchant1 (.input 'x')).state
  expect (ignored.partyInput.isEmpty) "Nonmerchant accepted irrelevant party text"
  let nonmerchantPreview := Loam.Tui.EventMerchant.update ignored .enter
  let nonmerchantPublish := Loam.Tui.EventMerchant.update nonmerchantPreview.state .enter
  let nonmerchantDraft ← requireSome nonmerchantPublish.publish
    "Nonmerchant preview did not emit publication intent"
  expect (nonmerchantDraft.target == rentId) "Nonmerchant editor changed Event identity"
  match nonmerchantDraft.disposition with
  | .nonmerchant => pure ()
  | .merchant _ => throw (IO.userError "Nonmerchant editor emitted Merchant")

  let .ok () ← Loam.HouseholdCommand.classifyEventMerchant root nonmerchantDraft
    | throw (IO.userError "HouseholdCommand refused Nonmerchant TUI intent")
  let .ok final ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload final Merchant authority")
  expect (decide (final.merchants.findDisposition? rentId = some .nonmerchant))
    "explicit Nonmerchant disposition was not retained"

  IO.println
    "TUI Event Merchant: m entrance, explicit Merchant/Nonmerchant edit, preview, shared publication and duplicate refusal passed."
