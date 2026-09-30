import Loam.Export.PlainTextAccountingExport

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def balancedEvent
    (id left right measure : String) (amount : Int) : IO Event := do
  requireSome
    (Event.ofEffects? ⟨id⟩
      [ Effect.ofAnonymousQuantity ⟨left⟩ ⟨measure⟩ (Quantity.ofQuanta (-amount))
      , Effect.ofAnonymousQuantity ⟨right⟩ ⟨measure⟩ (Quantity.ofQuanta amount)
      ])
    ("event admission failed: " ++ id)

def main : IO Unit := do
  let roles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [ { locus := ⟨"checking"⟩, role := .asset }
      , { locus := ⟨"software"⟩, role := .expense }
      , { locus := ⟨"pension"⟩, role := .income }
      , { locus := ⟨"personal-loan"⟩, role := .liability }
      , { locus := ⟨"equity:opening-balances"⟩, role := .equity }
      ])
    "role fixture"

  let event ← balancedEvent "event-1" "checking" "software" "jpy" 3000
  let entry : Loam.ActualJournalProjection.Entry := {
    event := event
    validOn := "2026-09-15"
    description := some "ChatGPT Plus; monthly\ncharge"
  }
  let .ok rendered := Loam.PlainTextAccountingExport.renderWithPresentation? [] roles [entry]
    | throw (IO.userError "balanced PTA export refused")

  expect (contains "2026-09-15 ChatGPT Plus, monthly charge" rendered)
    "transaction heading was not normalized into one safe line"
  expect (contains "    ; loam-event-id: event-1" rendered)
    "LOAM Event identity was not retained as a transaction comment"
  expect (contains "    assets:checking  -3000 jpy" rendered)
    "Asset role did not project to assets: account prefix"
  expect (contains "    expenses:software  3000 jpy" rendered)
    "Expense role did not project to expenses: account prefix"

  let incomeEvent ← balancedEvent "event-income" "pension" "checking" "jpy" 1000
  let incomeEntry : Loam.ActualJournalProjection.Entry := {
    event := incomeEvent
    validOn := "2026-09-15"
    description := some "income"
  }
  let .ok incomeRendered := Loam.PlainTextAccountingExport.renderWithPresentation? [] roles [incomeEntry]
    | throw (IO.userError "income PTA export refused")
  expect (contains "    income:pension  -1000 jpy" incomeRendered)
    "Income sign was rewritten instead of preserving LOAM quantity"
  expect (contains "    assets:checking  1000 jpy" incomeRendered)
    "Asset side of income Event changed sign"

  let liabilityEvent ← balancedEvent "event-liability" "checking" "personal-loan" "jpy" 500
  let liabilityEntry : Loam.ActualJournalProjection.Entry := {
    event := liabilityEvent
    validOn := "2026-09-15"
    description := some "repayment"
  }
  let .ok liabilityRendered :=
      Loam.PlainTextAccountingExport.renderWithPresentation? [] roles [liabilityEntry]
    | throw (IO.userError "liability PTA export refused")
  expect (contains "    liabilities:personal-loan  500 jpy" liabilityRendered)
    "Liability sign was rewritten instead of preserving LOAM quantity"

  let openingEvent ← balancedEvent
    "event-opening" "equity:opening-balances" "checking" "jpy" 100
  let openingEntry : Loam.ActualJournalProjection.Entry := {
    event := openingEvent
    validOn := "2026-09-15"
    description := some "opening"
  }
  let .ok openingRendered :=
      Loam.PlainTextAccountingExport.renderWithPresentation? [] roles [openingEntry]
    | throw (IO.userError "opening PTA export refused")
  expect (contains "    equity:opening-balances  -100 jpy" openingRendered)
    "already role-prefixed Locus was prefixed twice"
  expect (!contains "equity:equity:opening-balances" openingRendered)
    "explicit role prefix duplicated in PTA account name"

  let usdEvent ← balancedEvent "event-usd" "checking" "software" "usd" 1234
  let usdEntry : Loam.ActualJournalProjection.Entry := {
    event := usdEvent
    validOn := "2026-09-15"
    description := some "USD charge"
  }
  let presentation : List Loam.MeasurePresentation.Metadata :=
    [{ measure := ⟨"usd"⟩, scale := 2 }]
  let .ok usdRendered :=
      Loam.PlainTextAccountingExport.renderWithPresentation? presentation roles [usdEntry]
    | throw (IO.userError "scaled USD PTA export refused")
  expect (contains "    assets:checking  -12.34 usd" usdRendered)
    "PTA asset posting did not preserve USD scale"
  expect (contains "    expenses:software  12.34 usd" usdRendered)
    "PTA expense posting did not preserve USD scale"

  let unresolved ← balancedEvent "event-2" "checking" "legacy-bucket" "jpy" 500
  let unresolvedEntry : Loam.ActualJournalProjection.Entry := {
    event := unresolved
    validOn := "2026-09-16"
    description := none
  }
  let .ok unresolvedRendered :=
      Loam.PlainTextAccountingExport.renderWithPresentation? [] roles [unresolvedEntry]
    | throw (IO.userError "unresolved role should remain exportable")
  expect (contains "    unclassified:legacy-bucket  500 jpy" unresolvedRendered)
    "unresolved AccountingRole was not kept visibly unclassified"

  let unbalanced ← requireSome
    (Event.ofEffects? ⟨"event-unbalanced"⟩
      [Effect.ofAnonymousQuantity ⟨"checking"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-100))])
    "unbalanced Event fixture admission"
  let unbalancedEntry : Loam.ActualJournalProjection.Entry := {
    event := unbalanced
    validOn := "2026-09-17"
    description := some "not representable"
  }
  match Loam.PlainTextAccountingExport.renderWithPresentation? [] roles [unbalancedEntry] with
  | .ok _ => throw (IO.userError "unbalanced Event was exported as ordinary PTA")
  | .error message =>
      expect (contains "per-Measure balance" message)
        "unbalanced refusal did not explain the representability boundary"

  let empty ← requireSome (Event.ofEffects? ⟨"event-empty"⟩ []) "empty Event fixture"
  let emptyEntry : Loam.ActualJournalProjection.Entry := {
    event := empty
    validOn := "2026-09-18"
    description := none
  }
  match Loam.PlainTextAccountingExport.renderWithPresentation? [] roles [emptyEntry] with
  | .ok _ => throw (IO.userError "effect-free Event was exported as ordinary PTA")
  | .error message =>
      expect (contains "effect-free Event" message)
        "effect-free refusal did not explain the representability boundary"

  IO.println "Plain Text Accounting export: role prefixes, unresolved visibility, safe description, and fail-closed balance checks passed."
