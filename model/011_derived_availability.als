module model/observation_011_derived_availability

open util/ordering[Time]

sig Time {}
sig Unit {}

one sig Origin {
  initial: set Unit
}

sig Use {
  when: one Time,
  unit: one Unit
}

one sig Stored {
  available: Time -> Unit
}

fun usedAt[t: Time]: set Unit {
  { u: Unit |
    some e: Use |
      e.when = t and e.unit = u
  }
}

fun usedBefore[t: Time]: set Unit {
  { u: Unit |
    some e: Use |
      e.unit = u and e.when in t.^prev
  }
}

fun derivedAvailable[t: Time]: set Unit {
  Origin.initial - usedBefore[t]
}

pred weakStoredRules {
  Stored.available[first] = Origin.initial

  all t: Time - last |
    Stored.available[next[t]] in Stored.available[t]

  all e: Use |
    e.unit in Stored.available[e.when]

  all t: Time - last, u: usedAt[t] |
    u not in Stored.available[next[t]]
}

pred phantomLossUnderWeakRules {
  weakStoredRules

  some Origin.initial
  some Unit - Origin.initial
  some Use

  some t: Time - last, u: Unit |
    u in Stored.available[t] and
    u not in Stored.available[next[t]] and
    u not in usedAt[t]
}

pred exactStoredEvolution {
  Stored.available[first] = Origin.initial

  all t: Time - last |
    Stored.available[next[t]] =
      Stored.available[t] - usedAt[t]
}

assert ExactStoredEqualsDerived {
  exactStoredEvolution implies
    all t: Time |
      Stored.available[t] = derivedAvailable[t]
}

pred usesOnlyDerivedAvailability {
  all e: Use |
    e.unit in derivedAvailable[e.when]

  all t: Time, u: Unit |
    lone e: Use |
      e.when = t and e.unit = u
}

pred derivedConsumptiveWorld {
  usesOnlyDerivedAvailability

  some Origin.initial
  some Unit - Origin.initial
  some Use

  some t: Time - first |
    some usedBefore[t] and
    some derivedAvailable[t]
}

assert DerivedAvailabilityForbidsRepeatedUse {
  usesOnlyDerivedAvailability implies
    no disj e1, e2: Use |
      e1.unit = e2.unit and
      e1.when != e2.when
}

run phantomLossUnderWeakRules for exactly 3 Time, exactly 3 Unit, 3 Use
check ExactStoredEqualsDerived for exactly 4 Time, exactly 4 Unit, 4 Use
run derivedConsumptiveWorld for exactly 3 Time, exactly 3 Unit, 3 Use
check DerivedAvailabilityForbidsRepeatedUse for exactly 4 Time, exactly 3 Unit, 4 Use
