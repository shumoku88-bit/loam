module experiments/observation_125_provider_key_continuity

abstract sig ProviderKey {}
one sig PendingKey, PostedKey extends ProviderKey {}

abstract sig Stage {}
one sig PendingStage, PostedStage extends Stage {}

abstract sig SourceShape {}
one sig SharedShape extends SourceShape {}

abstract sig Observation {
  key: one ProviderKey,
  stage: one Stage,
  shape: one SourceShape
}
one sig PendingObs, PostedObs extends Observation {}

abstract sig World {
  continuation: Observation -> lone Observation
}
one sig Left, Right extends World {}

fact FixedSourceEvidence {
  PendingObs.key = PendingKey
  PendingObs.stage = PendingStage
  PendingObs.shape = SharedShape

  PostedObs.key = PostedKey
  PostedObs.stage = PostedStage
  PostedObs.shape = SharedShape
}

fact ContinuityShape {
  all w: World |
    w.continuation in PendingObs -> PostedObs
}

fun lifecycleStarts[w: World]: set Observation {
  Observation - Observation.(w.continuation)
}

pred linkedAcrossProviderKeyChange {
  PendingObs -> PostedObs in Left.continuation
  PendingObs.key != PostedObs.key
  #lifecycleStarts[Left] = 1
}

pred sameSourceEvidenceDifferentContinuity {
  PendingObs -> PostedObs in Left.continuation
  no Right.continuation
  #lifecycleStarts[Left] = 1
  #lifecycleStarts[Right] = 2
}

pred providerKeyWouldSplitLinkedLifecycle {
  PendingObs.key != PostedObs.key
  PendingObs -> PostedObs in Left.continuation
}

assert DifferentProviderKeysImplyDifferentLifecycles {
  all w: World |
    PendingObs.key != PostedObs.key implies
      PendingObs -> PostedObs not in w.continuation
}

assert ProviderFactsDetermineContinuity {
  all w1, w2: World |
    w1.continuation = w2.continuation
}

assert ProviderFactsDetermineLifecycleCount {
  all w1, w2: World |
    #lifecycleStarts[w1] = #lifecycleStarts[w2]
}

assert ExplicitContinuityDeterminesLifecycleCount {
  all w1, w2: World |
    w1.continuation = w2.continuation implies
      #lifecycleStarts[w1] = #lifecycleStarts[w2]
}

run linkedAcrossProviderKeyChange for 4 Int
run sameSourceEvidenceDifferentContinuity for 4 Int
run providerKeyWouldSplitLinkedLifecycle for 4 Int
check DifferentProviderKeysImplyDifferentLifecycles for 4 Int
check ProviderFactsDetermineContinuity for 4 Int
check ProviderFactsDetermineLifecycleCount for 4 Int
check ExplicitContinuityDeterminesLifecycleCount for 4 Int
