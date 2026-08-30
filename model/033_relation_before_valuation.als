module model/observation_033_relation_before_valuation

sig Purpose {}
sig Locus {}
sig Measure {}
sig RelationValue {}
sig Event {}

sig Cell {
  locus: one Locus,
  measure: one Measure
}

abstract sig World {
  present: set Event,
  effect: Event -> Cell -> lone Int,
  purpose: Event -> lone Purpose,
  parent: Event -> set Event,
  relation: Measure -> Measure -> lone RelationValue
}

one sig Left, Right extends World {}

fact CoordinateCells {
  all l: Locus, m: Measure |
    one c: Cell | c.locus = l and c.measure = m

  all disj a, b: Cell |
    a.locus != b.locus or a.measure != b.measure
}

fact WellFormed {
  all w: World | {
    w.effect.Int in w.present -> Cell
    w.purpose.Purpose in w.present
    w.parent in w.present -> w.present

    all e: w.present | {
      some e.(w.effect) or some e.(w.purpose) or some e.(w.parent)
      all c: Cell |
        let n = amount[w, e, c] |
          n >= -2 and n <= 2
    }

    no iden & ^(w.parent)

    all m: Measure |
      no m->m->RelationValue & w.relation
  }
}

fun amount[w: World, e: Event, c: Cell]: one Int {
  sum { i: Int | e->c->i in w.effect }
}

fun superseded[w: World]: set Event {
  w.present.(w.parent)
}

fun tips[w: World]: set Event {
  w.present - superseded[w]
}

fun balanceAt[w: World, c: Cell]: one Int {
  sum e: tips[w] | amount[w, e, c]
}

fun coordinateBalances[w: World]: Cell -> Int {
  { c: Cell, i: Int | i = balanceAt[w, c] }
}

fun commitments[w: World]: set Purpose {
  tips[w].(w.purpose)
}

fun explanation[w: World]: Event -> Event {
  tips[w] <: *(w.parent)
}

fun heldMeasures[w: World]: set Measure {
  { m: Measure |
      some c: Cell |
        c.measure = m and balanceAt[w, c] != 0 }
}

fun valuationView[w: World]: Measure -> Measure -> RelationValue {
  { source, target: Measure, r: RelationValue |
      source in heldMeasures[w] and
      source != target and
      source->target->r in w.relation }
}

pred sameEventCore[a, b: World] {
  a.present = b.present
  a.effect = b.effect
  a.purpose = b.purpose
  a.parent = b.parent
}

pred sameCoreAnswers[a, b: World] {
  coordinateBalances[a] = coordinateBalances[b]
  commitments[a] = commitments[b]
  explanation[a] = explanation[b]
}

pred sameSelectedAnswers[a, b: World] {
  sameCoreAnswers[a, b]
  valuationView[a] = valuationView[b]
}

pred relationOverlayCanChangeOnlyValuation {
  #Left.present = 3
  #Locus = 1
  #Measure = 2

  sameEventCore[Left, Right]
  sameCoreAnswers[Left, Right]

  #heldMeasures[Left] = 2
  Left.relation != Right.relation
  valuationView[Left] != valuationView[Right]
}

pred relationCanBeAbsentWithoutChangingCore {
  #Left.present = 3
  #Locus = 1
  #Measure = 2

  sameEventCore[Left, Right]
  sameCoreAnswers[Left, Right]

  #heldMeasures[Left] = 2
  no Left.relation
  some Right.relation
  valuationView[Left] != valuationView[Right]
}

pred relationValuesCanVaryOverSameHistory {
  #Left.present = 3
  #Locus = 1
  #Measure = 2
  #RelationValue = 2

  sameEventCore[Left, Right]
  some Left.relation
  some Right.relation
  Left.relation != Right.relation
  valuationView[Left] != valuationView[Right]
}

assert EventCoreDeterminesValuation {
  sameEventCore[Left, Right] implies
    valuationView[Left] = valuationView[Right]
}

assert FullViewDeterminesSelectedVocabulary {
  (sameEventCore[Left, Right] and Left.relation = Right.relation) implies
    sameSelectedAnswers[Left, Right]
}

run relationOverlayCanChangeOnlyValuation for exactly 3 Event, exactly 1 Locus, exactly 2 Measure, exactly 2 Cell, exactly 2 RelationValue, exactly 2 Purpose, exactly 2 World, 5 Int
run relationCanBeAbsentWithoutChangingCore for exactly 3 Event, exactly 1 Locus, exactly 2 Measure, exactly 2 Cell, exactly 2 RelationValue, exactly 2 Purpose, exactly 2 World, 5 Int
run relationValuesCanVaryOverSameHistory for exactly 3 Event, exactly 1 Locus, exactly 2 Measure, exactly 2 Cell, exactly 2 RelationValue, exactly 2 Purpose, exactly 2 World, 5 Int
check EventCoreDeterminesValuation for exactly 3 Event, exactly 1 Locus, exactly 2 Measure, exactly 2 Cell, exactly 2 RelationValue, exactly 2 Purpose, exactly 2 World, 5 Int
check FullViewDeterminesSelectedVocabulary for exactly 3 Event, exactly 1 Locus, exactly 2 Measure, exactly 2 Cell, exactly 2 RelationValue, exactly 2 Purpose, exactly 2 World, 5 Int
