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
  sourceEvent := ⟨"purchase-event"⟩
  sourceEffect := ⟨"purchase-usd"⟩
  debtor := .household
  creditor := .external ⟨"issuer"⟩
  measure := ⟨"jpy"⟩
  committed := Quantity.ofQuanta 1000
  settled := Quantity.ofQuanta 600
  outstanding := Quantity.ofQuanta 400
  direct := [{
    correspondence := ⟨"direct-1"⟩
    event := ⟨"payment-event"⟩
    effect := ⟨"payment-jpy"⟩
    quantity := Quantity.ofQuanta 600
  }]
  netting := []
}

private def rowSettled : Loam.SettlementReview.Row := {
  id := ⟨"settled-net"⟩
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
  expect (contains "open-card" initialText &&
          contains "1000" initialText &&
          contains "600" initialText &&
          contains "400" initialText)
    "open commitment summary missing"
  expect (contains "household -> issuer" initialText)
    "commitment direction missing from details"
  expect (contains "purchase-event/purchase-usd" initialText)
    "source provenance missing from details"
  expect (contains "direct-1" initialText &&
          contains "payment-event/payment-jpy" initialText)
    "direct settlement provenance missing"

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
  expect (contains "settled-net" settledText &&
          contains "broker -> household" settledText)
    "settled commitment details missing"
  expect (contains "net-member" settledText &&
          contains "context net-context" settledText &&
          contains "[zero]" settledText)
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

  IO.println "TUI Settlement: read-only open/all list and provenance detail passed."
