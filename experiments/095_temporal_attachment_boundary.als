module experiments/observation_095_temporal_attachment_boundary

abstract sig Payload {}
one sig P0, P1 extends Payload {}

abstract sig Event {
  payload : one Payload
}
one sig E0, E1 extends Event {}

abstract sig Day {}
one sig D0, D1 extends Day {}

one sig EmbeddedStore {
  embeddedDay : Event -> lone Day
}

abstract sig TemporalFact {
  target : one Event,
  day : one Day
}
one sig ExistingFact, NewFact extends TemporalFact {}

abstract sig AttachedStore {
  facts : set TemporalFact
}
one sig Unknown, Learned, Equivalent extends AttachedStore {}

fact StableEventCore {
  E0.payload = P0
  E1.payload = P1
}

fact FactShape {
  ExistingFact.target = E1
  ExistingFact.day = D1
  NewFact.target = E0
  NewFact.day = D0
}

fact AttachmentUniqueness {
  all s : AttachedStore, e : Event |
    lone { f : s.facts | f.target = e }
}

fact LearningStepShape {
  Unknown.facts = ExistingFact
  Learned.facts = ExistingFact + NewFact
}

fun attachedDay[s : AttachedStore] : Event -> Day {
  { e : Event, d : Day |
    some f : s.facts | f.target = e and f.day = d }
}

fun embeddedMembers[d : Day] : set Event {
  { e : Event | e->d in EmbeddedStore.embeddedDay }
}

fun attachedMembers[s : AttachedStore, d : Day] : set Event {
  { e : Event | e->d in attachedDay[s] }
}

pred equivalentEncodingWitness {
  Equivalent.facts = ExistingFact + NewFact
  EmbeddedStore.embeddedDay = attachedDay[Equivalent]
  some EmbeddedStore.embeddedDay
}

pred lateTemporalLearningWitness {
  Unknown.facts in Learned.facts
  no E0.(attachedDay[Unknown])
  E0->D0 in attachedDay[Learned]
  E1.(attachedDay[Unknown]) = E1.(attachedDay[Learned])
}

pred sameCoreDifferentTemporalAnswer {
  attachedDay[Unknown] != attachedDay[Learned]
}

pred unknownTimeRetainsEventWitness {
  some Event
  no E0.(attachedDay[Unknown])
  E0.payload = P0
}

assert EqualTemporalRelationGivesEqualDayProjection {
  all s : AttachedStore |
    attachedDay[s] = EmbeddedStore.embeddedDay implies
      all d : Day |
        attachedMembers[s, d] = embeddedMembers[d]
}

assert AttachmentPreservesKnownTemporalAnswers {
  all e : Event |
    some e.(attachedDay[Unknown]) implies
      e.(attachedDay[Unknown]) = e.(attachedDay[Learned])
}

assert EventCoreDeterminesTemporalAnswer {
  all disj s1, s2 : AttachedStore |
    attachedDay[s1] = attachedDay[s2]
}

assert MissingAttachmentInventsNoDay {
  no E0.(attachedDay[Unknown])
}

run equivalentEncodingWitness
run lateTemporalLearningWitness
run sameCoreDifferentTemporalAnswer
run unknownTimeRetainsEventWitness
check EqualTemporalRelationGivesEqualDayProjection
check AttachmentPreservesKnownTemporalAnswers
check EventCoreDeterminesTemporalAnswer
check MissingAttachmentInventsNoDay
