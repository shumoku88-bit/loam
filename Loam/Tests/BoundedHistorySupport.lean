import Loam.BoundedHistorySupportPublisher
import Loam.BoundedHistorySupportReview
import Loam.CurrentQuantityAnchorPublisher
import Loam.Persistence.BoundedHistorySupportPersistence
import Loam.Persistence.NormalizedActualPersistence

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
  | .error detail => throw (IO.userError (message ++ ": " ++ detail))

private def cash : EffectCoordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩
private def expense : EffectCoordinate := ⟨⟨"expense"⟩, ⟨"jpy"⟩⟩

private def eventFixture : IO Event := do
  requireSome
    (Event.ofEffects? ⟨"history-event"⟩ [
      Effect.ofQuantity ⟨"cash-effect"⟩ cash.locus cash.measure (Quantity.ofQuanta (-100)),
      Effect.ofQuantity ⟨"expense-effect"⟩ expense.locus expense.measure (Quantity.ofQuanta 100)
    ])
    "history Event fixture"

private def imageWithDate? (date : Option String) : IO Loam.ActualAuthority.Image := do
  let event ← eventFixture
  let events ← requireSome (EventMemory.ofEvents? [event]) "history Event memory"
  let validity ←
    match date with
    | some day =>
        requireSome
          (ActualValidityHistory.ofParts? [.base event.id day] [])
          "history validity"
    | none =>
        requireSome
          (ActualValidityHistory.ofParts? [] [])
          "empty history validity"
  let evidence : Loam.ActualEvidence := {
    Loam.ActualEvidence.empty with
    events := events
    validity := validity
  }
  requireSome
    (Loam.Persistence.admitActualImage? evidence)
    "history Actual image admission"

private def anchorFor
    (event : Event)
    (quantity : Int) : IO Loam.CurrentQuantityAnchor.Evidence := do
  requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists?
      [event.id]
      [{ coordinate := cash, quantity := Quantity.ofQuanta quantity }])
    "history anchor fixture"

def main : IO Unit := do
  let event ← eventFixture
  let image ← imageWithDate? (some "2026-09-01")
  let anchor ← anchorFor event (-100)
  let admission ← requireSome
    (LocusAdmissionVocabulary.ofLoci? [cash.locus, expense.locus])
    "history Locus admission"
  let draft : Loam.BoundedHistorySupportPublisher.Draft := {
    coordinate := cash
    startDay := some "2026-09-01"
  }

  let admitted ← requireOk
    (Loam.BoundedHistorySupportPublisher.propose?
      image admission anchor Loam.BoundedHistorySupport.Evidence.empty draft)
    "dated anchored history support"
  let some support := admitted.supportFor? cash
    | throw (IO.userError "history support proposal disappeared")
  expect (support.startDay == "2026-09-01")
    "history support start changed during admission"

  let moved ← requireOk
    (Loam.BoundedHistorySupportPublisher.propose?
      image admission anchor admitted
      { coordinate := cash, startDay := some "2026-09-02" })
    "history support start move"
  expect ((moved.supportFor? cash).map (·.startDay) == some "2026-09-02")
    "history support did not replace the coordinate-local start"

  let cleared ← requireOk
    (Loam.BoundedHistorySupportPublisher.propose?
      image admission anchor moved
      { coordinate := cash, startDay := none })
    "history support removal"
  expect ((cleared.supportFor? cash).isNone)
    "history support removal left a retained claim"

  expect
    (!(Loam.BoundedHistorySupportPublisher.propose?
      image admission Loam.CurrentQuantityAnchor.Evidence.empty
      Loam.BoundedHistorySupport.Evidence.empty draft).isOk)
    "history support was admitted without an exact current anchor"

  expect
    (!(Loam.BoundedHistorySupportPublisher.propose?
      image admission anchor Loam.BoundedHistorySupport.Evidence.empty
      { coordinate := cash, startDay := some "2026-02-29" }).isOk)
    "history support accepted an invalid calendar day"

  let undatedImage ← imageWithDate? none
  expect
    (!(Loam.BoundedHistorySupportPublisher.propose?
      undatedImage admission anchor Loam.BoundedHistorySupport.Evidence.empty draft).isOk)
    "history support accepted a current quantity Event with no occurrence date"

  let encoded ← requireSome
    (Loam.Persistence.encodeBoundedHistorySupport? admitted)
    "history support encoding"
  let decoded ← requireSome
    (Loam.Persistence.decodeBoundedHistorySupport? encoded)
    "history support decoding"
  expect (decide (decoded = admitted))
    "history support persistence roundtrip changed evidence"

  expect
    (Loam.BoundedHistorySupport.Evidence.ofSupports? [
      { coordinate := cash, startDay := "2026-09-01" },
      { coordinate := cash, startDay := "2026-09-02" }
    ]).isNone
    "history support admitted duplicate coordinates"

  expect
    (Loam.BoundedHistorySupport.Evidence.ofSupports? [
      { coordinate := cash, startDay := "2026-02-29" }
    ]).isNone
    "history support admitted invalid persisted calendar date"

  let snapshot := Loam.BoundedHistorySupportReview.project admitted anchor
  let some row := snapshot.rows.find? fun row => row.coordinate = cash
    | throw (IO.userError "history support review lost cash")
  expect (row.startDay == some "2026-09-01" && row.hasExactCurrentAnchor)
    "history support review changed retained support state"

  requireOk
    (Loam.CurrentQuantityAnchorPublisher.validateBoundedHistoryReobservation
      image.evidence.events image.evidence.corrections anchor admitted
      [{ coordinate := cash, quantity := Quantity.ofQuanta (-100) }])
    "same current quantity re-observation should preserve bounded support"

  expect
    (!(Loam.CurrentQuantityAnchorPublisher.validateBoundedHistoryReobservation
      image.evidence.events image.evidence.corrections anchor admitted
      [{ coordinate := cash, quantity := Quantity.ofQuanta (-99) }]).isOk)
    "different current quantity silently preserved bounded historical completeness"

  IO.println
    "Bounded history support: explicit start, replacement/removal, anchor/date gates, persistence, review and reconciliation guard passed."
