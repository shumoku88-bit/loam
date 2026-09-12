module experiments/normalized_actual_writer_topology

sig Event {}
sig Coordinate {}
sig EffectKey {}

// Semantic multiplicity inside one immutable Actual generation. There is no
// canonical ordinal or globally durable identity for an ordinary Effect.
sig EffectOccurrence {
  owner: one Event,
  coordinate: one Coordinate
}

sig Relation {
  source: one EffectOccurrence
}

// One complete immutable Actual generation. Actual distinctions that must switch
// together live behind this one selected generation.
sig ActualGeneration {
  events: set Event,
  effects: set EffectOccurrence,
  keyOf: EffectOccurrence -> lone EffectKey,
  relations: set Relation,
  correction: Event -> lone Event,
  reversal: Event -> lone Event
}

pred closed[g: ActualGeneration] {
  g.effects.owner in g.events
  g.relations.source in g.effects

  all relation: g.relations |
    one g.keyOf[relation.source]

  all ownerEvent: Event, key: EffectKey |
    lone { effect: g.effects |
      effect.owner = ownerEvent and key in g.keyOf[effect]
    }

  all target, replacement: Event |
    target->replacement in g.correction implies
      target in g.events and replacement in g.events

  all replacement: Event |
    lone { target: Event | target->replacement in g.correction }

  all target, inverse: Event |
    target->inverse in g.reversal implies
      target in g.events and inverse in g.events

  all inverse: Event |
    lone { target: Event | target->inverse in g.reversal }
}

fact EveryActualGenerationIsClosed {
  all generation: ActualGeneration | closed[generation]
}

// Locus admission policy and Scheduled lifecycle remain independent authorities.
sig PolicyGeneration {}
sig ScheduledGeneration {}

sig Snapshot {
  actual: one ActualGeneration,
  policy: one PolicyGeneration,
  scheduled: one ScheduledGeneration
}

// Current production has four semantic Actual write entrances. Relation creation
// and Relation discharge are optional evidence inside MovementWrite.
abstract sig WriteKind {}
one sig MovementWrite extends WriteKind {}
one sig DateRevisionWrite extends WriteKind {}
one sig CorrectionWrite extends WriteKind {}
one sig ReversalWrite extends WriteKind {}

sig Write {
  kind: one WriteKind,
  pre: one Snapshot,
  post: one Snapshot,
  candidate: one ActualGeneration,
  policyRead: lone PolicyGeneration,
  scheduledRead: lone ScheduledGeneration
}

pred needsPolicy[kind: WriteKind] {
  kind in MovementWrite + CorrectionWrite + ReversalWrite
}

pred needsScheduled[kind: WriteKind] {
  kind = ReversalWrite
}

pred dependenciesRead[w: Write] {
  needsPolicy[w.kind] implies w.policyRead = w.pre.policy
  not needsPolicy[w.kind] implies no w.policyRead

  needsScheduled[w.kind] implies w.scheduledRead = w.pre.scheduled
  not needsScheduled[w.kind] implies no w.scheduledRead
}

// One Actual generation switch. Dependencies must remain at the version read by
// admission, but unrelated authorities may advance independently.
pred guardedCommit[w: Write] {
  dependenciesRead[w]
  w.post.actual = w.candidate

  needsPolicy[w.kind] implies
    w.post.policy = w.pre.policy

  needsScheduled[w.kind] implies
    w.post.scheduled = w.pre.scheduled
}

// Positive race witnesses. They should be SAT unless the corresponding dependency
// is kept stable between admission and Actual selection.
pred unguardedPolicyRace {
  some w: Write | {
    needsPolicy[w.kind]
    dependenciesRead[w]
    w.post.actual = w.candidate
    w.post.policy != w.pre.policy
  }
}

pred unguardedScheduledRace {
  some w: Write | {
    w.kind = ReversalWrite
    dependenciesRead[w]
    w.post.actual = w.candidate
    w.post.scheduled != w.pre.scheduled
  }
}

// Independence witnesses. Atomic Actual publication does not require unrelated
// authorities to share the same generation or change boundary.
pred dateRevisionWhilePolicyAdvances {
  some w: Write | {
    w.kind = DateRevisionWrite
    guardedCommit[w]
    w.post.policy != w.pre.policy
  }
}

pred movementWhileScheduledAdvances {
  some w: Write | {
    w.kind = MovementWrite
    guardedCommit[w]
    w.post.scheduled != w.pre.scheduled
  }
}

assert GuardedPolicyDependencyCannotRace {
  all w: Write |
    guardedCommit[w] and needsPolicy[w.kind] implies
      w.post.policy = w.policyRead
}

assert GuardedScheduledDependencyCannotRace {
  all w: Write |
    guardedCommit[w] and needsScheduled[w.kind] implies
      w.post.scheduled = w.scheduledRead
}

assert GuardedCommitSelectsOneClosedActualGeneration {
  all w: Write |
    guardedCommit[w] implies closed[w.post.actual]
}

// --- Optional future extension: attach Relation after original Movement. ---
// Current production does not need this capability for migration. A command-local
// generation-bound locator can nevertheless promote one keyless Effect later
// without persisting ordinal identity.
sig Locator {
  generation: one ActualGeneration,
  effect: one EffectOccurrence
}

pred locatorResolves[l: Locator, snapshot: Snapshot] {
  snapshot.actual = l.generation
  l.effect in snapshot.actual.effects
}

assert StaleLocatorCannotResolveAgainstAnotherGeneration {
  all l: Locator, snapshot: Snapshot |
    snapshot.actual != l.generation implies
      not locatorResolves[l, snapshot]
}

pred promoteForRelation[
    old, new: ActualGeneration,
    locator: Locator,
    key: EffectKey,
    relation: Relation] {
  locator.generation = old
  locator.effect in old.effects
  no old.keyOf[locator.effect]
  relation not in old.relations
  relation.source = locator.effect

  new.events = old.events
  new.effects = old.effects
  new.correction = old.correction
  new.reversal = old.reversal
  new.relations = old.relations + relation
  new.keyOf = old.keyOf + locator.effect->key
}

// Same owner and coordinate, two distinct occurrences. Coordinate alone cannot
// select the source, yet a generation-bound locator can promote exactly one.
pred duplicateCoordinatePromotion {
  some disj chosen, twin: EffectOccurrence,
       old, new: ActualGeneration,
       locator: Locator,
       key: EffectKey,
       relation: Relation | {
    chosen in old.effects
    twin in old.effects
    chosen.owner = twin.owner
    chosen.coordinate = twin.coordinate
    locator.generation = old
    locator.effect = chosen
    no old.keyOf[chosen]
    no old.keyOf[twin]
    promoteForRelation[old, new, locator, key, relation]
  }
}

pred staleLocatorWitness {
  some locator: Locator, snapshot: Snapshot | {
    locator.effect in locator.generation.effects
    snapshot.actual != locator.generation
    not locatorResolves[locator, snapshot]
  }
}

assert PromotionChangesOnlyChosenEffectIdentity {
  all old, new: ActualGeneration,
      locator: Locator,
      key: EffectKey,
      relation: Relation |
    promoteForRelation[old, new, locator, key, relation] implies {
      new.keyOf[locator.effect] = key
      all other: old.effects - locator.effect |
        new.keyOf[other] = old.keyOf[other]
    }
}

assert RelationSourceIsStableAfterPromotion {
  all old, new: ActualGeneration,
      locator: Locator,
      key: EffectKey,
      relation: Relation |
    promoteForRelation[old, new, locator, key, relation] implies {
      relation in new.relations
      relation.source = locator.effect
      key in new.keyOf[relation.source]
    }
}

// Keep each bounded search deliberately small. These are local topology laws,
// not a census of unrelated Write/Snapshot atoms.
run unguardedPolicyRace for 5 but exactly 2 PolicyGeneration, exactly 1 ScheduledGeneration
run unguardedScheduledRace for 5 but exactly 1 PolicyGeneration, exactly 2 ScheduledGeneration
run dateRevisionWhilePolicyAdvances for 5 but exactly 2 PolicyGeneration
run movementWhileScheduledAdvances for 5 but exactly 2 ScheduledGeneration
run duplicateCoordinatePromotion for 5 but exactly 2 Event, exactly 2 EffectOccurrence, exactly 1 Coordinate, exactly 2 ActualGeneration, exactly 1 EffectKey, exactly 1 Relation, exactly 1 Locator
run staleLocatorWitness for 5 but exactly 2 ActualGeneration, exactly 1 Locator, exactly 1 Snapshot

check GuardedPolicyDependencyCannotRace for 5
check GuardedScheduledDependencyCannotRace for 5
check GuardedCommitSelectsOneClosedActualGeneration for 5
check StaleLocatorCannotResolveAgainstAnotherGeneration for 5
check PromotionChangesOnlyChosenEffectIdentity for 5
check RelationSourceIsStableAfterPromotion for 5
