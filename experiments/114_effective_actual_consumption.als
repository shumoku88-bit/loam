module experiments/observation_114_effective_actual_consumption

sig Purpose {}
one sig Food, Household extends Purpose {}

sig Locus {}
one sig Coffee extends Locus {}

sig Day {}
one sig D1, D2 extends Day {}

sig Event {
  locus: one Locus,
  amount: one Int
}

sig EventCorrection {
  target: one Event,
  replacement: one Event
}

sig ValidityFact {
  event: one Event,
  day: one Day
}

sig ValidityCorrection {
  target: one ValidityFact,
  replacement: one ValidityFact
}

sig Route {
  locus: one Locus,
  day: one Day,
  purpose: lone Purpose
}

sig World {
  events: set Event,
  eventCorrections: set EventCorrection,
  validityFacts: set ValidityFact,
  validityCorrections: set ValidityCorrection,
  routes: set Route
}

one sig Left, Right extends World {}

fact SmallPositiveAmounts {
  all e: Event | e.amount > 0 and e.amount <= 3
}

fun eventEdges[w: World]: Event -> Event {
  { source, destination: Event |
    some c: w.eventCorrections |
      c.target = source and c.replacement = destination }
}

fun validityEdges[w: World]: ValidityFact -> ValidityFact {
  { source, destination: ValidityFact |
    some c: w.validityCorrections |
      c.target = source and c.replacement = destination }
}

fun eventFrontier[w: World]: set Event {
  w.events - w.eventCorrections.target
}

fun validityFrontier[w: World]: set ValidityFact {
  w.validityFacts - w.validityCorrections.target
}

fun currentDay[w: World, e: Event]: lone Day {
  { d: Day |
    some v: validityFrontier[w] |
      v.event = e and v.day = d }
}

fun routedPurpose[w: World, e: Event]: lone Purpose {
  { p: Purpose |
    some r: w.routes |
      r.locus = e.locus and
      r.day in currentDay[w, e] and
      r.purpose = p }
}

fun rawConsumption[w: World, p: Purpose]: one Int {
  sum e: { e: w.events | p in routedPurpose[w, e] } | e.amount
}

fun effectiveConsumption[w: World, p: Purpose]: one Int {
  sum e: { e: eventFrontier[w] | p in routedPurpose[w, e] } | e.amount
}

pred consumable[w: World] {
  all e: eventFrontier[w] | one currentDay[w, e]
}

fact WorldAdmission {
  all w: World | {
    all c: w.eventCorrections | {
      c.target in w.events
      c.replacement in w.events
      c.target != c.replacement
    }
    all e: Event | {
      lone { c: w.eventCorrections | c.target = e }
      lone { c: w.eventCorrections | c.replacement = e }
    }
    no e: Event | e in e.^(eventEdges[w])

    all c: w.validityCorrections | {
      c.target in w.validityFacts
      c.replacement in w.validityFacts
      c.target != c.replacement
      c.target.event = c.replacement.event
    }
    all v: ValidityFact | {
      lone { c: w.validityCorrections | c.target = v }
      lone { c: w.validityCorrections | c.replacement = v }
    }
    no v: ValidityFact | v in v.^(validityEdges[w])

    all e: Event |
      lone { v: validityFrontier[w] | v.event = e }

    all l: Locus, d: Day |
      lone { r: w.routes | r.locus = l and r.day = d }
  }
}

pred rawDoubleCountsCorrectedActual {
  some disj original, revised: Event,
       c: EventCorrection,
       originalDate, revisedDate: ValidityFact,
       route: Route | {
    Left.events = original + revised
    Left.eventCorrections = c
    c.target = original
    c.replacement = revised

    Left.validityFacts = originalDate + revisedDate
    no Left.validityCorrections
    originalDate.event = original
    revisedDate.event = revised
    originalDate.day = D1
    revisedDate.day = D1

    Left.routes = route
    route.locus = Coffee
    route.day = D1
    route.purpose = Food
    original.locus = Coffee
    revised.locus = Coffee

    consumable[Left]
    rawConsumption[Left, Food] = add[original.amount, revised.amount]
    effectiveConsumption[Left, Food] = revised.amount
    rawConsumption[Left, Food] != effectiveConsumption[Left, Food]
  }
}

pred missingReplacementValidityFailsClosed {
  some disj original, revised: Event,
       c: EventCorrection,
       originalDate: ValidityFact | {
    Left.events = original + revised
    Left.eventCorrections = c
    c.target = original
    c.replacement = revised

    Left.validityFacts = originalDate
    no Left.validityCorrections
    originalDate.event = original
    originalDate.day = D1

    no Left.routes
    no currentDay[Left, revised]
    not consumable[Left]
  }
}

pred correctionDoesNotForceSameOccurrenceDay {
  some disj original, revised: Event,
       c: EventCorrection,
       originalDate, revisedDate: ValidityFact | {
    Left.events = original + revised
    Left.eventCorrections = c
    c.target = original
    c.replacement = revised

    Left.validityFacts = originalDate + revisedDate
    no Left.validityCorrections
    originalDate.event = original
    revisedDate.event = revised
    originalDate.day = D1
    revisedDate.day = D2

    currentDay[Left, original] = D1
    currentDay[Left, revised] = D2
  }
}

pred replacementDateCorrectionReroutesConsumption {
  some disj original, revised: Event,
       eventCorrection: EventCorrection,
       originalDate, oldRevisedDate, newRevisedDate: ValidityFact,
       dateCorrection: ValidityCorrection,
       foodRoute, householdRoute: Route | {
    Left.events = original + revised
    Left.eventCorrections = eventCorrection
    eventCorrection.target = original
    eventCorrection.replacement = revised

    Left.validityFacts = originalDate + oldRevisedDate + newRevisedDate
    Left.validityCorrections = dateCorrection
    originalDate.event = original
    originalDate.day = D1
    oldRevisedDate.event = revised
    oldRevisedDate.day = D1
    newRevisedDate.event = revised
    newRevisedDate.day = D2
    dateCorrection.target = oldRevisedDate
    dateCorrection.replacement = newRevisedDate

    Left.routes = foodRoute + householdRoute
    foodRoute.locus = Coffee
    foodRoute.day = D1
    foodRoute.purpose = Food
    householdRoute.locus = Coffee
    householdRoute.day = D2
    householdRoute.purpose = Household
    original.locus = Coffee
    revised.locus = Coffee

    consumable[Left]
    currentDay[Left, revised] = D2
    effectiveConsumption[Left, Food] = 0
    effectiveConsumption[Left, Household] = revised.amount
  }
}

pred correctionsChangeAnswerWithoutChangingRawEvents {
  some disj original, revised: Event,
       correction: EventCorrection,
       originalDate, revisedDate: ValidityFact,
       route: Route | {
    Left.events = Right.events
    Left.events = original + revised

    no Left.eventCorrections
    Right.eventCorrections = correction
    correction.target = original
    correction.replacement = revised

    Left.validityFacts = Right.validityFacts
    Left.validityFacts = originalDate + revisedDate
    no Left.validityCorrections
    no Right.validityCorrections
    originalDate.event = original
    revisedDate.event = revised
    originalDate.day = D1
    revisedDate.day = D1

    Left.routes = Right.routes
    Left.routes = route
    route.locus = Coffee
    route.day = D1
    route.purpose = Food
    original.locus = Coffee
    revised.locus = Coffee

    consumable[Left]
    consumable[Right]
    effectiveConsumption[Left, Food] != effectiveConsumption[Right, Food]
  }
}

pred sameEffectiveInputs[a, b: World] {
  eventFrontier[a] = eventFrontier[b]
  validityFrontier[a] = validityFrontier[b]
  a.routes = b.routes
}

assert RawAndEffectiveAgreeWithoutEventCorrection {
  all w: World, p: Purpose |
    (no w.eventCorrections and consumable[w])
    implies rawConsumption[w, p] = effectiveConsumption[w, p]
}

assert EventCorrectionImpliesSameOccurrenceDay {
  all w: World, c: w.eventCorrections |
    (one currentDay[w, c.target] and one currentDay[w, c.replacement])
    implies currentDay[w, c.target] = currentDay[w, c.replacement]
}

assert EffectiveInputsDetermineConsumption {
  all a, b: World, p: Purpose |
    (sameEffectiveInputs[a, b] and consumable[a] and consumable[b])
    implies effectiveConsumption[a, p] = effectiveConsumption[b, p]
}

run rawDoubleCountsCorrectedActual for exactly 2 Purpose, exactly 1 Locus, exactly 2 Day, exactly 2 Event, exactly 1 EventCorrection, exactly 2 ValidityFact, exactly 0 ValidityCorrection, exactly 1 Route, exactly 2 World, 5 Int
run missingReplacementValidityFailsClosed for exactly 2 Purpose, exactly 1 Locus, exactly 2 Day, exactly 2 Event, exactly 1 EventCorrection, exactly 1 ValidityFact, exactly 0 ValidityCorrection, exactly 0 Route, exactly 2 World, 5 Int
run correctionDoesNotForceSameOccurrenceDay for exactly 2 Purpose, exactly 1 Locus, exactly 2 Day, exactly 2 Event, exactly 1 EventCorrection, exactly 2 ValidityFact, exactly 0 ValidityCorrection, exactly 0 Route, exactly 2 World, 5 Int
run replacementDateCorrectionReroutesConsumption for exactly 2 Purpose, exactly 1 Locus, exactly 2 Day, exactly 2 Event, exactly 1 EventCorrection, exactly 3 ValidityFact, exactly 1 ValidityCorrection, exactly 2 Route, exactly 2 World, 5 Int
run correctionsChangeAnswerWithoutChangingRawEvents for exactly 2 Purpose, exactly 1 Locus, exactly 2 Day, exactly 2 Event, exactly 1 EventCorrection, exactly 2 ValidityFact, exactly 0 ValidityCorrection, exactly 1 Route, exactly 2 World, 5 Int

check RawAndEffectiveAgreeWithoutEventCorrection for exactly 2 Purpose, exactly 1 Locus, exactly 2 Day, 3 Event, 2 EventCorrection, 4 ValidityFact, 2 ValidityCorrection, 2 Route, exactly 2 World, 5 Int
check EventCorrectionImpliesSameOccurrenceDay for exactly 2 Purpose, exactly 1 Locus, exactly 2 Day, 3 Event, 2 EventCorrection, 4 ValidityFact, 2 ValidityCorrection, 2 Route, exactly 2 World, 5 Int
check EffectiveInputsDetermineConsumption for exactly 2 Purpose, exactly 1 Locus, exactly 2 Day, 3 Event, 2 EventCorrection, 4 ValidityFact, 2 ValidityCorrection, 2 Route, exactly 2 World, 5 Int
