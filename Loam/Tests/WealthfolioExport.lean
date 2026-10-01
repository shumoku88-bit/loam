import Loam.Export.WealthfolioExport

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def effect
    (locus measure : String)
    (quanta : Int) : Effect :=
  Effect.ofAnonymousQuantity
    ⟨locus⟩ ⟨measure⟩ (Quantity.ofQuanta quanta)

private def event
    (id : String)
    (effects : List Effect) : IO Event :=
  requireSome (Event.ofEffects? ⟨id⟩ effects) ("Wealthfolio Event fixture " ++ id)

def main : IO Unit := do
  let roles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [ { locus := ⟨"smbc"⟩, role := .asset }
      , { locus := ⟨"cash"⟩, role := .asset }
      , { locus := ⟨"wise_usd"⟩, role := .asset }
      , { locus := ⟨"food"⟩, role := .expense }
      , { locus := ⟨"salary"⟩, role := .income }
      , { locus := ⟨"receivable"⟩, role := .asset }
      ])
    "Wealthfolio AccountingRole fixture"

  let opening : Loam.OpeningPositionReview.Snapshot := {
    accountingEpoch := "2026-09-01"
    rows :=
      [ { coordinate := ⟨⟨"smbc"⟩, ⟨"jpy"⟩⟩, quantity := Quantity.ofQuanta 10000 }
      , { coordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩, quantity := Quantity.ofQuanta 500 }
      , { coordinate := ⟨⟨"wise_usd"⟩, ⟨"usd"⟩⟩, quantity := Quantity.ofQuanta 0 }
      ]
  }

  let old ← event "old"
    [effect "smbc" "jpy" (-100), effect "food" "jpy" 100]
  let spend ← event "spend"
    [effect "smbc" "jpy" (-700), effect "food" "jpy" 700]
  let transfer ← event "transfer"
    [effect "smbc" "jpy" (-1000), effect "cash" "jpy" 1000]
  let income ← event "income"
    [effect "smbc" "jpy" 2000, effect "salary" "jpy" (-2000)]
  let receivableTransfer ← event "receivable-transfer"
    [effect "smbc" "jpy" (-300), effect "receivable" "jpy" 300]
  let usdSpend ← event "usd-spend"
    [effect "wise_usd" "usd" (-1234), effect "food" "usd" 1234]

  let entries : List Loam.ActualJournalProjection.Entry :=
    [ { event := old, validOn := "2026-08-31", description := some "before epoch" }
    , { event := spend, validOn := "2026-09-02", description := some "Lunch, \"good\"" }
    , { event := transfer, validOn := "2026-09-03", description := some "cash refill" }
    , { event := income, validOn := "2026-09-04", description := some "salary" }
    , { event := receivableTransfer, validOn := "2026-09-04", description := some "mother receivable" }
    , { event := usdSpend, validOn := "2026-09-05", description := some "travel food" }
    ]

  let presentation : List Loam.MeasurePresentation.Metadata :=
    [{ measure := ⟨"usd"⟩, scale := 2 }]

  let rendered ←
    match Loam.WealthfolioExport.renderWithPresentation?
        presentation roles [⟨"smbc"⟩, ⟨"cash"⟩, ⟨"wise_usd"⟩] opening entries with
    | .ok rendered => pure rendered
    | .error message => throw (IO.userError ("Wealthfolio export failed: " ++ message))

  expect (contains "date,symbol,activityType,currency,amount,account,comment" rendered)
    "Wealthfolio CSV header missing"
  expect (contains "2026-09-01,$CASH-JPY,DEPOSIT,JPY,500,\"cash\"" rendered)
    "cash opening position missing"
  expect (contains "2026-09-01,$CASH-JPY,DEPOSIT,JPY,10000,\"smbc\"" rendered)
    "SMBC opening position missing"
  expect (!contains "before epoch" rendered)
    "pre-epoch Actual leaked into Wealthfolio export"
  expect (contains "2026-09-02,$CASH-JPY,WITHDRAWAL,JPY,700,\"smbc\"" rendered)
    "expense did not become Asset withdrawal"
  expect (contains "\"Lunch, \"\"good\"\" | loam_event_id=spend" rendered)
    "CSV quoting did not preserve description and provenance"
  expect (contains "2026-09-03,$CASH-JPY,TRANSFER_OUT,JPY,1000,\"smbc\"" rendered)
    "Asset source transfer missing"
  expect (contains "2026-09-03,$CASH-JPY,TRANSFER_IN,JPY,1000,\"cash\"" rendered)
    "Asset destination transfer missing"
  expect (contains "2026-09-04,$CASH-JPY,DEPOSIT,JPY,2000,\"smbc\"" rendered)
    "income did not become Asset deposit"
  expect (contains "2026-09-04,$CASH-JPY,TRANSFER_OUT,JPY,300,\"smbc\"" rendered)
    "transfer to unselected Asset did not remain a transfer"
  expect (!contains "\"receivable\"" rendered)
    "unselected Asset leaked into Wealthfolio cash accounts"
  expect (contains "2026-09-05,$CASH-USD,WITHDRAWAL,USD,12.34,\"wise_usd\"" rendered)
    "Measure presentation scale was not retained"
  expect (!contains "2026-09-01,$CASH-USD,DEPOSIT,USD,0.00" rendered)
    "zero opening position should not create a target activity"

  let unresolved ← event "unresolved"
    [effect "smbc" "jpy" (-100), effect "mystery" "jpy" 100]
  match Loam.WealthfolioExport.renderWithPresentation?
      presentation roles [⟨"smbc"⟩, ⟨"cash"⟩, ⟨"wise_usd"⟩] opening
      [{ event := unresolved, validOn := "2026-09-06", description := none }] with
  | .ok _ => throw (IO.userError "unresolved AccountingRole was silently exported")
  | .error message =>
      expect (contains "explicit AccountingRole" message)
        "unresolved-role refusal did not explain the boundary"

  let nonCurrency ← event "points"
    [effect "smbc" "points" (-10), effect "food" "points" 10]
  match Loam.WealthfolioExport.renderWithPresentation?
      presentation roles [⟨"smbc"⟩, ⟨"cash"⟩, ⟨"wise_usd"⟩] opening
      [{ event := nonCurrency, validOn := "2026-09-06", description := none }] with
  | .ok _ => throw (IO.userError "non-currency Measure was silently exported")
  | .error message =>
      expect (contains "three-letter currency Measure" message)
        "non-currency refusal did not explain the boundary"

  IO.println
    "Wealthfolio cash export: opening positions, epoch filter, cash flow, transfers, scale, CSV quoting, and fail-closed role/currency checks passed."
