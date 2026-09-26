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

private def admittedEmptyImage : IO Loam.ActualAuthority.Image :=
  requireSome
    (Loam.Persistence.admitActualImage? Loam.ActualEvidence.empty)
    "empty Actual image admission"

private def exactAnchor (quantity : Int) : IO Loam.CurrentQuantityAnchor.Evidence :=
  requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists?
      []
      [{ coordinate := cash, quantity := Quantity.ofQuanta quantity }])
    "exact current anchor fixture"

def main : IO Unit := do
  let image ← admittedEmptyImage
  let anchor ← exactAnchor (-100)
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
    "anchored history support"
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

  let staleAnchor ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists?
      [⟨"missing-root"⟩]
      [{ coordinate := cash, quantity := Quantity.ofQuanta (-100) }])
    "stale current anchor fixture"
  expect
    (!(Loam.BoundedHistorySupportPublisher.propose?
      image admission staleAnchor Loam.BoundedHistorySupport.Evidence.empty draft).isOk)
    "history support accepted an anchor that does not resolve in current Actual"

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
    "Bounded history support: explicit start, replacement/removal, anchor gate, persistence, review and reconciliation guard passed."
