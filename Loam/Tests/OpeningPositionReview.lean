import Loam.Publisher.CurrentQuantityAnchorPublisher
import Loam.Review.OpeningPositionReview
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

private def expectError {α : Type}
    (value : Except String α)
    (needle message : String) : IO Unit :=
  match value with
  | .ok _ => throw (IO.userError message)
  | .error detail =>
      expect ((detail.splitOn needle).length > 1)
        (message ++ ": unexpected error: " ++ detail)

private def cash : EffectCoordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩
private def offset : EffectCoordinate := ⟨⟨"opening-offset"⟩, ⟨"jpy"⟩⟩
private def expense : EffectCoordinate := ⟨⟨"expense"⟩, ⟨"jpy"⟩⟩

private def effect
    (coordinate : EffectCoordinate)
    (quanta : Int) : Effect :=
  Effect.ofAnonymousQuantity
    coordinate.locus coordinate.measure (Quantity.ofQuanta quanta)

private def event
    (id : String)
    (effects : List Effect) : IO Event :=
  requireSome (Event.ofEffects? ⟨id⟩ effects) ("opening-position Event fixture " ++ id)

private def quantityFor?
    (snapshot : Loam.OpeningPositionReview.Snapshot)
    (coordinate : EffectCoordinate) : Option Int :=
  (snapshot.rows.find? fun row => decide (row.coordinate = coordinate)).map
    (fun row => row.quantity.quanta)

private def buildImage : IO Loam.ActualAuthority.Image := do
  let deposit ← event "deposit"
    [effect cash 100, effect offset (-100)]
  let spend ← event "spend"
    [effect cash (-20), effect expense 20]

  let events ← requireSome
    (EventMemory.ofEvents? [deposit, spend])
    "opening-position Event memory"
  let validity ← requireSome
    (ActualValidityHistory.ofParts?
      [ .base deposit.id "2026-06-01"
      , .base spend.id "2026-06-03"
      ]
      [])
    "opening-position validity history"

  let evidence : Loam.ActualEvidence := {
    Loam.ActualEvidence.empty with
      events := events
      validity := validity
  }
  requireSome
    (Loam.Persistence.admitActualImage? evidence)
    "opening-position admitted Actual image"

private def buildAnchor
    (image : Loam.ActualAuthority.Image) :
    IO Loam.CurrentQuantityAnchor.Evidence := do
  let admission ← requireSome
    (LocusAdmissionVocabulary.ofLoci?
      [cash.locus, offset.locus, expense.locus])
    "opening-position Locus admission"
  requireOk
    (Loam.CurrentQuantityAnchorPublisher.propose?
      image.evidence.events
      image.evidence.corrections
      admission
      ZeroOriginCoverage.empty
      OpeningSupportMap.empty
      [{ coordinate := cash, quantity := Quantity.ofQuanta 180 }])
    "opening-position exact current anchor"

def main : IO Unit := do
  let image ← buildImage
  let anchor ← buildAnchor image
  let bounded ← requireSome
    (Loam.BoundedHistorySupport.Evidence.ofSupports?
      [{ coordinate := cash, startDay := "2026-06-01" }])
    "opening-position bounded history"

  let evidence : Loam.HistoricalBalanceReview.Evidence := {
    zeroOrigin := ZeroOriginCoverage.empty
    opening := OpeningSupportMap.empty
    bounded := bounded
    anchor := anchor
  }

  let opening ← requireOk
    (Loam.OpeningPositionReview.project
      image evidence "2026-06-01" [cash])
    "derived opening position"

  expect (opening.accountingEpoch == "2026-06-01")
    "opening position did not retain the explicit Accounting Epoch"
  expect (quantityFor? opening cash == some 100)
    "opening position did not derive the pre-window quantity"

  let later ← requireOk
    (Loam.OpeningPositionReview.project
      image evidence "2026-06-03" [cash])
    "later opening-position boundary"
  expect (quantityFor? later cash == some 200)
    "opening position did not reuse correction-aware historical reconstruction"

  expectError
    (Loam.OpeningPositionReview.project
      image evidence "2026-05-31" [cash])
    "precedes bounded history start"
    "Accounting Epoch before qualified history was accepted"

  let openingOnly ← requireSome
    (OpeningSupportMap.ofSupports?
      [{ coordinate := cash, openingEvent := ⟨"deposit"⟩ }])
    "opening-position OpeningSupport fixture"
  expectError
    (Loam.OpeningPositionReview.project
      image
      {
        zeroOrigin := ZeroOriginCoverage.empty
        opening := openingOnly
        bounded := Loam.BoundedHistorySupport.Evidence.empty
        anchor := Loam.CurrentQuantityAnchor.Evidence.empty
      }
      "2026-06-01"
      [cash])
    "opening support does not justify historical reconstruction"
    "OpeningSupport silently became an Accounting Epoch authority"

  IO.println
    "Opening Position Review: derived Accounting Epoch quantity, later boundary, and fail-closed support separation passed."
