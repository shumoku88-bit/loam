module experiments/observation_052_effect_identity_before_coordinate_collapse

sig Event {}
sig Locus {}
sig Measure {}
sig Purpose {}
sig Effect {}

abstract sig World {
  present: set Effect,
  event: Effect -> lone Event,
  locus: Effect -> lone Locus,
  measure: Effect -> lone Measure,
  quantity: Effect -> lone Int,
  purpose: Effect -> lone Purpose
}

one sig Left, Right extends World {}

fact WellFormed {
  all w: World | {
    w.event.Event in w.present
    w.locus.Locus in w.present
    w.measure.Measure in w.present
    w.quantity.Int in w.present
    w.purpose.Purpose in w.present

    all x: w.present | {
      one x.(w.event)
      one x.(w.locus)
      one x.(w.measure)
      one x.(w.quantity)
      one x.(w.purpose)
      x.(w.quantity) >= -2
      x.(w.quantity) <= 2
      x.(w.quantity) != 0
    }
  }
}

fun effectsAt[w: World, e: Event, l: Locus, m: Measure]: set Effect {
  { x: w.present |
      x.(w.event) = e and
      x.(w.locus) = l and
      x.(w.measure) = m }
}

fun amount[w: World, e: Event, l: Locus, m: Measure]: one Int {
  sum x: effectsAt[w, e, l, m] | x.(w.quantity)
}

fun purposeAmount[
    w: World,
    e: Event,
    l: Locus,
    m: Measure,
    p: Purpose
]: one Int {
  sum x: { y: effectsAt[w, e, l, m] | y.(w.purpose) = p } |
    x.(w.quantity)
}

pred sameCollapsedCoordinates[a, b: World] {
  all e: Event, l: Locus, m: Measure |
    amount[a, e, l, m] = amount[b, e, l, m]
}

pred samePurposeBreakdown[a, b: World] {
  all e: Event, l: Locus, m: Measure, p: Purpose |
    purposeAmount[a, e, l, m, p] = purposeAmount[b, e, l, m, p]
}

pred sameIdentityDetail[a, b: World] {
  a.present = b.present
  a.event = b.event
  a.locus = b.locus
  a.measure = b.measure
  a.quantity = b.quantity
  a.purpose = b.purpose
}

pred duplicateCoordinateCanCarryDistinctPurposes {
  some w: World, disj x, y: w.present | {
    x.(w.event) = y.(w.event)
    x.(w.locus) = y.(w.locus)
    x.(w.measure) = y.(w.measure)
    x.(w.purpose) != y.(w.purpose)
  }
}

pred sameCollapsedCanHidePurposeBreakdown {
  #Left.present = 2
  #Right.present = 2
  sameCollapsedCoordinates[Left, Right]
  not samePurposeBreakdown[Left, Right]
}

assert CollapsedCoordinatesDeterminePurposeBreakdown {
  sameCollapsedCoordinates[Left, Right] implies
    samePurposeBreakdown[Left, Right]
}

assert IdentityDetailDeterminesPurposeBreakdown {
  sameIdentityDetail[Left, Right] implies
    samePurposeBreakdown[Left, Right]
}

run duplicateCoordinateCanCarryDistinctPurposes for exactly 1 Event, exactly 1 Locus, exactly 1 Measure, exactly 2 Purpose, exactly 4 Effect, exactly 2 World, 5 Int
run sameCollapsedCanHidePurposeBreakdown for exactly 1 Event, exactly 1 Locus, exactly 1 Measure, exactly 2 Purpose, exactly 4 Effect, exactly 2 World, 5 Int
check CollapsedCoordinatesDeterminePurposeBreakdown for exactly 1 Event, exactly 1 Locus, exactly 1 Measure, exactly 2 Purpose, exactly 4 Effect, exactly 2 World, 5 Int
check IdentityDetailDeterminesPurposeBreakdown for exactly 1 Event, exactly 1 Locus, exactly 1 Measure, exactly 2 Purpose, exactly 4 Effect, exactly 2 World, 5 Int
