import Loam.StockFlowReview

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def effect (key locus : String) (quantity : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ ⟨locus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quantity)

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
  let records :=
    [ record opening (some "2026-07-01")
    , record transfer (some "2026-08-05")
    , record use (some "2026-08-10")
    , record later (some "2026-09-01")
    , record superseded (some "2026-08-20") false
    ]

  match Loam.StockFlowReview.project balances records "2026-08-01" "2026-09-01" with
  | .error message => throw (IO.userError message)
  | .ok snapshot =>
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

  match Loam.StockFlowReview.project balances records "2026-09-01" "2026-08-01" with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "reversed Stock–Flow window was accepted")

  let some undated := event? "undated" [effect "d1" "cash" 1]
    | throw (IO.userError "undated Event fixture was rejected")
  match Loam.StockFlowReview.project balances (record undated none :: records)
      "2026-08-01" "2026-09-01" with
  | .error message =>
      expect ((message.splitOn "no occurrence date").length > 1)
        "undated selected Event refusal lost its evidence explanation"
  | .ok _ => throw (IO.userError "undated selected Event was silently positioned")

  let some invalid := event? "invalid" [effect "i1" "cash" 2]
    | throw (IO.userError "invalid-date Event fixture was rejected")
  match Loam.StockFlowReview.project balances
      (record invalid (some "2026-02-30") :: records)
      "2026-08-01" "2026-09-01" with
  | .error message =>
      expect ((message.splitOn "invalid occurrence date").length > 1)
        "invalid selected Event refusal lost its evidence explanation"
  | .ok _ => throw (IO.userError "invalid selected Event date was accepted")

  let some zeroUndated := event? "zero-undated"
      [effect "z1" "cash" 7, effect "z2" "cash" (-7)]
    | throw (IO.userError "zero-undated Event fixture was rejected")
  match Loam.StockFlowReview.project balances
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
  match Loam.StockFlowReview.project balances
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
  match Loam.StockFlowReview.project mixedBalances records
      "2026-08-01" "2026-09-01" with
  | .error message =>
      expect
        (message == "loam: stock-flow currently requires an explicit JPY balance selection")
        "mixed-Measure Stock-Flow refusal lost its explicit measure boundary"
  | .ok _ =>
      throw (IO.userError "mixed-Measure Stock-Flow silently summed unlike Measures")

  match Loam.StockFlowReview.project balances [record undated none]
      "not-a-date" "2026-09-01" with
  | .error message =>
      expect (message == "loam: stock-flow endpoints must be real YYYY-MM-DD calendar dates")
        "record refusal overtook malformed endpoint priority"
  | .ok _ => throw (IO.userError "malformed Stock-Flow endpoint was accepted")

  match Loam.StockFlowReview.project balances [record undated none]
      "2026-09-01" "2026-08-01" with
  | .error message =>
      expect (message == "loam: stock-flow start must be earlier than end")
        "record refusal overtook reversed-window priority"
  | .ok _ => throw (IO.userError "reversed Stock-Flow window was accepted with failing records")

  IO.println "Stock–Flow Review: boundary reconstruction, event-net aggregation, later-event separation and undated refusal passed."
