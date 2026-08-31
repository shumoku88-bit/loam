module experiments/observation_073_descriptive_context_attachment

abstract sig Event {}
one sig Purchase extends Event {}

abstract sig Effect {
  event: one Event
}
one sig FirstEffect, SecondEffect extends Effect {}

abstract sig Context {}
one sig WholeContext, FirstContext, SecondContext extends Context {}

abstract sig World {
  eventContext: Event -> lone Context,
  effectContext: Effect -> lone Context
}
one sig Left, Right extends World {}

fact RepresentativePhysicalShape {
  FirstEffect.event = Purchase
  SecondEffect.event = Purchase
}

pred uniformWithEvent[w: World] {
  all e: Effect |
    e.(w.effectContext) = e.event.(w.eventContext)
}

pred representativeSplitAttachment {
  Purchase.(Left.eventContext) = WholeContext
  FirstEffect.(Left.effectContext) = FirstContext
  SecondEffect.(Left.effectContext) = SecondContext
}

pred sameEventContextDifferentEffectContext {
  Left.eventContext = Right.eventContext
  Left.effectContext != Right.effectContext
}

pred sameEffectContextDifferentEventContext {
  Left.effectContext = Right.effectContext
  Left.eventContext != Right.eventContext
}

pred splitEffectsNeedNotShareContext {
  some w: World | {
    some FirstEffect.(w.effectContext)
    some SecondEffect.(w.effectContext)
    FirstEffect.(w.effectContext) != SecondEffect.(w.effectContext)
  }
}

pred eventAndEffectCanDisagree {
  some w: World, e: Effect |
    e.(w.effectContext) != e.event.(w.eventContext)
}

pred uniformConformanceAllowsCompression {
  Left.eventContext = Right.eventContext
  uniformWithEvent[Left]
  uniformWithEvent[Right]
  some Purchase.(Left.eventContext)
}

assert PhysicalShapeDeterminesContext {
  Left.eventContext = Right.eventContext
  Left.effectContext = Right.effectContext
}

assert EventContextDeterminesEffectContext {
  Left.eventContext = Right.eventContext implies
    Left.effectContext = Right.effectContext
}

assert EffectContextDeterminesEventContext {
  Left.effectContext = Right.effectContext implies
    Left.eventContext = Right.eventContext
}

assert UniformConformanceMakesEventContextSufficient {
  Left.eventContext = Right.eventContext and
  uniformWithEvent[Left] and
  uniformWithEvent[Right] implies
    Left.effectContext = Right.effectContext
}

assert SplitContextCannotConformToSingleEventContext {
  all w: World |
    (some FirstEffect.(w.effectContext) and
     some SecondEffect.(w.effectContext) and
     FirstEffect.(w.effectContext) != SecondEffect.(w.effectContext)) implies
      not uniformWithEvent[w]
}

run representativeSplitAttachment for exactly 1 Event, exactly 2 Effect, exactly 3 Context, exactly 2 World
run sameEventContextDifferentEffectContext for exactly 1 Event, exactly 2 Effect, exactly 3 Context, exactly 2 World
run sameEffectContextDifferentEventContext for exactly 1 Event, exactly 2 Effect, exactly 3 Context, exactly 2 World
run splitEffectsNeedNotShareContext for exactly 1 Event, exactly 2 Effect, exactly 3 Context, exactly 2 World
run eventAndEffectCanDisagree for exactly 1 Event, exactly 2 Effect, exactly 3 Context, exactly 2 World
run uniformConformanceAllowsCompression for exactly 1 Event, exactly 2 Effect, exactly 3 Context, exactly 2 World
check PhysicalShapeDeterminesContext for exactly 1 Event, exactly 2 Effect, exactly 3 Context, exactly 2 World
check EventContextDeterminesEffectContext for exactly 1 Event, exactly 2 Effect, exactly 3 Context, exactly 2 World
check EffectContextDeterminesEventContext for exactly 1 Event, exactly 2 Effect, exactly 3 Context, exactly 2 World
check UniformConformanceMakesEventContextSufficient for exactly 1 Event, exactly 2 Effect, exactly 3 Context, exactly 2 World
check SplitContextCannotConformToSingleEventContext for exactly 1 Event, exactly 2 Effect, exactly 3 Context, exactly 2 World
