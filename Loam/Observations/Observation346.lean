import Loam.Core.EventMemory

namespace Loam.Observation346

open Loam.Core

set_option autoImplicit false

/-!
# Observation 346 — purchase / holding / disposal / realised-gain vertical slice

Observation 345 found a production-boundary problem before any new investment
schema was introduced:

- neutral Event / Effect can carry JPY and security units together;
- normalized Actual currently needs an explicit cross-Measure qualifier;
- reusing ExchangeEvidence can open that admission path;
- but doing so also classifies the stock trade as Exchange to existing reports.

This observation asks the constructive follow-up:

> If investment semantics receive their own additive evidence, can the existing
> neutral Event / Effect / EffectKey Core carry a practical buy -> hold -> sell
> -> realised-gain slice without a LotId or a security-specific Core Event?

Selected history:

    Acquisition A
      bank    -1000 jpy
      broker     +3 acme-share
      explicit carried basis = 1000 jpy

    Acquisition B
      bank    -1800 jpy
      broker     +3 acme-share
      explicit carried basis = 1800 jpy

    Disposal
      broker     -3 acme-share
      bank    +1500 jpy

After the disposal the household holds three shares. Which acquisition supplied
the disposed three shares remains independent provenance and changes realised
gain:

    dispose A -> 1500 - 1000 = +500 jpy
    dispose B -> 1500 - 1800 = -300 jpy

The cash settlement is now inside the retained physical Events rather than being
passed as an observation-local scalar as in Observation 287.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def shares : MeasureId := ⟨"acme-share"⟩

private def bank : LocusId := ⟨"bank"⟩
private def broker : LocusId := ⟨"broker"⟩

private def acquisitionAId : EventId := ⟨"stock-acquisition-a"⟩
private def acquisitionBId : EventId := ⟨"stock-acquisition-b"⟩
private def disposalId : EventId := ⟨"stock-disposal"⟩

private def acquisitionACash : EffectKey := ⟨"acquisition-a-cash"⟩
private def acquisitionAShares : EffectKey := ⟨"acquisition-a-shares"⟩
private def acquisitionBCash : EffectKey := ⟨"acquisition-b-cash"⟩
private def acquisitionBShares : EffectKey := ⟨"acquisition-b-shares"⟩
private def disposalCash : EffectKey := ⟨"disposal-cash"⟩
private def disposalShares : EffectKey := ⟨"disposal-shares"⟩

private def acquisitionA? : Option Event :=
  Event.ofEffects? acquisitionAId [
    Effect.ofQuantity acquisitionACash bank yen (Quantity.ofQuanta (-1000)),
    Effect.ofQuantity acquisitionAShares broker shares (Quantity.ofQuanta 3)
  ]

private def acquisitionB? : Option Event :=
  Event.ofEffects? acquisitionBId [
    Effect.ofQuantity acquisitionBCash bank yen (Quantity.ofQuanta (-1800)),
    Effect.ofQuantity acquisitionBShares broker shares (Quantity.ofQuanta 3)
  ]

private def disposal? : Option Event :=
  Event.ofEffects? disposalId [
    Effect.ofQuantity disposalShares broker shares (Quantity.ofQuanta (-3)),
    Effect.ofQuantity disposalCash bank yen (Quantity.ofQuanta 1500)
  ]

private def eventMemory? : Option EventMemory := do
  let a ← acquisitionA?
  let b ← acquisitionB?
  let sale ← disposal?
  EventMemory.ofEvents? [a, b, sale]

/--
Observation-local candidate semantic evidence.

The selected Effect names make the security side and settlement side explicit
without introducing a transaction-kind field into Event itself.
-/
structure SecurityTradeEvidence where
  event : EventId
  security : EffectKey
  settlement : EffectKey
deriving Repr, DecidableEq

inductive SecurityTradeDirection where
  | acquire
  | dispose
deriving Repr, DecidableEq

private def findEffectByKey?
    (event : Event)
    (key : EffectKey) : Option Effect :=
  event.effects.find? fun effect => effect.key = some key

/--
Narrow candidate admission for this vertical slice.

It intentionally admits exactly the selected two-Effect / two-Measure shape.
Fees, taxes, settlement delay and multiple security legs remain separate future
pressure rather than being smuggled into this first witness.
-/
private def securityTradeDirection?
    (events : EventMemory)
    (evidence : SecurityTradeEvidence) :
    Option SecurityTradeDirection := do
  let event ← events.findById? evidence.event
  if event.effects.length != 2 then
    none
  else
    let security ← findEffectByKey? event evidence.security
    let settlement ← findEffectByKey? event evidence.settlement
    if security.measure = settlement.measure then
      none
    else if security.quantity.quanta > 0 &&
        settlement.quantity.quanta < 0 then
      some .acquire
    else if security.quantity.quanta < 0 &&
        settlement.quantity.quanta > 0 then
      some .dispose
    else
      none

private def tradeA : SecurityTradeEvidence := {
  event := acquisitionAId
  security := acquisitionAShares
  settlement := acquisitionACash
}

private def tradeB : SecurityTradeEvidence := {
  event := acquisitionBId
  security := acquisitionBShares
  settlement := acquisitionBCash
}

private def tradeSale : SecurityTradeEvidence := {
  event := disposalId
  security := disposalShares
  settlement := disposalCash
}

/--
The same neutral Event shape supports two acquisitions and one disposal once
domain-specific evidence says which Effect is security quantity and which is
settlement quantity.
-/
theorem candidate_trade_evidence_admits_selected_lifecycle :
    (do
      let events ← eventMemory?
      pure (
        securityTradeDirection? events tradeA,
        securityTradeDirection? events tradeB,
        securityTradeDirection? events tradeSale)) =
      some (some .acquire, some .acquire, some .dispose) := by
  native_decide

/--
The physical Core alone answers current quantities exactly.

No basis, lot-selection policy or market valuation participates in this answer.
-/
private def currentPhysicalPosition? : Option (Int × Int) := do
  let events ← eventMemory?
  pure (
    (EventMemory.quantityAtRecorded events broker shares).quanta,
    (EventMemory.quantityAtRecorded events bank yen).quanta)

theorem physical_history_retains_three_shares_and_net_cash_change :
    currentPhysicalPosition? = some (3, -1300) := by
  native_decide

structure EffectAnchor where
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

private def acquisitionAAnchor : EffectAnchor :=
  ⟨acquisitionAId, acquisitionAShares⟩

private def acquisitionBAnchor : EffectAnchor :=
  ⟨acquisitionBId, acquisitionBShares⟩

private def disposalAnchor : EffectAnchor :=
  ⟨disposalId, disposalShares⟩

/--
Acquisition basis remains explicit additive evidence.

The comparison Measure is retained with the exact Quantity. Basis is not
reconstructed from ambient valuation or from the security-unit quantity.
-/
structure AcquisitionBasisEvidence where
  source : EffectAnchor
  measure : MeasureId
  quantity : Quantity
deriving Repr, DecidableEq

private def basisA : AcquisitionBasisEvidence := {
  source := acquisitionAAnchor
  measure := yen
  quantity := Quantity.ofQuanta 1000
}

private def basisB : AcquisitionBasisEvidence := {
  source := acquisitionBAnchor
  measure := yen
  quantity := Quantity.ofQuanta 1800
}

private def basisEvidence : List AcquisitionBasisEvidence :=
  [basisA, basisB]

private def basisFor?
    (source : EffectAnchor) :
    Option AcquisitionBasisEvidence :=
  basisEvidence.find? fun row => row.source = source

/--
Selected whole-source disposal provenance.

Observation 288 already proves that partial multi-source disposal requires exact
quantity per source. This vertical slice deliberately disposes one complete
three-share acquisition so no allocation/rounding policy is hidden here.
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

private def anchoredEffect?
    (events : EventMemory)
    (anchor : EffectAnchor) : Option Effect := do
  let event ← events.findById? anchor.event
  findEffectByKey? event anchor.effect

private def attributionAdmitted?
    (events : EventMemory)
    (attribution : DisposalAttribution) : Bool :=
  match anchoredEffect? events attribution.disposal,
        anchoredEffect? events attribution.source with
  | some disposal, some source =>
      disposal.locus = broker &&
      source.locus = broker &&
      disposal.measure = shares &&
      source.measure = shares &&
      disposal.quantity.quanta = -3 &&
      source.quantity.quanta = 3 &&
      attribution.units.quanta = 3
  | _, _ => false

private def saleProceeds? (events : EventMemory) : Option (MeasureId × Quantity) := do
  let event ← events.findById? disposalId
  let effect ← findEffectByKey? event disposalCash
  if effect.quantity.quanta > 0 then
    some (effect.measure, effect.quantity)
  else
    none

private def realisedGain?
    (events : EventMemory)
    (attribution : DisposalAttribution) :
    Option (MeasureId × Quantity) := do
  if !attributionAdmitted? events attribution then
    none
  let basis ← basisFor? attribution.source
  let (proceedsMeasure, proceeds) ← saleProceeds? events
  if basis.measure != proceedsMeasure then
    none
  else
    some (
      proceedsMeasure,
      Quantity.ofQuanta (proceeds.quanta - basis.quantity.quanta))

/--
The retained physical Events and sale proceeds are identical. Only disposal
provenance changes which acquisition basis is consumed, and therefore changes
realised gain.
-/
theorem additive_basis_and_provenance_determine_realised_gain :
    (do
      let events ← eventMemory?
      pure (
        realisedGain? events disposeA,
        realisedGain? events disposeB)) =
      some (
        some (yen, Quantity.ofQuanta 500),
        some (yen, Quantity.ofQuanta (-300))) := by
  native_decide

/--
Both source choices fit the same physical lifecycle.

This is why aggregate holding and sale proceeds cannot silently choose a lot.
-/
theorem both_source_choices_fit_same_physical_history :
    (do
      let events ← eventMemory?
      pure (
        attributionAdmitted? events disposeA,
        attributionAdmitted? events disposeB,
        (EventMemory.quantityAtRecorded events broker shares).quanta)) =
      some (true, true, 3) := by
  native_decide

/-!
## Finding

For the selected practical lifecycle, neutral Core plus additive evidence is
constructively sufficient:

    Event / Effect / EffectKey
        -> exact JPY settlement and exact security-unit movement

    SecurityTradeEvidence
        -> acquisition/disposal interpretation of selected Effects

    AcquisitionBasisEvidence
        -> carried acquisition-specific basis

    DisposalAttribution
        -> which acquisition source supplied the disposed quantity

    sale settlement Effect + consumed basis
        -> realised gain

No physical Core rewrite is required. In particular, the selected slice does
not require:

- a security-specific Event variant;
- a home/base-currency field;
- a first-class LotId;
- implicit FX or market valuation;
- automatic gain postings.

The production blocker is now much narrower than "LOAM cannot model stocks":

> normalized Actual has no retained semantic family for a security trade, so
> these otherwise sufficient cross-Measure Events cannot yet be admitted without
> pretending to be Exchange Events.

That suggests a conservative production path:

1. keep Event / Effect / Measure unchanged;
2. add a narrowly admitted security-trade evidence family and persistence row;
3. share only the two-Measure validation mechanics with Exchange admission;
4. add acquisition-basis evidence;
5. add quantity-bearing disposal provenance when practical sale workflows need
   it;
6. keep FIFO / average-cost / specific-identification as replaceable selection
   policy over admissible provenance rather than physical history.

Observation 288 already covers the richer partial multi-source quantity case,
so this vertical slice does not need to solve allocation arithmetic again.

Current external-accounting pressure is consistent with this decomposition:
systems that support investment lots preserve acquisition-specific basis and
later disposal selection rather than deriving both from aggregate holdings.

Not earned here:

- production investment persistence or writers;
- tax-basis jurisdiction rules;
- fee capitalization;
- dividends / reinvestment;
- stock split / merger / spin-off production mechanics;
- short positions;
- settlement delay/failure;
- market-price authority or unrealised-gain reporting;
- an unconditional universal Lot object.
-/

end Loam.Observation346
