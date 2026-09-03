module experiments/observation_134_capacity_formula_composition

abstract sig Purpose {}
one sig Food, Travel extends Purpose {}

-- Experiment-local half-open DateRanges. No Cycle identity participates.
abstract sig Range {
  start: one Int,
  end: one Int
}
one sig LeftRange, RightRange, UnionRange, OverlapLeft extends Range {}

-- Same small affine scaffold as Observation 132. This is not proposed as a
-- universal formula language.
abstract sig CapacityFormula {
  base: Purpose -> one Int,
  perDay: Purpose -> one Int
}
one sig RateFormula, RateFormulaCopy, FixedFormula extends CapacityFormula {}

fun duration[r: Range]: one Int {
  sub[r.end, r.start]
}

fun capacity[f: CapacityFormula, r: Range, p: Purpose]: one Int {
  add[p.(f.base), mul[p.(f.perDay), duration[r]]]
}

pred adjacentUnion[left, right, whole: Range] {
  left.end = right.start
  whole.start = left.start
  whole.end = right.end
}

fact FixedRanges {
  LeftRange.start = 0
  LeftRange.end = 2

  RightRange.start = 2
  RightRange.end = 5

  UnionRange.start = 0
  UnionRange.end = 5

  -- Overlaps RightRange on [2,3).
  OverlapLeft.start = 0
  OverlapLeft.end = 3

  all r: Range | {
    r.start >= 0
    r.start < r.end
    r.end <= 5
  }
}

fact FixedFormulaDefinitions {
  -- Pure duration rate. No per-window intercept.
  Food.(RateFormula.base) = 0
  Travel.(RateFormula.base) = 0
  Food.(RateFormula.perDay) = 3
  Travel.(RateFormula.perDay) = 1

  -- Identity-distinct copy of exactly the same definition.
  Food.(RateFormulaCopy.base) = 0
  Travel.(RateFormulaCopy.base) = 0
  Food.(RateFormulaCopy.perDay) = 3
  Travel.(RateFormulaCopy.perDay) = 1

  -- Fixed amount per selected window. Splitting one long window into two
  -- windows repeats this intercept.
  Food.(FixedFormula.base) = 10
  Travel.(FixedFormula.base) = 4
  Food.(FixedFormula.perDay) = 0
  Travel.(FixedFormula.perDay) = 0
}

fact ValidFormulaQuantities {
  all f: CapacityFormula, p: Purpose | {
    p.(f.base) >= 0
    p.(f.base) <= 10
    p.(f.perDay) >= 0
    p.(f.perDay) <= 3
  }
}

pred pureRateAdjacentRangesCompose {
  adjacentUnion[LeftRange, RightRange, UnionRange]
  all p: Purpose |
    add[capacity[RateFormula, LeftRange, p],
        capacity[RateFormula, RightRange, p]] =
      capacity[RateFormula, UnionRange, p]
}

pred fixedPerWindowAdjacentRangesDoNotCompose {
  adjacentUnion[LeftRange, RightRange, UnionRange]
  capacity[FixedFormula, LeftRange, Food] = 10
  capacity[FixedFormula, RightRange, Food] = 10
  capacity[FixedFormula, UnionRange, Food] = 10
  add[capacity[FixedFormula, LeftRange, Food],
      capacity[FixedFormula, RightRange, Food]] !=
    capacity[FixedFormula, UnionRange, Food]
}

pred overlappingRateViewsAreNotAdditive {
  -- [0,3) + [2,5) double-counts one day relative to [0,5).
  capacity[RateFormula, OverlapLeft, Food] = 9
  capacity[RateFormula, RightRange, Food] = 9
  capacity[RateFormula, UnionRange, Food] = 15
  add[capacity[RateFormula, OverlapLeft, Food],
      capacity[RateFormula, RightRange, Food]] !=
    capacity[RateFormula, UnionRange, Food]
}

pred equalDefinitionDifferentIdentitySameCompositionAnswer {
  all p: Purpose | {
    p.(RateFormula.base) = p.(RateFormulaCopy.base)
    p.(RateFormula.perDay) = p.(RateFormulaCopy.perDay)
    capacity[RateFormula, UnionRange, p] =
      capacity[RateFormulaCopy, UnionRange, p]
  }
}

-- Deliberately too strong. Adjacency and formula identity alone do not make
-- every formula additive across partitioned ranges; FixedFormula is a witness.
assert SameFormulaAdjacentRangesAlwaysCompose {
  all f: CapacityFormula |
    all p: Purpose |
      add[capacity[f, LeftRange, p], capacity[f, RightRange, p]] =
        capacity[f, UnionRange, p]
}

-- For this bounded affine scaffold, a zero per-window intercept is enough for
-- adjacent partition composition. The interval lengths add exactly.
assert ZeroInterceptAdjacentRangesCompose {
  all f: CapacityFormula |
    (all p: Purpose | p.(f.base) = 0) implies
      all p: Purpose |
        add[capacity[f, LeftRange, p], capacity[f, RightRange, p]] =
          capacity[f, UnionRange, p]
}

-- In this bounded non-negative affine scaffold, adjacent additivity across all
-- Purposes is equivalent to having no per-window intercept. Composition law is
-- therefore derivable from formula definition rather than a separate role tag.
assert AdjacentAdditivityCharacterizedByZeroIntercept {
  all f: CapacityFormula |
    ((all p: Purpose | p.(f.base) = 0) iff
      (all p: Purpose |
        add[capacity[f, LeftRange, p], capacity[f, RightRange, p]] =
          capacity[f, UnionRange, p]))
}

-- Deliberately too strong. Even an additive rate formula cannot be naively
-- summed across overlapping ranges because shared time is counted twice.
assert ZeroInterceptOverlappingRangesComposeByAddition {
  all p: Purpose |
    add[capacity[RateFormula, OverlapLeft, p],
        capacity[RateFormula, RightRange, p]] =
      capacity[RateFormula, UnionRange, p]
}

-- Formula identity remains unnecessary once information-equivalent definition
-- and range are fixed.
assert EqualDefinitionDeterminesSelectedCapacity {
  all p: Purpose |
    capacity[RateFormula, UnionRange, p] =
      capacity[RateFormulaCopy, UnionRange, p]
}

run pureRateAdjacentRangesCompose for 6 Int
run fixedPerWindowAdjacentRangesDoNotCompose for 6 Int
run overlappingRateViewsAreNotAdditive for 6 Int
run equalDefinitionDifferentIdentitySameCompositionAnswer for 6 Int

check SameFormulaAdjacentRangesAlwaysCompose for 6 Int
check ZeroInterceptAdjacentRangesCompose for 6 Int
check AdjacentAdditivityCharacterizedByZeroIntercept for 6 Int
check ZeroInterceptOverlappingRangesComposeByAddition for 6 Int
check EqualDefinitionDeterminesSelectedCapacity for 6 Int
