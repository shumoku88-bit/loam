module capacity_boundary_policy

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

abstract sig BoundaryPolicy {
  carry : Adjustment -> one Int
}

one sig ResetPolicy,
        CarryAllPolicy,
        CarryAllPolicyCopy,
        SelectivePolicy extends BoundaryPolicy {}

abstract sig Context {
  authority : one Range,
  view : one Range,
  formula : one CapacityFormula,
  policy : one BoundaryPolicy
}

one sig ResetNext,
        CarryAllNext,
        CarryAllNextCopy,
        SelectiveNext extends Context {}

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

  all a : Adjustment |
    ResetPolicy.carry[a] = 0

  CarryAllPolicy.carry[PriorA] = 1
  CarryAllPolicy.carry[PriorB] = 1
  CarryAllPolicy.carry[BoundaryAdjustment] = 0

  CarryAllPolicyCopy.carry[PriorA] = 1
  CarryAllPolicyCopy.carry[PriorB] = 1
  CarryAllPolicyCopy.carry[BoundaryAdjustment] = 0

  SelectivePolicy.carry[PriorA] = 1
  SelectivePolicy.carry[PriorB] = 0
  SelectivePolicy.carry[BoundaryAdjustment] = 0

  all p : BoundaryPolicy, a : Adjustment |
    p.carry[a] = 0 or p.carry[a] = 1

  ResetNext.authority = NextRange
  ResetNext.view = NextEarlyView
  ResetNext.formula = FixedFormula
  ResetNext.policy = ResetPolicy

  CarryAllNext.authority = NextRange
  CarryAllNext.view = NextEarlyView
  CarryAllNext.formula = FixedFormula
  CarryAllNext.policy = CarryAllPolicy

  CarryAllNextCopy.authority = NextRange
  CarryAllNextCopy.view = NextEarlyView
  CarryAllNextCopy.formula = FixedFormulaCopy
  CarryAllNextCopy.policy = CarryAllPolicyCopy

  SelectiveNext.authority = NextRange
  SelectiveNext.view = NextEarlyView
  SelectiveNext.formula = FixedFormula
  SelectiveNext.policy = SelectivePolicy

  all c : Context |
    c.view.start = c.authority.start and
    lte[c.view.end, c.authority.end]
}

pred sameFormulaDefinition[f1, f2 : CapacityFormula] {
  all p : Purpose | f1.base[p] = f2.base[p]
}

pred samePolicyDefinition[p1, p2 : BoundaryPolicy] {
  all a : Adjustment | p1.carry[a] = p2.carry[a]
}

fun carriedContribution[a : Adjustment, c : Context, p : Purpose] : one Int {
  (lt[a.effectiveDay, c.authority.start] and c.policy.carry[a] = 1)
    => a.delta[p]
    else 0
}

fun localContribution[a : Adjustment, c : Context, p : Purpose] : one Int {
  (gte[a.effectiveDay, c.authority.start] and lt[a.effectiveDay, c.view.end])
    => a.delta[p]
    else 0
}

fun contribution[a : Adjustment, c : Context, p : Purpose] : one Int {
  add[carriedContribution[a, c, p], localContribution[a, c, p]]
}

fun capacityAtViewEnd[c : Context, p : Purpose] : one Int {
  add[
    c.formula.base[p],
    add[
      contribution[PriorA, c, p],
      add[
        contribution[PriorB, c, p],
        contribution[BoundaryAdjustment, c, p]
      ]
    ]
  ]
}

fun resetOnlyCapacity[c : Context, p : Purpose] : one Int {
  add[
    c.formula.base[p],
    add[
      localContribution[PriorA, c, p],
      add[
        localContribution[PriorB, c, p],
        localContribution[BoundaryAdjustment, c, p]
      ]
    ]
  ]
}

fun carryAllCapacity[c : Context, p : Purpose] : one Int {
  add[
    c.formula.base[p],
    add[
      ((lt[PriorA.effectiveDay, c.authority.start]) => PriorA.delta[p] else 0),
      add[
        ((lt[PriorB.effectiveDay, c.authority.start]) => PriorB.delta[p] else 0),
        localContribution[BoundaryAdjustment, c, p]
      ]
    ]
  ]
}

pred resetAndCarryProduceDifferentNextCapacity {
  capacityAtViewEnd[ResetNext, Food] = 11
  capacityAtViewEnd[ResetNext, Travel] = 3
  capacityAtViewEnd[CarryAllNext, Food] = 10
  capacityAtViewEnd[CarryAllNext, Travel] = 4
}

pred selectiveCarryProducesThirdAnswer {
  capacityAtViewEnd[SelectiveNext, Food] = 9
  capacityAtViewEnd[SelectiveNext, Travel] = 5
  capacityAtViewEnd[SelectiveNext, Food] != capacityAtViewEnd[ResetNext, Food]
  capacityAtViewEnd[SelectiveNext, Food] != capacityAtViewEnd[CarryAllNext, Food]
}

pred boundaryAdjustmentBelongsToNextAuthority {
  BoundaryAdjustment.effectiveDay = NextRange.start
  localContribution[BoundaryAdjustment, ResetNext, Food] = 1
  carriedContribution[BoundaryAdjustment, CarryAllNext, Food] = 0
}

pred equalPolicyDefinitionDifferentIdentitySameAnswer {
  samePolicyDefinition[CarryAllNext.policy, CarryAllNextCopy.policy]
  sameFormulaDefinition[CarryAllNext.formula, CarryAllNextCopy.formula]
  all p : Purpose |
    capacityAtViewEnd[CarryAllNext, p] = capacityAtViewEnd[CarryAllNextCopy, p]
}

assert RangesFormulaAndTimedAdjustmentsDetermineNextCapacity {
  all c1, c2 : Context |
    (c1.authority.start = c2.authority.start and
     c1.authority.end = c2.authority.end and
     c1.view.start = c2.view.start and
     c1.view.end = c2.view.end and
     sameFormulaDefinition[c1.formula, c2.formula])
    implies
    (all p : Purpose | capacityAtViewEnd[c1, p] = capacityAtViewEnd[c2, p])
}

assert EveryBoundaryResetsPriorAdjustments {
  all c : Context, p : Purpose |
    capacityAtViewEnd[c, p] = resetOnlyCapacity[c, p]
}

assert EveryBoundaryCarriesAllPriorAdjustments {
  all c : Context, p : Purpose |
    capacityAtViewEnd[c, p] = carryAllCapacity[c, p]
}

assert BoundaryPolicyDefinitionDeterminesNextCapacity {
  all c1, c2 : Context |
    (c1.authority.start = c2.authority.start and
     c1.authority.end = c2.authority.end and
     c1.view.start = c2.view.start and
     c1.view.end = c2.view.end and
     sameFormulaDefinition[c1.formula, c2.formula] and
     samePolicyDefinition[c1.policy, c2.policy])
    implies
    (all p : Purpose | capacityAtViewEnd[c1, p] = capacityAtViewEnd[c2, p])
}

assert BoundaryPoliciesPreserveSelectedTotal {
  all c : Context |
    add[capacityAtViewEnd[c, Food], capacityAtViewEnd[c, Travel]] =
    add[c.formula.base[Food], c.formula.base[Travel]]
}

run resetAndCarryProduceDifferentNextCapacity for 6 Int
run selectiveCarryProducesThirdAnswer for 6 Int
run boundaryAdjustmentBelongsToNextAuthority for 6 Int
run equalPolicyDefinitionDifferentIdentitySameAnswer for 6 Int

check RangesFormulaAndTimedAdjustmentsDetermineNextCapacity for 6 Int
check EveryBoundaryResetsPriorAdjustments for 6 Int
check EveryBoundaryCarriesAllPriorAdjustments for 6 Int
check BoundaryPolicyDefinitionDeterminesNextCapacity for 6 Int
check BoundaryPoliciesPreserveSelectedTotal for 6 Int
