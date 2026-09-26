import Loam.Core.EventMemory
import Loam.PracticalMovement

namespace Loam.Observation342

open Loam.Core

set_option autoImplicit false

/-!
# Observation 342 — debit-card original amount can remain Event-scoped evidence

Issue #1351 needs a practical answer for a common travel case:

    merchant presents 30 USD
    household uses a JPY-funded debit card
    bank account is charged 4,700 JPY almost immediately

For household accounting, the retained Movement may remain entirely JPY:

    bank  -4,700 JPY
    food  +4,700 JPY

The household did not first acquire and then spend 30 USD, so inserting a USD
accounting Effect would invent a foreign-currency holding.

But retaining only free-form description text loses a useful later question:

    "How much did I spend in locally presented currencies during this trip?"

This observation tests a smaller orthogonal candidate:

    OriginalAmountEvidence
      event
      measure
      quantity

The candidate records one positive amount observed for the Event in its original
presented / charged currency. It is not an accounting posting and does not
participate in balance.

The bounded pressure asks whether this is enough to:

- keep the debit-card purchase an ordinary JPY Movement;
- retain a structured 30-USD observation;
- aggregate original amounts by Measure;
- keep USD and ILS totals separate;
- reject duplicate or dangling Event claims;
- avoid treating the observed pair as canonical FX valuation.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def dollar : MeasureId := ⟨"usd"⟩
private def shekel : MeasureId := ⟨"ils"⟩

private def bank : LocusId := ⟨"bank"⟩
private def food : LocusId := ⟨"food"⟩
private def transport : LocusId := ⟨"transport"⟩

private def usdPurchaseId : EventId := ⟨"travel-debit-usd-food"⟩
private def ilsPurchaseId : EventId := ⟨"travel-debit-ils-transport"⟩

private def usdPurchase? : Option Event :=
  Event.ofEffects? usdPurchaseId [
    Effect.ofAnonymousQuantity bank yen (Quantity.ofQuanta (-4700)),
    Effect.ofAnonymousQuantity food yen (Quantity.ofQuanta 4700)
  ]

private def ilsPurchase? : Option Event :=
  Event.ofEffects? ilsPurchaseId [
    Effect.ofAnonymousQuantity bank yen (Quantity.ofQuanta (-3200)),
    Effect.ofAnonymousQuantity transport yen (Quantity.ofQuanta 3200)
  ]

private def travelEvents? : Option EventMemory := do
  let usdPurchase ← usdPurchase?
  let ilsPurchase ← ilsPurchase?
  EventMemory.ofEvents? [usdPurchase, ilsPurchase]

/--
The actual household accounting remains a normal single-Measure JPY Movement.
No USD Effect is needed merely because the merchant displayed USD.
-/
private def usdPurchaseIsOrdinaryJpyMovement : Bool :=
  match usdPurchase? with
  | none => false
  | some event =>
      (Loam.PracticalMovement.ofEffects? yen event.effects).isSome

theorem debit_purchase_remains_ordinary_jpy_movement :
    usdPurchaseIsOrdinaryJpyMovement = true := by
  native_decide

/--
One Event-scoped observed original amount.

`quantity` is positive observed magnitude only. Its sign carries no debit /
credit meaning, and the row does not participate in Event balance.
-/
structure OriginalAmountEvidence where
  event : EventId
  measure : MeasureId
  quantity : Quantity
deriving Repr, DecidableEq

/--
A small observation-local memory.

At most one original amount is retained for one Event. This is deliberately the
same cardinality shape as EventDescription / EventMerchantEvidence rather than a
new transaction hierarchy.
-/
structure OriginalAmountMemory where
  entries : List OriginalAmountEvidence
  eventNodup : (entries.map OriginalAmountEvidence.event).Nodup
deriving Repr

private def referencesKnownEvents
    (events : EventMemory)
    (entries : List OriginalAmountEvidence) : Bool :=
  entries.all fun evidence =>
    (EventMemory.findById? events evidence.event).isSome

private def allPositive
    (entries : List OriginalAmountEvidence) : Bool :=
  entries.all fun evidence => evidence.quantity.quanta > 0

/--
Admit only one positive original amount per existing Event.

No comparison is made with the Event's accounting Measure or Quantity. Such a
comparison would already begin to assign conversion semantics that this evidence
does not claim.
-/
def originalAmountsAgainst?
    (events : EventMemory)
    (entries : List OriginalAmountEvidence) : Option OriginalAmountMemory :=
  if hNodup : (entries.map OriginalAmountEvidence.event).Nodup then
    if referencesKnownEvents events entries && allPositive entries then
      some { entries := entries, eventNodup := hNodup }
    else
      none
  else
    none

private def usdOriginal : OriginalAmountEvidence := {
  event := usdPurchaseId
  measure := dollar
  quantity := Quantity.ofQuanta 3000
}

private def ilsOriginal : OriginalAmountEvidence := {
  event := ilsPurchaseId
  measure := shekel
  quantity := Quantity.ofQuanta 7800
}

/--
The structured original amount can coexist with the ordinary JPY accounting
Event without introducing a USD accounting Effect.
-/
theorem usd_original_amount_is_admitted_against_jpy_event :
    (do
      let events ← travelEvents?
      let memory ← originalAmountsAgainst? events [usdOriginal]
      pure memory.entries) =
      some [usdOriginal] := by
  native_decide

/--
Aggregate only within one explicit Measure.

There is intentionally no function here that adds USD and ILS together.
-/
def originalTotalAt
    (memory : OriginalAmountMemory)
    (measure : MeasureId) : Quantity :=
  Quantity.ofQuanta <|
    memory.entries.foldl
      (fun total evidence =>
        if evidence.measure = measure
        then total + evidence.quantity.quanta
        else total)
      0

private def tripOriginalTotals? : Option (Int × Int) := do
  let events ← travelEvents?
  let memory ← originalAmountsAgainst? events [usdOriginal, ilsOriginal]
  pure (
    (originalTotalAt memory dollar).quanta,
    (originalTotalAt memory shekel).quanta)

theorem travel_original_totals_remain_measure_separated :
    tripOriginalTotals? = some (3000, 7800) := by
  native_decide

/--
The same JPY accounting Event can coexist with different possible original
amount observations.

Therefore the accounting payload alone does not determine the foreign presented
amount; the latter is genuinely additional evidence rather than a derived FX
fact.
-/
private def alternativeUsdOriginal : OriginalAmountEvidence := {
  event := usdPurchaseId
  measure := dollar
  quantity := Quantity.ofQuanta 3200
}

theorem same_jpy_event_does_not_determine_original_amount :
    (do
      let events ← travelEvents?
      let left ← originalAmountsAgainst? events [usdOriginal]
      let right ← originalAmountsAgainst? events [alternativeUsdOriginal]
      pure (
        (originalTotalAt left dollar).quanta,
        (originalTotalAt right dollar).quanta,
        left.entries != right.entries)) =
      some (3000, 3200, true) := by
  native_decide

/--
Changing only original-amount evidence cannot alter the retained JPY accounting
quantity because the evidence lives outside Event Effects.
-/
theorem original_amount_evidence_does_not_change_jpy_accounting :
    (do
      let event ← usdPurchase?
      pure (
        (event.quantityAt bank yen).quanta,
        (event.quantityAt food yen).quanta)) =
      some (-4700, 4700) := by
  native_decide

private def missingEventOriginal : OriginalAmountEvidence := {
  event := ⟨"missing-event"⟩
  measure := dollar
  quantity := Quantity.ofQuanta 1000
}

/-- A dangling original-amount claim cannot enter the admitted memory. -/
theorem dangling_original_amount_is_refused :
    (do
      let events ← travelEvents?
      pure ((originalAmountsAgainst? events [missingEventOriginal]).isNone)) =
      some true := by
  native_decide

/--
Two competing original amounts for the same Event fail closed rather than using
representation order as authority.
-/
theorem duplicate_original_amount_for_one_event_is_refused :
    (do
      let events ← travelEvents?
      pure ((originalAmountsAgainst?
        events [usdOriginal, alternativeUsdOriginal]).isNone)) =
      some true := by
  native_decide

private def zeroOriginal : OriginalAmountEvidence := {
  event := usdPurchaseId
  measure := dollar
  quantity := Quantity.ofQuanta 0
}

/-- Zero / negative presented amounts are outside this selected evidence shape. -/
theorem nonpositive_original_amount_is_refused :
    (do
      let events ← travelEvents?
      pure ((originalAmountsAgainst? events [zeroOriginal]).isNone)) =
      some true := by
  native_decide

/-!
## Finding

For the selected debit-card travel pressure, one small Event-scoped evidence
family is sufficient to preserve the useful distinction:

    accounting truth
      bank -4,700 JPY
      food +4,700 JPY

    observed original amount
      30.00 USD

The two facts answer different questions and do not need to be forced into one
balanced cross-Measure Event.

This gives a plausible later travel report with two independent lenses:

    household cost
      derived from ordinary accounting Effects, e.g. JPY

    original presented spend
      grouped separately by Measure, e.g. USD / ILS / EUR

The observation does not assign conversion semantics to the pair. Even when a
human can compute 4,700 / 30, the retained evidence does not declare that ratio
to be:

- a market FX rate;
- a reusable exchange rate;
- valuation authority;
- acquisition or tax basis.

What is **not** earned yet:

- a production OriginalAmountEvidence type;
- persistence / normalized Actual rows;
- correction / reversal behavior;
- CLI, TUI or Web UI fields;
- trip identity or automatic trip grouping;
- a report that converts all original amounts into one currency;
- any change to ExchangeEvidence or RelationDischarge.

The next production-design question for #1351 is therefore narrow:

> Is Event identity the correct long-lived anchor across correction / reversal,
> or should original amount evidence follow the same root/current projection
> pattern already used by other Event-scoped evidence?

Only after that question survives should this candidate be promoted.
-/

end Loam.Observation342
