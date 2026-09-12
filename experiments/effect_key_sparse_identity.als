module experiments/effect_key_sparse_identity

sig Event {}
sig Payload {}
sig Key {}

// Effect atoms represent physical quantity effects. Payload deliberately erases
// effect identity so duplicate payloads are possible inside one Event.
sig Effect {
  event: one Event,
  payload: one Payload
}

// Stable keys are optional until a world retains an independently referable
// source. A retained relation stores only the public (Event, Key) coordinate.
sig World {
  keyOf: Effect -> lone Key,
  relationEvent: lone Event,
  relationKey: lone Key
}

fact ScopedStableKeys {
  all w: World, disj left, right: Effect |
    left.event = right.event and
    some w.keyOf[left] and some w.keyOf[right]
    implies w.keyOf[left] != w.keyOf[right]
}

fact RelationCoordinateShape {
  all w: World |
    (some w.relationEvent iff some w.relationKey)
}

fun resolved[w: World, e: Event, k: Key]: set Effect {
  { effect: Effect |
      effect.event = e and
      k in w.keyOf[effect]
  }
}

// A retained relation coordinate must identify exactly one Effect.
fact RetainedRelationResolves {
  all w: World |
    some w.relationEvent implies
      one resolved[w, w.relationEvent, w.relationKey]
}

// Ordinary Effects can exist without any stable key while there is no retained
// Effect-level overlay requiring independent reference.
pred unreferencedEffectsCanRemainKeyless {
  some w: World, e: Event, disj left, right: Effect | {
    left.event = e
    right.event = e
    no w.keyOf
    no w.relationEvent
    no w.relationKey
  }
}

// Stable identity can be introduced at the same semantic transition that first
// retains an Effect-level relation. Physical Effect/Event/Payload facts do not
// change; only identity/reference evidence is added.
pred relationCanIntroduceOneSparseKey {
  some disj before, after: World,
       source, other: Effect,
       k: Key | {
    source != other
    source.event = other.event

    no before.keyOf
    no before.relationEvent
    no before.relationKey

    after.keyOf = source->k
    after.relationEvent = source.event
    after.relationKey = k
    resolved[after, source.event, k] = source
  }
}

// Duplicate physical payload does not force eager identity. When two Effects
// are otherwise indistinguishable, either symmetry-breaking choice produces
// the same retained public relation coordinate and the same keyed payload.
pred duplicatePayloadCanGainSparseIdentity {
  some disj leftWorld, rightWorld: World,
       disj left, right: Effect,
       k: Key | {
    left.event = right.event
    left.payload = right.payload

    leftWorld.keyOf = left->k
    rightWorld.keyOf = right->k
    leftWorld.relationEvent = left.event
    rightWorld.relationEvent = right.event
    leftWorld.relationKey = k
    rightWorld.relationKey = k

    resolved[leftWorld, left.event, k] = left
    resolved[rightWorld, right.event, k] = right

    // What the retained relation can observe is equal even though Alloy can
    // still name the interchangeable atoms internally.
    left.event = right.event
    left.payload = right.payload
  }
}

// Positional reconstruction is a different design. Swapping representation
// order changes what slot 1 names, so a stored "first effect" reference is not
// invariant under the Event model's permitted permutation.
abstract sig Slot {}
one sig First, Second extends Slot {}

sig Layout {
  at: Slot -> lone Effect
}

pred positionalIdentityChangesUnderPermutation {
  some disj leftLayout, rightLayout: Layout,
       disj left, right: Effect | {
    left.event = right.event
    leftLayout.at = First->left + Second->right
    rightLayout.at = First->right + Second->left
    leftLayout.at[First] != rightLayout.at[First]
  }
}

// Optional stable keys retain the same minimum lookup law as today's eager
// EffectKey: Event + Key identifies at most one Effect.
assert EventAndSparseKeyIdentifyAtMostOneEffect {
  all w: World, e: Event, k: Key |
    lone resolved[w, e, k]
}

run unreferencedEffectsCanRemainKeyless for 6 but exactly 1 Event, 2 Effect, 2 Payload, 2 Key, 1 World
run relationCanIntroduceOneSparseKey for 7 but exactly 1 Event, 2 Effect, 2 Payload, 2 Key, 2 World
run duplicatePayloadCanGainSparseIdentity for 7 but exactly 1 Event, 2 Effect, 1 Payload, 1 Key, 2 World
run positionalIdentityChangesUnderPermutation for 7 but exactly 1 Event, 2 Effect, 2 Payload, 2 Slot, 2 Layout
check EventAndSparseKeyIdentifyAtMostOneEffect for 7 but exactly 2 Event, 4 Effect, 3 Payload, 3 Key, 3 World
