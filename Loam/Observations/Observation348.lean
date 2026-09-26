import Loam.Core.Event

namespace Loam.Observation348

open Loam.Core

set_option autoImplicit false

/-!
# Observation 348 — finite Measure residual image survives one-to-many and many-to-one pressure

Observation 347 found that Exchange, SecurityTrade, and a two-Measure stock split
share a narrow mechanical shape without sharing semantic meaning.

The next pressure removes the accidental "two Measures" assumption.

Existing investment observations already contain:

- one-to-many spin-off topology;
- many-to-one merger provenance;
- two-Measure split transformation.

This observation asks a smaller question:

> What is the common mechanical image before any domain semantics are applied?

LOAM Core already has the candidate:

    Effect.measureTotals

It projects one Event's Effects to one exact signed total per represented
Measure. Filtering away zero totals yields the finite residual support.

No new Core algebra is introduced here.
-/

private def nonzeroMeasureTotals
    (event : Event) : List (MeasureId × Int) :=
  (Effect.measureTotals event.effects).filter fun row =>
    row.2 != 0

private structure ResidualSigns where
  negative : List MeasureId
  positive : List MeasureId
deriving Repr, DecidableEq

private def residualSigns (event : Event) : ResidualSigns :=
  let rows := nonzeroMeasureTotals event
  {
    negative := rows.filterMap fun row =>
      if row.2 < 0 then some row.1 else none
    positive := rows.filterMap fun row =>
      if row.2 > 0 then some row.1 else none
  }

private def yen : MeasureId := ⟨"jpy"⟩
private def usd : MeasureId := ⟨"usd"⟩
private def acme : MeasureId := ⟨"acme-share"⟩

private def preShare : MeasureId := ⟨"pre-share"⟩
private def postShare : MeasureId := ⟨"post-share"⟩

private def oldParent : MeasureId := ⟨"old-parent"⟩
private def parent : MeasureId := ⟨"parent"⟩
private def child : MeasureId := ⟨"child"⟩

private def classA : MeasureId := ⟨"class-a"⟩
private def classB : MeasureId := ⟨"class-b"⟩
private def successor : MeasureId := ⟨"successor-share"⟩

private def points : MeasureId := ⟨"points"⟩
private def kilograms : MeasureId := ⟨"kg"⟩

private def bank : LocusId := ⟨"bank"⟩
private def cashUsd : LocusId := ⟨"cash-usd"⟩
private def broker : LocusId := ⟨"broker"⟩
private def food : LocusId := ⟨"food"⟩
private def unknown : LocusId := ⟨"unknown"⟩

private def ordinary? : Option Event :=
  Event.ofEffects? ⟨"o348-ordinary"⟩ [
    Effect.ofAnonymousQuantity bank yen (Quantity.ofQuanta (-100)),
    Effect.ofAnonymousQuantity food yen (Quantity.ofQuanta 100)
  ]

private def exchange? : Option Event :=
  Event.ofEffects? ⟨"o348-exchange"⟩ [
    Effect.ofAnonymousQuantity bank yen (Quantity.ofQuanta (-15000)),
    Effect.ofAnonymousQuantity cashUsd usd (Quantity.ofQuanta 100)
  ]

private def securityAcquisition? : Option Event :=
  Event.ofEffects? ⟨"o348-security"⟩ [
    Effect.ofAnonymousQuantity bank yen (Quantity.ofQuanta (-1000)),
    Effect.ofAnonymousQuantity broker acme (Quantity.ofQuanta 3)
  ]

private def split? : Option Event :=
  Event.ofEffects? ⟨"o348-split"⟩ [
    Effect.ofAnonymousQuantity broker preShare (Quantity.ofQuanta (-3)),
    Effect.ofAnonymousQuantity broker postShare (Quantity.ofQuanta 6)
  ]

private def spinoff? : Option Event :=
  Event.ofEffects? ⟨"o348-spinoff"⟩ [
    Effect.ofAnonymousQuantity broker oldParent (Quantity.ofQuanta (-4)),
    Effect.ofAnonymousQuantity broker parent (Quantity.ofQuanta 4),
    Effect.ofAnonymousQuantity broker child (Quantity.ofQuanta 2)
  ]

/--
A bounded many-source / one-destination transformation.

This is only a mechanical pressure specimen. It does not claim that every
real-world merger uses this exact representation.
-/
private def consolidation? : Option Event :=
  Event.ofEffects? ⟨"o348-consolidation"⟩ [
    Effect.ofAnonymousQuantity broker classA (Quantity.ofQuanta (-2)),
    Effect.ofAnonymousQuantity broker classB (Quantity.ofQuanta (-4)),
    Effect.ofAnonymousQuantity broker successor (Quantity.ofQuanta 3)
  ]

/--
A deliberately unexplained mixed-Measure occurrence.

Its residual shape is mechanically ordinary enough to classify, but no
semantic evidence is supplied which would justify persistence admission.
-/
private def unexplained? : Option Event :=
  Event.ofEffects? ⟨"o348-unexplained"⟩ [
    Effect.ofAnonymousQuantity bank yen (Quantity.ofQuanta (-100)),
    Effect.ofAnonymousQuantity unknown points (Quantity.ofQuanta 1),
    Effect.ofAnonymousQuantity unknown kilograms (Quantity.ofQuanta 7)
  ]

/--
Ordinary same-Measure movement has no nonzero Measure residual.

The represented JPY total exists in measureTotals but closes exactly to zero.
-/
theorem ordinary_movement_has_empty_nonzero_residual_support :
    (do
      let event ← ordinary?
      pure (nonzeroMeasureTotals event)) =
      some [] := by
  native_decide

/--
The previously studied pair-shaped domains are exactly two residual Measures.

This is the special case Observation 347 was seeing.
-/
theorem exchange_security_and_split_are_two_measure_residual_special_cases :
    (do
      let exchange ← exchange?
      let security ← securityAcquisition?
      let split ← split?
      pure (
        nonzeroMeasureTotals exchange,
        nonzeroMeasureTotals security,
        nonzeroMeasureTotals split)) =
      some (
        [(yen, -15000), (usd, 100)],
        [(yen, -1000), (acme, 3)],
        [(preShare, -3), (postShare, 6)]) := by
  native_decide

/--
One-to-many spin-off pressure does not fit a two-Measure pair, but the existing
Core projection still records its complete finite residual image exactly.
-/
theorem spinoff_is_one_negative_measure_to_two_positive_measures :
    (do
      let event ← spinoff?
      pure (
        nonzeroMeasureTotals event,
        residualSigns event)) =
      some (
        [(oldParent, -4), (parent, 4), (child, 2)],
        {
          negative := [oldParent]
          positive := [parent, child]
        }) := by
  native_decide

/--
The opposite support topology also needs no new physical Core representation.

Two negative Measures and one positive Measure remain an ordinary finite
Measure-indexed image.
-/
theorem consolidation_is_two_negative_measures_to_one_positive_measure :
    (do
      let event ← consolidation?
      pure (
        nonzeroMeasureTotals event,
        residualSigns event)) =
      some (
        [(classA, -2), (classB, -4), (successor, 3)],
        {
          negative := [classA, classB]
          positive := [successor]
        }) := by
  native_decide

/--
The shared residual image is deliberately too weak to be semantic admission.

An unexplained three-Measure Event has the same one-negative / two-positive
support topology as the spin-off specimen.
-/
theorem residual_topology_alone_cannot_authorize_mixed_measure_actual :
    (do
      let spinoff ← spinoff?
      let unexplained ← unexplained?
      pure (
        residualSigns spinoff,
        residualSigns unexplained)) =
      some (
        {
          negative := [oldParent]
          positive := [parent, child]
        },
        {
          negative := [yen]
          positive := [points, kilograms]
        }) := by
  native_decide

private def hasBothResidualSigns (event : Event) : Bool :=
  let signs := residualSigns event
  !signs.negative.isEmpty && !signs.positive.isEmpty

/--
Even a generic "has negative and positive residual Measures" predicate accepts
both a meaningful corporate-action specimen and an unexplained occurrence.

Therefore such a predicate is useful mechanics, not sufficient authority.
-/
theorem generic_residual_shape_is_not_a_safe_persistence_bypass :
    (do
      let spinoff ← spinoff?
      let unexplained ← unexplained?
      pure (
        hasBothResidualSigns spinoff,
        hasBothResidualSigns unexplained)) =
      some (true, true) := by
  native_decide

/-!
## Finding

The pair-shaped validator from Observation 347 was still slightly too specific.

The common physical image below Exchange, SecurityTrade, split, spin-off, and
many-source consolidation is already present in Core:

    Effect.measureTotals

with zero rows optionally filtered away for one query.

That finite Measure-indexed image survives:

    1 negative -> 1 positive
    1 negative -> many positive
    many negative -> 1 positive

without introducing:

- CrossMeasureTransaction;
- TransformKind;
- a generic corporate-action object;
- a new residual container in Core.

This is smaller than the earlier candidate "two-Measure transform mechanics".

The production architecture suggested by the pressure is now:

    Event / Effect
        |
        v
    Effect.measureTotals
        |
        +-- all totals zero
        |      -> ordinary per-Measure-balanced admission
        |
        +-- nonzero residual support
               -> domain semantic frontier must independently justify
                  the selected occurrence

Examples of semantic frontiers may later include:

    Exchange
    SecurityTrade
    Split / SpinOff / Merger transformation

but equal residual support does not merge those authorities.

The deliberately unexplained specimen is important. It shows why the residual
image itself must not become a canonical "mixed Measure allowed" token.

So the strongest current candidate is even more conservative:

> reuse the already-existing finite Measure projection; add no new shared
> semantic noun until two production semantic frontiers actually need more
> shared mechanics than measureTotals already provides.

This also follows Architecture Law 9: research consumers are pressure, not an
automatic reason to promote another primitive.

Not earned here:

- production residual-obligation type;
- generic persisted residual discharge;
- arbitrary mixed-Measure admission;
- production SecurityTrade or corporate-action evidence;
- one shared transform lifecycle;
- a Core Lot or TransactionKind.
-/

end Loam.Observation348
