module experiments/observation_175_relation_retraction_absence_authority

abstract sig Coverage {}
one sig Covered, Legacy extends Coverage {}

sig Effect {
  coverage: one Coverage
}

// Observation 172-174 already qualified endpoint identity, exact magnitude,
// and semantic direction. This observation intentionally keeps only relation
// unit identity plus its source Effect so it can isolate revision/absence
// authority without reopening those dimensions.
sig RelationUnit {
  source: one Effect
}

// One family-specific append-only revision. A replacement is optional:
//
//   replacement present  -> replace one positive relation unit
//   replacement absent   -> explicitly retract that positive relation unit
//
// The absent replacement is not silent deletion. The revision itself is the
// retained authority saying that the target unit is no longer current.
sig RelationRevision {
  target: one RelationUnit,
  replacement: lone RelationUnit
}

// Exceptional source-level negative evidence. This is deliberately separate
// from retracting one relation unit because one Effect may carry multiple
// relation units, and because uncovered absence remains unknown.
sig ExplicitNoneEvidence {
  source: one Effect
}

fact RevisionShape {
  all revision: RelationRevision | {
    revision.replacement != revision.target
    some revision.replacement implies
      revision.replacement.source = revision.target.source
  }

  // This observation studies one resolved revision frontier. Sibling/conflict
  // behavior was already qualified by earlier correction-frontier work.
  all unit: RelationUnit |
    lone { revision: RelationRevision | revision.target = unit }

  let edge = {
    oldUnit, newUnit: RelationUnit |
      some revision: RelationRevision |
        revision.target = oldUnit and
        revision.replacement = newUnit
  } |
    no iden & ^edge
}

fact ExplicitNoneUniqueness {
  all effect: Effect |
    lone { evidence: ExplicitNoneEvidence | evidence.source = effect }
}

fun currentRelationUnits[effect: Effect]: set RelationUnit {
  { unit: RelationUnit |
    unit.source = effect and
    no revision: RelationRevision | revision.target = unit
  }
}

fun explicitNoneFor[effect: Effect]: set ExplicitNoneEvidence {
  { evidence: ExplicitNoneEvidence | evidence.source = effect }
}

// Observation 169's completeness rule applies after explicit revisions have
// determined which positive relation units remain current.
fun knownNoneEffects: set Effect {
  { effect: Effect |
    no currentRelationUnits[effect] and
    (effect.coverage = Covered or some explicitNoneFor[effect])
  }
}

fun unknownRelationEffects: set Effect {
  { effect: Effect |
    no currentRelationUnits[effect] and
    effect.coverage = Legacy and
    no explicitNoneFor[effect]
  }
}

// Explicit whole-Effect none evidence and a retained current positive unit are
// incompatible authorities. No storage/list order is allowed to choose one.
fun contradictedEffects: set Effect {
  { effect: Effect |
    some currentRelationUnits[effect] and
    some explicitNoneFor[effect]
  }
}

// In a covered region, explicitly retracting the last current positive unit is
// enough for completeness to derive known-none. No separate baseline NoRelation
// fact is needed.
pred coveredRetractionBecomesKnownNone {
  some effect: Effect, unit: RelationUnit, revision: RelationRevision | {
    effect.coverage = Covered
    unit.source = effect
    revision.target = unit
    no revision.replacement
    no explicitNoneFor[effect]
    no currentRelationUnits[effect]
    effect in knownNoneEffects
  }
}

// The same explicit retraction outside the completeness boundary does not prove
// that no other unrecorded relation exists. It returns the Effect to unknown.
pred legacyRetractionRemainsUnknown {
  some effect: Effect, unit: RelationUnit, revision: RelationRevision | {
    effect.coverage = Legacy
    unit.source = effect
    revision.target = unit
    no revision.replacement
    no explicitNoneFor[effect]
    no currentRelationUnits[effect]
    effect in unknownRelationEffects
  }
}

// If an uncovered historical Effect is positively known to have no relation at
// all, exceptional source-level negative evidence can establish known-none.
pred legacyExplicitNoneAfterRetractionKnownNone {
  some effect: Effect,
       unit: RelationUnit,
       revision: RelationRevision,
       evidence: ExplicitNoneEvidence | {
    effect.coverage = Legacy
    unit.source = effect
    revision.target = unit
    no revision.replacement
    evidence.source = effect
    no currentRelationUnits[effect]
    effect in knownNoneEffects
  }
}

// Observation 173 permits multiple relation units on one source Effect.
// Retracting one unit therefore must not erase another still-current unit.
pred retractOneOfSeveralLeavesPositive {
  some effect: Effect,
       disj firstUnit, secondUnit: RelationUnit,
       revision: RelationRevision | {
    firstUnit.source = effect
    secondUnit.source = effect
    revision.target = firstUnit
    no revision.replacement
    secondUnit in currentRelationUnits[effect]
    effect not in knownNoneEffects
  }
}

// The same revision relation can still express ordinary positive-to-positive
// replacement, so the observation does not require a separate physical
// Retraction record type merely to encode a no-replacement outcome.
pred revisionCanReplacePositive {
  some effect: Effect,
       disj oldUnit, newUnit: RelationUnit,
       revision: RelationRevision | {
    oldUnit.source = effect
    newUnit.source = effect
    revision.target = oldUnit
    revision.replacement = newUnit
    oldUnit not in currentRelationUnits[effect]
    newUnit in currentRelationUnits[effect]
  }
}

// Retraction is append-only provenance, not deletion: the superseded positive
// relation unit remains in retained history even when it is not current.
pred retractionPreservesHistoricalPositive {
  some effect: Effect, unit: RelationUnit, revision: RelationRevision | {
    unit.source = effect
    revision.target = unit
    no revision.replacement
    unit not in currentRelationUnits[effect]
    unit in RelationUnit
  }
}

// Whole-Effect none evidence and a still-current positive relation can collide.
// Such a state is contradictory, not a last-write-wins result.
pred explicitNoneConflictsWithCurrentPositive {
  some effect: Effect,
       unit: RelationUnit,
       evidence: ExplicitNoneEvidence | {
    unit.source = effect
    unit in currentRelationUnits[effect]
    evidence.source = effect
    effect in contradictedEffects
  }
}

// Deliberately too strong: retracting the last recorded positive relation does
// not establish known-none for an uncovered Effect.
assert RetractionOfLastPositiveAlwaysKnownNone {
  all effect: Effect, unit: RelationUnit, revision: RelationRevision |
    unit.source = effect and
    revision.target = unit and
    no revision.replacement and
    no currentRelationUnits[effect]
    implies
      effect in knownNoneEffects
}

// Retained Observation 169 law: inside the qualified completeness region,
// absence of current positive relation units is known-none.
assert CoveredNoCurrentMeansKnownNone {
  all effect: Effect |
    effect.coverage = Covered and
    no currentRelationUnits[effect]
    implies
      effect in knownNoneEffects
}

// Deliberately too strong: uncovered absence remains unknown unless explicit
// source-level none evidence exists.
assert LegacyNoCurrentMeansKnownNone {
  all effect: Effect |
    effect.coverage = Legacy and
    no currentRelationUnits[effect]
    implies
      effect in knownNoneEffects
}

// Deliberately too strong: a revision may explicitly retract its target with no
// positive replacement. The revision record itself supplies the authority.
assert EveryRevisionNeedsPositiveReplacement {
  all revision: RelationRevision |
    one revision.replacement
}

// Deliberately too strong: one retraction cannot erase other independently
// current relation units on the same source Effect.
assert RetractingOneRelationEliminatesAllCurrentRelations {
  all effect: Effect, unit: RelationUnit, revision: RelationRevision |
    unit.source = effect and
    revision.target = unit and
    no revision.replacement
    implies
      no currentRelationUnits[effect]
}

// Deliberately too strong: current absence does not imply that historical
// positive relation evidence was physically deleted.
assert NoCurrentMeansNoRetainedRelationHistory {
  all effect: Effect |
    no currentRelationUnits[effect]
    implies
      no { unit: RelationUnit | unit.source = effect }
}

// Deliberately too strong: explicit source-level none evidence may conflict
// with a current positive relation and therefore requires fail-closed handling.
assert ExplicitNoneAndCurrentPositiveNeverConflict {
  no contradictedEffects
}

run coveredRetractionBecomesKnownNone for exactly 2 Effect, exactly 3 RelationUnit, exactly 2 RelationRevision, exactly 1 ExplicitNoneEvidence
run legacyRetractionRemainsUnknown for exactly 2 Effect, exactly 3 RelationUnit, exactly 2 RelationRevision, exactly 1 ExplicitNoneEvidence
run legacyExplicitNoneAfterRetractionKnownNone for exactly 2 Effect, exactly 3 RelationUnit, exactly 2 RelationRevision, exactly 1 ExplicitNoneEvidence
run retractOneOfSeveralLeavesPositive for exactly 2 Effect, exactly 3 RelationUnit, exactly 2 RelationRevision, exactly 1 ExplicitNoneEvidence
run revisionCanReplacePositive for exactly 2 Effect, exactly 3 RelationUnit, exactly 2 RelationRevision, exactly 1 ExplicitNoneEvidence
run retractionPreservesHistoricalPositive for exactly 2 Effect, exactly 3 RelationUnit, exactly 2 RelationRevision, exactly 1 ExplicitNoneEvidence
run explicitNoneConflictsWithCurrentPositive for exactly 2 Effect, exactly 3 RelationUnit, exactly 2 RelationRevision, exactly 1 ExplicitNoneEvidence

check RetractionOfLastPositiveAlwaysKnownNone for exactly 2 Effect, exactly 3 RelationUnit, exactly 2 RelationRevision, exactly 1 ExplicitNoneEvidence
check CoveredNoCurrentMeansKnownNone for exactly 2 Effect, exactly 3 RelationUnit, exactly 2 RelationRevision, exactly 1 ExplicitNoneEvidence
check LegacyNoCurrentMeansKnownNone for exactly 2 Effect, exactly 3 RelationUnit, exactly 2 RelationRevision, exactly 1 ExplicitNoneEvidence
check EveryRevisionNeedsPositiveReplacement for exactly 2 Effect, exactly 3 RelationUnit, exactly 2 RelationRevision, exactly 1 ExplicitNoneEvidence
check RetractingOneRelationEliminatesAllCurrentRelations for exactly 2 Effect, exactly 3 RelationUnit, exactly 2 RelationRevision, exactly 1 ExplicitNoneEvidence
check NoCurrentMeansNoRetainedRelationHistory for exactly 2 Effect, exactly 3 RelationUnit, exactly 2 RelationRevision, exactly 1 ExplicitNoneEvidence
check ExplicitNoneAndCurrentPositiveNeverConflict for exactly 2 Effect, exactly 3 RelationUnit, exactly 2 RelationRevision, exactly 1 ExplicitNoneEvidence
