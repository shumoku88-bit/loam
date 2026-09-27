import Loam.Tui.SettlementWorkspace

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
  expect (contains "no settlement commitments" emptyText)
    "empty settlement workspace message missing"

  IO.println "TUI Settlement: compact routine view and on-demand provenance detail passed."
