import Init.Data.List.Nat.Basic

namespace Loam.Observation352

set_option autoImplicit false

/-!
# Observation 352 — weighted exact apportionment is the stronger remainder kernel

Observation 351 re-derived the old equal-allocation conservation theorem from a
real investment pressure:

    exact total basis
        -> indivisible integer fragments
        -> explicit remainder placement

But equal fragments are not the general investment case.

A disposal or retained position can contain unequal quantities. The selected
specimen assigns one exact 1000 JPY basis total across three fragments whose
weights are:

    A = 4 units
    B = 2 units
    C = 1 unit

The exact proportional quotas are therefore:

    A = 4000 / 7
    B = 2000 / 7
    C = 1000 / 7

Their floors are:

    [571, 285, 142]
    sum = 998

Two indivisible JPY quanta remain.

Several integer allocations can conserve 1000 while staying within one quantum
of every exact quota:

    extras A,B -> [572, 286, 142]
    extras A,C -> [572, 285, 143]
    extras B,C -> [571, 286, 143]

So exact conservation plus weights still does not determine historical
assignment.

The exact fractional remainders are:

    A -> 3/7
    B -> 5/7
    C -> 6/7

For this selected case, assigning the two extra quanta to C then B yields the
smallest scaled absolute quota error among the three explicit candidates.

The observation does not promote "largest remainder" into a universal policy.
It only tests whether weighted apportionment is the genuinely stronger numeric
shape behind both the new investment pressure and the previously retired equal
Allocation kernel.
-/

structure FragmentId where
  token : String
deriving Repr, DecidableEq

structure WeightedFragment where
  id : FragmentId
  weight : Nat
deriving Repr, DecidableEq

private def fragmentA : FragmentId := ⟨"fragment-a"⟩
private def fragmentB : FragmentId := ⟨"fragment-b"⟩
private def fragmentC : FragmentId := ⟨"fragment-c"⟩

private def weightedFragments : List WeightedFragment := [
  ⟨fragmentA, 4⟩,
  ⟨fragmentB, 2⟩,
  ⟨fragmentC, 1⟩
]

private def totalBasis : Nat := 1000

private def weightTotal (rows : List WeightedFragment) : Nat :=
  rows.foldl (fun total row => total + row.weight) 0

private def quotaFloor
    (total denominator : Nat)
    (row : WeightedFragment) : Nat :=
  if denominator = 0 then
    0
  else
    (total * row.weight) / denominator

private def quotaRemainder
    (total denominator : Nat)
    (row : WeightedFragment) : Nat :=
  if denominator = 0 then
    0
  else
    (total * row.weight) % denominator

private def floorRows
    (total : Nat)
    (rows : List WeightedFragment) : List (FragmentId × Nat) :=
  let denominator := weightTotal rows
  rows.map fun row =>
    (row.id, quotaFloor total denominator row)

private def sumAssigned
    (rows : List (FragmentId × Nat)) : Nat :=
  rows.foldl (fun total row => total + row.2) 0

private def getsExtra
    (extras : List FragmentId)
    (id : FragmentId) : Nat :=
  if extras.any fun extra => decide (extra = id) then 1 else 0

private def apportionedRows
    (total : Nat)
    (rows : List WeightedFragment)
    (extras : List FragmentId) : List (FragmentId × Nat) :=
  let denominator := weightTotal rows
  rows.map fun row =>
    (row.id,
      quotaFloor total denominator row + getsExtra extras row.id)

theorem selected_weighted_exact_quotas_have_distinct_floors_and_remainders :
    weightTotal weightedFragments = 7 ∧
    floorRows totalBasis weightedFragments =
      [(fragmentA, 571), (fragmentB, 285), (fragmentC, 142)] ∧
    quotaRemainder totalBasis 7 ⟨fragmentA, 4⟩ = 3 ∧
    quotaRemainder totalBasis 7 ⟨fragmentB, 2⟩ = 5 ∧
    quotaRemainder totalBasis 7 ⟨fragmentC, 1⟩ = 6 := by
  native_decide

theorem floor_projection_leaves_two_indivisible_quanta :
    sumAssigned (floorRows totalBasis weightedFragments) = 998 ∧
    totalBasis - sumAssigned (floorRows totalBasis weightedFragments) = 2 := by
  native_decide

private def extrasAB : List FragmentId := [fragmentA, fragmentB]
private def extrasAC : List FragmentId := [fragmentA, fragmentC]
private def extrasBC : List FragmentId := [fragmentB, fragmentC]

theorem three_distinct_near_quota_allocations_all_conserve_total :
    apportionedRows totalBasis weightedFragments extrasAB =
      [(fragmentA, 572), (fragmentB, 286), (fragmentC, 142)] ∧
    apportionedRows totalBasis weightedFragments extrasAC =
      [(fragmentA, 572), (fragmentB, 285), (fragmentC, 143)] ∧
    apportionedRows totalBasis weightedFragments extrasBC =
      [(fragmentA, 571), (fragmentB, 286), (fragmentC, 143)] ∧
    sumAssigned (apportionedRows totalBasis weightedFragments extrasAB) =
      totalBasis ∧
    sumAssigned (apportionedRows totalBasis weightedFragments extrasAC) =
      totalBasis ∧
    sumAssigned (apportionedRows totalBasis weightedFragments extrasBC) =
      totalBasis := by
  native_decide

/--
Conservation and exact weights still do not determine which fragments receive
the indivisible extra quanta.
-/
theorem weighted_conservation_does_not_determine_recipient_assignment :
    apportionedRows totalBasis weightedFragments extrasAB ≠
      apportionedRows totalBasis weightedFragments extrasBC := by
  native_decide

private def absDiff (left right : Nat) : Nat :=
  if left ≤ right then right - left else left - right

/--
Compare an integer assigned amount with its exact quota without introducing a
Rational type.

Both sides are scaled by the common positive denominator.
-/
private def scaledQuotaError
    (total denominator assigned weight : Nat) : Nat :=
  absDiff (assigned * denominator) (total * weight)

private def selectedErrorAB : Nat :=
  scaledQuotaError totalBasis 7 572 4 +
  scaledQuotaError totalBasis 7 286 2 +
  scaledQuotaError totalBasis 7 142 1

private def selectedErrorAC : Nat :=
  scaledQuotaError totalBasis 7 572 4 +
  scaledQuotaError totalBasis 7 285 2 +
  scaledQuotaError totalBasis 7 143 1

private def selectedErrorBC : Nat :=
  scaledQuotaError totalBasis 7 571 4 +
  scaledQuotaError totalBasis 7 286 2 +
  scaledQuotaError totalBasis 7 143 1

/--
For this concrete specimen, assigning the extra quanta to the two largest exact
fractional remainders B and C gives the smallest scaled absolute error among the
three explicit conserving candidates.

This is evidence for a policy candidate, not a generic optimality theorem.
-/
theorem largest_remainder_candidate_is_closest_in_selected_case :
    selectedErrorAB = 12 ∧
    selectedErrorAC = 10 ∧
    selectedErrorBC = 6 ∧
    selectedErrorBC < selectedErrorAC ∧
    selectedErrorAC < selectedErrorAB := by
  native_decide

/--
The previously retired equal-allocation shape is a strict special case of
weighted apportionment where every recipient has weight one.
-/
private def equalFragments : List WeightedFragment := [
  ⟨fragmentA, 1⟩,
  ⟨fragmentB, 1⟩,
  ⟨fragmentC, 1⟩
]

theorem equal_weight_special_case_recovers_old_front_allocation :
    weightTotal equalFragments = 3 ∧
    apportionedRows totalBasis equalFragments [fragmentA] =
      [(fragmentA, 334), (fragmentB, 333), (fragmentC, 333)] ∧
    sumAssigned
      (apportionedRows totalBasis equalFragments [fragmentA]) =
      totalBasis := by
  native_decide

/--
Simply conserving 1000 while ignoring the weights answers a different question.

The old equal result is exact as an equal split, but it is not the selected
4:2:1 proportional projection.
-/
theorem equal_allocation_is_not_weighted_allocation :
    apportionedRows totalBasis equalFragments [fragmentA] ≠
      apportionedRows totalBasis weightedFragments extrasBC := by
  native_decide

/-!
## Finding

The investment pressure is stronger than the old equal Allocation kernel.

The common numeric skeleton is now:

    exact integer total T
        +
    positive recipient weights w_i
        |
        v
    exact quota numerators T * w_i
    common denominator sum(w_i)
        |
        v
    floor quota for every recipient
        +
    finite missing-quanta count
        |
        v
    explicit policy selects recipients for +1 quanta
        |
        v
    integer assignment

The old equal allocator is recovered when every weight is one.

So if this mathematics is eventually promoted again, resurrecting only the old
equal-count API would likely be too narrow. A weighted apportionment kernel is
the more general candidate.

But this observation also prevents premature promotion.

Even with:

- exact total;
- exact weights;
- each output staying at floor or ceil of its quota;
- exact aggregate conservation;

multiple historical assignments remain valid.

A policy is still required to decide which recipients receive remainder quanta.

The selected largest-fractional-remainder choice has lower scaled absolute error
than the two other explicit candidates, but this observation does not prove a
generic optimum and does not declare that criterion authoritative for tax,
investment, budgeting, or any other domain.

The architecture boundary is therefore:

    exact proportional arithmetic
        !=
    remainder-recipient selection policy
        !=
    domain authority choosing that policy

This is now a stronger mathematical recurrence than Observation 351:

    equal exact allocation
        is a special case of
    weighted exact apportionment

Still not earned:

- resurrection of a production Allocation module;
- a Core WeightedAllocation type;
- a universal largest-remainder policy;
- generic sorting / tie-breaking rules;
- negative weights or signed totals;
- zero-weight recipient semantics;
- correction/reversal semantics for retained assignments;
- temporal fairness or rotation;
- proof of generic optimality;
- jurisdiction-specific tax authority.

The next pressure, if pursued, should target ties and stability:

    equal fractional remainders
        +
    recipient reorder / insertion
        ->
    does historical assignment change?

That would reveal whether policy needs stable recipient identity and retained
tie-break provenance rather than relying on list order.
-/

end Loam.Observation352
