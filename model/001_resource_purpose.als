module model/001_resource_purpose

open util/ordering[Time]

sig Time {}
sig Purpose {}
sig Unit {}

one sig Trace {
  at: Time -> Unit -> Purpose
}

fun purposeAt[t: Time, u: Unit]: set Purpose {
  u.(t.(Trace.at))
}

fact EveryUnitHasOnePurposeAtEveryTime {
  all t: Time, u: Unit | one purposeAt[t, u]
}

pred somePlacementChanges {
  some t: Time - last, u: Unit |
    purposeAt[t, u] != purposeAt[next[t], u]
}

pred somePlacementPersists {
  some u: Unit |
    all t: Time - last |
      purposeAt[t, u] = purposeAt[next[t], u]
}

pred mixedWorld {
  somePlacementChanges
  somePlacementPersists
}

assert NoUnitDisappearsFromPlacement {
  all t: Time, u: Unit | one purposeAt[t, u]
}

run mixedWorld for exactly 3 Time, exactly 3 Purpose, exactly 5 Unit
check NoUnitDisappearsFromPlacement for exactly 4 Time, exactly 3 Purpose, exactly 6 Unit
