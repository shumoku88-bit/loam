import Loam.Core.EventMemory

namespace Loam.Observation288

open Loam.Core

set_option autoImplicit false

/-!
# Observation 288 — partial disposal needs quantity-bearing provenance

Observation 287 showed that one complete acquisition can be selected as the
source of one disposal without introducing a first-class Lot identity.

This observation sharpens the pressure:

> What if one disposal consumes quantity from more than one acquisition?

The selected fixture keeps the same neutral physical Core shape:

```text
Acquisition A   +3 units
Acquisition B   +3 units
Disposal        -3 units
Final holding    3 units
```

Both candidate attributions name the same two acquisition Effects:

```text
Left:   A -> 2 units, B -> 1 unit
Right:  A -> 1 unit, B -> 2 units
```

So even the *set of source identities* is the same. Only the quantity attached
to each source differs.

For arithmetic clarity this bounded fixture supplies exact per-unit acquisition
basis:

```text
A: 300 JPY / unit
B: 600 JPY / unit
sale proceeds: 1,500 JPY
```

That local representation does not claim that production cost basis should
always be stored per unit. It merely avoids introducing rounding policy into a
probe whose real question is provenance quantity.
-/

private def broker : LocusId := ⟨"broker"⟩
private def outside : LocusId := ⟨"outside"⟩
private def unit : MeasureId := ⟨"unit"⟩

private def acquisitionAId : EventId := ⟨"acquisition-a"⟩
private def acquisitionBId : EventId := ⟨"acquisition-b"⟩
private def disposalId : EventId := ⟨"partial-disposal"⟩

private def acquisitionAKey : EffectKey := ⟨"acquisition-a-held"⟩
private def acquisitionBKey : EffectKey := ⟨"acquisition-b-held"⟩
private def disposalKey : EffectKey := ⟨"partial-disposal-held"⟩

private def acquisitionA? : Option Event :=
  Event.ofEffects? acquisitionAId [
    Effect.ofQuantity acquisitionAKey broker unit (Quantity.ofQuanta 3),
    Effect.ofAnonymousQuantity outside unit (Quantity.ofQuanta (-3))
  ]

private def acquisitionB? : Option Event :=
  Event.ofEffects? acquisitionBId [
    Effect.ofQuantity acquisitionBKey broker unit (Quantity.ofQuanta 3),
    Effect.ofAnonymousQuantity outside unit (Quantity.ofQuanta (-3))
  ]

private def disposal? : Option Event :=
  Event.ofEffects? disposalId [
    Effect.ofQuantity disposalKey broker unit (Quantity.ofQuanta (-3)),
    Effect.ofAnonymousQuantity outside unit (Quantity.ofQuanta 3)
  ]

private def physicalMemory? : Option EventMemory := do
  let a ← acquisitionA?
  let b ← acquisitionB?
  let sale ← disposal?
  EventMemory.ofEvents? [a, b, sale]

private def recordedBrokerUnits? : Option Int := do
  let memory ← physicalMemory?
  pure (EventMemory.quantityAtRecorded memory broker unit).quanta

theorem physical_holding_is_three :
    recordedBrokerUnits? = some 3 := by
  native_decide

structure EffectAnchor where
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

private def acquisitionAAnchor : EffectAnchor :=
  ⟨acquisitionAId, acquisitionAKey⟩

private def acquisitionBAnchor : EffectAnchor :=
  ⟨acquisitionBId, acquisitionBKey⟩

private def disposalAnchor : EffectAnchor :=
  ⟨disposalId, disposalKey⟩

private def findEffect?
    (memory : EventMemory)
    (anchor : EffectAnchor) : Option Effect := do
  let event ← EventMemory.findById? memory anchor.event
  event.effects.find? fun effect => effect.key = some anchor.effect

private def anchoredUnits?
    (memory : EventMemory)
    (anchor : EffectAnchor) : Option Int := do
  let effect ← findEffect? memory anchor
  if effect.locus = broker ∧ effect.measure = unit then
    some effect.quantity.quanta
  else
    none

structure UnitBasis where
  source : EffectAnchor
  basisPerUnitJpy : Int
deriving Repr, DecidableEq

private def basisEvidence : List UnitBasis := [
  ⟨acquisitionAAnchor, 300⟩,
  ⟨acquisitionBAnchor, 600⟩
]

private def basisPerUnit?
    (basis : List UnitBasis)
    (source : EffectAnchor) : Option Int := do
  let row ← basis.find? fun row => row.source = source
  pure row.basisPerUnitJpy

structure Consumption where
  source : EffectAnchor
  units : Quantity
deriving Repr, DecidableEq

structure DisposalAttribution where
  disposal : EffectAnchor
  consumptions : List Consumption
deriving Repr, DecidableEq

private def allocation21 : DisposalAttribution := {
  disposal := disposalAnchor
  consumptions := [
    ⟨acquisitionAAnchor, Quantity.ofQuanta 2⟩,
    ⟨acquisitionBAnchor, Quantity.ofQuanta 1⟩
  ]
}

private def allocation12 : DisposalAttribution := {
  disposal := disposalAnchor
  consumptions := [
    ⟨acquisitionAAnchor, Quantity.ofQuanta 1⟩,
    ⟨acquisitionBAnchor, Quantity.ofQuanta 2⟩
  ]
}

private def sourceShape
    (attribution : DisposalAttribution) : List EffectAnchor :=
  attribution.consumptions.map (·.source)

private def consumptionTotal
    (attribution : DisposalAttribution) : Int :=
  attribution.consumptions.foldl
    (fun total row => total + row.units.quanta)
    0

private def eachConsumptionFits
    (memory : EventMemory)
    (attribution : DisposalAttribution) : Bool :=
  attribution.consumptions.all fun row =>
    match anchoredUnits? memory row.source with
    | none => false
    | some available =>
        row.units.quanta > 0 &&
        row.units.quanta <= available

/--
The selected attribution admits only exact positive source quantities whose
sum equals the three disposed units. Source identities must also be unique.

This remains observation-local. No generic production disposal relation is
earned here.
-/
private def attributionAdmitted?
    (memory : EventMemory)
    (attribution : DisposalAttribution) : Bool :=
  anchoredUnits? memory attribution.disposal = some (-3) &&
  decide (sourceShape attribution).Nodup &&
  consumptionTotal attribution = 3 &&
  eachConsumptionFits memory attribution

theorem both_partial_allocations_fit_the_same_physical_events :
    (do
      let memory ← physicalMemory?
      pure (
        attributionAdmitted? memory allocation21,
        attributionAdmitted? memory allocation12)) =
      some (true, true) := by
  native_decide

theorem source_identity_set_is_not_enough :
    sourceShape allocation21 = sourceShape allocation12 ∧
    consumptionTotal allocation21 = consumptionTotal allocation12 := by
  native_decide

private def consumedBasisRows?
    (basis : List UnitBasis)
    (rows : List Consumption) : Option Int :=
  match rows with
  | [] => some 0
  | row :: rest => do
      let perUnit ← basisPerUnit? basis row.source
      let tail ← consumedBasisRows? basis rest
      pure (row.units.quanta * perUnit + tail)

private def consumedBasis?
    (basis : List UnitBasis)
    (attribution : DisposalAttribution) : Option Int :=
  consumedBasisRows? basis attribution.consumptions

private def realisedGain?
    (basis : List UnitBasis)
    (attribution : DisposalAttribution)
    (saleProceedsJpy : Int) : Option Int := do
  let consumed ← consumedBasis? basis attribution
  pure (saleProceedsJpy - consumed)

theorem quantity_bearing_provenance_changes_realised_gain :
    consumedBasis? basisEvidence allocation21 = some 1200 ∧
    consumedBasis? basisEvidence allocation12 = some 1500 ∧
    realisedGain? basisEvidence allocation21 1500 = some 300 ∧
    realisedGain? basisEvidence allocation12 1500 = some 0 := by
  native_decide

private def totalAcquisitionBasisJpy : Int :=
  3 * 300 + 3 * 600

private def remainingBasis?
    (basis : List UnitBasis)
    (attribution : DisposalAttribution) : Option Int := do
  let consumed ← consumedBasis? basis attribution
  pure (totalAcquisitionBasisJpy - consumed)

private def unrealisedGain?
    (basis : List UnitBasis)
    (attribution : DisposalAttribution)
    (remainingMarketValueJpy : Int) : Option Int := do
  let remaining ← remainingBasis? basis attribution
  pure (remainingMarketValueJpy - remaining)

theorem same_remaining_quantity_and_market_value_still_need_allocation :
    recordedBrokerUnits? = some 3 ∧
    remainingBasis? basisEvidence allocation21 = some 1500 ∧
    remainingBasis? basisEvidence allocation12 = some 1200 ∧
    unrealisedGain? basisEvidence allocation21 2100 = some 600 ∧
    unrealisedGain? basisEvidence allocation12 2100 = some 900 := by
  native_decide

/-!
## Finding

This practical specimen sharpens Observation 287:

```text
source identity set
    !=
quantity consumed from each source
```

Both admissible worlds retain:

- the exact same physical EventMemory;
- the same final three-unit holding;
- the same disposal quantity;
- the same two acquisition source identities;
- the same sale proceeds;
- the same current market value.

Only the quantity-bearing source relation differs:

```text
A -> 2, B -> 1
        !=
A -> 1, B -> 2
```

and that difference changes both consumed basis and the realised / unrealised
gain answers.

So a future practical implementation cannot compress partial disposal provenance
to:

```text
List EffectAnchor
```

or any equivalent source-identity set.

It needs information equivalent to:

```text
(EventId, EffectKey) -> exact Quantity
```

for each acquisition source that participates.

The result still does **not** force a first-class `LotId`. The already-earned
Effect endpoint remains sufficient for this selected specimen.

Nor does it earn:

- a production disposal-provenance family;
- a production basis representation;
- per-unit basis as the canonical production encoding;
- FIFO, LIFO, average-cost, or specific-identification policy;
- rounding rules;
- fees or tax basis;
- split / merger / spin-off handling;
- partial-lot writer or UI;
- automatic realised-gain posting.

The narrow earned statement is:

> Once one disposal may consume several acquisition Effects, provenance must
> retain exact quantity per source. Source identity alone is insufficient.
-/

end Loam.Observation288
