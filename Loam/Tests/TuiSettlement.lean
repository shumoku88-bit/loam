import Loam.Tui.SettlementWorkspace
import Loam.Tui.SettlementAction

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def rowOpen : Loam.SettlementReview.Row := {
  id := ⟨"open-card"⟩
  label := some "Card purchase"
  sourceEvent := ⟨"purchase-event"⟩
  sourceEffect := ⟨"purchase-usd"⟩
  debtor := .household
  creditor := .external ⟨"issuer"⟩
  measure := ⟨"jpy"⟩
  committed := Quantity.ofQuanta 1000
  settled := Quantity.ofQuanta 600
  outstanding := Quantity.ofQuanta 300
  direct := [{
    correspondence := ⟨"direct-1"⟩
    event := ⟨"payment-event"⟩
    effect := ⟨"payment-jpy"⟩
    quantity := Quantity.ofQuanta 600
  }]
  netting := []
  extinguished := Quantity.ofQuanta 100
  extinguishments := [{
    id := ⟨"adjust-1"⟩
    quantity := Quantity.ofQuanta 100
    effectiveOn := none
  }]
}

private def rowSettled : Loam.SettlementReview.Row := {
  id := ⟨"settled-net"⟩
  label := some "Broker settlement"
  sourceEvent := ⟨"trade-event"⟩
  sourceEffect := ⟨"trade-source"⟩
  debtor := .external ⟨"broker"⟩
  creditor := .household
  measure := ⟨"jpy"⟩
  committed := Quantity.ofQuanta 500
  settled := Quantity.ofQuanta 500
  outstanding := Quantity.ofQuanta 0
  direct := []
  netting := [{
    member := ⟨"net-member"⟩
    context := ⟨"net-context"⟩
    quantity := Quantity.ofQuanta 500
    outcome := .zero
  }]
}

def main : IO Unit := do
  let snapshot : Loam.SettlementReview.Snapshot := {
    rows := [rowOpen, rowSettled]
  }
  let initial := Loam.Tui.SettlementWorkspace.initial snapshot

  expect ((Loam.Tui.SettlementWorkspace.visibleRows initial).length == 1)
    "Settlement workspace did not default to open commitments"
  expect ((Loam.Tui.SettlementWorkspace.selectedRow? initial).map (·.id.token) ==
    some "open-card")
    "Settlement workspace did not select the first open commitment"

  let bounds : Bounds := { width := 100, height := 28 }
  let initialText :=
    widgetText (Loam.Tui.SettlementWorkspace.view bounds initial)
  expect (contains "Settlement" initialText)
    "Settlement workspace heading missing"
  expect (contains "Card purchase" initialText &&
          contains "300" initialText &&
          contains "jpy" initialText)
    "compact open commitment summary missing"
  expect (!contains "open-card" initialText &&
          !contains "purchase-event/purchase-usd" initialText &&
          !contains "direct-1" initialText)
    "compact settlement view leaked internal identity or provenance"
  expect (!contains "Committed" initialText &&
          !contains "Settled" initialText &&
          !contains "Adjusted" initialText)
    "compact settlement view exposed accounting decomposition by default"

  let detailed :=
    (Loam.Tui.SettlementWorkspace.update initial .toggleDetail).state
  let detailedText :=
    widgetText (Loam.Tui.SettlementWorkspace.view bounds detailed)
  expect (contains "open-card" detailedText &&
          contains "household -> issuer" detailedText &&
          contains "purchase-event/purchase-usd" detailedText)
    "settlement detail toggle did not expose identity and source provenance"
  expect (contains "direct-1" detailedText &&
          contains "payment-event/payment-jpy" detailedText)
    "settlement detail toggle lost direct provenance"
  expect (contains "Adjusted" detailedText &&
          contains "100" detailedText &&
          contains "adjust-1" detailedText &&
          contains "date unknown" detailedText)
    "settlement detail toggle lost non-settlement reduction provenance"

  let allStep :=
    Loam.Tui.SettlementWorkspace.update initial .cycleScope
  let allState := allStep.state
  expect ((Loam.Tui.SettlementWorkspace.visibleRows allState).length == 2)
    "open/all toggle did not expose settled commitments"

  let selectedSecond :=
    (Loam.Tui.SettlementWorkspace.update allState .next).state
  expect ((Loam.Tui.SettlementWorkspace.selectedRow? selectedSecond).map (·.id.token) ==
    some "settled-net")
    "j/next navigation did not select settled commitment"

  let settledText :=
    widgetText (Loam.Tui.SettlementWorkspace.view bounds selectedSecond)
  expect (contains "Broker settlement" settledText &&
          contains "done" settledText)
    "settled commitment compact summary missing"
  expect (!contains "net-member" settledText &&
          !contains "broker -> household" settledText)
    "settled compact view leaked provenance"

  let settledDetailed :=
    (Loam.Tui.SettlementWorkspace.update selectedSecond .toggleDetail).state
  let settledDetailedText :=
    widgetText (Loam.Tui.SettlementWorkspace.view bounds settledDetailed)
  expect (contains "settled-net" settledDetailedText &&
          contains "broker -> household" settledDetailedText)
    "settled commitment details missing"
  expect (contains "net-member" settledDetailedText &&
          contains "context net-context" settledDetailedText &&
          contains "[zero]" settledDetailedText)
    "zero-net provenance missing from details"

  -- Friendly action entrance emits human intent without asking for retained IDs.
  match Loam.Tui.SettlementWorkspace.update initial .action with
  | { command := .action, .. } => pure ()
  | _ => throw (IO.userError "Settlement workspace action intent missing")

  let action := Loam.Tui.SettlementAction.initial "2026-09-28" rowOpen
  let actionText := widgetText (Loam.Tui.SettlementAction.view action)
  expect (contains "Card purchase" actionText &&
          contains "Change the original amount" actionText &&
          contains "This record itself is wrong" actionText &&
          contains "Remaining amount decreased without payment" actionText)
    "friendly settlement action menu missing"
  expect (!contains "open-card" actionText &&
          !contains "SettlementCommitment" actionText &&
          !contains "extinguishment" actionText)
    "friendly settlement action menu leaked internal vocabulary"
  expect (!contains "Review an earlier decrease" actionText)
    "routine action menu exposed reduction-repair complexity too early"

  -- Amount correction validates against already explained quantity before
  -- emitting the surface-neutral intent.
  let amountEditing := {
    action with
    mode := Loam.Tui.SettlementAction.Mode.editAmount "1200"
  }
  let amountPreview :=
    (Loam.Tui.SettlementAction.update amountEditing .enter).state
  match amountPreview.mode with
  | .editAmountPreview quantity =>
      expect (quantity.quanta == 1200)
        "friendly amount editor changed entered quantity"
  | _ => throw (IO.userError "friendly amount editor did not enter preview")
  match (Loam.Tui.SettlementAction.update amountPreview .enter).publish with
  | some (.correctAmount draft) =>
      expect (draft.target == rowOpen.id && draft.quantity.quanta == 1200)
        "friendly amount editor emitted the wrong correction intent"
  | _ => throw (IO.userError "friendly amount editor did not emit correction intent")

  let tooSmall := {
    action with
    mode := Loam.Tui.SettlementAction.Mode.editAmount "500"
  }
  let tooSmallStep := Loam.Tui.SettlementAction.update tooSmall .enter
  expect (contains "smaller than payment/adjustment" tooSmallStep.state.notice)
    "friendly amount editor did not explain its lower bound"

  -- Whole-record retraction is unavailable when later activity exists.
  let blockedWrong :=
    Loam.Tui.SettlementAction.update action (.input '2')
  expect (contains "later payment or adjustment" blockedWrong.state.notice)
    "friendly action menu did not preflight unsafe whole-record retraction"

  let cleanRow : Loam.SettlementReview.Row := {
    rowOpen with
    settled := Quantity.ofQuanta 0
    outstanding := Quantity.ofQuanta 1000
    direct := []
    extinguished := Quantity.ofQuanta 0
    extinguishments := []
  }
  let cleanAction := Loam.Tui.SettlementAction.initial "2026-09-28" cleanRow
  let retractConfirm :=
    (Loam.Tui.SettlementAction.update cleanAction (.input '2')).state
  match (Loam.Tui.SettlementAction.update retractConfirm .enter).publish with
  | some (.retract draft) =>
      expect (draft.target == cleanRow.id)
        "friendly retraction emitted the wrong target"
  | _ => throw (IO.userError "friendly retraction did not emit intent")

  -- "I don't know" remains a first-class date answer and emits no guessed date.
  let reduceAmountState : Loam.Tui.SettlementAction.State := {
    action with
    mode := .reduceAmount "100"
  }
  let reduceWhen :=
    (Loam.Tui.SettlementAction.update reduceAmountState .enter).state
  let reduceUnknown :=
    (Loam.Tui.SettlementAction.update reduceWhen (.input '3')).state
  let reduceUnknownText := widgetText (Loam.Tui.SettlementAction.view reduceUnknown)
  expect (contains "date unknown" reduceUnknownText)
    "friendly reduction preview did not preserve unknown date"
  match (Loam.Tui.SettlementAction.update reduceUnknown .enter).publish with
  | some (.reduceWithoutPayment draft) =>
      expect (draft.target == rowOpen.id &&
              draft.quantity.quanta == 100 &&
              draft.effectiveOn.isNone)
        "friendly reduction emitted guessed or incorrect evidence"
  | _ => throw (IO.userError "friendly reduction did not emit intent")

  -- Existing decreases are managed only inside the third branch, so the top
  -- level stays small. The list uses amount/date rather than retained row IDs.
  let reductionHub :=
    (Loam.Tui.SettlementAction.update action (.input '3')).state
  let reductionHubText := widgetText (Loam.Tui.SettlementAction.view reductionHub)
  expect (contains "Record another decrease" reductionHubText &&
          contains "Review an earlier decrease" reductionHubText)
    "existing reduction did not reveal the nested review branch"

  let reductionList :=
    (Loam.Tui.SettlementAction.update reductionHub (.input '2')).state
  let reductionListText := widgetText (Loam.Tui.SettlementAction.view reductionList)
  expect (contains "1. 100" reductionListText &&
          contains "date unknown" reductionListText)
    "earlier reduction list lost human-recognizable amount/date"
  expect (!contains "adjust-1" reductionListText)
    "earlier reduction list leaked retained row identity"

  let reductionItem :=
    (Loam.Tui.SettlementAction.update reductionList .enter).state
  let reductionItemText := widgetText (Loam.Tui.SettlementAction.view reductionItem)
  expect (contains "Change this decrease" reductionItemText &&
          contains "This decrease record is wrong" reductionItemText)
    "earlier reduction actions missing"

  let repairAmount : Loam.Tui.SettlementAction.State := {
    action with
    mode := .repairAmount 0 "80"
  }
  let repairWhen :=
    (Loam.Tui.SettlementAction.update repairAmount .enter).state
  let repairPreview :=
    (Loam.Tui.SettlementAction.update repairWhen (.input '3')).state
  let repairPreviewText :=
    widgetText (Loam.Tui.SettlementAction.view repairPreview)
  expect (contains "from 100 to 80" repairPreviewText &&
          contains "date unknown" repairPreviewText &&
          contains "Remaining would be 320" repairPreviewText)
    "earlier reduction correction preview is unclear"
  expect (!contains "adjust-1" repairPreviewText)
    "earlier reduction correction preview leaked retained identity"
  match (Loam.Tui.SettlementAction.update repairPreview .enter).publish with
  | some (.correctReduction draft) =>
      expect (draft.target.token == "adjust-1" &&
              draft.quantity.quanta == 80 &&
              draft.effectiveOn.isNone)
        "earlier reduction correction emitted the wrong hidden intent"
  | _ => throw (IO.userError "earlier reduction correction did not emit intent")

  let tooLargeRepair : Loam.Tui.SettlementAction.State := {
    action with
    mode := .repairAmount 0 "401"
  }
  let tooLargeRepairStep :=
    Loam.Tui.SettlementAction.update tooLargeRepair .enter
  expect (contains "larger than the amount" tooLargeRepairStep.state.notice)
    "earlier reduction correction did not explain its upper bound"

  let retractReduction :=
    (Loam.Tui.SettlementAction.update
      { action with mode := .reductionItem 0 0 } (.input '2')).state
  let retractReductionText :=
    widgetText (Loam.Tui.SettlementAction.view retractReduction)
  expect (contains "Remaining would return to 400" retractReductionText)
    "earlier reduction retraction did not explain the resulting balance"
  match (Loam.Tui.SettlementAction.update retractReduction .enter).publish with
  | some (.retractReduction draft) =>
      expect (draft.target.token == "adjust-1")
        "earlier reduction retraction emitted the wrong hidden target"
  | _ => throw (IO.userError "earlier reduction retraction did not emit intent")

  let tooLargeReduction : Loam.Tui.SettlementAction.State := {
    action with
    mode := .reduceAmount "400"
  }
  let tooLargeStep :=
    Loam.Tui.SettlementAction.update tooLargeReduction .enter
  expect (contains "larger than the remaining amount" tooLargeStep.state.notice)
    "friendly reduction did not explain its upper bound"

  let backToFirst :=
    (Loam.Tui.SettlementWorkspace.update selectedSecond .previous).state
  expect ((Loam.Tui.SettlementWorkspace.selectedRow? backToFirst).map (·.id.token) ==
    some "open-card")
    "k/previous navigation did not restore first commitment"

  match Loam.Tui.SettlementWorkspace.update backToFirst .back with
  | { command := .back, .. } => pure ()
  | _ => throw (IO.userError "Settlement workspace back intent failed")

  let empty := Loam.Tui.SettlementWorkspace.initial { rows := [] }
  let emptyText := widgetText (Loam.Tui.SettlementWorkspace.view bounds empty)
  expect (contains "nothing to show in this view" emptyText)
    "empty settlement workspace message missing"

  IO.println "TUI Settlement: compact review and nested friendly settlement repair passed."
