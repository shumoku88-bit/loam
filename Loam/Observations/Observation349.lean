import Loam.Core.EventMemory

namespace Loam.Observation349

open Loam.Core

set_option autoImplicit false

/-!
# Observation 349 — average-cost basis can remain a projection over immutable acquisition evidence

Current hledger 2 lot work applies a strong pressure to the investment boundary:

- AVERAGE maintains one running per-unit cost for a pool.
- A new acquisition changes that running average.
- Existing lot basis is rewritten to the new pool cost in hledger's resolved
  lot state.
- Acquisition dates still survive, and disposal fragments remain useful for
  holding-period questions.

LOAM has a different historical discipline: retained acquisition evidence should
not be silently rewritten merely because a later policy projection changes.

This observation asks:

> Can the selected AVERAGE result be reconstructed from immutable acquisition
> basis evidence while acquisition provenance remains unchanged?

Selected history:

    Acquisition A
      +2 shares
      basis 600 JPY total
      original unit basis 300 JPY

    Acquisition B
      +4 shares
      basis 2400 JPY total
      original unit basis 600 JPY

After both acquisitions:

    quantity      6 shares
    total basis   3000 JPY
    average       500 JPY / share

Dispose three shares for 2100 JPY.

For holding-period provenance, the selected FIFO-shaped fragments are:

    A -> 2 shares
    B -> 1 share

Their original acquisition basis is:

    2 * 300 + 1 * 600 = 1200 JPY

Under AVERAGE, however, the consumed basis is:

    3 * 500 = 1500 JPY

So source provenance and basis policy are independently observable inputs even
when both use the same physical acquisition history.

The specimen is exactly divisible. No rounding rule is smuggled into the
observation.
-/

private def broker : LocusId := ⟨"broker"⟩
private def outside : LocusId := ⟨"outside"⟩
private def shares : MeasureId := ⟨"acme-share"⟩

private def acquisitionAId : EventId := ⟨"average-acquisition-a"⟩
private def acquisitionBId : EventId := ⟨"average-acquisition-b"⟩
private def disposalId : EventId := ⟨"average-disposal"⟩

private def acquisitionAKey : EffectKey := ⟨"average-a-held"⟩
private def acquisitionBKey : EffectKey := ⟨"average-b-held"⟩
private def disposalKey : EffectKey := ⟨"average-disposal-held"⟩

private def acquisitionA? : Option Event :=
  Event.ofEffects? acquisitionAId [
    Effect.ofQuantity acquisitionAKey broker shares (Quantity.ofQuanta 2),
    Effect.ofAnonymousQuantity outside shares (Quantity.ofQuanta (-2))
  ]

private def acquisitionB? : Option Event :=
  Event.ofEffects? acquisitionBId [
    Effect.ofQuantity acquisitionBKey broker shares (Quantity.ofQuanta 4),
    Effect.ofAnonymousQuantity outside shares (Quantity.ofQuanta (-4))
  ]

private def disposal? : Option Event :=
  Event.ofEffects? disposalId [
    Effect.ofQuantity disposalKey broker shares (Quantity.ofQuanta (-3)),
    Effect.ofAnonymousQuantity outside shares (Quantity.ofQuanta 3)
  ]

private def physicalMemory? : Option EventMemory := do
  let a ← acquisitionA?
  let b ← acquisitionB?
  let sale ← disposal?
  EventMemory.ofEvents? [a, b, sale]

theorem physical_history_leaves_three_shares :
    (do
      let memory ← physicalMemory?
      pure (EventMemory.quantityAtRecorded memory broker shares).quanta) =
      some 3 := by
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

structure AcquisitionBasis where
  source : EffectAnchor
  acquiredOn : String
  units : Int
  totalBasisJpy : Int
deriving Repr, DecidableEq

private def basisA : AcquisitionBasis := {
  source := acquisitionAAnchor
  acquiredOn := "2026-01-10"
  units := 2
  totalBasisJpy := 600
}

private def basisB : AcquisitionBasis := {
  source := acquisitionBAnchor
  acquiredOn := "2026-02-10"
  units := 4
  totalBasisJpy := 2400
}

private def acquisitions : List AcquisitionBasis :=
  [basisA, basisB]

structure AveragePool where
  units : Int
  totalBasisJpy : Int
deriving Repr, DecidableEq

private def addAcquisition
    (pool : AveragePool)
    (basis : AcquisitionBasis) : AveragePool :=
  {
    units := pool.units + basis.units
    totalBasisJpy := pool.totalBasisJpy + basis.totalBasisJpy
  }

private def poolOf (rows : List AcquisitionBasis) : AveragePool :=
  rows.foldl addAcquisition { units := 0, totalBasisJpy := 0 }

private def poolAfterA : AveragePool :=
  poolOf [basisA]

private def poolAfterAB : AveragePool :=
  poolOf acquisitions

/--
The average state changes when acquisition B arrives, while the retained basis A
record itself remains exactly the same value.
-/
theorem later_acquisition_changes_average_projection_not_prior_evidence :
    poolAfterA = { units := 2, totalBasisJpy := 600 } ∧
    poolAfterAB = { units := 6, totalBasisJpy := 3000 } ∧
    acquisitions.head? = some basisA := by
  native_decide

/--
Represent one exact unit basis only when the selected pool divides evenly.

A future production implementation may instead retain an exact rational or a
currency-specific rounding policy. This observation deliberately does neither.
-/
private def exactUnitBasis? (pool : AveragePool) : Option Int :=
  if pool.units <= 0 then
    none
  else if pool.totalBasisJpy % pool.units != 0 then
    none
  else
    some (pool.totalBasisJpy / pool.units)

theorem average_unit_basis_moves_from_300_to_500_without_rewriting_acquisitions :
    exactUnitBasis? poolAfterA = some 300 ∧
    exactUnitBasis? poolAfterAB = some 500 ∧
    basisA.totalBasisJpy = 600 ∧
    basisB.totalBasisJpy = 2400 := by
  native_decide

structure Consumption where
  source : EffectAnchor
  units : Int
deriving Repr, DecidableEq

/--
Selected holding-period provenance.

The order matches the earlier acquisition first, but this observation does not
promote FIFO as a universal law. It only needs one exact retained attribution.
-/
private def selectedFragments : List Consumption := [
  { source := acquisitionAAnchor, units := 2 },
  { source := acquisitionBAnchor, units := 1 }
]

private def basisFor? (anchor : EffectAnchor) : Option AcquisitionBasis :=
  acquisitions.find? fun row => row.source = anchor

private def originalConsumedBasisRow?
    (row : Consumption) : Option Int := do
  let basis ← basisFor? row.source
  if row.units <= 0 || row.units > basis.units then
    none
  else if basis.totalBasisJpy % basis.units != 0 then
    none
  else
    pure (row.units * (basis.totalBasisJpy / basis.units))

private def originalConsumedBasisRows?
    (rows : List Consumption) : Option Int :=
  match rows with
  | [] => some 0
  | row :: rest => do
      let current ← originalConsumedBasisRow? row
      let tail ← originalConsumedBasisRows? rest
      pure (current + tail)

private def exactAverageConsumedBasis?
    (pool : AveragePool)
    (disposedUnits : Int) : Option Int := do
  if disposedUnits <= 0 || disposedUnits > pool.units then
    none
  let numerator := pool.totalBasisJpy * disposedUnits
  if numerator % pool.units != 0 then
    none
  else
    pure (numerator / pool.units)

theorem same_fragments_have_1200_original_basis_but_1500_average_basis :
    originalConsumedBasisRows? selectedFragments = some 1200 ∧
    exactAverageConsumedBasis? poolAfterAB 3 = some 1500 := by
  native_decide

inductive BasisPolicy where
  | originalSource
  | averagePool
deriving Repr, DecidableEq

private def consumedBasis?
    (policy : BasisPolicy)
    (fragments : List Consumption)
    (pool : AveragePool)
    (disposedUnits : Int) : Option Int :=
  match policy with
  | .originalSource => originalConsumedBasisRows? fragments
  | .averagePool => exactAverageConsumedBasis? pool disposedUnits

/--
The exact same physical history, acquisition evidence, and fragment provenance
support different accounting basis answers under different policy.

Therefore disposal provenance does not determine basis policy.
-/
theorem retained_history_does_not_determine_basis_policy_answer :
    consumedBasis? .originalSource selectedFragments poolAfterAB 3 =
      some 1200 ∧
    consumedBasis? .averagePool selectedFragments poolAfterAB 3 =
      some 1500 := by
  native_decide

private def realisedGain?
    (policy : BasisPolicy)
    (saleProceedsJpy : Int) : Option Int := do
  let consumed ← consumedBasis? policy selectedFragments poolAfterAB 3
  pure (saleProceedsJpy - consumed)

theorem same_sale_has_different_gain_under_original_and_average_basis_policy :
    realisedGain? .originalSource 2100 = some 900 ∧
    realisedGain? .averagePool 2100 = some 600 := by
  native_decide

private def poolAfterAverageDisposal? : Option AveragePool := do
  let consumed ← exactAverageConsumedBasis? poolAfterAB 3
  pure {
    units := poolAfterAB.units - 3
    totalBasisJpy := poolAfterAB.totalBasisJpy - consumed
  }

theorem average_disposal_preserves_running_unit_basis_in_selected_exact_case :
    poolAfterAverageDisposal? =
      some { units := 3, totalBasisJpy := 1500 } ∧
    (do
      let remaining ← poolAfterAverageDisposal?
      exactUnitBasis? remaining) =
      some 500 := by
  native_decide

/--
A retained fragment relation can preserve acquisition dates independently of the
basis policy applied to the disposal.
-/
private def selectedAcquisitionDates : List String :=
  selectedFragments.filterMap fun fragment =>
    (basisFor? fragment.source).map (·.acquiredOn)

theorem average_basis_does_not_require_erasing_acquisition_dates :
    selectedAcquisitionDates = ["2026-01-10", "2026-02-10"] := by
  native_decide

/-!
## Finding

The selected AVERAGE pressure does not force mutable acquisition-basis history.

LOAM can retain:

    acquisition A
      2 shares
      600 JPY basis
      2026-01-10

    acquisition B
      4 shares
      2400 JPY basis
      2026-02-10

unchanged, then derive at the selected query point:

    pool quantity   = 6
    pool basis      = 3000 JPY
    average basis   = 500 JPY / share

A three-share disposal may still retain or derive acquisition-date provenance
such as A:2 + B:1, while its consumed accounting basis under AVERAGE is 1500 JPY
rather than the 1200 JPY original basis of those same fragments.

So the stronger partition is:

    immutable acquisition evidence
        !=
    quantity-bearing disposal provenance
        !=
    basis policy
        !=
    policy-selected pool state

This matches the architectural distinction hledger 2 exposes, but LOAM need not
copy hledger's resolved-state rewrite into canonical history.

A future practical implementation can first try:

    retained acquisition basis evidence
      + retained/selected disposal provenance
      + explicit AVERAGE policy
      + query horizon
          -> derived AveragePool state

rather than:

    mutate every historical acquisition row whenever a later acquisition changes
    the running average.

This observation also exposes the next real boundary: exact arithmetic.

The selected numbers divide evenly. Real average-cost accounting may require:

- exact rational internal basis;
- currency minor-unit allocation;
- residual-cent distribution;
- jurisdiction-specific rounding;
- transfer-in / transfer-out pool rules.

Those are not consequences of AVERAGE identity itself and should be pressured
separately.

The earlier policy-history observations remain relevant: if LOAM ever retains a
historical disposal attribution or booked basis answer, changing today's policy
must not silently rewrite that retained historical meaning.

Not earned here:

- production BasisPolicy;
- production AveragePool storage;
- canonical mutation of acquisition basis;
- FIFO as a universal fragment rule;
- tax-jurisdiction correctness;
- rounding/allocation policy;
- transfer pool semantics;
- production realised-gain postings;
- a LotId or mutable Inventory object.
-/

end Loam.Observation349
