import Loam.CurrentBalanceReview

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def requireOk {α : Type} (value : Except String α) (message : String) : IO α :=
  match value with
  | .ok result => pure result
  | .error error => throw (IO.userError (message ++ ": " ++ error))

private def effect (key locus : String) (quanta : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ ⟨locus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quanta)

private def coordinate (locus : String) : EffectCoordinate :=
  ⟨⟨locus⟩, ⟨"jpy"⟩⟩

private def quantityFor?
    (snapshot : Loam.CurrentBalanceReview.Snapshot)
    (locus : String) : Option Quantity :=
  (snapshot.rows.find? fun row => row.coordinate.locus.token == locus).map (·.quantity)

def main : IO Unit := do
  let walletEvent ← requireSome
    (Event.ofEffects? ⟨"wallet-event"⟩ [effect "wallet-in" "wallet" 70])
    "wallet event"
  let debtOpening ← requireSome
    (Event.ofEffects? ⟨"debt-opening"⟩ [effect "debt-open" "debt" (-100)])
    "debt opening"
  let debtRepay ← requireSome
    (Event.ofEffects? ⟨"debt-repay"⟩ [effect "debt-repay-effect" "debt" 20])
    "debt repayment"
  let flow ← requireSome
    (Event.ofEffects? ⟨"flow"⟩ [effect "flow-expense" "expense" 10])
    "unsupported flow"

  let events ← requireSome
    (EventMemory.ofEvents? [walletEvent, debtOpening, debtRepay, flow])
    "events"
  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections? [])
    "corrections"

  let wallet := coordinate "wallet"
  let cash := coordinate "cash"
  let debt := coordinate "debt"
  let anchorOnly := coordinate "anchor-only"
  let wifi := coordinate "wifi"
  let expense := coordinate "expense"

  let coverage ← requireSome
    (ZeroOriginCoverage.ofCoordinates? [wallet, cash])
    "zero-origin"
  let opening ← requireSome
    (OpeningSupportMap.ofSupports? [{ coordinate := debt, openingEvent := debtOpening.id }])
    "opening support"
  let roots := [walletEvent.id, debtOpening.id, debtRepay.id, flow.id]
  let anchorAssertion : Loam.CurrentQuantityAnchor.Assertion := {
    coordinate := anchorOnly
    quantity := Quantity.ofQuanta 42
  }
  let anchor ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists? roots [anchorAssertion])
    "current anchor"
  let presence ← requireSome
    (Loam.CurrentQuantityPresence.Evidence.ofLists? roots [wifi])
    "current presence"

  let evidence : Loam.BalanceReview.Evidence := {
    events := events
    corrections := corrections
    coverage := coverage
  }
  let snapshot ← requireOk
    (Loam.CurrentBalanceReview.project evidence opening anchor presence)
    "neutral current balance projection"

  expect ((quantityFor? snapshot "wallet").map (·.quanta) == some 70)
    "zero-origin current quantity changed"
  expect ((quantityFor? snapshot "cash").map (·.quanta) == some 0)
    "explicit zero disappeared"
  expect ((quantityFor? snapshot "debt").map (·.quanta) == some (-80))
    "opening-supported current quantity changed"
  expect ((quantityFor? snapshot "anchor-only").map (·.quanta) == some 42)
    "anchor-supported current quantity changed"
  expect (snapshot.knownPresent.contains wifi)
    "known-present amount-unknown coordinate disappeared"
  expect (snapshot.unsupported.contains expense)
    "unsupported current coordinate disappeared"

  let selected ← requireOk
    (Loam.CurrentBalanceReview.selectExact snapshot [cash, anchorOnly, debt])
    "exact current selection"
  expect (selected.rows.map (fun row => row.quantity.quanta) == [0, 42, -80])
    "exact current selection changed caller order or quantities"

  expect
    (match Loam.CurrentBalanceReview.selectExact snapshot [wifi] with
      | .error _ => true
      | .ok _ => false)
    "known-present amount-unknown coordinate became an exact quantity"
  expect
    (match Loam.CurrentBalanceReview.selectExact snapshot [expense] with
      | .error _ => true
      | .ok _ => false)
    "unsupported coordinate became an exact quantity"

  let overlappingPresence ← requireSome
    (Loam.CurrentQuantityPresence.Evidence.ofLists? roots [anchorOnly])
    "overlapping presence"
  expect
    (match Loam.CurrentBalanceReview.project evidence opening anchor overlappingPresence with
      | .error _ => true
      | .ok _ => false)
    "current support overlap gained implicit precedence"

  expect
    (match Loam.BalanceReview.project events corrections coverage [anchorOnly] with
      | .error _ => true
      | .ok _ => false)
    "current anchor leaked into historical zero-origin BalanceReview"

  IO.println
    "Current Balance Review: zero, opening, anchor, amount-unknown and unsupported states stay distinct."
