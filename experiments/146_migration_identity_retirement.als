module migration_identity_retirement

abstract sig Time {}
one sig DayA, DayB extends Time {}

sig Payload {}

sig Event {
  payload: one Payload,
  baseTime: one Time
}

sig EventCorrection {
  target: one Event,
  replacement: one Event
}

fact EventCorrectionIsNotSelfReplacement {
  all c: EventCorrection | c.target != c.replacement
}

sig Locus {}
sig Amount {}

sig Effect {
  owner: one Event,
  locus: one Locus,
  amount: one Amount
}

sig ProvenanceUse {
  source: one Effect
}

-- Candidate for a smaller ActualValidity representation:
-- the Event itself is the initial temporal root, while only later corrections
-- allocate independently identified revision nodes.
sig Revision {
  forEvent: one Event,
  atTime: one Time
}

one sig RootedHistory {
  replaces: (Event + Revision) -> Revision
}

one sig ValueHistory {
  replacesTime: Time -> Time
}

fun eventOf[n: Event + Revision]: one Event {
  (n & Event) + (n & Revision).forEvent
}

fun timesOf[ns: set Event + Revision]: set Time {
  (ns & Event).baseTime + (ns & Revision).atTime
}

fun revisionsFor[e: Event]: set Revision {
  e.~forEvent
}

fun reachableFrom[e: Event]: set Event + Revision {
  e + e.^(RootedHistory.replaces)
}

fun terminalNodes[e: Event]: set Event + Revision {
  { n: reachableFrom[e] | no n.(RootedHistory.replaces) }
}

fun currentTimes[e: Event]: set Time {
  timesOf[terminalNodes[e]]
}

pred rootedAdmissible {
  -- Every correction stays inside one Event's temporal history.
  all n: Event + Revision, r: Revision |
    n->r in RootedHistory.replaces implies eventOf[n] = r.forEvent

  -- Correction alone must justify disjoint finite paths, not sibling winners,
  -- merges, or cycles.
  all n: Event + Revision | lone n.(RootedHistory.replaces)
  all r: Revision | lone r.~(RootedHistory.replaces)
  no iden & ^(RootedHistory.replaces)

  -- A retained revision is not an unattached side record.
  all r: Revision | r in reachableFrom[r.forEvent]

  -- One admitted current temporal answer per Event.
  all e: Event | one terminalNodes[e]
}

pred sameEventShapeDifferentCorrectionRole {
  some disj a, b, replacement: Event |
    a.payload = b.payload and
    a.baseTime = b.baseTime and
    some c: EventCorrection |
      c.target = a and
      c.replacement = replacement and
      no c2: EventCorrection | c2.target = b
}

pred sameEffectCoordinatesDifferentProvenanceRole {
  some e: Event, disj a, b: Effect |
    a.owner = e and
    b.owner = e and
    a.locus = b.locus and
    a.amount = b.amount and
    some p: ProvenanceUse |
      p.source = a and
      no p2: ProvenanceUse | p2.source = b
}

pred uncorrectedEventNeedsNoRevision {
  one Event
  no Revision
  no RootedHistory.replaces
  rootedAdmissible
  all e: Event | currentTimes[e] = e.baseTime
}

pred returnToOriginalDateWithOnDemandRevisions {
  one Event
  #Revision = 2
  some e: Event, disj first, second: Revision |
    first.forEvent = e and
    second.forEvent = e and
    e.baseTime = DayA and
    first.atTime = DayB and
    second.atTime = DayA and
    RootedHistory.replaces = e->first + first->second and
    rootedAdmissible and
    currentTimes[e] = DayA
}

-- If temporal nodes are identified only by their date value, returning from A
-- to B and later back to A necessarily becomes A -> B -> A, which is a cycle.
pred identityFreeReturnToOriginalDate {
  DayA->DayB in ValueHistory.replacesTime
  DayB->DayA in ValueHistory.replacesTime
  no iden & ^(ValueHistory.replacesTime)
}

pred siblingRootedCorrectionsRefused {
  one Event
  #Revision = 2
  some e: Event, disj left, right: Revision |
    left.forEvent = e and
    right.forEvent = e and
    e->left in RootedHistory.replaces and
    e->right in RootedHistory.replaces and
    not rootedAdmissible
}

assert RootedAdmissibleDeterminesOneCurrentTime {
  rootedAdmissible implies all e: Event | one currentTimes[e]
}

assert RootedNoCorrectionReturnsBaseTime {
  rootedAdmissible and no RootedHistory.replaces implies
    all e: Event | currentTimes[e] = e.baseTime
}

run sameEventShapeDifferentCorrectionRole for 6 but exactly 3 Event, exactly 1 EventCorrection, exactly 1 Payload
run sameEffectCoordinatesDifferentProvenanceRole for 6 but exactly 1 Event, exactly 2 Effect, exactly 1 ProvenanceUse, exactly 1 Locus, exactly 1 Amount
run uncorrectedEventNeedsNoRevision for 6 but exactly 1 Event, exactly 0 Revision, exactly 1 Payload
run returnToOriginalDateWithOnDemandRevisions for 6 but exactly 1 Event, exactly 2 Revision, exactly 1 Payload
run identityFreeReturnToOriginalDate for 6
run siblingRootedCorrectionsRefused for 6 but exactly 1 Event, exactly 2 Revision, exactly 1 Payload
check RootedAdmissibleDeterminesOneCurrentTime for 6
check RootedNoCorrectionReturnsBaseTime for 6
