module experiments/observation_066_acquisition_basis_pressure

sig Time {}
one sig AcquisitionTime, CurrentTime extends Time {}

sig ComparisonValue {}

sig Acquisition {
  at: one Time
}

abstract sig World {
  valuationAt: Time -> one ComparisonValue,
  acquisitionBasis: Acquisition -> one ComparisonValue
}

one sig Left, Right extends World {}

fact AcquisitionsOccurAtAcquisitionTime {
  all a: Acquisition | a.at = AcquisitionTime
}

fun valuationFor[w: World, t: Time]: one ComparisonValue {
  t.(w.valuationAt)
}

fun historicalValuation[w: World, a: Acquisition]: one ComparisonValue {
  valuationFor[w, a.at]
}

fun currentValuation[w: World]: one ComparisonValue {
  valuationFor[w, CurrentTime]
}

fun basisFor[w: World, a: Acquisition]: one ComparisonValue {
  a.(w.acquisitionBasis)
}

pred representativeAcquisitionPressure {
  some a: Acquisition | {
    historicalValuation[Left, a] != currentValuation[Left]
    basisFor[Left, a] != historicalValuation[Left, a]
  }
}

pred sameValuationHistoryDifferentBasis {
  Left.valuationAt = Right.valuationAt
  Left.acquisitionBasis != Right.acquisitionBasis
}

pred currentValuationCanMoveWithoutRewritingBasis {
  Left.acquisitionBasis = Right.acquisitionBasis
  valuationFor[Left, AcquisitionTime] = valuationFor[Right, AcquisitionTime]
  currentValuation[Left] != currentValuation[Right]
}

pred sameAcquisitionTimeValuationDifferentBasis {
  valuationFor[Left, AcquisitionTime] = valuationFor[Right, AcquisitionTime]
  Left.acquisitionBasis != Right.acquisitionBasis
}

pred basisCanDifferFromAcquisitionTimeValuation {
  some w: World, a: Acquisition |
    basisFor[w, a] != historicalValuation[w, a]
}

assert ValuationHistoryDeterminesAcquisitionBasis {
  Left.valuationAt = Right.valuationAt implies
    Left.acquisitionBasis = Right.acquisitionBasis
}

assert AcquisitionBasisEqualsHistoricalValuation {
  all w: World, a: Acquisition |
    basisFor[w, a] = historicalValuation[w, a]
}

assert AcquisitionBasisDeterminesCurrentValuation {
  Left.acquisitionBasis = Right.acquisitionBasis implies
    currentValuation[Left] = currentValuation[Right]
}

assert ExplicitBasisAndValuationDetermineSelectedAnswers {
  Left.valuationAt = Right.valuationAt and
  Left.acquisitionBasis = Right.acquisitionBasis implies {
    currentValuation[Left] = currentValuation[Right]
    all a: Acquisition | {
      historicalValuation[Left, a] = historicalValuation[Right, a]
      basisFor[Left, a] = basisFor[Right, a]
    }
  }
}

run representativeAcquisitionPressure for exactly 1 Acquisition, exactly 2 Time, exactly 3 ComparisonValue, exactly 2 World
run sameValuationHistoryDifferentBasis for exactly 1 Acquisition, exactly 2 Time, exactly 3 ComparisonValue, exactly 2 World
run currentValuationCanMoveWithoutRewritingBasis for exactly 1 Acquisition, exactly 2 Time, exactly 3 ComparisonValue, exactly 2 World
run sameAcquisitionTimeValuationDifferentBasis for exactly 1 Acquisition, exactly 2 Time, exactly 3 ComparisonValue, exactly 2 World
run basisCanDifferFromAcquisitionTimeValuation for exactly 1 Acquisition, exactly 2 Time, exactly 3 ComparisonValue, exactly 2 World
check ValuationHistoryDeterminesAcquisitionBasis for exactly 1 Acquisition, exactly 2 Time, exactly 3 ComparisonValue, exactly 2 World
check AcquisitionBasisEqualsHistoricalValuation for exactly 1 Acquisition, exactly 2 Time, exactly 3 ComparisonValue, exactly 2 World
check AcquisitionBasisDeterminesCurrentValuation for exactly 1 Acquisition, exactly 2 Time, exactly 3 ComparisonValue, exactly 2 World
check ExplicitBasisAndValuationDetermineSelectedAnswers for exactly 1 Acquisition, exactly 2 Time, exactly 3 ComparisonValue, exactly 2 World
