import Loam.TransactionsFlowReview

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def effect
    (key locus measure : String) (quantity : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ ⟨locus⟩ ⟨measure⟩ (Quantity.ofQuanta quantity)

private def event? (id : String) (effects : List Effect) : Option Event :=
  Event.ofEffects? ⟨id⟩ effects

private def record
    (event : Event) (date : Option String)
    (description : String := "") (isCurrent : Bool := true) :
    Loam.ActualReview.Record :=
  {
    event := event
    date := date
    description := description
    replacement := none
    isCurrent := isCurrent
  }

private def ids (snapshot : Loam.TransactionsFlowReview.Snapshot) : List String :=
  snapshot.columns.map fun column => column.event.id.token

private def rowTokens
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : List (String × String) :=
  snapshot.rows.map fun coordinate =>
    (coordinate.locus.token, coordinate.measure.token)


def main : IO Unit := do
  let some original := event? "original"
      [effect "o1" "paypay" "jpy" (-9999), effect "o2" "food" "jpy" 9999]
    | throw (IO.userError "original Event fixture was rejected")
  let some replacement := event? "replacement"
      [ effect "r1" "paypay" "jpy" (-1000)
      , effect "r2" "food" "jpy" 600
      , effect "r3" "book" "jpy" 400
      ]
    | throw (IO.userError "replacement Event fixture was rejected")
  let some later := event? "later"
      [effect "l1" "smbc" "jpy" (-2470), effect "l2" "book" "jpy" 2470]
    | throw (IO.userError "later Event fixture was rejected")
  let some before := event? "before"
      [effect "b1" "paypay" "jpy" (-100), effect "b2" "food" "jpy" 100]
    | throw (IO.userError "before Event fixture was rejected")
  let some after := event? "after"
      [effect "a1" "paypay" "jpy" (-200), effect "a2" "food" "jpy" 200]
    | throw (IO.userError "after Event fixture was rejected")

  let records :=
    [ record later (some "2026-09-15") "later"
    , record original (some "2026-09-04") "superseded" false
    , record after (some "2026-10-01") "exclusive end"
    , record replacement (some "2026-09-05") "replacement"
    , record before (some "2026-08-31") "before"
    ]

  let snapshot ←
    match Loam.TransactionsFlowReview.project records "2026-09-01" "2026-10-01" with
    | .error message => throw (IO.userError message)
    | .ok snapshot => pure snapshot

  expect (ids snapshot == ["replacement", "later"])
    "Transactions-Flow columns did not use current explicit-date order"
  expect (rowTokens snapshot ==
      [("book", "jpy"), ("food", "jpy"), ("paypay", "jpy"), ("smbc", "jpy")])
    "Transactions-Flow rows were not the represented EffectCoordinates"

  let bookJpy : EffectCoordinate := ⟨⟨"book"⟩, ⟨"jpy"⟩⟩
  let foodJpy : EffectCoordinate := ⟨⟨"food"⟩, ⟨"jpy"⟩⟩
  let paypayJpy : EffectCoordinate := ⟨⟨"paypay"⟩, ⟨"jpy"⟩⟩

  expect ((Loam.TransactionsFlowReview.cellAt snapshot foodJpy ⟨"replacement"⟩).map
      (·.quanta) == some 600)
    "Transactions-Flow cell lost the selected Event quantity"
  expect ((Loam.TransactionsFlowReview.cellAt snapshot foodJpy ⟨"original"⟩).isNone)
    "superseded Event leaked into Transactions-Flow columns"
  expect ((Loam.TransactionsFlowReview.rowTotal snapshot bookJpy).quanta == 2870)
    "Transactions-Flow row total was wrong"

  let bookActivity := Loam.TransactionsFlowReview.rowActivity snapshot bookJpy
  expect (bookActivity.net.quanta == 2870 &&
      bookActivity.positive.quanta == 2870 &&
      bookActivity.negative.quanta == 0 &&
      bookActivity.gross.quanta == 2870 &&
      bookActivity.activeEvents == 2)
    "Transactions-Flow row activity did not preserve two Event contributions"

  let paypayActivity := Loam.TransactionsFlowReview.rowActivity snapshot paypayJpy
  expect (paypayActivity.net.quanta == -1000 &&
      paypayActivity.positive.quanta == 0 &&
      paypayActivity.negative.quanta == -1000 &&
      paypayActivity.gross.quanta == 1000 &&
      paypayActivity.activeEvents == 1)
    "Transactions-Flow signed row activity was wrong"

  match Loam.TransactionsFlowReview.project records "2026-10-01" "2026-09-01" with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "reversed Transactions-Flow window was accepted")

  let undatedRecords := record replacement none "undated" :: records
  match Loam.TransactionsFlowReview.project undatedRecords "2026-09-01" "2026-10-01" with
  | .error message =>
      expect ((message.splitOn "no occurrence date").length > 1)
        "undated current Event refusal lost its evidence explanation"
  | .ok _ => throw (IO.userError "undated current quantity Event was silently positioned")

  let invalidRecords := record replacement (some "2026-02-29") "invalid" :: records
  match Loam.TransactionsFlowReview.project invalidRecords "2026-09-01" "2026-10-01" with
  | .error message =>
      expect ((message.splitOn "invalid occurrence date").length > 1)
        "invalid-date current Event refusal lost its evidence explanation"
  | .ok _ => throw (IO.userError "invalid current quantity Event was silently positioned")

  let some emptyEvent := event? "empty" []
    | throw (IO.userError "empty Event fixture was rejected")
  match Loam.TransactionsFlowReview.project
      (record emptyEvent none "empty" :: records) "2026-09-01" "2026-10-01" with
  | .error message => throw (IO.userError ("empty undated Event blocked quantity matrix: " ++ message))
  | .ok emptySnapshot =>
      expect (ids emptySnapshot == ["replacement", "later"])
        "empty undated Event became a quantity column"

  let some mixed := event? "mixed"
      [ effect "m1" "cash" "jpy" (-100)
      , effect "m2" "food" "jpy" 100
      , effect "m3" "point" "point" 3
      ]
    | throw (IO.userError "mixed-Measure Event fixture was rejected")
  let mixedSnapshot ←
    match Loam.TransactionsFlowReview.project
        [record mixed (some "2026-09-20") "mixed"] "2026-09-01" "2026-10-01" with
    | .error message => throw (IO.userError message)
    | .ok selected => pure selected
  let [mixedColumn] := mixedSnapshot.columns
    | throw (IO.userError "mixed-Measure fixture did not yield one column")
  expect ((Loam.TransactionsFlowReview.measureResidual mixedColumn ⟨"jpy"⟩).quanta == 0)
    "JPY residual mixed another Measure"
  expect ((Loam.TransactionsFlowReview.measureResidual mixedColumn ⟨"point"⟩).quanta == 3)
    "point residual was lost or mixed with JPY"

  let some neutral := event? "neutral" [effect "n1" "income" "jpy" 500]
    | throw (IO.userError "neutral Core Event fixture was rejected")
  let neutralSnapshot ←
    match Loam.TransactionsFlowReview.project
        [record neutral (some "2026-09-21") "neutral"] "2026-09-01" "2026-10-01" with
    | .error message => throw (IO.userError message)
    | .ok selected => pure selected
  let [neutralColumn] := neutralSnapshot.columns
    | throw (IO.userError "neutral fixture did not yield one column")
  expect ((Loam.TransactionsFlowReview.measureResidual neutralColumn ⟨"jpy"⟩).quanta == 500)
    "nonzero neutral Core residual was rejected or hidden"

  let some income := event? "income"
      [effect "i1" "lesson-income" "jpy" (-30000), effect "i2" "cash" "jpy" 30000]
    | throw (IO.userError "income fixture was rejected")
  let some deposit := event? "deposit"
      [effect "d1" "cash" "jpy" (-30000), effect "d2" "smbc" "jpy" 30000]
    | throw (IO.userError "deposit fixture was rejected")
  let circulation ←
    match Loam.TransactionsFlowReview.project
        [ record deposit (some "2026-09-06") "cash to smbc"
        , record income (some "2026-09-01") "lesson income"
        ] "2026-09-01" "2026-09-10" with
    | .error message => throw (IO.userError message)
    | .ok selected => pure selected
  let cashJpy : EffectCoordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩
  let cashActivity := Loam.TransactionsFlowReview.rowActivity circulation cashJpy
  expect (cashActivity.net.quanta == 0 &&
      cashActivity.positive.quanta == 30000 &&
      cashActivity.negative.quanta == -30000 &&
      cashActivity.gross.quanta == 60000 &&
      cashActivity.activeEvents == 2)
    "zero-net circulation was collapsed into an inactive row"

  IO.println "Transactions-Flow Review: correction-aware window, incidence cells, row activity, Measure residuals and fail-closed date boundaries passed."
