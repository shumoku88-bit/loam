module experiments/observation_132_date_range_capacity_policy

abstract sig Purpose {}
one sig Food, Travel extends Purpose {}

-- Experiment-local half-open ranges. No Cycle identity or recurrence kind is
-- used by the Capacity formula itself.
abstract sig Range {
  start: one Int,
  end: one Int
}
one sig ShortRange, ShortRangeCopy, LongRange extends Range {}

-- A deliberately tiny formula scaffold. It is not proposed as a universal DSL.
-- A definition maps range duration to base Capacity with one intercept and one
-- per-day coefficient per Purpose.
abstract sig CapacityFormula {
  base: Purpose -> one Int,
  perDay: Purpose -> one Int
}
one sig FixedFormula, DailyFormula, DailyFormulaCopy extends CapacityFormula {}

-- Existing Capacity-movement pressure remains independently observable. This
-- experiment represents only one bounded Purpose-to-Purpose reallocation.
abstract sig Adjustment {
  source: one Purpose,
  target: one Purpose,
  qty: one Int
}
one sig MoveTwo extends Adjustment {}

-- Query/application context only: choose a resolved DateRange, a formula
-- definition, and zero or more retained Capacity adjustments.
abstract sig Context {
  range: one Range,
  formula: one CapacityFormula,
  adjustments: set Adjustment
}
one sig DailyShort, DailyShortCopy, DailyLong,
        FixedShort, DailyShortAdjusted extends Context {}

fun duration[r: Range]: one Int {
  sub[r.end, r.start]
}

fun baseCapacity[f: CapacityFormula, r: Range, p: Purpose]: one Int {
  add[p.(f.base), mul[p.(f.perDay), duration[r]]]
}

fun incoming[c: Context, p: Purpose]: one Int {
  sum a: c.adjustments | a.target = p => a.qty else 0
}

fun outgoing[c: Context, p: Purpose]: one Int {
  sum a: c.adjustments | a.source = p => a.qty else 0
}

fun finalCapacity[c: Context, p: Purpose]: one Int {
  add[baseCapacity[c.formula, c.range, p], sub[incoming[c, p], outgoing[c, p]]]
}

fun totalBase[c: Context]: one Int {
  sum p: Purpose | baseCapacity[c.formula, c.range, p]
}

fun totalFinal[c: Context]: one Int {
  sum p: Purpose | finalCapacity[c, p]
}

fact FixedRanges {
  ShortRange.start = 0
  ShortRange.end = 2

  ShortRangeCopy.start = 0
  ShortRangeCopy.end = 2

  LongRange.start = 0
  LongRange.end = 4

  all r: Range | r.start < r.end
}

fact FixedFormulaDefinitions {
  -- Fixed-per-selected-window example.
  Food.(FixedFormula.base) = 10
  Travel.(FixedFormula.base) = 4
  Food.(FixedFormula.perDay) = 0
  Travel.(FixedFormula.perDay) = 0

  -- Duration-sensitive example.
  Food.(DailyFormula.base) = 0
  Travel.(DailyFormula.base) = 0
  Food.(DailyFormula.perDay) = 3
  Travel.(DailyFormula.perDay) = 1

  -- Identity-distinct copy with exactly the same definition.
  Food.(DailyFormulaCopy.base) = 0
  Travel.(DailyFormulaCopy.base) = 0
  Food.(DailyFormulaCopy.perDay) = 3
  Travel.(DailyFormulaCopy.perDay) = 1
}

fact FixedAdjustment {
  MoveTwo.source = Food
  MoveTwo.target = Travel
  MoveTwo.qty = 2
}

fact FixedContexts {
  DailyShort.range = ShortRange
  DailyShort.formula = DailyFormula
  no DailyShort.adjustments

  DailyShortCopy.range = ShortRangeCopy
  DailyShortCopy.formula = DailyFormulaCopy
  no DailyShortCopy.adjustments

  DailyLong.range = LongRange
  DailyLong.formula = DailyFormula
  no DailyLong.adjustments

  FixedShort.range = ShortRange
  FixedShort.formula = FixedFormula
  no FixedShort.adjustments

  DailyShortAdjusted.range = ShortRange
  DailyShortAdjusted.formula = DailyFormula
  DailyShortAdjusted.adjustments = MoveTwo
}

fact ValidQuantities {
  all f: CapacityFormula, p: Purpose | {
    p.(f.base) >= 0
    p.(f.perDay) >= 0
  }
  all a: Adjustment | {
    a.qty > 0
    a.source != a.target
  }
  all c: Context, p: Purpose | finalCapacity[c, p] >= 0
}

pred equalDefinitionDifferentIdentitySameAnswer {
  DailyShort.range.start = DailyShortCopy.range.start
  DailyShort.range.end = DailyShortCopy.range.end
  all p: Purpose | {
    p.(DailyShort.formula.base) = p.(DailyShortCopy.formula.base)
    p.(DailyShort.formula.perDay) = p.(DailyShortCopy.formula.perDay)
    finalCapacity[DailyShort, p] = finalCapacity[DailyShortCopy, p]
  }
}

pred sameFormulaDifferentRangeChangesBase {
  baseCapacity[DailyFormula, ShortRange, Food] = 6
  baseCapacity[DailyFormula, LongRange, Food] = 12
  baseCapacity[DailyFormula, ShortRange, Food] !=
    baseCapacity[DailyFormula, LongRange, Food]
}

pred sameRangeDifferentFormulaChangesBase {
  baseCapacity[DailyFormula, ShortRange, Food] = 6
  baseCapacity[FixedFormula, ShortRange, Food] = 10
  baseCapacity[DailyFormula, ShortRange, Food] !=
    baseCapacity[FixedFormula, ShortRange, Food]
}

pred retainedReallocationChangesAllocationWithoutNewCycle {
  finalCapacity[DailyShort, Food] = 6
  finalCapacity[DailyShort, Travel] = 2
  finalCapacity[DailyShortAdjusted, Food] = 4
  finalCapacity[DailyShortAdjusted, Travel] = 4
  totalFinal[DailyShort] = totalFinal[DailyShortAdjusted]
}

pred formulaSwitchAndAdjustmentCoexist {
  finalCapacity[FixedShort, Food] = 10
  finalCapacity[DailyShort, Food] = 6
  finalCapacity[DailyShortAdjusted, Food] = 4
}

-- The resolved DateRange does not own Capacity authority. Different formula
-- definitions can give different base Capacity for the same endpoints.
assert DateRangeAloneDeterminesGeneratedCapacity {
  all c1, c2: Context |
    (c1.range.start = c2.range.start and c1.range.end = c2.range.end) implies
      all p: Purpose |
        baseCapacity[c1.formula, c1.range, p] =
          baseCapacity[c2.formula, c2.range, p]
}

-- Formula-generated base Capacity does not erase retained user reallocation.
-- Same range and same formula can still have different final Capacity.
assert DateRangeAndFormulaDetermineFinalCapacity {
  all c1, c2: Context |
    (c1.range.start = c2.range.start and
     c1.range.end = c2.range.end and
     c1.formula = c2.formula) implies
      all p: Purpose | finalCapacity[c1, p] = finalCapacity[c2, p]
}

-- Formula identity itself is not needed once the definition is equal.
assert FormulaDefinitionAndRangeDetermineGeneratedBase {
  all c1, c2: Context |
    (c1.range.start = c2.range.start and
     c1.range.end = c2.range.end and
     (all p: Purpose | {
       p.(c1.formula.base) = p.(c2.formula.base)
       p.(c1.formula.perDay) = p.(c2.formula.perDay)
     })) implies
      all p: Purpose |
        baseCapacity[c1.formula, c1.range, p] =
          baseCapacity[c2.formula, c2.range, p]
}

-- Once range, formula definition, and retained adjustment evidence are fixed,
-- this bounded final-Capacity projection is fixed. No Cycle identity participates.
assert RangeFormulaAndAdjustmentsDetermineFinalCapacity {
  all c1, c2: Context |
    (c1.range.start = c2.range.start and
     c1.range.end = c2.range.end and
     c1.adjustments = c2.adjustments and
     (all p: Purpose | {
       p.(c1.formula.base) = p.(c2.formula.base)
       p.(c1.formula.perDay) = p.(c2.formula.perDay)
     })) implies
      all p: Purpose | finalCapacity[c1, p] = finalCapacity[c2, p]
}

-- The bounded Purpose-to-Purpose adjustment changes allocation, not total
-- generated authority.
assert RetainedAdjustmentConservesSelectedTotal {
  totalFinal[DailyShortAdjusted] = totalBase[DailyShortAdjusted]
}

run equalDefinitionDifferentIdentitySameAnswer for 6 Int
run sameFormulaDifferentRangeChangesBase for 6 Int
run sameRangeDifferentFormulaChangesBase for 6 Int
run retainedReallocationChangesAllocationWithoutNewCycle for 6 Int
run formulaSwitchAndAdjustmentCoexist for 6 Int

check DateRangeAloneDeterminesGeneratedCapacity for 6 Int
check DateRangeAndFormulaDetermineFinalCapacity for 6 Int
check FormulaDefinitionAndRangeDetermineGeneratedBase for 6 Int
check RangeFormulaAndAdjustmentsDetermineFinalCapacity for 6 Int
check RetainedAdjustmentConservesSelectedTotal for 6 Int
