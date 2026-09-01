module experiments/observation_085_query_relative_basis

sig Locus {}
sig Measure {}

sig Coordinate {
  locus: one Locus,
  measure: one Measure
}

abstract sig FactSet {
  eventQuantity: Coordinate -> one Int,
  basis: Coordinate -> lone Int
}

one sig Missing, Zeroed extends FactSet {}

abstract sig ProjectionMode {}
one sig AnchoredCurrent, ActivityTotal extends ProjectionMode {}

sig Query {
  mode: one ProjectionMode,
  selected: some Coordinate
}

fact CoordinateIdentity {
  all l: Locus, m: Measure |
    one c: Coordinate | c.locus = l and c.measure = m

  all disj a, b: Coordinate |
    a.locus != b.locus or a.measure != b.measure
}

fun eventQuantityAt[f: FactSet, c: Coordinate]: one Int {
  sum c.(f.eventQuantity)
}

fun basisQuantityAt[f: FactSet, c: Coordinate]: one Int {
  sum c.(f.basis)
}

fact SmallQuantities {
  all f: FactSet, c: Coordinate | {
    let q = eventQuantityAt[f, c] |
      q >= -3 and q <= 3

    all b: c.(f.basis) |
      b >= -3 and b <= 3
  }
}

pred answerable[f: FactSet, q: Query, c: Coordinate] {
  c in q.selected
  q.mode = ActivityTotal or some c.(f.basis)
}

pred wholeAnswerable[f: FactSet, q: Query] {
  all c: q.selected | answerable[f, q, c]
}

fun projectedValue[f: FactSet, q: Query, c: Coordinate]: one Int {
  (q.mode = AnchoredCurrent) =>
    add[basisQuantityAt[f, c], eventQuantityAt[f, c]]
  else
    eventQuantityAt[f, c]
}

pred dogfoodCurrentCanFailWhileActivityIsDefined {
  some disj source, use: Coordinate |
    some disj current, activity: Query | {
      current.mode = AnchoredCurrent
      activity.mode = ActivityTotal
      current.selected = source + use
      activity.selected = use

      some source.(Missing.basis)
      no use.(Missing.basis)

      eventQuantityAt[Missing, source] < 0
      eventQuantityAt[Missing, use] > 0
      add[eventQuantityAt[Missing, source], eventQuantityAt[Missing, use]] = 0

      answerable[Missing, current, source]
      not answerable[Missing, current, use]
      not wholeAnswerable[Missing, current]
      wholeAnswerable[Missing, activity]
    }
}

pred sameCoordinateSupportsBothReadings {
  some c: Coordinate |
    some disj current, activity: Query | {
      current.mode = AnchoredCurrent
      activity.mode = ActivityTotal
      current.selected = c
      activity.selected = c

      some c.(Missing.basis)
      basisQuantityAt[Missing, c] != 0
      eventQuantityAt[Missing, c] != 0

      answerable[Missing, current, c]
      answerable[Missing, activity, c]
      projectedValue[Missing, current, c] != projectedValue[Missing, activity, c]
    }
}

pred explicitZeroEnablesCurrentWithoutChangingActivity {
  some c: Coordinate |
    some disj current, activity: Query | {
      Missing.eventQuantity = Zeroed.eventQuantity
      no c.(Missing.basis)
      Zeroed.basis = Missing.basis + c->0

      current.mode = AnchoredCurrent
      activity.mode = ActivityTotal
      current.selected = c
      activity.selected = c
      eventQuantityAt[Missing, c] > 0

      not answerable[Missing, current, c]
      answerable[Zeroed, current, c]
      answerable[Missing, activity, c]
      answerable[Zeroed, activity, c]

      projectedValue[Missing, activity, c] = projectedValue[Zeroed, activity, c]
      projectedValue[Zeroed, current, c] = projectedValue[Zeroed, activity, c]
    }
}

assert AnchoredCurrentRequiresExplicitBasis {
  all f: FactSet, q: Query, c: Coordinate |
    q.mode = AnchoredCurrent and c in q.selected and no c.(f.basis) implies
      not answerable[f, q, c]
}

assert ActivityValueIgnoresBasis {
  all a, b: FactSet, q: Query, c: Coordinate |
    q.mode = ActivityTotal and
    c in q.selected and
    a.eventQuantity = b.eventQuantity implies
      projectedValue[a, q, c] = projectedValue[b, q, c]
}

assert CoordinateDeterminesProjectionMode {
  all disj a, b: Query |
    a.selected = b.selected implies a.mode = b.mode
}

run dogfoodCurrentCanFailWhileActivityIsDefined for exactly 2 Locus, exactly 1 Measure, exactly 2 Coordinate, exactly 2 FactSet, exactly 2 ProjectionMode, exactly 2 Query, 5 Int
run sameCoordinateSupportsBothReadings for exactly 1 Locus, exactly 1 Measure, exactly 1 Coordinate, exactly 2 FactSet, exactly 2 ProjectionMode, exactly 2 Query, 5 Int
run explicitZeroEnablesCurrentWithoutChangingActivity for exactly 1 Locus, exactly 1 Measure, exactly 1 Coordinate, exactly 2 FactSet, exactly 2 ProjectionMode, exactly 2 Query, 5 Int
check AnchoredCurrentRequiresExplicitBasis for exactly 1 Locus, exactly 1 Measure, exactly 1 Coordinate, exactly 2 FactSet, exactly 2 ProjectionMode, exactly 2 Query, 5 Int
check ActivityValueIgnoresBasis for exactly 1 Locus, exactly 1 Measure, exactly 1 Coordinate, exactly 2 FactSet, exactly 2 ProjectionMode, exactly 2 Query, 5 Int
check CoordinateDeterminesProjectionMode for exactly 1 Locus, exactly 1 Measure, exactly 1 Coordinate, exactly 2 FactSet, exactly 2 ProjectionMode, exactly 2 Query, 5 Int
