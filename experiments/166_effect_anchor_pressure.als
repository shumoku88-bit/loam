module experiments/observation_166_effect_anchor_pressure

sig Event {}
sig Key {}

sig Effect {
  event: one Event,
  key: one Key
}

abstract sig Party {}
one sig Household, Outside extends Party {}

sig Unit {
  source: one Effect
}

sig World {
  events: set Event,
  incurred: set Unit,
  burden: Unit -> lone Party,
  claims: set Unit,
  debtor: Unit -> lone Party,
  creditor: Unit -> lone Party,
  discharges: Event -> set Unit
}

// Mirrors LOAM's current practical identity law: EffectKey is unique only
// inside one Event, not globally across all Events.
fact EffectKeyScopedIdentity {
  all disj left, right: Effect |
    left.event = right.event implies left.key != right.key
}

fact WellFormedWorlds {
  all w: World | {
    all u: w.incurred | {
      one w.burden[u]
      u.source.event in w.events
    }

    all u: Unit - w.incurred |
      no w.burden[u]

    w.claims in w.incurred

    all u: w.claims | {
      one w.debtor[u]
      one w.creditor[u]
      w.debtor[u] != w.creditor[u]
      w.debtor[u] = Household or w.creditor[u] = Household
    }

    all u: Unit - w.claims | {
      no w.debtor[u]
      no w.creditor[u]
    }

    all e: w.events |
      w.discharges[e] in w.claims

    all e: Event - w.events |
      no w.discharges[e]

    // Current-view stop condition from Observation 165: one claim unit is
    // discharged by at most one later Event.
    all u: w.claims |
      lone { e: w.events | u in w.discharges[e] }
  }
}

fun discharged[w: World]: set Unit {
  { u: w.claims | some e: w.events | u in w.discharges[e] }
}

fun outstanding[w: World]: set Unit {
  w.claims - discharged[w]
}

fun incurredAtEvent[w: World, e: Event]: set Unit {
  { u: w.incurred | u.source.event = e }
}

fun householdBurdenAtEvent[w: World, e: Event]: set Unit {
  { u: incurredAtEvent[w, e] | w.burden[u] = Household }
}

fun outsideOutstandingAtEvent[w: World, e: Event]: set Unit {
  { u: outstanding[w] |
    u.source.event = e and
    w.debtor[u] = Outside and
    w.creditor[u] = Household
  }
}

fun householdBurdenAtEffect[w: World, effect: Effect]: set Unit {
  { u: w.incurred | u.source = effect and w.burden[u] = Household }
}

fun outsideOutstandingAtEffect[w: World, effect: Effect]: set Unit {
  { u: outstanding[w] |
    u.source = effect and
    w.debtor[u] = Outside and
    w.creditor[u] = Household
  }
}

// One observed Event can contain effects whose economic burden differs.
// Event-wide burden classification would therefore be too coarse.
pred mixedBurdenInsideOneEvent {
  some w: World, e: Event,
       disj ownEffect, sharedEffect: Effect,
       disj ownUnit, sharedUnit: Unit | {
    ownEffect.event = e
    sharedEffect.event = e
    ownUnit.source = ownEffect
    sharedUnit.source = sharedEffect

    w.events = e
    w.incurred = ownUnit + sharedUnit
    w.burden = ownUnit->Household + sharedUnit->Outside
    w.claims = sharedUnit
    w.debtor = sharedUnit->Outside
    w.creditor = sharedUnit->Household
    no w.discharges[e]

    householdBurdenAtEffect[w, ownEffect] = ownUnit
    no householdBurdenAtEffect[w, sharedEffect]
    outsideOutstandingAtEffect[w, sharedEffect] = sharedUnit
  }
}

// Two worlds have the same Event-level totals but disagree about which Effect
// carries the outside-borne outstanding share. Event aggregate answers cannot
// reconstruct the Effect-specific meaning.
pred sameEventAggregateDifferentEffectMeaning {
  some disj left, right: World, e: Event,
       disj effectA, effectB: Effect,
       disj unitA, unitB: Unit | {
    effectA.event = e
    effectB.event = e
    unitA.source = effectA
    unitB.source = effectB

    left.events = e
    right.events = e
    left.incurred = unitA + unitB
    right.incurred = unitA + unitB

    left.burden = unitA->Household + unitB->Outside
    right.burden = unitA->Outside + unitB->Household

    left.claims = unitB
    right.claims = unitA
    left.debtor = unitB->Outside
    right.debtor = unitA->Outside
    left.creditor = unitB->Household
    right.creditor = unitA->Household
    no left.discharges[e]
    no right.discharges[e]

    #householdBurdenAtEvent[left, e] = 1
    #householdBurdenAtEvent[right, e] = 1
    #outsideOutstandingAtEvent[left, e] = 1
    #outsideOutstandingAtEvent[right, e] = 1

    no outsideOutstandingAtEffect[left, effectA]
    #outsideOutstandingAtEffect[right, effectA] = 1
  }
}

// EventId alone cannot identify an Effect when one Event contains more than one.
pred eventAloneCannotIdentifyEffect {
  some disj left, right: Effect |
    left.event = right.event
}

// EffectKey alone is not globally identifying: the current Core law allows the
// same key token to appear under different Event identities.
pred keyAloneCannotIdentifyEffect {
  some disj left, right: Effect |
    left.event != right.event and
    left.key = right.key
}

// A discharge endpoint can remain Event-scoped in the bounded model. The later
// Event may contain multiple effects while the explicit Event -> claim-unit
// correspondence still determines that the claim is no longer outstanding.
pred eventScopedDischargeStillWorks {
  some w: World,
       originEvent, paymentEvent: Event,
       originEffect: Effect,
       disj paymentEffectA, paymentEffectB: Effect,
       u: Unit | {
    originEvent != paymentEvent
    originEffect.event = originEvent
    paymentEffectA.event = paymentEvent
    paymentEffectB.event = paymentEvent
    u.source = originEffect

    w.events = originEvent + paymentEvent
    w.incurred = u
    w.burden = u->Household
    w.claims = u
    w.debtor = u->Household
    w.creditor = u->Outside
    w.discharges[paymentEvent] = u
    no w.discharges[originEvent]

    no outstanding[w]
  }
}

// The existing pair of identities is sufficient to identify one Effect within
// this model. No new globally unique EffectId is required merely for lookup.
assert EventAndKeyIdentifyEffect {
  all left, right: Effect |
    left.event = right.event and left.key = right.key implies left = right
}

// Stored outstanding state is unnecessary once claim identity and explicit
// discharge correspondence are fixed.
assert DischargeCorrespondenceDeterminesOutstanding {
  all left, right: World |
    left.claims = right.claims and
    left.events = right.events and
    left.discharges = right.discharges
    implies
      outstanding[left] = outstanding[right]
}

run mixedBurdenInsideOneEvent for 7 but exactly 2 Event, 4 Effect, 4 Key, 4 Unit, 1 World
run sameEventAggregateDifferentEffectMeaning for 8 but exactly 2 Event, 4 Effect, 4 Key, 4 Unit, 2 World
run eventAloneCannotIdentifyEffect for 5 but exactly 2 Event, 4 Effect, 4 Key
run keyAloneCannotIdentifyEffect for 5 but exactly 3 Event, 4 Effect, 3 Key
run eventScopedDischargeStillWorks for 8 but exactly 3 Event, 5 Effect, 5 Key, 4 Unit, 1 World

check EventAndKeyIdentifyEffect for 7 but exactly 3 Event, 5 Effect, 4 Key
check DischargeCorrespondenceDeterminesOutstanding for 8 but exactly 3 Event, 5 Effect, 5 Key, 5 Unit, 3 World
