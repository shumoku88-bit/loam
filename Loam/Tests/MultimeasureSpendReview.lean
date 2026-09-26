import Loam.MultimeasureSpendReview

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def effect
    (key locus measure : String)
    (quanta : Int) : Effect :=
  Effect.ofQuantity
    ⟨key⟩ ⟨locus⟩ ⟨measure⟩ (Quantity.ofQuanta quanta)

private def event
    (id : String)
    (effects : List Effect) : IO Event :=
  requireSome (Event.ofEffects? ⟨id⟩ effects) ("Event fixture " ++ id)

private def record
    (event : Event)
    (date : String)
    (description : String) : Loam.ActualReview.Record :=
  {
    event := event
    date := some date
    description := description
    replacement := none
  }

private def total
    (rows : List Loam.MultimeasureSpendReview.MeasureTotal)
    (measure : String) : Int :=
  match rows.find? fun row => row.measure.token == measure with
  | some row => row.quantity.quanta
  | none => 0

def main : IO Unit := do
  let debit ← event "debit-usd"
    [ effect "debit-bank" "bank-jpy" "jpy" (-4700)
    , effect "debit-food" "food" "jpy" 4700
    ]
  let cashPurchase ← event "cash-usd-purchase"
    [ effect "cash-usd-out" "cash-usd" "usd" (-2500)
    , effect "museum" "museum" "usd" 2500
    ]
  let eurDebit ← event "eur-debit-jpy-shop"
    [ effect "eur-bank" "bank-eur" "eur" (-7000)
    , effect "eur-hotel" "hotel" "eur" 7000
    ]
  let outbound ← event "exchange-jpy-usd"
    [ effect "out-source" "cash-jpy" "jpy" (-15100)
    , effect "out-destination" "cash-usd" "usd" 10000
    , effect "out-fee" "fx-fee" "jpy" 100
    ]
  let returning ← event "exchange-usd-jpy"
    [ effect "return-source" "cash-usd" "usd" (-4000)
    , effect "return-destination" "cash-jpy" "jpy" 6000
    ]
  let unresolved ← event "unresolved-ils"
    [ effect "unresolved-bank" "bank-jpy" "jpy" (-3000)
    , effect "unresolved-target" "mystery" "jpy" 3000
    ]
  let transfer ← event "asset-transfer"
    [ effect "transfer-source" "bank-jpy" "jpy" (-1000)
    , effect "transfer-destination" "cash-jpy" "jpy" 1000
    ]

  let roles ← requireSome
    (AccountingRoleMap.ofAssignments? [
      { locus := ⟨"bank-jpy"⟩, role := .asset },
      { locus := ⟨"food"⟩, role := .expense },
      { locus := ⟨"cash-usd"⟩, role := .asset },
      { locus := ⟨"museum"⟩, role := .expense },
      { locus := ⟨"bank-eur"⟩, role := .asset },
      { locus := ⟨"hotel"⟩, role := .expense },
      { locus := ⟨"cash-jpy"⟩, role := .asset },
      { locus := ⟨"fx-fee"⟩, role := .expense }
    ])
    "AccountingRole fixture"

  let exchanges ← requireSome
    (ExchangeEvidenceMemory.ofEntries? [
      {
        event := outbound.id
        source := ⟨"out-source"⟩
        destination := ⟨"out-destination"⟩
      },
      {
        event := returning.id
        source := ⟨"return-source"⟩
        destination := ⟨"return-destination"⟩
      }
    ])
    "ExchangeEvidence fixture"

  let originals : List Loam.Application.CurrentOriginalAmount := [
    {
      event := debit.id
      measure := ⟨"usd"⟩
      quantity := Quantity.ofQuanta 3000
    },
    {
      event := eurDebit.id
      measure := ⟨"jpy"⟩
      quantity := Quantity.ofQuanta 120000
    },
    {
      event := unresolved.id
      measure := ⟨"ils"⟩
      quantity := Quantity.ofQuanta 2000
    },
    {
      event := transfer.id
      measure := ⟨"eur"⟩
      quantity := Quantity.ofQuanta 500
    }
  ]

  let evidence : Loam.MultimeasureSpendReview.Evidence := {
    records := [
      record debit "2026-09-10" "JPY debit / USD shop amount",
      record cashPurchase "2026-09-11" "USD cash purchase",
      record eurDebit "2026-09-12" "EUR debit / JPY shop amount",
      record outbound "2026-09-13" "JPY to USD",
      record returning "2026-09-14" "USD to JPY",
      record unresolved "2026-09-15" "unresolved original amount",
      record transfer "2026-09-16" "asset transfer"
    ]
    roles := roles
    originalAmounts := originals
    exchanges := exchanges
  }

  let .ok snapshot :=
      Loam.MultimeasureSpendReview.project
        evidence "2026-09-01" "2026-10-01"
    | throw (IO.userError "qualified multicurrency spending fixture refused")

  expect (total snapshot.accountingExpense "jpy" == 4700)
    "JPY ordinary Expense did not stay separate from exchange fee"
  expect (total snapshot.accountingExpense "usd" == 2500)
    "USD cash spending was not retained as ordinary same-Measure Expense"
  expect (total snapshot.accountingExpense "eur" == 7000)
    "EUR household spending was not handled symmetrically"
  expect (total snapshot.exchangeExpense "jpy" == 100)
    "exchange-associated JPY fee Expense was mixed into ordinary spend or lost"
  expect (total snapshot.exchangeExpense "usd" == 0)
    "exchange source/destination quantities were misclassified as Expense"

  expect (total snapshot.originalPresentedExpense "usd" == 3000)
    "USD OriginalAmountEvidence was not projected as presented spend"
  expect (total snapshot.originalPresentedExpense "jpy" == 120000)
    "JPY OriginalAmountEvidence for an EUR household was not Measure-symmetric"
  expect (total snapshot.originalPresentedExpense "ils" == 0)
    "unresolved ILS original amount was silently counted as spend"
  expect (total snapshot.originalPresentedExpense "eur" == 0)
    "fully classified asset transfer OriginalAmountEvidence became false spend"

  expect (snapshot.unresolvedExpenseEffects.length == 1)
    "unresolved ordinary Effect witness count changed"
  let [unresolvedEffect] := snapshot.unresolvedExpenseEffects
    | throw (IO.userError "expected one unresolved ordinary Effect")
  expect (unresolvedEffect.event == unresolved.id &&
      unresolvedEffect.effect.locus.token == "mystery")
    "unresolved ordinary Effect lost its Event/Locus witness"

  expect (snapshot.unresolvedOriginalAmounts.length == 1)
    "unresolved OriginalAmount witness count changed"
  let [unresolvedOriginal] := snapshot.unresolvedOriginalAmounts
    | throw (IO.userError "expected one unresolved OriginalAmount")
  expect (unresolvedOriginal.event == unresolved.id &&
      unresolvedOriginal.measure.token == "ils" &&
      unresolvedOriginal.quantity.quanta == 2000)
    "unresolved OriginalAmount lost exact Event/Measure/Quantity evidence"

  expect (snapshot.unresolvedExchangeEffects.isEmpty)
    "fully classified exchange Effects became unresolved"
  expect (snapshot.exchanges.length == 2)
    "exchange occurrences were not retained separately from spend"

  let [firstExchange, secondExchange] := snapshot.exchanges
    | throw (IO.userError "expected outbound and return exchange occurrences")
  expect
    (firstExchange.source.measure.token == "jpy" &&
      firstExchange.source.quantity.quanta == -15100 &&
      firstExchange.destination.measure.token == "usd" &&
      firstExchange.destination.quantity.quanta == 10000)
    "outbound exchange exact source/destination Effects changed"
  expect
    (firstExchange.extraEffects.length == 1 &&
      (firstExchange.extraEffects[0]?).map (fun effect =>
        effect.locus.token == "fx-fee" &&
          effect.quantity.quanta == 100 &&
          effect.measure.token == "jpy") == some true)
    "fee-bearing exchange did not retain its extra Effect separately"
  expect
    (secondExchange.source.measure.token == "usd" &&
      secondExchange.destination.measure.token == "jpy")
    "return exchange acquired a home/foreign direction assumption"

  match Loam.MultimeasureSpendReview.project
      evidence "2026-10-01" "2026-09-01" with
  | .error _ => pure ()
  | .ok _ =>
      throw (IO.userError "reversed multicurrency spending window was accepted")

  IO.println
    "Multimeasure Spend Review: separate ordinary expense, exchange expense, original presented amounts, unresolved evidence and direction-neutral exchanges passed."
