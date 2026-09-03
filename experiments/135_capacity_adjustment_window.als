module capacity_adjustment_window

open util/integer

abstract sig Purpose {}
one sig Food, Travel extends Purpose {}

abstract sig Range {
  start : one Int,
  end : one Int
}

one sig PensionRange, FirstRange, MonthRange, SecondRange extends Range {}

abstract sig CapacityFormula {
  base : Purpose -> one Int,
  perDay : Purpose -> one Int
}

one sig FixedFormula, FixedFormulaCopy extends CapacityFormula {}

abstract sig Adjustment {
  effectiveDay : one Int,
  delta : Purpose -> one Int
}

one sig EarlyReallocation, LateReallocation extends Adjustment {}

abstract sig Context {
  authority : one Range,
  view : one Range,
  formula : one CapacityFormula
}

one sig PensionWhole,
        PensionFirst,
        PensionMonth,
        PensionMonthCopy,
        PensionSecond,
        ResetMonth extends Context {}

fact Specimen {
  PensionRange.start = 0
  PensionRange.end = 4

  FirstRange.start = 0
  FirstRange.end = 2

  MonthRange.start = 2
  MonthRange.end = 3

  SecondRange.start = 2
  SecondRange.end = 4

  FixedFormula.base[Food] = 10
  FixedFormula.base[Travel] = 4
  FixedFormula.perDay[Food] = 0
  FixedFormula.perDay[Travel] = 0

  FixedFormulaCopy.base[Food] = 10
  FixedFormulaCopy.base[Travel] = 4
  FixedFormulaCopy.perDay[Food] = 0
  FixedFormulaCopy.perDay[Travel] = 0

  EarlyReallocation.effectiveDay = 1
  EarlyReallocation.delta[Food] = -2
  EarlyReallocation.delta[Travel] = 2

  LateReallocation.effectiveDay = 3
  LateReallocation.delta[Food] = 1
  LateReallocation.delta[Travel] = -1

  PensionWhole.authority = PensionRange
  PensionWhole.view = PensionRange
  PensionWhole.formula = FixedFormula

  PensionFirst.authority = PensionRange
  PensionFirst.view = FirstRange
  PensionFirst.formula = FixedFormula

  PensionMonth.authority = PensionRange
  PensionMonth.view = MonthRange
  PensionMonth.formula = FixedFormula

  PensionMonthCopy.authority = PensionRange
  PensionMonthCopy.view = MonthRange
  PensionMonthCopy.formula = FixedFormulaCopy

  PensionSecond.authority = PensionRange
  PensionSecond.view = SecondRange
  PensionSecond.formula = FixedFormula

  ResetMonth.authority = MonthRange
  ResetMonth.view = MonthRange
  ResetMonth.formula = FixedFormula

  all c : Context |
    gte[c.view.start, c.authority.start] and
    lte[c.view.end, c.authority.end]
}

fun duration[r : Range] : one Int {
  sub[r.end, r.start]
}

fun generatedCapacity[f : CapacityFormula, r : Range, p : Purpose] : one Int {
  add[f.base[p], mul[f.perDay[p], duration[r]]]
}

pred sameFormulaDefinition[f1, f2 : CapacityFormula] {
  all p : Purpose |
    f1.base[p] = f2.base[p] and
    f1.perDay[p] = f2.perDay[p]
}

fun authorityContribution[a : Adjustment, c : Context, p : Purpose] : one Int {
  (gte[a.effectiveDay, c.authority.start] and lt[a.effectiveDay, c.view.end])
    => a.delta[p]
    else 0
}

fun viewLocalContribution[a : Adjustment, c : Context, p : Purpose] : one Int {
  (gte[a.effectiveDay, c.view.start] and lt[a.effectiveDay, c.view.end])
    => a.delta[p]
    else 0
}

fun authorityDeltaAtViewEnd[c : Context, p : Purpose] : one Int {
  add[
    authorityContribution[EarlyReallocation, c, p],
    authorityContribution[LateReallocation, c, p]
  ]
}

fun viewLocalDelta[c : Context, p : Purpose] : one Int {
  add[
    viewLocalContribution[EarlyReallocation, c, p],
    viewLocalContribution[LateReallocation, c, p]
  ]
}

fun capacityAtViewEnd[c : Context, p : Purpose] : one Int {
  add[
    generatedCapacity[c.formula, c.authority, p],
    authorityDeltaAtViewEnd[c, p]
  ]
}

fun viewLocalOnlyCapacity[c : Context, p : Purpose] : one Int {
  add[
    generatedCapacity[c.formula, c.authority, p],
    viewLocalDelta[c, p]
  ]
}

pred preViewAdjustmentCarriesIntoSubview {
  capacityAtViewEnd[PensionMonth, Food] = 8
  capacityAtViewEnd[PensionMonth, Travel] = 6
  viewLocalOnlyCapacity[PensionMonth, Food] = 10
  viewLocalOnlyCapacity[PensionMonth, Travel] = 4
}

pred sameViewDifferentAuthorityDifferentAnswer {
  PensionMonth.view.start = ResetMonth.view.start
  PensionMonth.view.end = ResetMonth.view.end
  sameFormulaDefinition[PensionMonth.formula, ResetMonth.formula]
  capacityAtViewEnd[PensionMonth, Food] != capacityAtViewEnd[ResetMonth, Food]
}

pred adjustmentAtViewEndIsExcluded {
  LateReallocation.effectiveDay = PensionMonth.view.end
  capacityAtViewEnd[PensionMonth, Food] = 8
  capacityAtViewEnd[PensionMonth, Travel] = 6
}

pred laterSubviewIncludesBoundaryAdjustment {
  LateReallocation.effectiveDay = PensionSecond.view.start + 1
  capacityAtViewEnd[PensionSecond, Food] = 9
  capacityAtViewEnd[PensionSecond, Travel] = 5
}

pred equalDefinitionCopySameAnswer {
  sameFormulaDefinition[PensionMonth.formula, PensionMonthCopy.formula]
  all p : Purpose |
    capacityAtViewEnd[PensionMonth, p] = capacityAtViewEnd[PensionMonthCopy, p]
}

assert ViewRangeFormulaAndTimedAdjustmentsDetermineCapacityAtEnd {
  all c1, c2 : Context |
    (c1.view.start = c2.view.start and
     c1.view.end = c2.view.end and
     sameFormulaDefinition[c1.formula, c2.formula])
    implies
    (all p : Purpose | capacityAtViewEnd[c1, p] = capacityAtViewEnd[c2, p])
}

assert OnlyViewLocalAdjustmentsDetermineCapacityAtEnd {
  all c : Context, p : Purpose |
    capacityAtViewEnd[c, p] = viewLocalOnlyCapacity[c, p]
}

assert AuthorityViewFormulaAndTimedAdjustmentsDetermineCapacityAtEnd {
  all c1, c2 : Context |
    (c1.authority.start = c2.authority.start and
     c1.authority.end = c2.authority.end and
     c1.view.start = c2.view.start and
     c1.view.end = c2.view.end and
     sameFormulaDefinition[c1.formula, c2.formula])
    implies
    (all p : Purpose | capacityAtViewEnd[c1, p] = capacityAtViewEnd[c2, p])
}

assert AdjacentSubviewCapacitySnapshotsComposeByAddition {
  all p : Purpose |
    add[
      capacityAtViewEnd[PensionFirst, p],
      capacityAtViewEnd[PensionSecond, p]
    ] = capacityAtViewEnd[PensionWhole, p]
}

run preViewAdjustmentCarriesIntoSubview for 6 Int
run sameViewDifferentAuthorityDifferentAnswer for 6 Int
run adjustmentAtViewEndIsExcluded for 6 Int
run laterSubviewIncludesBoundaryAdjustment for 6 Int
run equalDefinitionCopySameAnswer for 6 Int

check ViewRangeFormulaAndTimedAdjustmentsDetermineCapacityAtEnd for 6 Int
check OnlyViewLocalAdjustmentsDetermineCapacityAtEnd for 6 Int
check AuthorityViewFormulaAndTimedAdjustmentsDetermineCapacityAtEnd for 6 Int
check AdjacentSubviewCapacitySnapshotsComposeByAddition for 6 Int
