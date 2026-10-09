import Loam.Publisher.CurrentQuantityAnchorPublisher
import Loam.Review.HistoricalBalanceReview
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
private def expense : EffectCoordinate := ⟨⟨"expense"⟩, ⟨"jpy"⟩⟩
private def jpyOffset : EffectCoordinate := ⟨⟨"jpy-offset"⟩, ⟨"jpy"⟩⟩
private def usdCash : EffectCoordinate := ⟨⟨"usd-cash"⟩, ⟨"usd"⟩⟩
private def usdOffset : EffectCoordinate := ⟨⟨"usd-offset"⟩, ⟨"usd"⟩⟩

private def effect
    (coordinate : EffectCoordinate)
    (quanta : Int) : Effect :=
  Effect.ofAnonymousQuantity
    coordinate.locus coordinate.measure (Quantity.ofQuanta quanta)

private def event
    (id : String)
    (effects : List Effect) : IO Event :=
  requireSome (Event.ofEffects? ⟨id⟩ effects) ("Event fixture " ++ id)

private def quantityFor?
    (snapshot : Loam.HistoricalBalanceReview.Snapshot)
    (coordinate : EffectCoordinate) : Option Int :=
  (snapshot.rows.find? fun row => decide (row.coordinate = coordinate)).map
    (fun row => row.quantity.quanta)

private def buildImage : IO Loam.ActualAuthority.Image := do
  let deposit ← event "deposit"
    [effect cash 100, effect jpyOffset (-100)]
  let oldSpend ← event "old-spend"
    [effect cash (-5), effect expense 5]
  let correctedSpend ← event "corrected-spend"
    [effect cash (-8), effect expense 8]
  let adjustment ← event "adjustment"
    [effect cash (-10), effect expense 10]
  let usdDeposit ← event "usd-deposit"
    [effect usdCash 30, effect usdOffset (-30)]

  let events ← requireSome
    (EventMemory.ofEvents?
      [deposit, oldSpend, correctedSpend, adjustment, usdDeposit])
    "historical Event memory"
  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := oldSpend.id, replacement := correctedSpend.id }])
    "historical Event correction memory"

  let adjustmentRevision : ActualValidityRevisionId := ⟨"adjustment-date-r1"⟩
  let validity ← requireSome
    (ActualValidityHistory.ofParts?
      [ .base deposit.id "2026-06-01"
      , .base oldSpend.id "2026-06-02"
      , .base correctedSpend.id "2026-06-02"
      , .base adjustment.id "2026-06-07"
      , .revision adjustmentRevision adjustment.id "2026-06-03"
      , .base usdDeposit.id "2026-06-02"
      ]
      [{ target := .root adjustment.id, replacement := adjustmentRevision }])
    "historical Actual validity history"

  let evidence : Loam.ActualEvidence := {
    Loam.ActualEvidence.empty with
      events := events
      corrections := corrections
      validity := validity
  }
  requireSome
    (Loam.Persistence.admitActualImage? evidence)
    "historical admitted Actual image"

private def buildAnchor
    (image : Loam.ActualAuthority.Image) :
    IO Loam.CurrentQuantityAnchor.Evidence := do
  let admission ← requireSome
    (LocusAdmissionVocabulary.ofLoci?
      [cash.locus, expense.locus, jpyOffset.locus, usdCash.locus, usdOffset.locus])
    "historical Locus admission"
  requireOk
    (Loam.CurrentQuantityAnchorPublisher.propose?
      image.evidence.events
      image.evidence.corrections
      admission
      ZeroOriginCoverage.empty
      OpeningSupportMap.empty
      [ { coordinate := cash, quantity := Quantity.ofQuanta 132 }
      , { coordinate := usdCash, quantity := Quantity.ofQuanta 230 }
      ])
    "historical exact current anchor"

private def buildBounded : IO Loam.BoundedHistorySupport.Evidence :=
  requireSome
    (Loam.BoundedHistorySupport.Evidence.ofSupports?
      [ { coordinate := cash, startDay := "2026-06-01" }
      , { coordinate := usdCash, startDay := "2026-06-02" }
      ])
    "bounded history fixture"

def main : IO Unit := do
  let image ← buildImage
  let anchor ← buildAnchor image
  let bounded ← buildBounded
  let evidence : Loam.HistoricalBalanceReview.Evidence := {
    zeroOrigin := ZeroOriginCoverage.empty
    opening := OpeningSupportMap.empty
    bounded := bounded
    anchor := anchor
  }

  -- Start boundary: subtract every current-truth delta from the exact current anchor.
  let start ← requireOk
    (Loam.HistoricalBalanceReview.projectBoundedStartOfDay
      image evidence "2026-06-01" [cash])
    "bounded history start"
  expect (quantityFor? start cash == some 50)
    "bounded start did not reconstruct the pre-Actual opening quantity"

  -- 2026-06-02 catches EventCorrection: old-spend must not contribute beside corrected-spend.
  let corrected ← requireOk
    (Loam.HistoricalBalanceReview.projectBoundedStartOfDay
      image evidence "2026-06-02" [cash])
    "bounded history correction frontier"
  expect (quantityFor? corrected cash == some 150)
    "EventCorrection did not select exactly one current quantity world"

  -- 2026-06-04 catches ActualValidity refinement: adjustment moved from 06-07 to 06-03.
  let refined ← requireOk
    (Loam.HistoricalBalanceReview.projectBoundedStartOfDay
      image evidence "2026-06-04" [cash])
    "bounded history refined date"
  expect (quantityFor? refined cash == some 132)
    "ActualValidity correction did not move the retained quantity to its refined day"

  -- After every retained delta, the reconstructed boundary equals the exact current anchor.
  let currentEndpoint ← requireOk
    (Loam.HistoricalBalanceReview.projectBoundedStartOfDay
      image evidence "2026-06-08" [cash])
    "bounded history current endpoint"
  expect (quantityFor? currentEndpoint cash == some 132)
    "current endpoint did not agree with the exact current anchor"

  -- Distinct Measures and coordinates remain independent rows, never one arithmetic total.
  let mixed ← requireOk
    (Loam.HistoricalBalanceReview.projectBoundedStartOfDay
      image evidence "2026-06-02" [cash, usdCash, cash])
    "bounded history multimeasure projection"
  expect (mixed.rows.length == 2)
    "duplicate presentation coordinates were not normalized"
  expect (quantityFor? mixed cash == some 150)
    "JPY coordinate changed in multimeasure projection"
  expect (quantityFor? mixed usdCash == some 200)
    "USD coordinate did not reconstruct independently"

  -- The general historical boundary may compose independent routes in one question.
  let zeroCovered ← requireSome
    (ZeroOriginCoverage.ofCoordinates? [jpyOffset])
    "mixed historical zero-origin coverage"
  let mixedEvidence : Loam.HistoricalBalanceReview.Evidence := {
    evidence with zeroOrigin := zeroCovered
  }
  let routed ← requireOk
    (Loam.HistoricalBalanceReview.projectStartOfDay
      image mixedEvidence "2026-06-02" [jpyOffset, cash])
    "mixed zero-origin and bounded historical routes"
  expect (quantityFor? routed jpyOffset == some (-100))
    "zero-origin route did not reconstruct forward from exact zero"
  expect (quantityFor? routed cash == some 150)
    "bounded route changed when composed beside zero-origin history"

  let openingOnly ← requireSome
    (OpeningSupportMap.ofSupports?
      [{ coordinate := expense, openingEvent := ⟨"deposit"⟩ }])
    "opening-only historical fixture"
  expectError
    (Loam.HistoricalBalanceReview.projectStartOfDay
      image { evidence with opening := openingOnly } "2026-06-02" [expense])
    "opening support does not justify historical reconstruction"
    "OpeningSupport silently became historical completeness"

  expectError
    (Loam.HistoricalBalanceReview.projectBoundedStartOfDay
      image evidence "2026-05-31" [cash])
    "precedes bounded history start"
    "query before bounded support start was accepted"

  expectError
    (Loam.HistoricalBalanceReview.projectBoundedStartOfDay
      image evidence "2026-06-01" [usdCash])
    "precedes bounded history start"
    "coordinate-specific bounded start was ignored"

  expectError
    (Loam.HistoricalBalanceReview.projectBoundedStartOfDay
      image
      { evidence with bounded := Loam.BoundedHistorySupport.Evidence.empty }
      "2026-06-02" [cash])
    "bounded history support missing"
    "historical reconstruction proceeded without bounded support"

  expectError
    (Loam.HistoricalBalanceReview.projectBoundedStartOfDay
      image
      { evidence with anchor := Loam.CurrentQuantityAnchor.Evidence.empty }
      "2026-06-02" [cash])
    "exact current anchor missing"
    "historical reconstruction proceeded without exact current anchor"

  let staleAnchor ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists?
      [⟨"ghost-root"⟩]
      [{ coordinate := cash, quantity := Quantity.ofQuanta 132 }])
    "stale historical anchor fixture"
  expectError
    (Loam.HistoricalBalanceReview.projectBoundedStartOfDay
      image { evidence with anchor := staleAnchor } "2026-06-02" [cash])
    "stable correction root"
    "stale current anchor was accepted by historical reconstruction"

  let overlapZero ← requireSome
    (ZeroOriginCoverage.ofCoordinates? [cash])
    "zero-origin overlap fixture"
  expectError
    (Loam.HistoricalBalanceReview.projectBoundedStartOfDay
      image { evidence with zeroOrigin := overlapZero } "2026-06-02" [cash])
    "competing support families"
    "zero-origin and bounded history overlap received silent precedence"

  let overlapOpening ← requireSome
    (OpeningSupportMap.ofSupports?
      [{ coordinate := cash, openingEvent := ⟨"deposit"⟩ }])
    "opening-support overlap fixture"
  expectError
    (Loam.HistoricalBalanceReview.projectBoundedStartOfDay
      image { evidence with opening := overlapOpening } "2026-06-02" [cash])
    "competing support families"
    "opening and bounded history overlap received silent precedence"

  expectError
    (Loam.HistoricalBalanceReview.projectBoundedStartOfDay
      image evidence "2026-02-30" [cash])
    "real YYYY-MM-DD"
    "invalid historical query date was accepted"

  -- Indexed lookup follows admitted Event identity, not list position. Missing
  -- and invalid dates are still refused at normalized admission before indexing.
  let dated ← event "indexed-dated" [effect cash 7, effect jpyOffset (-7)]
  let other ← event "indexed-other" [effect usdCash 9, effect usdOffset (-9)]
  let indexedEvents ← requireSome (EventMemory.ofEvents? [dated, other]) "indexed Events"
  let indexedCoverage ← requireSome (ZeroOriginCoverage.ofCoordinates? [cash, usdCash])
    "indexed coverage"
  let indexedSupport : Loam.HistoricalBalanceReview.Evidence := {
    zeroOrigin := indexedCoverage
    opening := OpeningSupportMap.empty
    bounded := Loam.BoundedHistorySupport.Evidence.empty
    anchor := Loam.CurrentQuantityAnchor.Evidence.empty }
  for otherDates in [[], [ActualValidityFact.base other.id "not-a-calendar-date"]] do
    let validity ← requireSome
      (ActualValidityHistory.ofParts? (.base dated.id "2026-06-01" :: otherDates) [])
      "indexed validity"
    expect (Loam.Persistence.admitActualImage? {
      Loam.ActualEvidence.empty with events := indexedEvents, validity := validity }).isNone
      "missing/invalid date was admitted before indexed reconstruction"
  let reversedDates ← requireSome
    (ActualValidityHistory.ofParts?
      [.base other.id "2026-06-01", .base dated.id "2026-06-01"] []) "reversed dates"
  let indexedImage ← requireSome (Loam.Persistence.admitActualImage? {
    Loam.ActualEvidence.empty with events := indexedEvents, validity := reversedDates })
    "indexed admitted image"
  let indexed ← requireOk
    (Loam.HistoricalBalanceReview.projectStartOfDay
      indexedImage indexedSupport "2026-06-02" [usdCash, cash]) "indexed coordinates"
  expect (quantityFor? indexed cash == some 7 && quantityFor? indexed usdCash == some 9)
    "indexed date lookup confused Event identity or coordinate order"

  IO.println
    "Historical Balance Review: bounded/zero routes, correction/date refinement, multimeasure independence, indexed date refusals and fail-closed support gates passed."
