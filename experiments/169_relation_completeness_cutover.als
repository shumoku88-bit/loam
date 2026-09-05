module experiments/observation_169_relation_completeness_cutover

abstract sig Party {}
one sig Household, Friend extends Party {}

sig Event {}
sig Key {}

abstract sig ValidEra {}
one sig ValidBefore, ValidAfter extends ValidEra {}

abstract sig AdmissionEra {}
one sig LegacyAdmission, CompleteAdmission extends AdmissionEra {}

abstract sig CompletenessBasis {}
one sig ByValidTime, ByAdmission extends CompletenessBasis {}

sig Effect {
  event: one Event,
  key: one Key,
  validEra: one ValidEra,
  admissionEra: one AdmissionEra
}

sig DirectedRelation {
  debtor: one Party,
  creditor: one Party
} {
  debtor != creditor
}

sig RelationFact {
  source: one Effect,
  meaning: one DirectedRelation
}

sig World {
  effects: set Effect,
  facts: set RelationFact,
  semantic: Effect -> lone DirectedRelation,
  basis: one CompletenessBasis
}

one sig Left, Right extends World {}

fact EffectKeyScopedIdentity {
  all disj a, b: Effect |
    a.event = b.event implies a.key != b.key
}

fun factsFor[w: World, e: Effect]: set RelationFact {
  { f: w.facts | f.source = e }
}

pred covered[w: World, e: Effect] {
  (w.basis = ByValidTime and e.validEra = ValidAfter)
  or
  (w.basis = ByAdmission and e.admissionEra = CompleteAdmission)
}

fact WellFormedWorlds {
  all w: World | {
    w.facts.source in w.effects

    all f: w.facts |
      f.meaning = f.source.(w.semantic)

    all e: w.effects |
      lone factsFor[w, e]

    all e: Effect - w.effects |
      no e.(w.semantic)

    // The observation-local completeness contract:
    // for a covered Effect, a directed semantic relation exists iff one
    // positive relation fact exists. Therefore covered absence can mean none
    // without a per-Effect NoRelation fact.
    all e: w.effects |
      covered[w, e] implies
        ((one factsFor[w, e]) iff one e.(w.semantic))
  }
}

// A valid-time cutover can represent a known-none relation with no negative
// fact at all, provided the writer/import contract is complete for that region.
pred validTimeKnownNoneWithoutNegativeFact {
  some e: Effect | {
    e.validEra = ValidAfter
    Left.basis = ByValidTime
    Left.effects = e
    no Left.facts
    no e.(Left.semantic)
  }
}

// Before the valid-time cutover, identical absence remains compatible with
// either no relation or a directed relation. Legacy absence stays unknown.
pred preCutoverAbsenceSupportsDifferentMeanings {
  some e: Effect, r: DirectedRelation | {
    e.validEra = ValidBefore

    Left.basis = ByValidTime
    Right.basis = ByValidTime
    Left.effects = e
    Right.effects = e
    no Left.facts
    no Right.facts

    no e.(Left.semantic)
    e.(Right.semantic) = r
  }
}

// A backdated Effect admitted by a complete writer exposes the difference
// between valid-time and admission-regime completeness. The valid-time policy
// leaves this pre-cutover occurrence unknown; the admission policy can know
// none from absence.
pred backdatedAdmissionPoliciesDiverge {
  some e: Effect, r: DirectedRelation | {
    e.validEra = ValidBefore
    e.admissionEra = CompleteAdmission

    Left.basis = ByValidTime
    Right.basis = ByAdmission
    Left.effects = e
    Right.effects = e
    no Left.facts
    no Right.facts

    e.(Left.semantic) = r
    no e.(Right.semantic)
  }
}

// Conversely, valid-time completeness does not need admission provenance for
// an occurrence in the covered valid-time region.
pred postValidLegacyAdmissionStillCoveredByValidPolicy {
  some e: Effect | {
    e.validEra = ValidAfter
    e.admissionEra = LegacyAdmission

    Left.basis = ByValidTime
    Left.effects = e
    no Left.facts
    no e.(Left.semantic)
  }
}

// Effective/valid time and admission regime are independent coordinates in the
// bounded model. A future admission-based cutover would therefore require
// retained admission provenance rather than inferring it from valid time.
pred sameValidTimeDifferentAdmissionRegime {
  some disj a, b: Effect | {
    a.validEra = b.validEra
    a.admissionEra = LegacyAdmission
    b.admissionEra = CompleteAdmission
  }
}

// Positive relation evidence has the same meaning under either completeness
// basis. Completeness changes how absence is interpreted, not what a positive
// directed fact means.
pred positiveFactWorksAcrossBothBases {
  some e: Effect, f: RelationFact, r: DirectedRelation | {
    e.validEra = ValidAfter
    e.admissionEra = CompleteAdmission
    f.source = e
    f.meaning = r

    Left.basis = ByValidTime
    Right.basis = ByAdmission
    Left.effects = e
    Right.effects = e
    Left.facts = f
    Right.facts = f
    e.(Left.semantic) = r
    e.(Right.semantic) = r
  }
}

// Covered absence is the exact compression law under the completeness
// contract: no positive relation fact means known-none.
assert CoveredAbsenceMeansNone {
  all w: World, e: Effect |
    e in w.effects and covered[w, e] and no factsFor[w, e]
    implies no e.(w.semantic)
}

// Covered directed meaning cannot exist without its positive relation evidence.
assert CoveredRelationRequiresPositiveFact {
  all w: World, e: Effect |
    e in w.effects and covered[w, e] and some e.(w.semantic)
    implies one factsFor[w, e]
}

// Deliberately too strong. Outside the completeness region, absence does not
// justify known-none.
assert UncoveredAbsenceMeansNone {
  all w: World, e: Effect |
    e in w.effects and not covered[w, e] and no factsFor[w, e]
    implies no e.(w.semantic)
}

// Deliberately too strong. Valid/effective time does not determine which writer
// regime admitted an Effect.
assert ValidTimeDeterminesAdmissionRegime {
  all a, b: Effect |
    a.validEra = b.validEra implies a.admissionEra = b.admissionEra
}

// A completeness cutover does not silently retract already-retained positive
// evidence. Correcting a directed relation to none still needs explicit
// revision/retraction authority outside this observation.
assert RetainedPositiveFactCannotSilentlyBecomeNone {
  all w: World, e: Effect |
    some factsFor[w, e] implies some e.(w.semantic)
}

run validTimeKnownNoneWithoutNegativeFact for exactly 2 Party, exactly 4 Event, exactly 4 Key, exactly 5 Effect, exactly 4 DirectedRelation, exactly 4 RelationFact, exactly 2 World
run preCutoverAbsenceSupportsDifferentMeanings for exactly 2 Party, exactly 4 Event, exactly 4 Key, exactly 5 Effect, exactly 4 DirectedRelation, exactly 4 RelationFact, exactly 2 World
run backdatedAdmissionPoliciesDiverge for exactly 2 Party, exactly 4 Event, exactly 4 Key, exactly 5 Effect, exactly 4 DirectedRelation, exactly 4 RelationFact, exactly 2 World
run postValidLegacyAdmissionStillCoveredByValidPolicy for exactly 2 Party, exactly 4 Event, exactly 4 Key, exactly 5 Effect, exactly 4 DirectedRelation, exactly 4 RelationFact, exactly 2 World
run sameValidTimeDifferentAdmissionRegime for exactly 2 Party, exactly 4 Event, exactly 4 Key, exactly 5 Effect, exactly 4 DirectedRelation, exactly 4 RelationFact, exactly 2 World
run positiveFactWorksAcrossBothBases for exactly 2 Party, exactly 4 Event, exactly 4 Key, exactly 5 Effect, exactly 4 DirectedRelation, exactly 4 RelationFact, exactly 2 World

check CoveredAbsenceMeansNone for exactly 2 Party, exactly 4 Event, exactly 4 Key, exactly 5 Effect, exactly 4 DirectedRelation, exactly 4 RelationFact, exactly 2 World
check CoveredRelationRequiresPositiveFact for exactly 2 Party, exactly 4 Event, exactly 4 Key, exactly 5 Effect, exactly 4 DirectedRelation, exactly 4 RelationFact, exactly 2 World
check UncoveredAbsenceMeansNone for exactly 2 Party, exactly 4 Event, exactly 4 Key, exactly 5 Effect, exactly 4 DirectedRelation, exactly 4 RelationFact, exactly 2 World
check ValidTimeDeterminesAdmissionRegime for exactly 2 Party, exactly 4 Event, exactly 4 Key, exactly 5 Effect, exactly 4 DirectedRelation, exactly 4 RelationFact, exactly 2 World
check RetainedPositiveFactCannotSilentlyBecomeNone for exactly 2 Party, exactly 4 Event, exactly 4 Key, exactly 5 Effect, exactly 4 DirectedRelation, exactly 4 RelationFact, exactly 2 World
