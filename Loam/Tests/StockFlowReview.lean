import Loam.Persistence.BoundedHistorySupportPersistence
import Loam.Persistence.CurrentQuantityAnchorPersistence
import Loam.Persistence.ZeroOriginCoveragePersistence
import Loam.Review.StockFlowReview
import Loam.Tests.ActualWorldFixture

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

private def effectIn
    (key locus measure : String) (quantity : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ ⟨locus⟩ ⟨measure⟩ (Quantity.ofQuanta quantity)

private def effect (key locus : String) (quantity : Int) : Effect :=
  effectIn key locus "jpy" quantity

private def event? (id : String) (effects : List Effect) : Option Event :=
  Event.ofEffects? ⟨id⟩ effects

private def record (event : Event) (date : Option String) (isCurrent : Bool := true) :
    Loam.ActualReview.Record :=
  {
    event := event
    date := date
    description := ""
    replacement := if isCurrent then none else some ⟨"fixture-replacement"⟩
  }

private def historicalStart
    (date : String)
    (rows : List Loam.BalanceReview.Row) :
    Loam.HistoricalBalanceReview.Snapshot :=
  {
    startOfDay := date
    rows := rows.map fun row =>
      { coordinate := row.coordinate, quantity := row.quantity }
  }

private def boundedIntegration : IO Unit := do
  let cash : EffectCoordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩
  let offset : EffectCoordinate := ⟨⟨"offset"⟩, ⟨"jpy"⟩⟩
  let expense : EffectCoordinate := ⟨⟨"expense"⟩, ⟨"jpy"⟩⟩
  let some deposit := event? "bounded-deposit"
      [ effect "bd1" "cash" 100
      , effect "bd2" "offset" (-100)
      ]
    | throw (IO.userError "bounded deposit fixture was rejected")
  let some spend := event? "bounded-spend"
      [ effect "bs1" "cash" (-20)
      , effect "bs2" "expense" 20
      ]
    | throw (IO.userError "bounded spend fixture was rejected")
  let some later := event? "bounded-later"
      [ effect "bl1" "cash" 10
      , effect "bl2" "offset" (-10)
      ]
    | throw (IO.userError "bounded later fixture was rejected")
  let events ← requireSome
    (EventMemory.ofEvents? [deposit, spend, later])
    "bounded Stock-Flow Event memory"
  let validity ← requireSome
    (ActualValidityHistory.ofParts?
      [ .base deposit.id "2026-06-01"
      , .base spend.id "2026-06-03"
      , .base later.id "2026-06-10"
      ]
      [])
    "bounded Stock-Flow validity history"
  let actual : Loam.ActualEvidence := {
    Loam.ActualEvidence.empty with
      events := events
      validity := validity
  }

  let root ← IO.FS.createTempDir
  let .ok () ← Loam.ActualAuthority.publishActual? root actual
    | throw (IO.userError "publish bounded Stock-Flow Actual")
  IO.FS.createDirAll (root / "config")
  IO.FS.writeFile (root / "config" / "balance-view.tsv") "cash\tjpy\n"

  let zeroOriginBody ← requireSome
    (Loam.Persistence.encodeZeroOriginCoverage? ZeroOriginCoverage.empty)
    "encode bounded Stock-Flow empty zero-origin coverage"
  let .ok () ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "ZeroOrigin" zeroOriginBody
    | throw (IO.userError "publish bounded Stock-Flow Household zero-origin coverage")

  let roots ← requireSome
    (Loam.Application.correctionRootIds? actual.events actual.corrections)
    "bounded Stock-Flow correction roots"
  let anchor ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists?
      roots
      [{ coordinate := cash, quantity := Quantity.ofQuanta 90 }])
    "bounded Stock-Flow current anchor"
  let anchorBody ← requireSome
    (Loam.Persistence.encodeCurrentQuantityAnchor? anchor)
    "encode bounded Stock-Flow Household current anchor"
  let .ok () ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "CurrentQuantityAnchor" anchorBody
    | throw (IO.userError "publish bounded Stock-Flow Household current anchor")
  expect
    (← Loam.Persistence.saveCurrentQuantityAnchor?
      (Loam.HouseholdPaths.currentQuantityAnchor root) anchor)
    "save bounded Stock-Flow frozen legacy current anchor"
  let frozenLegacyAnchor ←
    IO.FS.readFile (Loam.HouseholdPaths.currentQuantityAnchor root)

  let bounded ← requireSome
    (Loam.BoundedHistorySupport.Evidence.ofSupports?
      [{ coordinate := cash, startDay := "2026-06-01" }])
    "bounded Stock-Flow support"
  let boundedBody ← requireSome
    (Loam.Persistence.encodeBoundedHistorySupport? bounded)
    "encode bounded Stock-Flow Household historical support"
  let .ok () ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "BoundedHistorySupport" boundedBody
    | throw (IO.userError "publish bounded Stock-Flow Household historical support")
  expect
    (← Loam.Persistence.saveBoundedHistorySupport?
      (Loam.HouseholdPaths.boundedHistorySupport root) bounded)
    "save bounded Stock-Flow frozen legacy historical support"
  let frozenLegacyBounded ←
    IO.FS.readFile (Loam.HouseholdPaths.boundedHistorySupport root)

  let snapshot ← requireOk
    (← Loam.StockFlowReview.loadSnapshot
      root root "2026-06-02" "2026-06-09")
    "load bounded Stock-Flow"
  expect (snapshot.reconstructedStart.quanta == 100)
    "bounded Stock-Flow did not reconstruct its exact historical start"
  expect (snapshot.decreasesAcrossEvents.quanta == -20)
    "bounded Stock-Flow lost the selected window outflow"
  expect (snapshot.increasesAcrossEvents.quanta == 0)
    "bounded Stock-Flow invented a window inflow"
  expect (snapshot.reconstructedEnd.quanta == 80)
    "bounded Stock-Flow closing boundary did not equal start plus flow"
  expect (snapshot.currentTracked.quanta == 90)
    "bounded Stock-Flow current context did not use the exact current anchor"
  expect
    ((← IO.FS.readFile (Loam.HouseholdPaths.currentQuantityAnchor root)) ==
      frozenLegacyAnchor)
    "Stock-Flow production read changed frozen legacy current anchor"
  expect
    ((← IO.FS.readFile (Loam.HouseholdPaths.boundedHistorySupport root)) ==
      frozenLegacyBounded)
    "Stock-Flow production read changed frozen legacy bounded support"

  let beforeStart ←
    Loam.StockFlowReview.loadSnapshot root root "2026-05-31" "2026-06-09"
  match beforeStart with
  | .error message =>
      expect ((message.splitOn "precedes bounded history start").length > 1)
        "bounded Stock-Flow pre-start refusal lost its explanation"
  | .ok _ =>
      throw (IO.userError "bounded Stock-Flow crossed before its certified start")

  -- Keep these names live in the fixture so coordinate independence remains explicit.
  expect (offset != cash && expense != cash)
    "bounded Stock-Flow fixture coordinates collapsed"

def main : IO Unit := do
  let some opening := event? "opening" [effect "o1" "bank" 100]
    | throw (IO.userError "opening Event fixture was rejected")
  let some transfer := event? "transfer"
      [effect "t1" "bank" (-30), effect "t2" "cash" 30]
    | throw (IO.userError "transfer Event fixture was rejected")
  let some use := event? "use" [effect "u1" "bank" (-10)]
    | throw (IO.userError "use Event fixture was rejected")
  let some later := event? "later" [effect "l1" "bank" 20]
    | throw (IO.userError "later Event fixture was rejected")
  let some superseded := event? "superseded" [effect "s1" "bank" 999]
    | throw (IO.userError "superseded Event fixture was rejected")

  let balances : Loam.BalanceReview.Snapshot := {
    rows :=
      [ { coordinate := ⟨⟨"bank"⟩, ⟨"jpy"⟩⟩, quantity := Quantity.ofQuanta 80 }
      , { coordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩, quantity := Quantity.ofQuanta 30 }
      ]
  }
  let startBalances :=
    historicalStart "2026-08-01"
      [ { coordinate := ⟨⟨"bank"⟩, ⟨"jpy"⟩⟩, quantity := Quantity.ofQuanta 100 }
      , { coordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩, quantity := Quantity.ofQuanta 0 }
      ]
  let records :=
    [ record opening (some "2026-07-01")
    , record transfer (some "2026-08-05")
    , record use (some "2026-08-10")
    , record later (some "2026-09-01")
    , record superseded (some "2026-08-20") false
    ]

  match Loam.StockFlowReview.project balances startBalances records
      "2026-08-01" "2026-09-01" with
  | .error message => throw (IO.userError message)
  | .ok snapshot =>
      expect (snapshot.measure == some (⟨"jpy"⟩ : MeasureId))
        "Stock–Flow did not preserve the selected JPY Measure"
      expect (snapshot.reconstructedStart.quanta == 100)
        "Stock–Flow start reconstruction was wrong"
      expect (snapshot.reconstructedEnd.quanta == 90)
        "Stock–Flow end reconstruction included the later Event or lost the window"
      expect (snapshot.increasesAcrossEvents.quanta == 0)
        "internal tracked transfer was misclassified as a tracked increase"
      expect (snapshot.decreasesAcrossEvents.quanta == -10)
        "window decrease total was wrong"
      expect (snapshot.netChange.quanta == -10)
        "Stock–Flow net change was wrong"
      expect (snapshot.currentTracked.quanta == 110)
        "current tracked context did not preserve the later Event"

  match Loam.StockFlowReview.project balances startBalances records
      "2026-09-01" "2026-08-01" with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "reversed Stock–Flow window was accepted")

  let some undated := event? "undated" [effect "d1" "cash" 1]
    | throw (IO.userError "undated Event fixture was rejected")
  match Loam.StockFlowReview.project balances startBalances
      (record undated none :: records) "2026-08-01" "2026-09-01" with
  | .error message =>
      expect ((message.splitOn "no occurrence date").length > 1)
        "undated selected Event refusal lost its evidence explanation"
  | .ok _ => throw (IO.userError "undated selected Event was silently positioned")

  let some invalid := event? "invalid" [effect "i1" "cash" 2]
    | throw (IO.userError "invalid-date Event fixture was rejected")
  match Loam.StockFlowReview.project balances startBalances
      (record invalid (some "2026-02-30") :: records)
      "2026-08-01" "2026-09-01" with
  | .error message =>
      expect ((message.splitOn "invalid occurrence date").length > 1)
        "invalid selected Event refusal lost its evidence explanation"
  | .ok _ => throw (IO.userError "invalid selected Event date was accepted")

  let some zeroUndated := event? "zero-undated"
      [effect "z1" "cash" 7, effect "z2" "cash" (-7)]
    | throw (IO.userError "zero-undated Event fixture was rejected")
  match Loam.StockFlowReview.project balances startBalances
      (record zeroUndated none :: records)
      "2026-08-01" "2026-09-01" with
  | .error message =>
      throw (IO.userError ("zero selected quantity unexpectedly required a date: " ++ message))
  | .ok snapshot =>
      expect (snapshot.reconstructedStart.quanta == 100)
        "zero-undated Event changed the opening boundary"
      expect (snapshot.reconstructedEnd.quanta == 90)
        "zero-undated Event changed the closing boundary"

  let some supersededUndated := event? "superseded-undated"
      [effect "su1" "cash" 999]
    | throw (IO.userError "superseded-undated Event fixture was rejected")
  match Loam.StockFlowReview.project balances startBalances
      (record supersededUndated none false :: records)
      "2026-08-01" "2026-09-01" with
  | .error message =>
      throw (IO.userError ("superseded undated Event affected Stock-Flow: " ++ message))
  | .ok snapshot =>
      expect (snapshot.reconstructedStart.quanta == 100)
        "superseded Event changed the opening boundary"
      expect (snapshot.reconstructedEnd.quanta == 90)
        "superseded Event changed the closing boundary"

  let mixedBalances : Loam.BalanceReview.Snapshot := {
    rows :=
      [ { coordinate := ⟨⟨"bank"⟩, ⟨"jpy"⟩⟩, quantity := Quantity.ofQuanta 80 }
      , { coordinate := ⟨⟨"cash"⟩, ⟨"usd"⟩⟩, quantity := Quantity.ofQuanta 30 }
      ]
  }
  let mixedStart :=
    historicalStart "2026-08-01"
      [ { coordinate := ⟨⟨"bank"⟩, ⟨"jpy"⟩⟩, quantity := Quantity.ofQuanta 100 }
      , { coordinate := ⟨⟨"cash"⟩, ⟨"usd"⟩⟩, quantity := Quantity.ofQuanta 30 }
      ]
  match Loam.StockFlowReview.project mixedBalances mixedStart records
      "2026-08-01" "2026-09-01" with
  | .error message =>
      expect
        (message == "loam: stock-flow selected balances span multiple measures")
        "mixed-Measure Stock-Flow refusal lost its explicit measure boundary"
  | .ok _ =>
      throw (IO.userError "mixed-Measure Stock-Flow silently summed unlike Measures")

  let some usdOpening := event? "usd-opening"
      [effectIn "uo1" "usd-cash" "usd" 30,
       effectIn "uo2" "usd-offset" "usd" (-30)]
    | throw (IO.userError "USD Stock-Flow fixture was rejected")
  let usdBalances : Loam.BalanceReview.Snapshot := {
    rows :=
      [ { coordinate := ⟨⟨"usd-cash"⟩, ⟨"usd"⟩⟩, quantity := Quantity.ofQuanta 30 } ]
  }
  let usdStart :=
    historicalStart "2026-08-01"
      [ { coordinate := ⟨⟨"usd-cash"⟩, ⟨"usd"⟩⟩, quantity := Quantity.ofQuanta 30 } ]
  match Loam.StockFlowReview.project usdBalances usdStart
      [record usdOpening (some "2026-07-01")]
      "2026-08-01" "2026-09-01" with
  | .error message =>
      throw (IO.userError ("single-Measure USD Stock-Flow failed: " ++ message))
  | .ok snapshot =>
      expect (snapshot.measure == some (⟨"usd"⟩ : MeasureId))
        "Stock–Flow did not preserve the selected USD Measure"
      expect (snapshot.reconstructedStart.quanta == 30)
        "USD Stock-Flow opening reconstruction was wrong"
      expect (snapshot.reconstructedEnd.quanta == 30)
        "USD Stock-Flow closing reconstruction was wrong"
      expect (snapshot.currentTracked.quanta == 30)
        "USD Stock-Flow current tracked quantity was wrong"

  match Loam.StockFlowReview.project balances startBalances [record undated none]
      "not-a-date" "2026-09-01" with
  | .error message =>
      expect (message == "loam: stock-flow endpoints must be real YYYY-MM-DD calendar dates")
        "record refusal overtook malformed endpoint priority"
  | .ok _ => throw (IO.userError "malformed Stock-Flow endpoint was accepted")

  match Loam.StockFlowReview.project balances startBalances [record undated none]
      "2026-09-01" "2026-08-01" with
  | .error message =>
      expect (message == "loam: stock-flow start must be earlier than end")
        "record refusal overtook reversed-window priority"
  | .ok _ => throw (IO.userError "reversed Stock-Flow window was accepted with failing records")

  let wrongBoundary := { startBalances with startOfDay := "2026-07-31" }
  match Loam.StockFlowReview.project balances wrongBoundary records
      "2026-08-01" "2026-09-01" with
  | .error message =>
      expect
        (message == "loam: stock-flow historical balance boundary does not match the requested start")
        "historical boundary mismatch lost its explicit refusal"
  | .ok _ => throw (IO.userError "mismatched historical start boundary was accepted")

  boundedIntegration

  IO.println
    "Stock–Flow Review: shared historical start, bounded integration, event-net aggregation, later-event separation and refusal boundaries passed."
