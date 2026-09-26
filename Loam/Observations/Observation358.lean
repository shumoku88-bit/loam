import Loam.Application.ReplacementFrontier
import Loam.Core.EventMemory

namespace Loam.Observation358

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 358 — one investment lifecycle composes without a new Core primitive

Observations 345–357 qualified the pieces separately:

- neutral Event / Effect can retain security and settlement quantities;
- security-trade meaning should remain separate from Exchange meaning;
- acquisition basis is additive evidence;
- disposal provenance is independent from basis policy;
- average / quantization policy is a projection concern;
- historically booked basis can diverge from current-restated basis;
- booked-result amendment can reuse generic ReplacementFrontier mechanics.

This observation composes those boundaries into one selected practical history:

    purchase
      bank       -1000 jpy
      broker        +3 acme-share

    sale
      broker        -1 acme-share
      bank         +500 jpy

    original acquisition basis
      1000 jpy / 3 shares

    original per-unit ceil basis
      334 jpy

    original realised gain
      500 - 334 = 166 jpy

    original filing
      basis 334
      gain 166

Then the acquisition-basis evidence is corrected:

    corrected basis
      999 jpy / 3 shares

    current-restated unit basis
      333 jpy

    current-restated realised gain
      500 - 333 = 167 jpy

The original filing remains 334 / 166 until an explicit amendment arrives.

Finally:

    original filing 334 / 166
        ->
    amended filing 333 / 167

The question is not whether this is already production-ready.

The question is whether one realistic lifecycle can be composed from the small
boundaries already earned without introducing:

- an InvestmentTransaction Core variant;
- a universal LotId;
- a base currency;
- a new correction engine;
- mutable historical basis rows.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def shares : MeasureId := ⟨"acme-share"⟩

private def bank : LocusId := ⟨"bank"⟩
private def broker : LocusId := ⟨"broker"⟩

private def purchaseId : EventId := ⟨"o358-purchase"⟩
private def saleId : EventId := ⟨"o358-sale"⟩

private def purchaseCash : EffectKey := ⟨"o358-purchase-cash"⟩
private def purchaseShares : EffectKey := ⟨"o358-purchase-shares"⟩
private def saleShares : EffectKey := ⟨"o358-sale-shares"⟩
private def saleCash : EffectKey := ⟨"o358-sale-cash"⟩

private def purchase? : Option Event :=
  Event.ofEffects? purchaseId [
    Effect.ofQuantity purchaseCash bank yen (Quantity.ofQuanta (-1000)),
    Effect.ofQuantity purchaseShares broker shares (Quantity.ofQuanta 3)
  ]

private def sale? : Option Event :=
  Event.ofEffects? saleId [
    Effect.ofQuantity saleShares broker shares (Quantity.ofQuanta (-1)),
    Effect.ofQuantity saleCash bank yen (Quantity.ofQuanta 500)
  ]

private def events? : Option EventMemory := do
  let purchase ← purchase?
  let sale ← sale?
  EventMemory.ofEvents? [purchase, sale]

private def findEffectByKey?
    (event : Event)
    (key : EffectKey) : Option Effect :=
  event.effects.find? fun effect => effect.key = some key

structure SecurityTradeEvidence where
  event : EventId
  security : EffectKey
  settlement : EffectKey
deriving Repr, DecidableEq

inductive TradeDirection where
  | acquire
  | dispose
deriving Repr, DecidableEq

private def tradeDirection?
    (memory : EventMemory)
    (evidence : SecurityTradeEvidence) : Option TradeDirection := do
  let event ← memory.findById? evidence.event
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

private def purchaseTrade : SecurityTradeEvidence := {
  event := purchaseId
  security := purchaseShares
  settlement := purchaseCash
}

private def saleTrade : SecurityTradeEvidence := {
  event := saleId
  security := saleShares
  settlement := saleCash
}

theorem physical_events_support_purchase_and_sale_meaning :
    (do
      let memory ← events?
      pure (
        tradeDirection? memory purchaseTrade,
        tradeDirection? memory saleTrade)) =
      some (some .acquire, some .dispose) := by
  native_decide

theorem physical_history_leaves_two_shares_and_net_negative_500_jpy :
    (do
      let memory ← events?
      pure (
        (EventMemory.quantityAtRecorded memory broker shares).quanta,
        (EventMemory.quantityAtRecorded memory bank yen).quanta)) =
      some (2, -500) := by
  native_decide

structure EffectAnchor where
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

private def purchaseAnchor : EffectAnchor :=
  ⟨purchaseId, purchaseShares⟩

private def saleAnchor : EffectAnchor :=
  ⟨saleId, saleShares⟩

structure DisposalAttribution where
  disposal : EffectAnchor
  source : EffectAnchor
  units : Nat
deriving Repr, DecidableEq

private def selectedDisposal : DisposalAttribution := {
  disposal := saleAnchor
  source := purchaseAnchor
  units := 1
}

private def anchoredEffect?
    (memory : EventMemory)
    (anchor : EffectAnchor) : Option Effect := do
  let event ← memory.findById? anchor.event
  findEffectByKey? event anchor.effect

private def attributionAdmitted?
    (memory : EventMemory)
    (attribution : DisposalAttribution) : Bool :=
  match anchoredEffect? memory attribution.source,
        anchoredEffect? memory attribution.disposal with
  | some source, some disposal =>
      source.measure = shares &&
      disposal.measure = shares &&
      source.quantity.quanta > 0 &&
      disposal.quantity.quanta < 0 &&
      attribution.units = 1 &&
      source.quantity.quanta >= Int.ofNat attribution.units &&
      -disposal.quantity.quanta = Int.ofNat attribution.units
  | _, _ => false

theorem selected_sale_is_attributed_to_selected_acquisition :
    (do
      let memory ← events?
      pure (attributionAdmitted? memory selectedDisposal)) =
      some true := by
  native_decide

inductive BasisEvidenceId where
  | original
  | corrected
deriving Repr, DecidableEq

structure AcquisitionBasis where
  id : BasisEvidenceId
  source : EffectAnchor
  totalBasisJpy : Nat
  units : Nat
deriving Repr, DecidableEq

private def originalBasis : AcquisitionBasis := {
  id := .original
  source := purchaseAnchor
  totalBasisJpy := 1000
  units := 3
}

private def correctedBasis : AcquisitionBasis := {
  id := .corrected
  source := purchaseAnchor
  totalBasisJpy := 999
  units := 3
}

private structure BasisHistory where
  retained : List AcquisitionBasis
  replacements : List (ReplacementFrontier.Edge BasisEvidenceId)

private def basisPresent
    (history : BasisHistory)
    (id : BasisEvidenceId) : Bool :=
  history.retained.any fun row => decide (row.id = id)

private def effectiveBasis?
    (history : BasisHistory) : Option AcquisitionBasis := do
  if !ReplacementFrontier.structurallyAdmissible
      (basisPresent history) history.replacements then
    none
  let rows :=
    ReplacementFrontier.frontier
      AcquisitionBasis.id history.retained history.replacements
  match rows with
  | [row] => some row
  | _ => none

private def beforeBasisCorrection : BasisHistory := {
  retained := [originalBasis]
  replacements := []
}

private def afterBasisCorrection : BasisHistory := {
  retained := [originalBasis, correctedBasis]
  replacements := [
    { source := .original, successor := .corrected }
  ]
}

theorem basis_correction_preserves_old_evidence_and_moves_current_frontier :
    effectiveBasis? beforeBasisCorrection = some originalBasis ∧
    afterBasisCorrection.retained = [originalBasis, correctedBasis] ∧
    effectiveBasis? afterBasisCorrection = some correctedBasis := by
  native_decide

private def ceilUnitBasis?
    (basis : AcquisitionBasis) : Option Nat :=
  if basis.units = 0 then
    none
  else
    let q := basis.totalBasisJpy / basis.units
    let r := basis.totalBasisJpy % basis.units
    some (if r = 0 then q else q + 1)

private def saleProceeds? : Option Int := do
  let memory ← events?
  let event ← memory.findById? saleId
  let effect ← findEffectByKey? event saleCash
  if effect.measure != yen || effect.quantity.quanta <= 0 then
    none
  else
    some effect.quantity.quanta

private def currentRestatedAnswer?
    (history : BasisHistory) : Option (Nat × Int) := do
  let memory ← events?
  if !attributionAdmitted? memory selectedDisposal then
    none
  let basis ← effectiveBasis? history
  if basis.source != selectedDisposal.source then
    none
  let unitBasis ← ceilUnitBasis? basis
  let proceeds ← saleProceeds?
  let consumedBasis := unitBasis * selectedDisposal.units
  pure (consumedBasis, proceeds - Int.ofNat consumedBasis)

theorem original_history_projects_basis_334_and_gain_166 :
    currentRestatedAnswer? beforeBasisCorrection = some (334, 166) := by
  native_decide

theorem corrected_history_projects_basis_333_and_gain_167 :
    currentRestatedAnswer? afterBasisCorrection = some (333, 167) := by
  native_decide

inductive FilingId where
  | original
  | amended
deriving Repr, DecidableEq

structure FiledInvestmentResult where
  id : FilingId
  basisJpy : Nat
  realisedGainJpy : Int
deriving Repr, DecidableEq

private def filedOriginal : FiledInvestmentResult := {
  id := .original
  basisJpy := 334
  realisedGainJpy := 166
}

private def filedAmended : FiledInvestmentResult := {
  id := .amended
  basisJpy := 333
  realisedGainJpy := 167
}

private structure FilingHistory where
  retained : List FiledInvestmentResult
  replacements : List (ReplacementFrontier.Edge FilingId)

private def filingPresent
    (history : FilingHistory)
    (id : FilingId) : Bool :=
  history.retained.any fun row => decide (row.id = id)

private def effectiveFiling?
    (history : FilingHistory) : Option FiledInvestmentResult := do
  if !ReplacementFrontier.structurallyAdmissible
      (filingPresent history) history.replacements then
    none
  let rows :=
    ReplacementFrontier.frontier
      FiledInvestmentResult.id history.retained history.replacements
  match rows with
  | [row] => some row
  | _ => none

private def originalFilingHistory : FilingHistory := {
  retained := [filedOriginal]
  replacements := []
}

private def amendedFilingHistory : FilingHistory := {
  retained := [filedOriginal, filedAmended]
  replacements := [
    { source := .original, successor := .amended }
  ]
}

/--
Before any source correction, the original filing agrees with the then-current
projection.
-/
theorem original_filing_matches_original_projection :
    currentRestatedAnswer? beforeBasisCorrection =
      some (filedOriginal.basisJpy, filedOriginal.realisedGainJpy) ∧
    effectiveFiling? originalFilingHistory = some filedOriginal := by
  native_decide

/--
After source correction but before filing amendment, current-restated and
as-filed answers intentionally diverge.
-/
theorem source_correction_does_not_implicitly_amend_filing :
    currentRestatedAnswer? afterBasisCorrection = some (333, 167) ∧
    effectiveFiling? originalFilingHistory = some filedOriginal ∧
    filedOriginal.basisJpy = 334 ∧
    filedOriginal.realisedGainJpy = 166 := by
  native_decide

/--
An explicit amendment can then move the filing frontier to the corrected
integer answer without deleting the original filing.
-/
theorem explicit_amendment_reconciles_filing_with_restated_answer :
    currentRestatedAnswer? afterBasisCorrection =
      some (filedAmended.basisJpy, filedAmended.realisedGainJpy) ∧
    amendedFilingHistory.retained = [filedOriginal, filedAmended] ∧
    effectiveFiling? amendedFilingHistory = some filedAmended := by
  native_decide

structure LifecycleSnapshot where
  heldShares : Int
  netCashJpy : Int
  currentBasisJpy : Nat
  currentGainJpy : Int
  effectiveFiledBasisJpy : Nat
  effectiveFiledGainJpy : Int
deriving Repr, DecidableEq

private def lifecycleSnapshot?
    (basisHistory : BasisHistory)
    (filingHistory : FilingHistory) : Option LifecycleSnapshot := do
  let memory ← events?
  let (basisJpy, gainJpy) ← currentRestatedAnswer? basisHistory
  let filing ← effectiveFiling? filingHistory
  pure {
    heldShares :=
      (EventMemory.quantityAtRecorded memory broker shares).quanta
    netCashJpy :=
      (EventMemory.quantityAtRecorded memory bank yen).quanta
    currentBasisJpy := basisJpy
    currentGainJpy := gainJpy
    effectiveFiledBasisJpy := filing.basisJpy
    effectiveFiledGainJpy := filing.realisedGainJpy
  }

/--
Three points in one retained lifecycle:

1. original projection and original filing agree;
2. source correction changes only the current-restated coordinate;
3. explicit filing amendment moves the booked coordinate afterwards.

Physical holdings are unchanged throughout.
-/
theorem one_lifecycle_supports_original_divergent_and_amended_views :
    lifecycleSnapshot? beforeBasisCorrection originalFilingHistory =
      some {
        heldShares := 2
        netCashJpy := -500
        currentBasisJpy := 334
        currentGainJpy := 166
        effectiveFiledBasisJpy := 334
        effectiveFiledGainJpy := 166
      } ∧
    lifecycleSnapshot? afterBasisCorrection originalFilingHistory =
      some {
        heldShares := 2
        netCashJpy := -500
        currentBasisJpy := 333
        currentGainJpy := 167
        effectiveFiledBasisJpy := 334
        effectiveFiledGainJpy := 166
      } ∧
    lifecycleSnapshot? afterBasisCorrection amendedFilingHistory =
      some {
        heldShares := 2
        netCashJpy := -500
        currentBasisJpy := 333
        currentGainJpy := 167
        effectiveFiledBasisJpy := 333
        effectiveFiledGainJpy := 167
      } := by
  native_decide

/-!
## Finding

The selected end-to-end investment lifecycle composes.

The same retained physical purchase and sale support:

    exact holdings / cash
        from Event / Effect / Measure

    acquisition and disposal meaning
        from small domain evidence

    current basis
        from correction-aware acquisition-basis evidence

    current realised gain
        from sale proceeds + selected consumed basis

    historical filed basis / gain
        from an independently observed filing result

    amended filing
        from generic ReplacementFrontier mechanics

No new neutral Core primitive was required for the composition.

In particular, the witness does not require:

- InvestmentTransaction;
- LotId;
- base/home currency;
- mutable acquisition rows;
- booking-specific correction mechanics;
- one shared frontier for source correction and filing amendment.

The two revision domains remain independent:

    basis evidence frontier
        -> current-restated basis / gain

    filing frontier
        -> current effective filed basis / gain

That independence is observable in the middle state:

    current-restated = 333 / 167
    effective filing = 334 / 166

Only the later explicit amendment aligns them again.

## What remains before production

This observation is a composition witness, not a persistence design.

Production still needs to earn concrete domain evidence families and write paths
for at least:

- SecurityTrade semantic qualification / cross-Measure admission;
- acquisition basis evidence;
- disposal attribution;
- historically booked investment result, only if a real commitment workflow
  requires it.

The generic replacement mechanics already exist and need not be reinvented.

This materially narrows the original question "can LOAM implement stocks?":

> For this realistic purchase / sale / basis correction / filing amendment
> lifecycle, the remaining gap is production domain evidence and workflow
> plumbing, not a missing Core accounting algebra.

Still not earned:

- production investment schema;
- brokerage import semantics;
- settlement delay;
- fees / taxes in trade admission;
- dividends / reinvestment;
- short positions;
- corporate-action production writers;
- market valuation;
- tax-jurisdiction correctness;
- automatic filing generation.
-/

end Loam.Observation358
