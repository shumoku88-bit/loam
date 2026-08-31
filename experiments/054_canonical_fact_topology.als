module experiments/observation_054_canonical_fact_topology

open util/ordering[Slot] as slots

abstract sig Fact {}

sig Event extends Fact {}

sig Correction extends Fact {
  target: one Event,
  replacement: one Event
}

sig Resolution extends Fact {
  parents: some Event,
  replacement: one Event
}

sig Slot {}

abstract sig UnifiedImage {
  members: set Fact,
  placed: Slot -> lone Fact
}

one sig Left, Right extends UnifiedImage {}

one sig SplitImage {
  events: set Event,
  corrections: set Correction,
  resolutions: set Resolution
}

fact NondegenerateRelations {
  all c: Correction | c.target != c.replacement
  all r: Resolution | r.replacement not in r.parents
}

fact PlacementRepresentsMembership {
  all i: UnifiedImage | {
    i.members = Slot.(i.placed)
    all f: i.members | one (i.placed).f
  }
}

fun splitFacts: set Fact {
  SplitImage.events + SplitImage.corrections + SplitImage.resolutions
}

pred representationsAgree[i: UnifiedImage] {
  i.members = splitFacts
}

pred unifiedClosed[i: UnifiedImage] {
  all c: Correction & i.members |
    c.target + c.replacement in i.members & Event

  all r: Resolution & i.members |
    r.parents + r.replacement in i.members & Event
}

pred splitClosed {
  all c: SplitImage.corrections |
    c.target + c.replacement in SplitImage.events

  all r: SplitImage.resolutions |
    r.parents + r.replacement in SplitImage.events
}

fun correctionCandidatesUnified[i: UnifiedImage, tip: Event]: set Event {
  { candidate: Event |
    some c: Correction & i.members |
      c.target = tip and c.replacement = candidate
  }
}

fun correctionCandidatesSplit[tip: Event]: set Event {
  { candidate: Event |
    some c: SplitImage.corrections |
      c.target = tip and c.replacement = candidate
  }
}

pred equivalentClosedRepresentations {
  SplitImage.events = Event
  SplitImage.corrections = Correction
  SplitImage.resolutions = Resolution
  representationsAgree[Left]
  unifiedClosed[Left]
  splitClosed
}

assert TypedPartitionEquivalent {
  representationsAgree[Left] implies {
    Left.members & Event = SplitImage.events
    Left.members & Correction = SplitImage.corrections
    Left.members & Resolution = SplitImage.resolutions
  }
}

assert ClosureEquivalent {
  representationsAgree[Left] implies
    (unifiedClosed[Left] iff splitClosed)
}

assert CorrectionCandidatesEquivalent {
  representationsAgree[Left] implies
    all tip: Event |
      correctionCandidatesUnified[Left, tip] = correctionCandidatesSplit[tip]
}

pred sameFactsDifferentGlobalOrder {
  SplitImage.events = Event
  SplitImage.corrections = Correction
  SplitImage.resolutions = Resolution
  representationsAgree[Left]
  representationsAgree[Right]
  Left.placed != Right.placed
}

pred sameFactsCanChangeFirstKind {
  sameFactsDifferentGlobalOrder
  some (slots/first.(Left.placed) & Correction)
  some (slots/first.(Right.placed) & Event)
}

assert SplitFactsDetermineGlobalOrder {
  (representationsAgree[Left] and representationsAgree[Right]) implies
    Left.placed = Right.placed
}

run equivalentClosedRepresentations for exactly 3 Event, exactly 1 Correction, exactly 1 Resolution, exactly 5 Slot
check TypedPartitionEquivalent for exactly 3 Event, exactly 1 Correction, exactly 1 Resolution, exactly 5 Slot
check ClosureEquivalent for exactly 3 Event, exactly 1 Correction, exactly 1 Resolution, exactly 5 Slot
check CorrectionCandidatesEquivalent for exactly 3 Event, exactly 1 Correction, exactly 1 Resolution, exactly 5 Slot
run sameFactsDifferentGlobalOrder for exactly 3 Event, exactly 1 Correction, exactly 1 Resolution, exactly 5 Slot
run sameFactsCanChangeFirstKind for exactly 3 Event, exactly 1 Correction, exactly 1 Resolution, exactly 5 Slot
check SplitFactsDetermineGlobalOrder for exactly 3 Event, exactly 1 Correction, exactly 1 Resolution, exactly 5 Slot
