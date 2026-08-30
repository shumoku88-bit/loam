module model/observation_030_generic_event_core

sig Purpose {}

abstract sig Kind {}
one sig PhysicalTag, IntentTag, RevisionTag, OtherTag extends Kind {}

sig Event {}

abstract sig World {
  present: set Event,
  delta: Event -> lone Int,
  purpose: Event -> lone Purpose,
  parent: Event -> set Event,
  tag: Event -> lone Kind
}

one sig Left, Right extends World {}

fact WellFormed {
  all w: World | {
    w.delta.Int in w.present
    w.purpose.Purpose in w.present
    w.parent in w.present -> w.present
    w.tag.Kind in w.present

    all e: w.present | {
      one e.(w.delta)
      one e.(w.tag)
    }

    no iden & ^(w.parent)
  }
}

fun superseded[w: World]: set Event {
  w.present.(w.parent)
}

fun tips[w: World]: set Event {
  w.present - superseded[w]
}

fun balance[w: World]: one Int {
  sum e: tips[w] | e.(w.delta)
}

fun commitments[w: World]: set Purpose {
  tips[w].(w.purpose)
}

fun explanation[w: World]: set Event {
  tips[w].*(w.parent)
}

fun physicalEvents[w: World]: set Event {
  { e: w.present | e.(w.delta) != 0 }
}

fun intentionalEvents[w: World]: set Event {
  { e: w.present | some e.(w.purpose) }
}

fun revisionEvents[w: World]: set Event {
  { e: w.present | some e.(w.parent) }
}

fun withdrawalEvents[w: World]: set Event {
  { e: revisionEvents[w] |
      e.(w.delta) = 0 and no e.(w.purpose) }
}

fun resolutionEvents[w: World]: set Event {
  { e: w.present | #e.(w.parent) > 1 }
}

pred sameGenericCore[a, b: World] {
  a.present = b.present
  a.delta = b.delta
  a.purpose = b.purpose
  a.parent = b.parent
}

pred sameSelectedAnswers[a, b: World] {
  balance[a] = balance[b]
  commitments[a] = commitments[b]
  explanation[a] = explanation[b]
}

pred genericCoreExpressesHouseholdRoles {
  #Left.present >= 6

  some physicalEvents[Left]
  some intentionalEvents[Left]
  some revisionEvents[Left]
  some withdrawalEvents[Left]
  some resolutionEvents[Left]

  balance[Left] != 0
  some commitments[Left]
  some e: tips[Left] | some e.(Left.parent)
}

pred differentNominalKindsSameCoreSameAnswers {
  sameGenericCore[Left, Right]
  Left.tag != Right.tag
  sameSelectedAnswers[Left, Right]
}

pred forgettingDeltaCanLoseBalance {
  Left.present = Right.present
  Left.purpose = Right.purpose
  Left.parent = Right.parent
  Left.tag = Right.tag

  Left.delta != Right.delta
  balance[Left] != balance[Right]
}

pred forgettingPurposeCanLoseCommitment {
  Left.present = Right.present
  Left.delta = Right.delta
  Left.parent = Right.parent
  Left.tag = Right.tag

  Left.purpose != Right.purpose
  commitments[Left] != commitments[Right]
}

pred forgettingParentCanLoseCurrentMeaning {
  Left.present = Right.present
  Left.delta = Right.delta
  Left.purpose = Right.purpose
  Left.tag = Right.tag

  Left.parent != Right.parent
  balance[Left] != balance[Right] or
  commitments[Left] != commitments[Right]
}

pred forgettingParentCanLoseExplanationOnly {
  Left.present = Right.present
  Left.delta = Right.delta
  Left.purpose = Right.purpose
  Left.tag = Right.tag

  Left.parent != Right.parent
  balance[Left] = balance[Right]
  commitments[Left] = commitments[Right]
  explanation[Left] != explanation[Right]
}

assert GenericCoreDeterminesSelectedVocabulary {
  sameGenericCore[Left, Right] implies
    sameSelectedAnswers[Left, Right]
}

run genericCoreExpressesHouseholdRoles for exactly 6 Event, exactly 2 Purpose, exactly 4 Kind, exactly 2 World, 5 Int
run differentNominalKindsSameCoreSameAnswers for exactly 6 Event, exactly 2 Purpose, exactly 4 Kind, exactly 2 World, 5 Int
run forgettingDeltaCanLoseBalance for exactly 6 Event, exactly 2 Purpose, exactly 4 Kind, exactly 2 World, 5 Int
run forgettingPurposeCanLoseCommitment for exactly 6 Event, exactly 2 Purpose, exactly 4 Kind, exactly 2 World, 5 Int
run forgettingParentCanLoseCurrentMeaning for exactly 6 Event, exactly 2 Purpose, exactly 4 Kind, exactly 2 World, 5 Int
run forgettingParentCanLoseExplanationOnly for exactly 6 Event, exactly 2 Purpose, exactly 4 Kind, exactly 2 World, 5 Int
check GenericCoreDeterminesSelectedVocabulary for exactly 6 Event, exactly 2 Purpose, exactly 4 Kind, exactly 2 World, 5 Int
