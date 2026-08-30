module model/observation_048_backing_eligibility_overlay

sig Locus {}
sig Measure {}
sig Event {}

sig Cell {
  locus: one Locus,
  measure: one Measure
}

abstract sig World {
  present: set Event,
  effect: Event -> Cell -> lone Int,
  parent: Event -> set Event,
  eligible: set Locus
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
    w.parent in w.present -> w.present
    no iden & ^(w.parent)

    all e: w.present | {
      some e.(w.effect) or some e.(w.parent)
      all c: Cell |
        let n = amount[w, e, c] |
          n >= -3 and n <= 3
    }
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

fun totalByMeasure[w: World]: Measure -> Int {
  { m: Measure, i: Int |
      i = sum c: Cell | (c.measure = m) => balanceAt[w, c] else 0 }
}

fun allocatableByMeasure[w: World]: Measure -> Int {
  { m: Measure, i: Int |
      i = sum c: Cell |
        (c.measure = m and c.locus in w.eligible) => balanceAt[w, c] else 0 }
}

pred samePhysicalCore[a, b: World] {
  a.present = b.present
  a.effect = b.effect
  a.parent = b.parent
}

pred samePhysicalAnswers[a, b: World] {
  coordinateBalances[a] = coordinateBalances[b]
  totalByMeasure[a] = totalByMeasure[b]
}

pred eligibilityOverlayCanChangeOnlyAllocatable {
  #Left.present = 2
  samePhysicalCore[Left, Right]
  samePhysicalAnswers[Left, Right]

  all c: Cell | balanceAt[Left, c] > 0
  some Left.eligible
  some Right.eligible
  Left.eligible != Right.eligible
  allocatableByMeasure[Left] != allocatableByMeasure[Right]
}

pred heldQuantityCanRemainIneligible {
  #Left.present = 2
  #Left.eligible = 1
  all c: Cell | balanceAt[Left, c] > 0

  some c: Cell |
    c.locus not in Left.eligible and balanceAt[Left, c] > 0

  totalByMeasure[Left] != allocatableByMeasure[Left]
}

assert PhysicalCoreDeterminesPhysicalAnswers {
  samePhysicalCore[Left, Right] implies
    samePhysicalAnswers[Left, Right]
}

assert PhysicalCoreDeterminesAllocatableQuantity {
  samePhysicalCore[Left, Right] implies
    allocatableByMeasure[Left] = allocatableByMeasure[Right]
}

assert PhysicalCorePlusEligibilityDeterminesSelectedVocabulary {
  (samePhysicalCore[Left, Right] and Left.eligible = Right.eligible) implies {
    samePhysicalAnswers[Left, Right]
    allocatableByMeasure[Left] = allocatableByMeasure[Right]
  }
}

run eligibilityOverlayCanChangeOnlyAllocatable for exactly 2 Event, exactly 2 Locus, exactly 1 Measure, exactly 2 Cell, exactly 2 World, 5 Int
run heldQuantityCanRemainIneligible for exactly 2 Event, exactly 2 Locus, exactly 1 Measure, exactly 2 Cell, exactly 2 World, 5 Int
check PhysicalCoreDeterminesPhysicalAnswers for exactly 2 Event, exactly 2 Locus, exactly 1 Measure, exactly 2 Cell, exactly 2 World, 5 Int
check PhysicalCoreDeterminesAllocatableQuantity for exactly 2 Event, exactly 2 Locus, exactly 1 Measure, exactly 2 Cell, exactly 2 World, 5 Int
check PhysicalCorePlusEligibilityDeterminesSelectedVocabulary for exactly 2 Event, exactly 2 Locus, exactly 1 Measure, exactly 2 Cell, exactly 2 World, 5 Int
