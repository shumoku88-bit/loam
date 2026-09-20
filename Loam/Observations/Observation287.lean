import Loam.Core.EventMemory

namespace Loam.Observation287

open Loam.Core

set_option autoImplicit false

/-!
# Observation 287 — practical acquisition-basis / disposal provenance pressure

Observations 066–071 and 210 already established the abstract information
boundaries around acquisition basis, disposal provenance, policy and gain.

This observation asks a narrower practical question:

> Can the current `Event / Effect / EffectKey` Core carry the physical holding
> while acquisition basis and disposal provenance remain additive evidence,
> without introducing a first-class `Lot` identity?

The specimen uses one security-like Measure named `unit`.

Two acquisitions each add three units to the same broker Locus:

```text
Acquisition A   +3 units   basis 1,000 JPY
Acquisition B   +3 units   basis 1,800 JPY
```

One later disposal removes three units and receives 1,500 JPY of proceeds.

The Core physical answer is the same regardless of source attribution:

```text
6 units before disposal
3 units after disposal
```

But the realised-gain answer differs:

```text
dispose A -> 1,500 - 1,000 =  +500
dispose B -> 1,500 - 1,800 =  -300
```

The observation deliberately does not encode purchase cash settlement, tax law,
FIFO, average cost, or market-price persistence. The physical unit movement is
single-Measure and balanced. Basis/proceeds/valuation are observation-local
comparison evidence.
-/

private def broker : LocusId := ⟨"broker"⟩
private def outside : LocusId := ⟨"outside"⟩
private def unit : MeasureId := ⟨"unit"⟩

private def acquisitionAId : EventId := ⟨"acquisition-a"⟩
private def acquisitionBId : EventId := ⟨"acquisition-b"⟩
private def disposalId : EventId := ⟨"disposal"⟩

private def acquisitionAKey : EffectKey := ⟨"acquisition-a-held"⟩
private def acquisitionBKey : EffectKey := ⟨"acquisition-b-held"⟩
private def disposalKey : EffectKey := ⟨"disposal-held"⟩

private def acquisitionA? : Option Event :=
  Event.ofEffects? acquisitionAId [
    Effect.ofQuantity
      acquisitionAKey broker unit (Quantity.ofQuanta 3),
    Effect.ofAnonymousQuantity
      outside unit (Quantity.ofQuanta (-3))
  ]

private def acquisitionB? : Option Event :=
  Event.ofEffects? acquisitionBId [
    Effect.ofQuantity
      acquisitionBKey broker unit (Quantity.ofQuanta 3),
    Effect.ofAnonymousQuantity
      outside unit (Quantity.ofQuanta (-3))
  ]

private def disposal? : Option Event :=
  Event.ofEffects? disposalId [
    Effect.ofQuantity
      disposalKey broker unit (Quantity.ofQuanta (-3)),
    Effect.ofAnonymousQuantity
      outside unit (Quantity.ofQuanta 3)
  ]

private def physicalMemory? : Option EventMemory := do
  let a ← acquisitionA?
  let b ← acquisitionB?
  let sale ← disposal?
  EventMemory.ofEvents? [a, b, sale]

/--
The physical Core sees one remaining three-unit holding after the disposal.
No acquisition-basis or lot-selection meaning is needed for this quantity
answer.
-/
private def recordedBrokerUnits? : Option Int := do
  let memory ← physicalMemory?
  pure (EventMemory.quantityAtRecorded memory broker unit).quanta

theorem physical_holding_after_disposal_is_three :
    recordedBrokerUnits? = some 3 := by
  native_decide

/--
Observation-local endpoint shape.

This intentionally reuses the already-earned practical coordinate:

```text
EventId + EffectKey
```

rather than introducing `LotId`.
-/
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

/--
The two acquisitions remain independently addressable even though both occupy
the same `broker × unit` aggregate coordinate.
-/
theorem acquisition_effect_identity_survives_aggregation :
    (do
      let memory ← physicalMemory?
      pure (
        anchoredUnits? memory acquisitionAAnchor,
        anchoredUnits? memory acquisitionBAnchor,
        anchoredUnits? memory disposalAnchor)) =
      some (some 3, some 3, some (-3)) := by
  native_decide

/--
Observation-local acquisition basis.

`basisJpy` is explicit acquisition evidence. It is not inferred from the
security quantity, from a market valuation, or from a generic Rate.
-/
structure BasisEvidence where
  source : EffectAnchor
  basisJpy : Int
deriving Repr, DecidableEq

private def basisA : BasisEvidence :=
  ⟨acquisitionAAnchor, 1000⟩

private def basisB : BasisEvidence :=
  ⟨acquisitionBAnchor, 1800⟩

private def basisEvidence : List BasisEvidence :=
  [basisA, basisB]

private def basisFor?
    (basis : List BasisEvidence)
    (source : EffectAnchor) : Option Int := do
  let row ← basis.find? fun row => row.source = source
  pure row.basisJpy

/--
Observation-local quantity-bearing source attribution.

This specimen consumes one complete three-unit acquisition. Observation 067
already established that a richer disposal may need a quantity per source, so
this one-source form is deliberately not promoted as a universal disposal type.
-/
structure DisposalAttribution where
  disposal : EffectAnchor
  source : EffectAnchor
  units : Quantity
deriving Repr, DecidableEq

private def disposeA : DisposalAttribution := {
  disposal := disposalAnchor
  source := acquisitionAAnchor
  units := Quantity.ofQuanta 3
}

private def disposeB : DisposalAttribution := {
  disposal := disposalAnchor
  source := acquisitionBAnchor
  units := Quantity.ofQuanta 3
}

/--
Admit only the selected full-source specimen:

- named disposal Effect exists as -3 broker units;
- named acquisition Effect exists as +3 broker units;
- attribution quantity is exactly three positive units.

No order, FIFO, date, or Event-list position participates.
-/
private def attributionAdmitted?
    (memory : EventMemory)
    (attribution : DisposalAttribution) : Bool :=
  anchoredUnits? memory attribution.disposal = some (-3) &&
  anchoredUnits? memory attribution.source = some 3 &&
  attribution.units.quanta = 3

theorem both_source_attributions_fit_the_same_physical_core :
    (do
      let memory ← physicalMemory?
      pure (
        attributionAdmitted? memory disposeA,
        attributionAdmitted? memory disposeB)) =
      some (true, true) := by
  native_decide

private def realisedGain?
    (basis : List BasisEvidence)
    (attribution : DisposalAttribution)
    (saleProceedsJpy : Int) : Option Int := do
  let sourceBasis ← basisFor? basis attribution.source
  pure (saleProceedsJpy - sourceBasis)

theorem same_holding_and_same_proceeds_can_have_different_realised_gain :
    recordedBrokerUnits? = some 3 ∧
    realisedGain? basisEvidence disposeA 1500 = some 500 ∧
    realisedGain? basisEvidence disposeB 1500 = some (-300) := by
  native_decide

/--
For the same two-acquisition specimen, the source attribution also determines
which acquisition basis remains attached to the still-held three units.

This is basis bookkeeping, not current market valuation.
-/
private def remainingBasis?
    (basis : List BasisEvidence)
    (attribution : DisposalAttribution) : Option Int :=
  let remaining := basis.filter fun row => decide (row.source ≠ attribution.source)
  match remaining with
  | [row] => some row.basisJpy
  | _ => none

private def unrealisedGain?
    (basis : List BasisEvidence)
    (attribution : DisposalAttribution)
    (remainingMarketValueJpy : Int) : Option Int := do
  let carriedBasis ← remainingBasis? basis attribution
  pure (remainingMarketValueJpy - carriedBasis)

theorem same_market_value_still_needs_remaining_basis_provenance :
    unrealisedGain? basisEvidence disposeA 2400 = some 600 ∧
    unrealisedGain? basisEvidence disposeB 2400 = some 1400 := by
  native_decide

/-!
## Finding

The practical pressure reproduces the earlier abstract result without enlarging
the physical Core:

```text
Event / keyed Effect quantity
    -> physical holding

(EventId, EffectKey) + acquisition basis
    -> acquisition-specific carried basis

disposal Effect + explicit source attribution
    -> which basis was consumed

sale proceeds + consumed basis
    -> realised gain

remaining market valuation + remaining basis
    -> unrealised gain
```

The same physical EventMemory and the same aggregate holding support two valid
source attributions with different gain answers. Therefore neither aggregate
Quantity nor sale proceeds reconstruct acquisition provenance.

At the same time, no first-class `Lot` identity is required by this selected
specimen. The already-earned `EventId + EffectKey` endpoint is sufficient to
name the two acquisition-specific contributions.

This observation does **not** establish that LOAM now has production investment
accounting. It earns no:

- production `BasisEvidence` or `DisposalAttribution` family;
- basis persistence or writer;
- investment UI / CLI;
- FIFO, LIFO, average-cost, or specific-identification policy;
- tax basis;
- fee capitalization;
- partial multi-source disposal implementation;
- stock split / merger / spin-off handling;
- short positions;
- automatic gain postings;
- market-price authority;
- claim that every real investment lot is one acquisition Effect.

The useful result is smaller:

> For a concrete two-acquisition / one-disposal case, the next missing practical
> information is additive acquisition-basis and disposal-provenance evidence.
> The neutral physical `Event / Effect / EffectKey` shape does not need to be
> reinterpreted to carry that information.
-/

end Loam.Observation287
