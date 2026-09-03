module unused_remaining_carry

open util/integer

abstract sig Purpose {}
one sig Food, Travel extends Purpose {}

abstract sig Range {
  start : one Int,
  end : one Int
}

one sig PreviousRange, NextRange, NextEarlyView extends Range {}

abstract sig CapacityFormula {
  base : Purpose -> one Int
}

one sig FixedFormula, FixedFormulaCopy extends CapacityFormula {}

abstract sig Adjustment {
  effectiveDay : one Int,
  delta : Purpose -> one Int
}

one sig PriorA, PriorB, BoundaryAdjustment extends Adjustment {}

abstract sig Actual {
  effectiveDay : one Int,
  purpose : one Purpose,
  quantity : one Int
}

one sig FoodSpend, TravelSpend extends Actual {}

abstract sig BoundaryPolicy {
  carryAdjustment : Adjustment -> one Int,
  carryUnused : Purpose -> one Int
}

one sig ResetBothPolicy,
        AdjustmentOnlyPolicy,
        UnusedOnlyPolicy,
        BothPolicy,
        SelectiveUnusedPolicy,
        UnusedOnlyPolicyCopy extends BoundaryPolicy {}

abstract sig Context {
  authority : one Range,
  view : one Range,
  formula : one CapacityFormula,
  policy : one BoundaryPolicy
}

one sig ResetBothNext,
        AdjustmentOnlyNext,
        UnusedOnlyNext,
        BothNext,
        SelectiveUnusedNext,
        UnusedOnlyCopyNext extends Context {}

one sig BoundaryPhysicalState {
  holdingQuantity : one Int,
  backed : Purpose -> one Int
}

fact Specimen {
  PreviousRange.start = 0
  PreviousRange.end = 2

  NextRange.start = 2
  NextRange.end = 4

  NextEarlyView.start = 2
  NextEarlyView.end = 3

  FixedFormula.base[Food] = 10
  FixedFormula.base[Travel] = 4
  FixedFormulaCopy.base[Food] = 10
  FixedFormulaCopy.base[Travel] = 4

  PriorA.effectiveDay = 0
  PriorA.delta[Food] = -2
  PriorA.delta[Travel] = 2

  PriorB.effectiveDay = 1
  PriorB.delta[Food] = 1
  PriorB.delta[Travel] = -1

  BoundaryAdjustment.effectiveDay = 2
  BoundaryAdjustment.delta[Food] = 1
  BoundaryAdjustment.delta[Travel] = -1

  FoodSpend.effectiveDay = 0
  FoodSpend.purpose = Food
  FoodSpend.quantity = 6

  TravelSpend.effectiveDay = 1
  TravelSpend.purpose = Travel
  TravelSpend.quantity = 4

  all a : Actual | gt[a.quantity, 0]

  all a : Adjustment |
    ResetBothPolicy.carryAdjustment[a] = 0 and
    UnusedOnlyPolicy.carryAdjustment[a] = 0 and
    SelectiveUnusedPolicy.carryAdjustment[a] = 0 and
    UnusedOnlyPolicyCopy.carryAdjustment[a] = 0

  AdjustmentOnlyPolicy.carryAdjustment[PriorA] = 1
  AdjustmentOnlyPolicy.carryAdjustment[PriorB] = 1
  AdjustmentOnlyPolicy.carryAdjustment[BoundaryAdjustment] = 0

  BothPolicy.carryAdjustment[PriorA] = 1
  BothPolicy.carryAdjustment[PriorB] = 1
  BothPolicy.carryAdjustment[BoundaryAdjustment] = 0

  ResetBothPolicy.carryUnused[Food] = 0
  ResetBothPolicy.carryUnused[Travel] = 0

  AdjustmentOnlyPolicy.carryUnused[Food] = 0
  AdjustmentOnlyPolicy.carryUnused[Travel] = 0

  UnusedOnlyPolicy.carryUnused[Food] = 1
  UnusedOnlyPolicy.carryUnused[Travel] = 1

  BothPolicy.carryUnused[Food] = 1
  BothPolicy.carryUnused[Travel] = 1

  SelectiveUnusedPolicy.carryUnused[Food] = 1
  SelectiveUnusedPolicy.carryUnused[Travel] = 0

  UnusedOnlyPolicyCopy.carryUnused[Food] = 1
  UnusedOnlyPolicyCopy.carryUnused[Travel] = 1

  all p : BoundaryPolicy, a : Adjustment |
    p.carryAdjustment[a] = 0 or p.carryAdjustment[a] = 1

  all p : BoundaryPolicy, purpose : Purpose |
    p.carryUnused[purpose] = 0 or p.carryUnused[purpose] = 1

  ResetBothNext.authority = NextRange
  ResetBothNext.view = NextEarlyView
  ResetBothNext.formula = FixedFormula
  ResetBothNext.policy = ResetBothPolicy

  AdjustmentOnlyNext.authority = NextRange
  AdjustmentOnlyNext.view = NextEarlyView
  AdjustmentOnlyNext.formula = FixedFormula
  AdjustmentOnlyNext.policy = AdjustmentOnlyPolicy

  UnusedOnlyNext.authority = NextRange
  UnusedOnlyNext.view = NextEarlyView
  UnusedOnlyNext.formula = FixedFormula
  UnusedOnlyNext.policy = UnusedOnlyPolicy

  BothNext.authority = NextRange
  BothNext.view = NextEarlyView
  BothNext.formula = FixedFormula
  BothNext.policy = BothPolicy

  SelectiveUnusedNext.authority = NextRange
  SelectiveUnusedNext.view = NextEarlyView
  SelectiveUnusedNext.formula = FixedFormula
  SelectiveUnusedNext.policy = SelectiveUnusedPolicy

  UnusedOnlyCopyNext.authority = NextRange
  UnusedOnlyCopyNext.view = NextEarlyView
  UnusedOnlyCopyNext.formula = FixedFormulaCopy
  UnusedOnlyCopyNext.policy = UnusedOnlyPolicyCopy

  all c : Context |
    c.view.start = c.authority.start and
    lte[c.view.end, c.authority.end]

  BoundaryPhysicalState.holdingQuantity = 40
  BoundaryPhysicalState.backed[Food] = 20
  BoundaryPhysicalState.backed[Travel] = 20
  add[BoundaryPhysicalState.backed[Food], BoundaryPhysicalState.backed[Travel]] =
    BoundaryPhysicalState.holdingQuantity
}

pred sameFormulaDefinition[f1, f2 : CapacityFormula] {
  all p : Purpose | f1.base[p] = f2.base[p]
}

pred sameAdjustmentCarryDefinition[p1, p2 : BoundaryPolicy] {
  all a : Adjustment | p1.carryAdjustment[a] = p2.carryAdjustment[a]
}

pred sameUnusedCarryDefinition[p1, p2 : BoundaryPolicy] {
  all purpose : Purpose | p1.carryUnused[purpose] = p2.carryUnused[purpose]
}

pred sameBoundaryDefinition[p1, p2 : BoundaryPolicy] {
  sameAdjustmentCarryDefinition[p1, p2]
  sameUnusedCarryDefinition[p1, p2]
}

fun previousAdjustmentTotal[p : Purpose] : one Int {
  sum a : Adjustment |
    (gte[a.effectiveDay, PreviousRange.start] and lt[a.effectiveDay, PreviousRange.end])
      => a.delta[p]
      else 0
}

fun previousConsumption[p : Purpose] : one Int {
  sum a : Actual |
    (a.purpose = p and
     gte[a.effectiveDay, PreviousRange.start] and
     lt[a.effectiveDay, PreviousRange.end])
      => a.quantity
      else 0
}

fun previousCapacityAtEnd[c : Context, p : Purpose] : one Int {
  add[c.formula.base[p], previousAdjustmentTotal[p]]
}

fun previousRemaining[c : Context, p : Purpose] : one Int {
  sub[previousCapacityAtEnd[c, p], previousConsumption[p]]
}

fun carriedAdjustmentContribution[a : Adjustment, c : Context, p : Purpose] : one Int {
  (lt[a.effectiveDay, c.authority.start] and c.policy.carryAdjustment[a] = 1)
    => a.delta[p]
    else 0
}

fun localAdjustmentContribution[a : Adjustment, c : Context, p : Purpose] : one Int {
  (gte[a.effectiveDay, c.authority.start] and lt[a.effectiveDay, c.view.end])
    => a.delta[p]
    else 0
}

fun nextAdjustmentTotal[c : Context, p : Purpose] : one Int {
  sum a : Adjustment |
    add[
      carriedAdjustmentContribution[a, c, p],
      localAdjustmentContribution[a, c, p]
    ]
}

fun unusedCarryContribution[c : Context, p : Purpose] : one Int {
  (c.policy.carryUnused[p] = 1)
    => previousRemaining[c, p]
    else 0
}

fun capacityAtViewEnd[c : Context, p : Purpose] : one Int {
  add[
    c.formula.base[p],
    add[
      nextAdjustmentTotal[c, p],
      unusedCarryContribution[c, p]
    ]
  ]
}

pred previousRemainingIsDerivedFromCapacityAndActual {
  previousCapacityAtEnd[ResetBothNext, Food] = 9
  previousCapacityAtEnd[ResetBothNext, Travel] = 5
  previousConsumption[Food] = 6
  previousConsumption[Travel] = 4
  previousRemaining[ResetBothNext, Food] = 3
  previousRemaining[ResetBothNext, Travel] = 1
}

pred unusedCarryChangesNextCapacityWithoutReallocationCarry {
  sameAdjustmentCarryDefinition[ResetBothPolicy, UnusedOnlyPolicy]
  capacityAtViewEnd[ResetBothNext, Food] = 11
  capacityAtViewEnd[ResetBothNext, Travel] = 3
  capacityAtViewEnd[UnusedOnlyNext, Food] = 14
  capacityAtViewEnd[UnusedOnlyNext, Travel] = 4
}

pred reallocationCarryChangesNextCapacityWithoutUnusedCarry {
  sameUnusedCarryDefinition[ResetBothPolicy, AdjustmentOnlyPolicy]
  capacityAtViewEnd[AdjustmentOnlyNext, Food] = 10
  capacityAtViewEnd[AdjustmentOnlyNext, Travel] = 4
  capacityAtViewEnd[AdjustmentOnlyNext, Food] != capacityAtViewEnd[ResetBothNext, Food]
}

pred combinedPolicyComposesIndependentAxes {
  capacityAtViewEnd[BothNext, Food] = 13
  capacityAtViewEnd[BothNext, Travel] = 5
  capacityAtViewEnd[BothNext, Food] != capacityAtViewEnd[AdjustmentOnlyNext, Food]
  capacityAtViewEnd[BothNext, Food] != capacityAtViewEnd[UnusedOnlyNext, Food]
}

pred selectiveUnusedCarryProducesPurposeSpecificAnswer {
  capacityAtViewEnd[SelectiveUnusedNext, Food] = 14
  capacityAtViewEnd[SelectiveUnusedNext, Travel] = 3
}

pred samePhysicalBackingDifferentUnusedCarryDifferentCapacity {
  BoundaryPhysicalState.holdingQuantity = 40
  BoundaryPhysicalState.backed[Food] = 20
  BoundaryPhysicalState.backed[Travel] = 20
  capacityAtViewEnd[ResetBothNext, Food] != capacityAtViewEnd[UnusedOnlyNext, Food]
}

pred equalDefinitionDifferentIdentitySameAnswer {
  ResetBothPolicy != UnusedOnlyPolicyCopy
  UnusedOnlyPolicy != UnusedOnlyPolicyCopy
  sameBoundaryDefinition[UnusedOnlyPolicy, UnusedOnlyPolicyCopy]
  sameFormulaDefinition[UnusedOnlyNext.formula, UnusedOnlyCopyNext.formula]
  all p : Purpose |
    capacityAtViewEnd[UnusedOnlyNext, p] = capacityAtViewEnd[UnusedOnlyCopyNext, p]
}

assert FormulaActualsAdjustmentsAndAdjustmentCarryDetermineNextCapacity {
  all c1, c2 : Context |
    (c1.authority.start = c2.authority.start and
     c1.authority.end = c2.authority.end and
     c1.view.start = c2.view.start and
     c1.view.end = c2.view.end and
     sameFormulaDefinition[c1.formula, c2.formula] and
     sameAdjustmentCarryDefinition[c1.policy, c2.policy])
    implies
    (all p : Purpose | capacityAtViewEnd[c1, p] = capacityAtViewEnd[c2, p])
}

assert AdjustmentCarryDeterminesUnusedCarry {
  all p1, p2 : BoundaryPolicy |
    sameAdjustmentCarryDefinition[p1, p2]
    implies
    sameUnusedCarryDefinition[p1, p2]
}

assert UnusedCarryDeterminesAdjustmentCarry {
  all p1, p2 : BoundaryPolicy |
    sameUnusedCarryDefinition[p1, p2]
    implies
    sameAdjustmentCarryDefinition[p1, p2]
}

assert PhysicalHoldingsAndBackingPlusAdjustmentCarryDetermineNextCapacity {
  all c1, c2 : Context |
    (c1.authority.start = c2.authority.start and
     c1.authority.end = c2.authority.end and
     c1.view.start = c2.view.start and
     c1.view.end = c2.view.end and
     sameFormulaDefinition[c1.formula, c2.formula] and
     sameAdjustmentCarryDefinition[c1.policy, c2.policy] and
     BoundaryPhysicalState.holdingQuantity = 40 and
     BoundaryPhysicalState.backed[Food] = 20 and
     BoundaryPhysicalState.backed[Travel] = 20)
    implies
    (all p : Purpose | capacityAtViewEnd[c1, p] = capacityAtViewEnd[c2, p])
}

assert BoundaryPoliciesPreserveBaseTotal {
  all c : Context |
    add[capacityAtViewEnd[c, Food], capacityAtViewEnd[c, Travel]] =
    add[c.formula.base[Food], c.formula.base[Travel]]
}

assert CompositeBoundaryDefinitionDeterminesNextCapacity {
  all c1, c2 : Context |
    (c1.authority.start = c2.authority.start and
     c1.authority.end = c2.authority.end and
     c1.view.start = c2.view.start and
     c1.view.end = c2.view.end and
     sameFormulaDefinition[c1.formula, c2.formula] and
     sameBoundaryDefinition[c1.policy, c2.policy])
    implies
    (all p : Purpose | capacityAtViewEnd[c1, p] = capacityAtViewEnd[c2, p])
}

run previousRemainingIsDerivedFromCapacityAndActual for 6 Int
run unusedCarryChangesNextCapacityWithoutReallocationCarry for 6 Int
run reallocationCarryChangesNextCapacityWithoutUnusedCarry for 6 Int
run combinedPolicyComposesIndependentAxes for 6 Int
run selectiveUnusedCarryProducesPurposeSpecificAnswer for 6 Int
run samePhysicalBackingDifferentUnusedCarryDifferentCapacity for 6 Int
run equalDefinitionDifferentIdentitySameAnswer for 6 Int

check FormulaActualsAdjustmentsAndAdjustmentCarryDetermineNextCapacity for 6 Int
check AdjustmentCarryDeterminesUnusedCarry for 6 Int
check UnusedCarryDeterminesAdjustmentCarry for 6 Int
check PhysicalHoldingsAndBackingPlusAdjustmentCarryDetermineNextCapacity for 6 Int
check BoundaryPoliciesPreserveBaseTotal for 6 Int
check CompositeBoundaryDefinitionDeterminesNextCapacity for 6 Int
