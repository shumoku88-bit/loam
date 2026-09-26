namespace Loam.Observation350

set_option autoImplicit false

/-!
# Observation 350 — exact basis ratio is not quantization policy

Observation 349 showed that AVERAGE can be reconstructed as a policy-selected
pool projection without mutating retained acquisition evidence.

The next pressure is arithmetic.

A running average often does not terminate in the currency's minor unit. The
selected specimen is deliberately tiny:

    total basis = 1000 JPY
    quantity    = 3 shares

so the exact unit basis is:

    1000 / 3 JPY per share

Several practical systems make different choices at this boundary.

GnuCash's numeric layer represents exact rationals and makes output denominator
and rounding policy explicit:

- https://code.gnucash.org/docs/STABLE/group__Numeric.html

Current hledger 2 lot work instead keeps high-precision Decimal cost basis
internally and documents quantization when the rendered value crosses a file
boundary:

- https://hledger.org/SPEC-lots.html

For Japanese individual-stock acquisition cost, the current NTA guidance for
the selected "same issue acquired more than once" case computes a per-unit value
and rounds a fractional yen upward before multiplying by disposed units:

- https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/1466.htm
- https://www.nta.go.jp/law/tsutatsu/kobetsu/shotoku/sochiho/020624/sanrin/1273_1/37_10/01.htm

This observation does not choose one universal rule.

It asks whether LOAM can preserve:

    exact ratio
        !=
    rounding mode
        !=
    quantization stage

without adding any of them to neutral Core.
-/

structure BasisRatio where
  numeratorJpy : Nat
  denominatorUnits : Nat
deriving Repr, DecidableEq

private def exactAverage : BasisRatio := {
  numeratorJpy := 1000
  denominatorUnits := 3
}

private def scaleRatio
    (ratio : BasisRatio)
    (units : Nat) : BasisRatio := {
  numeratorJpy := ratio.numeratorJpy * units
  denominatorUnits := ratio.denominatorUnits
}

private def floorRatio? (ratio : BasisRatio) : Option Nat :=
  if ratio.denominatorUnits = 0 then
    none
  else
    some (ratio.numeratorJpy / ratio.denominatorUnits)

private def ceilRatio? (ratio : BasisRatio) : Option Nat :=
  if ratio.denominatorUnits = 0 then
    none
  else
    let q := ratio.numeratorJpy / ratio.denominatorUnits
    let r := ratio.numeratorJpy % ratio.denominatorUnits
    some (if r = 0 then q else q + 1)

private def nearestHalfUpRatio? (ratio : BasisRatio) : Option Nat :=
  if ratio.denominatorUnits = 0 then
    none
  else
    let q := ratio.numeratorJpy / ratio.denominatorUnits
    let r := ratio.numeratorJpy % ratio.denominatorUnits
    some (if 2 * r < ratio.denominatorUnits then q else q + 1)

inductive QuantizationMode where
  | floor
  | ceil
  | nearestHalfUp
deriving Repr, DecidableEq

private def quantizeRatio?
    (mode : QuantizationMode)
    (ratio : BasisRatio) : Option Nat :=
  match mode with
  | .floor => floorRatio? ratio
  | .ceil => ceilRatio? ratio
  | .nearestHalfUp => nearestHalfUpRatio? ratio

/--
The same exact ratio legitimately yields different integer-JPY projections under
different rounding modes.
-/
theorem exact_ratio_does_not_determine_rounding_mode :
    floorRatio? exactAverage = some 333 ∧
    ceilRatio? exactAverage = some 334 ∧
    nearestHalfUpRatio? exactAverage = some 333 := by
  native_decide

inductive QuantizationStage where
  | perUnitThenMultiply
  | multiplyExactThenQuantize
deriving Repr, DecidableEq

structure QuantizationPolicy where
  mode : QuantizationMode
  stage : QuantizationStage
deriving Repr, DecidableEq

private def projectDisposedBasis?
    (policy : QuantizationPolicy)
    (unitRatio : BasisRatio)
    (disposedUnits : Nat) : Option Nat :=
  match policy.stage with
  | .perUnitThenMultiply => do
      let unit ← quantizeRatio? policy.mode unitRatio
      pure (unit * disposedUnits)
  | .multiplyExactThenQuantize =>
      quantizeRatio? policy.mode (scaleRatio unitRatio disposedUnits)

private def ceilPerUnit : QuantizationPolicy := {
  mode := .ceil
  stage := .perUnitThenMultiply
}

private def ceilFinalAmount : QuantizationPolicy := {
  mode := .ceil
  stage := .multiplyExactThenQuantize
}

/--
The selected ratio exposes that *where* quantization happens is independent from
the rounding mode itself.

For two shares:

    ceil(1000 / 3) * 2 = 668

but:

    ceil((1000 * 2) / 3) = 667
-/
theorem identical_ratio_and_rounding_mode_can_differ_by_quantization_stage :
    projectDisposedBasis? ceilPerUnit exactAverage 2 = some 668 ∧
    projectDisposedBasis? ceilFinalAmount exactAverage 2 = some 667 := by
  native_decide

/--
Observation-local representation of the current Japanese selected rule:
per-unit acquisition value is rounded upward to whole yen before multiplication
by the disposed quantity.

This is not a Core law and is not claimed for every security, taxpayer,
jurisdiction, or accounting purpose.
-/
private def selectedJapanIndividualStockPolicy : QuantizationPolicy :=
  ceilPerUnit

theorem selected_japan_projection_is_one_policy_over_the_same_exact_ratio :
    projectDisposedBasis?
      selectedJapanIndividualStockPolicy exactAverage 2 =
      some 668 := by
  native_decide

/--
A quantized unit amount loses exact-ratio information.

Both exact ratios below round upward to 334 JPY per unit, but their exact total
basis differs.
-/
private def nearbyAverage : BasisRatio := {
  numeratorJpy := 1001
  denominatorUnits := 3
}

theorem quantized_unit_basis_does_not_reconstruct_exact_basis_ratio :
    exactAverage ≠ nearbyAverage ∧
    ceilRatio? exactAverage = some 334 ∧
    ceilRatio? nearbyAverage = some 334 := by
  native_decide

structure AveragePool where
  units : Nat
  totalBasisJpy : Nat
deriving Repr, DecidableEq

private def selectedPool : AveragePool := {
  units := 3
  totalBasisJpy := 1000
}

private def exactRatioOfPool? (pool : AveragePool) : Option BasisRatio :=
  if pool.units = 0 then
    none
  else
    some {
      numeratorJpy := pool.totalBasisJpy
      denominatorUnits := pool.units
    }

theorem exact_ratio_is_reconstructable_from_unquantized_pool_state :
    exactRatioOfPool? selectedPool = some exactAverage := by
  native_decide

/--
No rounded unit-basis field is required to reconstruct the selected exact
AVERAGE state.

The retained sufficient state is still the pool's exact total basis and exact
quantity.
-/
theorem selected_pool_preserves_more_information_than_rounded_unit_basis :
    exactRatioOfPool? selectedPool = some exactAverage ∧
    ceilRatio? exactAverage = some 334 ∧
    selectedPool.totalBasisJpy = 1000 ∧
    selectedPool.units = 3 := by
  native_decide

/-!
## Finding

The selected arithmetic pressure separates three independent questions:

    What is the exact average?
        1000 / 3 JPY per share

    How should that ratio be quantized?
        floor / ceil / nearest / jurisdiction-specific rule

    At which stage should quantization occur?
        per-unit first
        or
        exact subtotal first

The last distinction is observable:

    per-unit ceil, then multiply two shares
        -> 668 JPY

    multiply exact ratio by two, then ceil
        -> 667 JPY

So even one common rounding mode does not determine the final accounting answer
without a quantization-stage policy.

A rounded per-unit result also does not determine the exact retained basis
ratio: 1000/3 and 1001/3 both ceil to 334.

The strongest current LOAM candidate is therefore:

    immutable acquisition evidence
        +
    exact pool totals
        ->
    exact derived ratio

    exact ratio
        +
    selected quantization policy
        ->
    currency-minor-unit answer

rather than:

    store one rounded average unit basis as canonical investment truth

This is compatible with GnuCash's explicit exact-rational / rounding boundary,
with hledger 2's effort to retain more internal basis precision than it displays,
and with jurisdiction-specific tax rules such as the selected Japanese
per-unit-ceiling rule.

No neutral Core change is earned.

In particular, this observation does not earn:

- a Core Rational type;
- a universal rounding mode;
- a universal quantization stage;
- Japanese tax policy in reusable investment semantics;
- production AveragePool persistence;
- production tax calculation;
- a promise that Nat-sized observation arithmetic is sufficient for production;
- allocation of a remaining minor-unit residual across several disposals.

That last item is the next genuine pressure: once several rounded outputs must
sum back to one exact finite total, a remainder-allocation policy may become
independently observable.
-/

end Loam.Observation350
