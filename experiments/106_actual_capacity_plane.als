module experiments/observation_106_actual_capacity_plane

abstract sig Plane {}
one sig ActualPlane, CapacityPlane extends Plane {}

abstract sig Node {}
one sig Unallocated extends Node {}
sig Purpose extends Node {}
sig Holding extends Node {}

sig Flow {}

sig Effect {
  flow: one Flow,
  node: one Node,
  quantity: one Int
}

sig World {
  planeOf: Flow -> one Plane
}

one sig Left, Right extends World {}

fact BalancedSignedFlowShape {
  all f: Flow | {
    #f.~flow = 2
    one e: f.~flow | e.quantity < 0
    one e: f.~flow | e.quantity > 0
    sum e: f.~flow | e.quantity = 0
    all disj e1, e2: f.~flow | e1.node != e2.node
  }
}

fun negativeEffect[f: Flow]: one Effect {
  { e: Effect | e.flow = f and e.quantity < 0 }
}

fun positiveEffect[f: Flow]: one Effect {
  { e: Effect | e.flow = f and e.quantity > 0 }
}

fun sourceNode[f: Flow]: one Node {
  negativeEffect[f].node
}

fun targetNode[f: Flow]: one Node {
  positiveEffect[f].node
}

fun actualFlows[w: World]: set Flow {
  { f: Flow | f->ActualPlane in w.planeOf }
}

fun capacityFlows[w: World]: set Flow {
  { f: Flow | f->CapacityPlane in w.planeOf }
}

fun actualEffects[w: World]: set Effect {
  { e: Effect | e.flow in actualFlows[w] }
}

fun capacityEffects[w: World]: set Effect {
  { e: Effect | e.flow in capacityFlows[w] }
}

fact CapacityUsesPurposeBoundary {
  all w: World, f: capacityFlows[w] | {
    sourceNode[f] in Purpose + Unallocated
    targetNode[f] in Purpose + Unallocated
    not (sourceNode[f] = Unallocated and targetNode[f] = Unallocated)
  }
}

fun grants[w: World]: set Flow {
  { f: capacityFlows[w] |
    sourceNode[f] = Unallocated and targetNode[f] in Purpose
  }
}

fun reallocations[w: World]: set Flow {
  { f: capacityFlows[w] |
    sourceNode[f] in Purpose and targetNode[f] in Purpose
  }
}

fun releases[w: World]: set Flow {
  { f: capacityFlows[w] |
    sourceNode[f] in Purpose and targetNode[f] = Unallocated
  }
}

pred representativeMixedPlanes {
  some f: actualFlows[Left] | {
    sourceNode[f] in Holding
    targetNode[f] in Holding
  }
  some grants[Left]
  some reallocations[Left]
  some releases[Left]
}

pred sameSignedEffectsDifferentPlaneSensitiveAnswers {
  some f: Flow | {
    f in actualFlows[Left]
    f in capacityFlows[Right]
  }
  actualEffects[Left] != actualEffects[Right]
  capacityEffects[Left] != capacityEffects[Right]
}

pred capacityLabelsComeFromEndpoints {
  some grants[Left]
  some reallocations[Left]
  some releases[Left]
}

assert UntypedEffectMemoryDeterminesPlaneSensitiveAnswers {
  actualEffects[Left] = actualEffects[Right]
  capacityEffects[Left] = capacityEffects[Right]
}

assert ExplicitPlaneDeterminesSelectedAnswers {
  Left.planeOf = Right.planeOf implies {
    actualEffects[Left] = actualEffects[Right]
    capacityEffects[Left] = capacityEffects[Right]
    grants[Left] = grants[Right]
    reallocations[Left] = reallocations[Right]
    releases[Left] = releases[Right]
  }
}

assert CapacityOperationKindsPartitionCapacityFlows {
  all w: World | {
    capacityFlows[w] = grants[w] + reallocations[w] + releases[w]
    no grants[w] & reallocations[w]
    no grants[w] & releases[w]
    no reallocations[w] & releases[w]
  }
}

assert PlaneSeparatesEffectOwnership {
  all w: World | {
    no actualEffects[w] & capacityEffects[w]
    actualEffects[w] + capacityEffects[w] = Effect
  }
}

run representativeMixedPlanes for exactly 4 Flow, exactly 8 Effect, exactly 2 Purpose, exactly 2 Holding, exactly 2 World, 6 Int
run sameSignedEffectsDifferentPlaneSensitiveAnswers for exactly 4 Flow, exactly 8 Effect, exactly 2 Purpose, exactly 2 Holding, exactly 2 World, 6 Int
run capacityLabelsComeFromEndpoints for exactly 4 Flow, exactly 8 Effect, exactly 2 Purpose, exactly 2 Holding, exactly 2 World, 6 Int
check UntypedEffectMemoryDeterminesPlaneSensitiveAnswers for exactly 4 Flow, exactly 8 Effect, exactly 2 Purpose, exactly 2 Holding, exactly 2 World, 6 Int
check ExplicitPlaneDeterminesSelectedAnswers for exactly 4 Flow, exactly 8 Effect, exactly 2 Purpose, exactly 2 Holding, exactly 2 World, 6 Int
check CapacityOperationKindsPartitionCapacityFlows for exactly 4 Flow, exactly 8 Effect, exactly 2 Purpose, exactly 2 Holding, exactly 2 World, 6 Int
check PlaneSeparatesEffectOwnership for exactly 4 Flow, exactly 8 Effect, exactly 2 Purpose, exactly 2 Holding, exactly 2 World, 6 Int
