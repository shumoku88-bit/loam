module experiments/normalized_actual_writer_topology

sig Event {}
sig Coordinate {}
sig EffectKey {}

// EffectOccurrence is semantic multiplicity inside one immutable Actual generation.
// It deliberately has no canonical ordinal or globally durable identity.
sig EffectOccurrence {
  event: one Event,
  coordinate: one Coordinate
}

sig Relation {
  source: one EffectOccurrence
}

// One complete immutable Actual generation. All Actual distinctions that must
// switch together live behind this single selected generation.
sig ActualGeneration {
  events: set Event,
  effects: set EffectOccurrence,
  keyOf: EffectOccurrence -> lone EffectKey,
  relations: set Relation,
  correction: Event -> lone Event,
  reversal: Event -> lone Event
}

pred closed[g: ActualGeneration] {
  g.effects.event in g.events
  g.relations.source in g.effects

  all relation: g.relations |
    one g.keyOf[relation.source]

  all event: Event, key: EffectKey |
    lone { effect: g.effects |
      effect.event = event and key in g.keyOf[effect]
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
// Actual publication may depend on their selected versions without physically
// merging them into the Actual generation.
sig PolicyGeneration {}
sig ScheduledGeneration {}

sig Snapshot {
  actual: one ActualGeneration,
  policy: one PolicyGeneration,
  scheduled: one ScheduledGeneration
}

// Current production has four semantic Actual write entrances. Relation creation
// and Relation discharge are optional evidence inside MovementWrite, not separate
// writers. Keeping that distinction here prevents a future convenience feature
// from being mistaken for a migration requirement.
abstract sig WriteKind {}
one sig MovementWrite extends WriteKind {}
one sig DateRevisionWrite extends WriteKind {}
one sig CorrectionWrite extends WriteKind {}
one sig ReversalWrite extends WriteKind {}

sig Write {
  kind: one WriteKind,
  before: one Snapshot,
  after: one Snapshot,
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

// Admission records only the external authority versions whose meaning is needed
// by this operation. Date revision needs neither external authority. Movement,
// Correction and Reversal all create quantity-bearing Effects and therefore read
// current Locus policy; Reversal additionally reads Scheduled lifecycle.
pred dependenciesRead[w: Write] {
  needsPolicy[w.kind] implies w.policyRead = w.before.policy
  not needsPolicy[w.kind] implies no w.policyRead

  needsScheduled[w.kind] implies w.scheduledRead = w.before.scheduled
  not needsScheduled[w.kind] implies no w.scheduledRead
}

// A guarded Actual commit switches only the one complete Actual generation.
// External authorities are required to remain at the versions read by admission
// only when the operation semantically depends on them. Unneeded authorities may
// advance independently and are not dragged into the Actual publication unit.
pred guardedCommit[w: Write] {
  dependenciesRead[w]
  w.after.actual = w.candidate

  needsPolicy[w.kind] implies
    w.after.policy = w.before.policy

  needsScheduled[w.kind] implies
    w.after.scheduled = w.before.scheduled
}

// Without keeping Policy stable between admission and commit, a Movement,
// Correction or Reversal can be admitted under one vocabulary and selected after
// another policy has become current. Keep this SAT as pressure for a lock or
// compare-and-switch precondition rather than merging Policy into Actual.
pred unguardedPolicyRace {
  some w: Write | {
    needsPolicy[w.kind]
    dependenciesRead[w]
    w.after.actual = w.candidate
    w.after.policy != w.before.policy
  }
}

// Reversal additionally depends on Scheduled lifecycle, so the same race exists
// if Scheduled changes after admission and before Actual selection.
pred unguardedScheduledRace {
  some w: Write | {
    w.kind = ReversalWrite
    dependenciesRead[w]
    w.after.actual = w.candidate
    w.after.scheduled != w.before.scheduled
  }
}

// Date correction is independent of Locus policy. This witness demonstrates that
// keeping Actual atomic does not require co-publishing unrelated Policy state.
pred dateRevisionWhilePolicyAdvances {
  some w: Write | {
    w.kind = DateRevisionWrite
    guardedCommit[w]
    w.after.policy != w.before.policy
  }
}

// Ordinary Movement depends on Policy but not Scheduled lifecycle. Scheduled may
// therefore advance independently while the exact Policy version remains stable.
pred movementWhileScheduledAdvances {
  some w: Write | {
    w.kind = MovementWrite
    guardedCommit[w]
    w.after.scheduled != w.before.scheduled
  }
}

assert GuardedPolicyDependencyCannotRace {
  all w: Write |
    guardedCommit[w] and needsPolicy[w.kind] implies
      w.after.policy = w.policyRead
}

assert GuardedScheduledDependencyCannotRace {
  all w: Write |
    guardedCommit[w] and needsScheduled[w.kind] implies
      w.after.scheduled = w.scheduledRead
}

assert GuardedCommitSelectsOneClosedActualGeneration {
  all w: Write |
    guardedCommit[w] implies closed[w.after.actual]
}

// --- Optional future extension: later Relation attachment. ---
//
// Current production creates Relation evidence only inside MovementWrite, so the
// migration does not need this capability. It is modeled separately to show how a
// future editor could promote one historically-keyless Effect without making an
// ordinal or compatibility EffectKey part of canonical identity.

// A Locator is command-local capability, not canonical Actual data. In an
// implementation it can be represented by selected-generation digest plus an
// occurrence locator. Its generation precondition prevents silent retargeting.
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

// Promote exactly one previously-keyless occurrence while attaching the first
// retained Relation that needs to name it. The ephemeral Locator is consumed by
// the transition; only the new stable EffectKey and Relation survive canonically.
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

// Positive pressure: two effects can have identical event/coordinate payload yet
// a generation-bound locator can promote exactly one occurrence. Coordinate alone
// would be insufficient to choose between them.
pred duplicateCoordinatePromotion {
  some disj chosen, twin: EffectOccurrence,
       old, new: ActualGeneration,
       locator: Locator,
       key: EffectKey,
       relation: Relation | {
    chosen in old.effects
    twin in old.effects
    chosen.event = twin.event
    chosen.coordinate = twin.coordinate
    locator.generation = old
    locator.effect = chosen
    no old.keyOf[chosen]
    no old.keyOf[twin]
    promoteForRelation[old, new, locator, key, relation]
  }
}

// A stale command can exist after CURRENT changes, but must fail the resolver
// rather than reinterpret its occurrence locator in the newly selected bytes.
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

run unguardedPolicyRace for 10 but exactly 2 PolicyGeneration, 1 ScheduledGeneration
run unguardedScheduledRace for 10 but exactly 1 PolicyGeneration, 2 ScheduledGeneration
run dateRevisionWhilePolicyAdvances for 10 but exactly 2 PolicyGeneration
run movementWhileScheduledAdvances for 10 but exactly 2 ScheduledGeneration
run duplicateCoordinatePromotion for 12 but exactly 2 Event, 2 EffectOccurrence, 1 Coordinate, 2 ActualGeneration, 1 EffectKey, 1 Relation, 1 Locator
run staleLocatorWitness for 10 but exactly 2 ActualGeneration, 1 Locator, 1 Snapshot

check GuardedPolicyDependencyCannotRace for 12
check GuardedScheduledDependencyCannotRace for 12
check GuardedCommitSelectsOneClosedActualGeneration for 12
check StaleLocatorCannotResolveAgainstAnotherGeneration for 12
check PromotionChangesOnlyChosenEffectIdentity for 12
check RelationSourceIsStableAfterPromotion for 12
