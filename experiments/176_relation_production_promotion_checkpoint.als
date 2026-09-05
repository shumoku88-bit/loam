module experiments/observation_176_relation_production_promotion_checkpoint

abstract sig Coverage {}
one sig Covered, Legacy extends Coverage {}

abstract sig SourceSign {}
one sig PositiveSource, NegativeSource extends SourceSign {}

sig Event {}
sig Key {}
sig Measure {}

sig Effect {
  sourceEvent: one Event,
  sourceKey: one Key,
  sourceMeasure: one Measure,
  sourceSign: one SourceSign,
  magnitude: one Int,
  coverage: one Coverage
}

fact EffectShape {
  all effect: Effect | {
    effect.magnitude > 0
    effect.magnitude <= 10
  }

  all disj firstEffect, secondEffect: Effect |
    firstEffect.sourceEvent = secondEffect.sourceEvent implies
      firstEffect.sourceKey != secondEffect.sourceKey
}

abstract sig Endpoint {}
one sig Household extends Endpoint {}
sig ExternalEndpoint extends Endpoint {}

// Observation 176 deliberately lets the raw retained relation shape carry an
// ordinary exact Int-like quantity. Positive-magnitude meaning is established
// only by semantic admission below. This tests whether a new generic positive
// quantity primitive is required merely for safe composition.
sig RelationUnit {
  source: one Effect,
  debtor: one Endpoint,
  creditor: one Endpoint,
  quantity: one Int
}

// One family-specific append-only revision. `replacement = none` is explicit
// retraction; a present replacement remains on the same source Effect.
sig RelationRevision {
  target: one RelationUnit,
  replacement: lone RelationUnit
}

// Exceptional whole-source negative authority. Routine covered known-none is
// still derived from qualified absence rather than one negative fact per Effect.
sig ExplicitNoneEvidence {
  source: one Effect
}

// A World is an observation-local retained snapshot. Raw relation units may be
// retained before their source Effect is available, just as existing LOAM raw
// relation streams may precede referential admission.
sig World {
  presentEffects: set Effect,
  relationUnits: set RelationUnit,
  revisions: set RelationRevision,
  explicitNone: set ExplicitNoneEvidence
}

fact RevisionAndNoneShape {
  all world: World | {
    world.revisions.target in world.relationUnits
    world.revisions.replacement in world.relationUnits

    all revision: world.revisions | {
      revision.replacement != revision.target
      some revision.replacement implies
        revision.replacement.source = revision.target.source
    }

    all unit: world.relationUnits |
      lone { revision: world.revisions | revision.target = unit }

    let edge = {
      oldUnit, newUnit: world.relationUnits |
        some revision: world.revisions |
          revision.target = oldUnit and
          revision.replacement = newUnit
    } |
      no iden & ^edge

    world.explicitNone.source in world.presentEffects
    all effect: world.presentEffects |
      lone { evidence: world.explicitNone | evidence.source = effect }
  }
}

pred semanticallyValid[world: World, unit: RelationUnit] {
  unit.source in world.presentEffects
  unit.quantity > 0
  unit.quantity <= unit.source.magnitude
  unit.debtor != unit.creditor

  (unit.debtor = Household and unit.creditor in ExternalEndpoint)
  or
  (unit.creditor = Household and unit.debtor in ExternalEndpoint)
}

fun currentRawUnits[world: World, effect: Effect]: set RelationUnit {
  { unit: world.relationUnits |
    unit.source = effect and
    no revision: world.revisions | revision.target = unit
  }
}

fun currentValidUnits[world: World, effect: Effect]: set RelationUnit {
  { unit: currentRawUnits[world, effect] |
    semanticallyValid[world, unit]
  }
}

fun currentInvalidUnits[world: World, effect: Effect]: set RelationUnit {
  currentRawUnits[world, effect] - currentValidUnits[world, effect]
}

fun explicitNoneFor[world: World, effect: Effect]: set ExplicitNoneEvidence {
  { evidence: world.explicitNone | evidence.source = effect }
}

// Fail-closed status projection. Malformed current raw evidence is not silently
// filtered into absence: it blocks both known-positive and known-none.
fun knownPositiveEffects[world: World]: set Effect {
  { effect: world.presentEffects |
    some currentValidUnits[world, effect] and
    no currentInvalidUnits[world, effect] and
    no explicitNoneFor[world, effect]
  }
}

fun knownNoneEffects[world: World]: set Effect {
  { effect: world.presentEffects |
    no currentRawUnits[world, effect] and
    (effect.coverage = Covered or some explicitNoneFor[world, effect])
  }
}

fun unknownEffects[world: World]: set Effect {
  { effect: world.presentEffects |
    no currentRawUnits[world, effect] and
    effect.coverage = Legacy and
    no explicitNoneFor[world, effect]
  }
}

fun unresolvedEffects[world: World]: set Effect {
  { effect: world.presentEffects |
    some currentInvalidUnits[world, effect]
    or
    (some currentRawUnits[world, effect] and
      some explicitNoneFor[world, effect])
  }
}

pred sharedCostPositiveAdmitted {
  some world: World,
       effect: Effect,
       friend: ExternalEndpoint,
       relation: RelationUnit | {
    world.presentEffects = effect
    world.relationUnits = relation
    no world.revisions
    no world.explicitNone

    effect.sourceSign = NegativeSource
    effect.magnitude = 10
    relation.source = effect
    relation.debtor = friend
    relation.creditor = Household
    relation.quantity = 4

    relation in currentValidUnits[world, effect]
    effect in knownPositiveEffects[world]
  }
}

// Relation identity is not reducible to source/endpoints/quantity.
pred equalShapeDistinctRelationUnits {
  some world: World,
       effect: Effect,
       friend: ExternalEndpoint,
       disj firstRelation, secondRelation: RelationUnit | {
    world.presentEffects = effect
    world.relationUnits = firstRelation + secondRelation
    no world.revisions
    no world.explicitNone

    effect.magnitude = 10
    firstRelation.source = effect
    secondRelation.source = effect
    firstRelation.debtor = friend
    secondRelation.debtor = friend
    firstRelation.creditor = Household
    secondRelation.creditor = Household
    firstRelation.quantity = 4
    secondRelation.quantity = 4

    firstRelation + secondRelation in currentValidUnits[world, effect]
  }
}

// A malformed retained quantity must not disappear into completeness-derived
// known-none. It remains unresolved until explicitly corrected/retracted.
pred invalidMagnitudeBlocksCoveredNone {
  some world: World,
       effect: Effect,
       relation: RelationUnit | {
    world.presentEffects = effect
    world.relationUnits = relation
    no world.revisions
    no world.explicitNone

    effect.coverage = Covered
    effect.magnitude = 10
    relation.source = effect
    relation.debtor = Household
    relation.creditor in ExternalEndpoint
    relation.quantity = -4

    relation in currentInvalidUnits[world, effect]
    effect in unresolvedEffects[world]
    effect not in knownNoneEffects[world]
    effect not in knownPositiveEffects[world]
  }
}

// Raw retention may precede source admission. Such a unit is not semantically
// positive merely because a serialized record exists.
pred orphanRawRelationRetainedButNotAdmitted {
  some world: World,
       effect: Effect,
       relation: RelationUnit | {
    effect not in world.presentEffects
    relation in world.relationUnits
    relation.source = effect
    relation.quantity = 4
    not semanticallyValid[world, relation]
  }
}

pred coveredRetractionBecomesKnownNone {
  some world: World,
       effect: Effect,
       relation: RelationUnit,
       revision: RelationRevision | {
    world.presentEffects = effect
    world.relationUnits = relation
    world.revisions = revision
    no world.explicitNone

    effect.coverage = Covered
    relation.source = effect
    relation.debtor = Household
    relation.creditor in ExternalEndpoint
    relation.quantity = 4
    revision.target = relation
    no revision.replacement

    no currentRawUnits[world, effect]
    effect in knownNoneEffects[world]
  }
}

pred legacyRetractionReturnsToUnknown {
  some world: World,
       effect: Effect,
       relation: RelationUnit,
       revision: RelationRevision | {
    world.presentEffects = effect
    world.relationUnits = relation
    world.revisions = revision
    no world.explicitNone

    effect.coverage = Legacy
    relation.source = effect
    relation.debtor = Household
    relation.creditor in ExternalEndpoint
    relation.quantity = 4
    revision.target = relation
    no revision.replacement

    no currentRawUnits[world, effect]
    effect in unknownEffects[world]
    effect not in knownNoneEffects[world]
  }
}

pred positiveReplacementStaysOnSource {
  some world: World,
       effect: Effect,
       friend: ExternalEndpoint,
       disj oldRelation, newRelation: RelationUnit,
       revision: RelationRevision | {
    world.presentEffects = effect
    world.relationUnits = oldRelation + newRelation
    world.revisions = revision
    no world.explicitNone

    effect.magnitude = 10
    oldRelation.source = effect
    newRelation.source = effect
    oldRelation.debtor = friend
    oldRelation.creditor = Household
    oldRelation.quantity = 4
    newRelation.debtor = Household
    newRelation.creditor = friend
    newRelation.quantity = 4

    revision.target = oldRelation
    revision.replacement = newRelation
    oldRelation not in currentRawUnits[world, effect]
    newRelation in currentValidUnits[world, effect]
  }
}

pred explicitNoneConflictFailsClosed {
  some world: World,
       effect: Effect,
       relation: RelationUnit,
       evidence: ExplicitNoneEvidence | {
    world.presentEffects = effect
    world.relationUnits = relation
    no world.revisions
    world.explicitNone = evidence

    effect.magnitude = 10
    relation.source = effect
    relation.debtor = Household
    relation.creditor in ExternalEndpoint
    relation.quantity = 4
    evidence.source = effect

    effect in unresolvedEffects[world]
    effect not in knownPositiveEffects[world]
    effect not in knownNoneEffects[world]
  }
}

// Measure is recovered from the source Effect after reference admission; the
// relation record itself does not need a second stored measure coordinate.
pred sourceMeasureIsEnough {
  some world: World,
       disj firstEffect, secondEffect: Effect,
       disj firstRelation, secondRelation: RelationUnit | {
    firstEffect.sourceMeasure != secondEffect.sourceMeasure
    world.presentEffects = firstEffect + secondEffect
    world.relationUnits = firstRelation + secondRelation
    no world.revisions
    no world.explicitNone

    firstEffect.magnitude = 10
    secondEffect.magnitude = 10
    firstRelation.source = firstEffect
    secondRelation.source = secondEffect
    firstRelation.quantity = 4
    secondRelation.quantity = 4
    firstRelation.debtor = Household
    firstRelation.creditor in ExternalEndpoint
    secondRelation.debtor = Household
    secondRelation.creditor in ExternalEndpoint

    semanticallyValid[world, firstRelation]
    semanticallyValid[world, secondRelation]
    firstRelation.source.sourceMeasure != secondRelation.source.sourceMeasure
  }
}

assert KnownPositiveUsesOnlyValidCurrentUnits {
  all world: World, effect: knownPositiveEffects[world] |
    some currentValidUnits[world, effect] and
    no currentInvalidUnits[world, effect]
}

assert InvalidCurrentEvidenceCannotBecomeKnownNone {
  all world: World, effect: world.presentEffects |
    some currentInvalidUnits[world, effect] implies
      effect not in knownNoneEffects[world]
}

assert CoveredCleanAbsenceIsKnownNone {
  all world: World, effect: world.presentEffects |
    effect.coverage = Covered and
    no currentRawUnits[world, effect]
    implies
      effect in knownNoneEffects[world]
}

// Deliberately too strong: legacy clean absence is still unknown.
assert LegacyCleanAbsenceIsKnownNone {
  all world: World, effect: world.presentEffects |
    effect.coverage = Legacy and
    no currentRawUnits[world, effect] and
    no explicitNoneFor[world, effect]
    implies
      effect in knownNoneEffects[world]
}

// Deliberately too strong: retraction itself is not source-level known-none.
assert RetractionAlwaysProducesKnownNone {
  all world: World, effect: world.presentEffects,
      relation: world.relationUnits,
      revision: world.revisions |
    relation.source = effect and
    revision.target = relation and
    no revision.replacement and
    no currentRawUnits[world, effect]
    implies
      effect in knownNoneEffects[world]
}

// Deliberately too strong: raw retained records need not already satisfy the
// semantic positive-magnitude constraint. Application projection must fail
// closed instead of treating invalid current evidence as absence.
assert EveryRawRelationIsAlreadyPositive {
  all world: World, relation: world.relationUnits |
    relation.quantity > 0
}

// Deliberately too strong: exact shape does not collapse relation identity.
assert SourceEndpointsQuantityDetermineRelationUnit {
  all world: World, firstRelation, secondRelation: world.relationUnits |
    firstRelation.source = secondRelation.source and
    firstRelation.debtor = secondRelation.debtor and
    firstRelation.creditor = secondRelation.creditor and
    firstRelation.quantity = secondRelation.quantity
    implies
      firstRelation = secondRelation
}

// Deliberately too strong: explicit none authority does not silently override a
// still-current positive relation.
assert ExplicitNoneOverridesCurrentPositive {
  all world: World, effect: world.presentEffects |
    some explicitNoneFor[world, effect] implies
      effect in knownNoneEffects[world]
}

assert PositiveReplacementPreservesSource {
  all world: World, revision: world.revisions |
    some revision.replacement implies
      revision.replacement.source = revision.target.source
}

run sharedCostPositiveAdmitted for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int
run equalShapeDistinctRelationUnits for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int
run invalidMagnitudeBlocksCoveredNone for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int
run orphanRawRelationRetainedButNotAdmitted for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int
run coveredRetractionBecomesKnownNone for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int
run legacyRetractionReturnsToUnknown for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int
run positiveReplacementStaysOnSource for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int
run explicitNoneConflictFailsClosed for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int
run sourceMeasureIsEnough for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int

check KnownPositiveUsesOnlyValidCurrentUnits for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int
check InvalidCurrentEvidenceCannotBecomeKnownNone for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int
check CoveredCleanAbsenceIsKnownNone for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int
check LegacyCleanAbsenceIsKnownNone for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int
check RetractionAlwaysProducesKnownNone for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int
check EveryRawRelationIsAlreadyPositive for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int
check SourceEndpointsQuantityDetermineRelationUnit for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int
check ExplicitNoneOverridesCurrentPositive for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int
check PositiveReplacementPreservesSource for exactly 2 Event, exactly 3 Key, exactly 2 Measure, exactly 3 Effect, exactly 2 ExternalEndpoint, exactly 4 RelationUnit, exactly 3 RelationRevision, exactly 2 ExplicitNoneEvidence, exactly 2 World, 6 Int
