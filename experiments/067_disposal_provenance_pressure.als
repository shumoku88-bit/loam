module experiments/observation_067_disposal_provenance_pressure

sig BasisValue {}

sig AcquisitionEffect {
  quantity: one Int,
  basis: one BasisValue
}

one sig DisposalEffect {
  quantity: one Int
}

abstract sig World {
  consumesFrom: AcquisitionEffect -> one Int
}

one sig Left, Right extends World {}

fact RepresentativeInventory {
  all a: AcquisitionEffect | a.quantity = 3
  DisposalEffect.quantity = 3

  all disj a, b: AcquisitionEffect |
    a.basis != b.basis

  all w: World, a: AcquisitionEffect | {
    a.(w.consumesFrom) >= 0
    a.(w.consumesFrom) <= a.quantity
  }

  all w: World |
    sum a: AcquisitionEffect | a.(w.consumesFrom) = DisposalEffect.quantity
}

fun remainingFrom[w: World, a: AcquisitionEffect]: one Int {
  a.quantity - a.(w.consumesFrom)
}

fun aggregateBefore: one Int {
  sum a: AcquisitionEffect | a.quantity
}

fun aggregateAfter[w: World]: one Int {
  sum a: AcquisitionEffect | remainingFrom[w, a]
}

fun consumedSources[w: World]: set AcquisitionEffect {
  { a: AcquisitionEffect | a.(w.consumesFrom) > 0 }
}

fun consumedBases[w: World]: set BasisValue {
  consumedSources[w].basis
}

pred representativeDisposalPressure {
  some disj a, b: AcquisitionEffect | {
    a.(Left.consumesFrom) = 3
    b.(Left.consumesFrom) = 0
    aggregateBefore[] = 6
    aggregateAfter[Left] = 3
  }
}

pred sameAggregateDifferentSource {
  aggregateAfter[Left] = aggregateAfter[Right]
  consumedSources[Left] != consumedSources[Right]
}

pred sameAggregateDifferentBasisProvenance {
  aggregateAfter[Left] = aggregateAfter[Right]
  consumedBases[Left] != consumedBases[Right]
}

pred splitDisposalCanConsumeMultipleAcquisitions {
  #consumedSources[Left] = 2
}

pred sameSourcesDifferentAllocation {
  consumedSources[Left] = consumedSources[Right]
  #consumedSources[Left] = 2
  Left.consumesFrom != Right.consumesFrom
}

assert AggregateHoldingDeterminesDisposalSources {
  aggregateAfter[Left] = aggregateAfter[Right] implies
    consumedSources[Left] = consumedSources[Right]
}

assert AggregateHoldingDeterminesBasisProvenance {
  aggregateAfter[Left] = aggregateAfter[Right] implies
    consumedBases[Left] = consumedBases[Right]
}

assert SourceSetDeterminesConsumptionAllocation {
  consumedSources[Left] = consumedSources[Right] implies
    Left.consumesFrom = Right.consumesFrom
}

assert ExplicitConsumptionDeterminesSelectedAnswers {
  Left.consumesFrom = Right.consumesFrom implies {
    aggregateAfter[Left] = aggregateAfter[Right]
    consumedSources[Left] = consumedSources[Right]
    consumedBases[Left] = consumedBases[Right]
  }
}

run representativeDisposalPressure for exactly 2 AcquisitionEffect, exactly 2 BasisValue, exactly 2 World, 4 Int
run sameAggregateDifferentSource for exactly 2 AcquisitionEffect, exactly 2 BasisValue, exactly 2 World, 4 Int
run sameAggregateDifferentBasisProvenance for exactly 2 AcquisitionEffect, exactly 2 BasisValue, exactly 2 World, 4 Int
run splitDisposalCanConsumeMultipleAcquisitions for exactly 2 AcquisitionEffect, exactly 2 BasisValue, exactly 2 World, 4 Int
run sameSourcesDifferentAllocation for exactly 2 AcquisitionEffect, exactly 2 BasisValue, exactly 2 World, 4 Int
check AggregateHoldingDeterminesDisposalSources for exactly 2 AcquisitionEffect, exactly 2 BasisValue, exactly 2 World, 4 Int
check AggregateHoldingDeterminesBasisProvenance for exactly 2 AcquisitionEffect, exactly 2 BasisValue, exactly 2 World, 4 Int
check SourceSetDeterminesConsumptionAllocation for exactly 2 AcquisitionEffect, exactly 2 BasisValue, exactly 2 World, 4 Int
check ExplicitConsumptionDeterminesSelectedAnswers for exactly 2 AcquisitionEffect, exactly 2 BasisValue, exactly 2 World, 4 Int
