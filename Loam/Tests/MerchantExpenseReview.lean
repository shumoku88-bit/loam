import Loam.MerchantExpenseReview

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def effect
    (key locus measure : String) (quanta : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ ⟨locus⟩ ⟨measure⟩ (Quantity.ofQuanta quanta)

private def makeEvent
    (id : String) (effects : List Effect) : IO Event :=
  requireSome (Event.ofEffects? ⟨id⟩ effects) ("event " ++ id)

private def record
    (event : Event) (date description : String) : Loam.ActualReview.Record :=
  { event := event, date := some date, description := description, replacement := none }

private def makeMerchants
    (entries : List EventMerchantEvidence) : IO EventMerchantEvidenceMemory :=
  requireSome (EventMerchantEvidenceMemory.ofEntries? entries) "Merchant memory"

private def makeRoles
    (assignments : List AccountingRoleAssignment) : IO AccountingRoleMap :=
  requireSome (AccountingRoleMap.ofAssignments? assignments) "AccountingRole map"

private def findContribution?
    (snapshot : Loam.MerchantExpenseReview.Snapshot)
    (event : EventId) : Option Loam.MerchantExpenseReview.Contribution :=
  snapshot.contributions.find? fun row => row.event == event

def main : IO Unit := do
  let purchase ← makeEvent "purchase" [
    effect "p-wallet" "wallet" "jpy" (-105),
    effect "p-food" "food" "jpy" 80,
    effect "p-tobacco" "tobacco" "jpy" 20,
    effect "p-mystery" "mystery" "jpy" 5
  ]
  let refund ← makeEvent "refund" [
    effect "r-wallet" "wallet" "jpy" 30,
    effect "r-food" "food" "jpy" (-30)
  ]
  let other ← makeEvent "other" [
    effect "o-wallet" "wallet" "jpy" (-50),
    effect "o-unknown" "other-unknown" "jpy" 50
  ]
  let rent ← makeEvent "rent" [
    effect "l-wallet" "wallet" "jpy" (-500),
    effect "l-rent" "rent" "jpy" 500
  ]
  let transfer ← makeEvent "transfer" [
    effect "t-wallet" "wallet" "jpy" (-25),
    effect "t-savings" "savings" "jpy" 25
  ]
  let unresolvedMerchant ← makeEvent "unresolved-merchant" [
    effect "u-wallet" "wallet" "jpy" (-10),
    effect "u-food" "food" "jpy" 10
  ]

  let records : List Loam.ActualReview.Record := [
    record purchase "2026-09-01" "purchase",
    record refund "2026-09-02" "refund",
    record other "2026-09-03" "other merchant",
    record rent "2026-09-04" "rent",
    record transfer "2026-09-05" "self transfer",
    record unresolvedMerchant "2026-09-06" "coverage gap"
  ]
  let .ok flow := Loam.TransactionsFlowReview.project records "2026-09-01" "2026-09-07"
    | throw (IO.userError "TransactionsFlow fixture refused")

  let shop : ExternalPartyId := ⟨"shop"⟩
  let otherParty : ExternalPartyId := ⟨"other-shop"⟩

  let partialMerchants ← makeMerchants [
    { event := purchase.id, disposition := .merchant shop },
    { event := refund.id, disposition := .merchant shop },
    { event := other.id, disposition := .merchant otherParty },
    { event := rent.id, disposition := .nonmerchant }
  ]
  let completeMerchants ← makeMerchants (partialMerchants.entries ++ [
    { event := unresolvedMerchant.id, disposition := .nonmerchant }
  ])

  let partialRoles ← makeRoles [
    { locus := ⟨"wallet"⟩, role := .asset },
    { locus := ⟨"savings"⟩, role := .asset },
    { locus := ⟨"food"⟩, role := .expense },
    { locus := ⟨"tobacco"⟩, role := .expense }
  ]
  let completeTargetRoles ← makeRoles (partialRoles.assignments ++ [
    { locus := ⟨"mystery"⟩, role := .expense }
  ])

  let jpy : MeasureId := ⟨"jpy"⟩
  let incompleteMerchant :=
    Loam.MerchantExpenseReview.project flow partialMerchants partialRoles shop jpy
  expect (incompleteMerchant.unresolvedMerchantEvents.map (·.event) ==
      [unresolvedMerchant.id])
    "Merchant coverage did not ignore an unclassified Event proven non-Expense for this query"
  expect (incompleteMerchant.unresolvedRoleEffects.length == 1)
    "target Merchant role gap was not retained independently"
  expect (incompleteMerchant.knownTotal.quanta == 70)
    "known target Merchant Expense contribution changed"
  expect incompleteMerchant.exactTotal?.isNone
    "partial Merchant coverage was exposed as exact"

  let roleIncomplete :=
    Loam.MerchantExpenseReview.project flow completeMerchants partialRoles shop jpy
  expect roleIncomplete.unresolvedMerchantEvents.isEmpty
    "explicit nonmerchant did not close Merchant coverage"
  expect (roleIncomplete.unresolvedRoleEffects.length == 1)
    "target Merchant AccountingRole gap disappeared"
  expect roleIncomplete.exactTotal?.isNone
    "missing target AccountingRole evidence was exposed as exact"

  let exact :=
    Loam.MerchantExpenseReview.project flow completeMerchants completeTargetRoles shop jpy
  expect exact.unresolvedMerchantEvents.isEmpty
    "complete Merchant disposition still reported a coverage gap"
  expect exact.unresolvedRoleEffects.isEmpty
    "complete target Merchant roles still reported a role gap"
  let some total := exact.exactTotal?
    | throw (IO.userError "complete Merchant query did not expose an exact total")
  expect (total.quanta == 75)
    "exact Merchant Expense total did not derive purchase plus signed refund"
  expect (exact.knownTotal.quanta == 75)
    "known total diverged from exact total after completeness closed"

  let some refundContribution := findContribution? exact refund.id
    | throw (IO.userError "signed refund contribution missing")
  expect (refundContribution.quantity.quanta == -30)
    "merchant refund did not retain negative Expense contribution"

  expect (findContribution? exact other.id).isNone
    "different Merchant leaked into target Merchant total"
  expect (findContribution? exact rent.id).isNone
    "explicit nonmerchant Event leaked into target Merchant total"
  expect (findContribution? exact transfer.id).isNone
    "unclassified non-Expense Event leaked into target Merchant total"
  expect exact.exactTotal?.isSome
    "unresolved roles on other-Merchant/nonmerchant Events blocked target exactness"

  let points :=
    Loam.MerchantExpenseReview.project flow partialMerchants partialRoles shop ⟨"points"⟩
  expect points.unresolvedMerchantEvents.isEmpty
    "other-Measure query was blocked by unrelated Merchant classification gaps"
  let some pointsTotal := points.exactTotal?
    | throw (IO.userError "other-Measure query was blocked by unrelated evidence")
  expect (pointsTotal.quanta == 0)
    "other-Measure Merchant query did not derive exact zero"

  IO.println
    "Merchant Expense Review: Merchant coverage, role coverage, signed derivation and exactness boundary passed."
