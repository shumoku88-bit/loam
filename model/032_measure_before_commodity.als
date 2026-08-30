module model/observation_032_measure_before_commodity

sig Purpose {}
sig Locus {}
sig Measure {}
sig MeasureName {}
sig Event {}

abstract sig World {
  present: set Event,
  effect: Event -> Locus -> Measure -> lone Int,
  purpose: Event -> lone Purpose,
  parent: Event -> set Event,
  measureName: Measure -> lone MeasureName
}

one sig Left, Right extends World {}

fact WellFormed {
  all w: World | {
    w.effect.Int in w.present -> Locus -> Measure
    w.purpose.Purpose in w.present
    w.parent in w.present -> w.present
    w.measureName.MeasureName in Measure

    all m: Measure | one m.(w.measureName)
    all n: MeasureName | one n.~(w.measureName)

    all e: w.present | {
      some e.(w.effect) or some e.(w.purpose) or some e.(w.parent)
      all l: Locus, m: Measure | {
        let n = amount[w, e, l, m] |
          n >= -2 and n <= 2
      }
    }

    no iden & ^(w.parent)
  }
}

fun amount[w: World, e: Event, l: Locus, m: Measure]: one Int {
  sum { i: Int | e->l->m->i in w.effect }
}

fun collapsedAmount[w: World, e: Event, l: Locus]: one Int {
  sum m: Measure | amount[w, e, l, m]
}

fun affectedMeasures[w: World, e: Event]: set Measure {
  { m: Measure | some l: Locus | amount[w, e, l, m] != 0 }
}

fun measureDelta[w: World, e: Event, m: Measure]: one Int {
  sum l: Locus | amount[w, e, l, m]
}

fun superseded[w: World]: set Event {
  w.present.(w.parent)
}

fun tips[w: World]: set Event {
  w.present - superseded[w]
}

fun balanceAt[w: World, l: Locus, m: Measure]: one Int {
  sum e: tips[w] | amount[w, e, l, m]
}

fun coordinateBalances[w: World]: Locus -> Measure -> Int {
  { l: Locus, m: Measure, i: Int | i = balanceAt[w, l, m] }
}

fun measureTotals[w: World]: Measure -> Int {
  { m: Measure, i: Int |
      i = sum l: Locus | balanceAt[w, l, m] }
}

fun commitments[w: World]: set Purpose {
  tips[w].(w.purpose)
}

fun explanation[w: World]: Event -> Event {
  tips[w] <: *(w.parent)
}

fun conversionLikeEvents[w: World]: set Event {
  { e: tips[w] |
      #affectedMeasures[w, e] = 2 and
      (some m: Measure | measureDelta[w, e, m] < 0) and
      (some m: Measure | measureDelta[w, e, m] > 0) }
}

pred sameMeasureCore[a, b: World] {
  a.present = b.present
  a.effect = b.effect
  a.purpose = b.purpose
  a.parent = b.parent
}

pred sameCollapsedCore[a, b: World] {
  a.present = b.present
  all e: a.present, l: Locus |
    collapsedAmount[a, e, l] = collapsedAmount[b, e, l]
}

pred sameSelectedAnswers[a, b: World] {
  coordinateBalances[a] = coordinateBalances[b]
  measureTotals[a] = measureTotals[b]
  commitments[a] = commitments[b]
  explanation[a] = explanation[b]
  conversionLikeEvents[a] = conversionLikeEvents[b]
}

pred measureCoreExpressesDistinctQuantityAxes {
  #Left.present = 4
  #Locus = 2
  #Measure = 2

  some conversionLikeEvents[Left]

  some l: Locus, m1, m2: Measure |
    m1 != m2 and balanceAt[Left, l, m1] != balanceAt[Left, l, m2]

  some e: tips[Left] |
    some e.(Left.purpose) and some e.(Left.effect)

  some e: tips[Left] | some e.(Left.parent)
}

pred differentMeasureNamesSameCoreSameAnswers {
  sameMeasureCore[Left, Right]
  Left.measureName != Right.measureName
  sameSelectedAnswers[Left, Right]
}

pred forgettingMeasureCanLoseDistribution {
  sameCollapsedCore[Left, Right]
  Left.purpose = Right.purpose
  Left.parent = Right.parent
  Left.measureName = Right.measureName

  coordinateBalances[Left] != coordinateBalances[Right]
}

pred forgettingMeasureCanLoseConversionShape {
  sameCollapsedCore[Left, Right]
  Left.purpose = Right.purpose
  Left.parent = Right.parent
  Left.measureName = Right.measureName

  conversionLikeEvents[Left] != conversionLikeEvents[Right]
}

assert MeasureCoreDeterminesSelectedVocabulary {
  sameMeasureCore[Left, Right] implies
    sameSelectedAnswers[Left, Right]
}

run measureCoreExpressesDistinctQuantityAxes for exactly 4 Event, exactly 2 Locus, exactly 2 Measure, exactly 2 MeasureName, exactly 2 Purpose, exactly 2 World, 6 Int
run differentMeasureNamesSameCoreSameAnswers for exactly 4 Event, exactly 2 Locus, exactly 2 Measure, exactly 2 MeasureName, exactly 2 Purpose, exactly 2 World, 6 Int
run forgettingMeasureCanLoseDistribution for exactly 4 Event, exactly 2 Locus, exactly 2 Measure, exactly 2 MeasureName, exactly 2 Purpose, exactly 2 World, 6 Int
run forgettingMeasureCanLoseConversionShape for exactly 4 Event, exactly 2 Locus, exactly 2 Measure, exactly 2 MeasureName, exactly 2 Purpose, exactly 2 World, 6 Int
check MeasureCoreDeterminesSelectedVocabulary for exactly 4 Event, exactly 2 Locus, exactly 2 Measure, exactly 2 MeasureName, exactly 2 Purpose, exactly 2 World, 6 Int
