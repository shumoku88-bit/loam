module temporal_valuation_coordinate

abstract sig Coordinate {}
one sig C0, C2, C3 extends Coordinate {}

abstract sig Measure {}
one sig ForeignMeasure, BaseMeasure extends Measure {}

abstract sig RelationValue {}
one sig V5, V6, V7 extends RelationValue {}

abstract sig RelationObservation {
  source : one Measure,
  target : one Measure,
  effectiveAt : one Coordinate,
  value : one RelationValue
}
one sig R0, R2, R3 extends RelationObservation {}

abstract sig ValuationSubject {
  measure : one Measure,
  occurredAt : one Coordinate,
  settledAt : lone Coordinate
}
one sig SettledSubject, OpenSubject extends ValuationSubject {}

abstract sig World {
  retained : set RelationObservation
}
one sig FullHistory, CurrentOnly extends World {}

one sig QueryContext {
  currentAt : one Coordinate
}

fact Specimen {
  R0.source = ForeignMeasure
  R0.target = BaseMeasure
  R0.effectiveAt = C0
  R0.value = V5

  R2.source = ForeignMeasure
  R2.target = BaseMeasure
  R2.effectiveAt = C2
  R2.value = V6

  R3.source = ForeignMeasure
  R3.target = BaseMeasure
  R3.effectiveAt = C3
  R3.value = V7

  SettledSubject.measure = ForeignMeasure
  SettledSubject.occurredAt = C0
  SettledSubject.settledAt = C2

  OpenSubject.measure = ForeignMeasure
  OpenSubject.occurredAt = C0
  no OpenSubject.settledAt

  FullHistory.retained = R0 + R2 + R3
  CurrentOnly.retained = R3

  QueryContext.currentAt = C3
}

fun relationAt[w : World, m : Measure, c : Coordinate] : set RelationObservation {
  { r : w.retained |
      r.source = m
      and r.target = BaseMeasure
      and r.effectiveAt = c }
}

fun bookedObservation[w : World, s : ValuationSubject] : set RelationObservation {
  relationAt[w, s.measure, s.occurredAt]
}

fun settlementObservation[w : World, s : ValuationSubject] : set RelationObservation {
  { r : w.retained |
      r.source = s.measure
      and r.target = BaseMeasure
      and r.effectiveAt in s.settledAt }
}

fun currentObservation[w : World, s : ValuationSubject] : set RelationObservation {
  relationAt[w, s.measure, QueryContext.currentAt]
}

fun realisedComparison[w : World, s : ValuationSubject] : RelationValue -> RelationValue {
  bookedObservation[w, s].value -> settlementObservation[w, s].value
}

fun unrealisedComparison[w : World, s : ValuationSubject] : RelationValue -> RelationValue {
  bookedObservation[w, s].value -> currentObservation[w, s].value
}

pred fullHistoryUsesThreeTemporalObservations {
  bookedObservation[FullHistory, SettledSubject] = R0
  settlementObservation[FullHistory, SettledSubject] = R2
  currentObservation[FullHistory, OpenSubject] = R3
}

pred realisedAndUnrealisedUseDifferentInputs {
  realisedComparison[FullHistory, SettledSubject] = V5 -> V6
  unrealisedComparison[FullHistory, OpenSubject] = V5 -> V7
}

pred currentOnlyLosesHistoricalInputs {
  currentObservation[CurrentOnly, SettledSubject] = R3
  currentObservation[CurrentOnly, OpenSubject] = R3

  no bookedObservation[CurrentOnly, SettledSubject]
  no settlementObservation[CurrentOnly, SettledSubject]
  no bookedObservation[CurrentOnly, OpenSubject]
}

assert OneTimelessRelationValueAnswersAllTemporalQuestions {
  bookedObservation[FullHistory, SettledSubject].value
    = settlementObservation[FullHistory, SettledSubject].value

  bookedObservation[FullHistory, OpenSubject].value
    = currentObservation[FullHistory, OpenSubject].value
}

assert CurrentOnlyCanReconstructHistoricalSelections {
  some currentObservation[CurrentOnly, SettledSubject]
  implies
  (
    one bookedObservation[CurrentOnly, SettledSubject]
    and one settlementObservation[CurrentOnly, SettledSubject]
  )
}

assert FullHistoryTemporalSelectionIsUnambiguous {
  one bookedObservation[FullHistory, SettledSubject]
  one settlementObservation[FullHistory, SettledSubject]
  one currentObservation[FullHistory, SettledSubject]

  one bookedObservation[FullHistory, OpenSubject]
  no settlementObservation[FullHistory, OpenSubject]
  one currentObservation[FullHistory, OpenSubject]
}

run fullHistoryUsesThreeTemporalObservations
run realisedAndUnrealisedUseDifferentInputs
run currentOnlyLosesHistoricalInputs

check OneTimelessRelationValueAnswersAllTemporalQuestions
check CurrentOnlyCanReconstructHistoricalSelections
check FullHistoryTemporalSelectionIsUnambiguous
