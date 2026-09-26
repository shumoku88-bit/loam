import Loam.Application.RelationDischargeFrontier
import Loam.Core.EventMemory

namespace Loam.Observation341

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 341 — foreign card settlement exceeds the current discharge boundary

Issue #1351 asks whether an overseas card purchase followed by a later JPY bank
debit can reuse the existing directional Relation / Discharge semantics without
inventing a second expense or smuggling FX meaning into ordinary Movement.

The existing production boundary deliberately gives `RelationDischarge` a
small meaning:

    later EventId
    + target RelationUnitId
    + exact discharge Quantity

The discharge Event is required to exist, but the raw correspondence does not
name one Effect inside that Event and does not duplicate Measure identity.

That is sufficient for the questions the current boundary was designed to
answer. This observation asks whether it is also sufficient to justify a
cross-Measure card settlement.

Selected specimen:

    purchase occurrence
      food +30 usd
      household -> card issuer relation: 30 units

    later bank debit
      bank -4700 jpy

The question is not whether a human can say that the debit paid the card.
The question is stricter:

> Does the current Relation / Discharge representation itself establish that
> this exact JPY movement is the physical settlement corresponding to the
> 30-USD relation?

A falsification pair changes only the JPY bank-debit magnitude while preserving
the same later Event identity and the same RelationDischarge row.
-/

private def dollar : MeasureId := ⟨"usd"⟩
private def yen : MeasureId := ⟨"jpy"⟩

private def food : LocusId := ⟨"food"⟩
private def bank : LocusId := ⟨"bank"⟩

private def purchaseId : EventId := ⟨"foreign-card-purchase"⟩
private def purchaseEffect : EffectKey := ⟨"foreign-purchase-burden"⟩
private def settlementId : EventId := ⟨"card-bank-settlement"⟩
private def settlementEffect : EffectKey := ⟨"bank-debit"⟩

private def issuer : ExternalPartyId := ⟨"card-issuer"⟩
private def relationId : RelationUnitId := ⟨"card-payable"⟩

private def purchase? : Option Event :=
  Event.ofEffects? purchaseId [
    Effect.ofQuantity
      purchaseEffect food dollar (Quantity.ofQuanta 30)
  ]

private def settlement4700? : Option Event :=
  Event.ofEffects? settlementId [
    Effect.ofQuantity
      settlementEffect bank yen (Quantity.ofQuanta (-4700))
  ]

private def settlement100? : Option Event :=
  Event.ofEffects? settlementId [
    Effect.ofQuantity
      settlementEffect bank yen (Quantity.ofQuanta (-100))
  ]

/--
The purchase Effect anchors a directional household obligation to the card
issuer.

The source Effect carries USD, so the admitted relation inherits USD as its
Measure. No JPY amount is present in this relation evidence.
-/
private def cardRelation : RelationUnit := {
  id := relationId
  sourceEvent := purchaseId
  sourceEffect := purchaseEffect
  debtor := .household
  creditor := .external issuer
  quantity := Quantity.ofQuanta 30
}

/--
The current discharge vocabulary records only that the later Event discharged
30 units of the relation. It does not point to `settlementEffect`.
-/
private def cardDischarge : RelationDischarge := {
  event := settlementId
  target := relationId
  quantity := Quantity.ofQuanta 30
}

private def memoryWith? (settlement : Event) : Option EventMemory := do
  let purchase ← purchase?
  EventMemory.ofEvents? [purchase, settlement]

private def outstandingWith?
    (settlement : Event) : Option Int := do
  let memory ← memoryWith? settlement
  let outstanding ← relationOutstandingQuantity?
    memory
    [cardRelation]
    [cardDischarge]
    relationId
  pure outstanding.quanta

private def admittedRelationMeasureWith?
    (settlement : Event) : Option MeasureId := do
  let memory ← memoryWith? settlement
  let admitted ← currentAdmittedRelationById?
    memory [cardRelation] relationId
  pure admitted.measure

/-- The relation itself is unambiguously USD-denominated through its source. -/
theorem card_relation_inherits_purchase_measure :
    (do
      let settlement ← settlement4700?
      admittedRelationMeasureWith? settlement) =
      some dollar := by
  native_decide

/--
A 4,700-JPY settlement Event is enough for the current discharge frontier to
project the 30-unit relation as fully discharged.
-/
theorem current_discharge_accepts_selected_4700_jpy_event :
    (do
      let settlement ← settlement4700?
      outstandingWith? settlement) =
      some 0 := by
  native_decide

/--
Crucial falsification witness.

Changing the physical JPY debit from 4,700 to 100 while keeping the same later
Event identity and the same 30-unit RelationDischarge row leaves the derived
outstanding answer unchanged.

Therefore the current discharge admission does not establish a quantitative
correspondence between the physical JPY settlement Effect and the USD relation.
-/
theorem current_discharge_does_not_determine_cross_measure_settlement_amount :
    (do
      let settlement ← settlement4700?
      let tinySettlement ← settlement100?
      pure (
        outstandingWith? settlement,
        outstandingWith? tinySettlement)) =
      some (some 0, some 0) := by
  native_decide

/--
The two later Events really do differ in the retained physical JPY quantity.
The equal discharge answer above is therefore not caused by identical Event
payloads.
-/
theorem falsification_worlds_have_different_jpy_debits :
    (do
      let settlement ← settlement4700?
      let tinySettlement ← settlement100?
      pure (
        (settlement.quantityAt bank yen).quanta,
        (tinySettlement.quantityAt bank yen).quanta)) =
      some (-4700, -100) := by
  native_decide

/-!
## Finding

The current Relation / Discharge boundary is not wrong. It is simply narrower
than the travel-card question.

It can establish:

    a USD source Effect
      -> household owes card issuer 30 relation units

    later Event exists
      + discharge row says 30 units fulfilled
      -> outstanding relation becomes zero

But it does **not** establish:

    which later Effect performed settlement
    what Measure that settlement Effect uses
    why -4700 JPY, rather than -100 JPY, corresponds to the 30-USD obligation

That missing correspondence matters for overseas cards because purchase Measure
and billing / bank-settlement Measure may differ.

Therefore #1351 should not declare Visa-style foreign purchase -> JPY debit
qualified merely by reusing the existing RelationDischarge row.

The next candidate should remain additive and narrow. A useful pressure target is
something equivalent to:

    settlement correspondence
      target relation
      later Event
      later EffectKey
      discharged relation quantity

possibly composed with a separately observed billing / exchange relation when
the source and settlement Measures differ.

This observation does **not** earn that production schema. It only proves the
negative result needed before designing one.

Important non-conclusions:

- ordinary same-Measure Relation / Discharge semantics are not invalidated;
- card settlement does not need to become a Core transaction kind;
- a market FX rate is still not required;
- the observed card conversion must not automatically become valuation,
  acquisition basis, tax basis, or a timeless exchange rate;
- the later bank debit must not create the purchase Expense again.
-/

end Loam.Observation341
