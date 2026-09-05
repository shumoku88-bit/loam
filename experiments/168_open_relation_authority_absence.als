module experiments/observation_168_open_relation_authority_absence

sig Event {}
sig Key {}

sig Effect {
  sourceEvent: one Event,
  sourceKey: one Key
}

sig Unit {
  sourceEffect: one Effect
}

abstract sig Party {}
one sig Household extends Party {}
sig Outside extends Party {}

abstract sig RelationMeaning {}
one sig NoRelation extends RelationMeaning {}
sig DirectedRelation extends RelationMeaning {
  debtorParty: one Party,
  creditorParty: one Party
}

sig RelationFact {
  unitRef: one Unit,
  meaningRef: one RelationMeaning
}

sig RelationCorrection {
  targetFact: one RelationFact,
  replacementFact: one RelationFact
}

sig World {
  units: set Unit,

  // Observation-only burden meaning. This is intentionally independent from
  // open-relation evidence so the model can test whether one determines the other.
  burdenBearer: Unit -> lone Party,

  relationFacts: set RelationFact,
  relationCorrections: set RelationCorrection,

  // Observation-only latent relation meaning. Current admitted evidence must
  // remain compatible with it; missing evidence deliberately leaves it open.
  semanticRelation: Unit -> lone RelationMeaning
}

one sig Left, Right extends World {}

fact EffectKeyScopedIdentity {
  all disj firstEffect, secondEffect: Effect |
    firstEffect.sourceEvent = secondEffect.sourceEvent implies
      firstEffect.sourceKey != secondEffect.sourceKey
}

fact DirectedEndpointsDiffer {
  all directed: DirectedRelation |
    directed.debtorParty != directed.creditorParty
}

fun currentRelationFacts[w: World]: set RelationFact {
  { f: w.relationFacts |
    no c: w.relationCorrections | c.targetFact = f
  }
}

fun currentRelationFor[w: World, u: Unit]: set RelationFact {
  { f: currentRelationFacts[w] | f.unitRef = u }
}

fun currentMeanings[w: World, u: Unit]: set RelationMeaning {
  currentRelationFor[w, u].meaningRef
}

fun knownNoRelation[w: World]: set Unit {
  { u: w.units |
    one currentRelationFor[w, u] and
    currentMeanings[w, u] = NoRelation
  }
}

fun knownReceivable[w: World]: set Unit {
  { u: w.units |
    one currentRelationFor[w, u] and
    some directed: DirectedRelation |
      currentMeanings[w, u] = directed and
      directed.debtorParty != Household and
      directed.creditorParty = Household
  }
}

fun knownPayable[w: World]: set Unit {
  { u: w.units |
    one currentRelationFor[w, u] and
    some directed: DirectedRelation |
      currentMeanings[w, u] = directed and
      directed.debtorParty = Household and
      directed.creditorParty != Household
  }
}

fun unknownRelation[w: World]: set Unit {
  { u: w.units | no currentRelationFor[w, u] }
}

fun conflictingRelation[w: World]: set Unit {
  { u: w.units | #currentRelationFor[w, u] > 1 }
}

fact WellFormedEvidence {
  all w: World | {
    w.burdenBearer in w.units -> Party
    all u: w.units | one u.(w.burdenBearer)
    all u: Unit - w.units | no u.(w.burdenBearer)

    w.semanticRelation in w.units -> RelationMeaning
    all u: w.units | one u.(w.semanticRelation)
    all u: Unit - w.units | no u.(w.semanticRelation)

    w.relationFacts.unitRef in w.units

    w.relationCorrections.targetFact in w.relationFacts
    w.relationCorrections.replacementFact in w.relationFacts

    all c: w.relationCorrections | {
      c.targetFact != c.replacementFact
      c.targetFact.unitRef = c.replacementFact.unitRef
    }

    let edge = { oldFact, newFact: w.relationFacts |
      some c: w.relationCorrections |
        c.targetFact = oldFact and c.replacementFact = newFact
    } |
      no iden & ^edge

    // Missing relation evidence is unknown. One current fact is authoritative.
    // Multiple current facts remain unresolved candidates.
    all u: w.units |
      let current = currentRelationFor[w, u] | {
        some current implies u.(w.semanticRelation) in current.meaningRef
        one current implies u.(w.semanticRelation) = current.meaningRef
      }
  }
}

// Same source and same outside burden can correspond either to no open relation
// or to a Friend -> Household receivable. Outside burden alone does not create
// a receivable-like relation.
pred outsideBurdenDoesNotDetermineReceivable {
  some effectRef: Effect, u: Unit, friend: Outside,
       noRelationFact, receivableFact: RelationFact,
       receivableMeaning: DirectedRelation | {
    u.sourceEffect = effectRef

    receivableMeaning.debtorParty = friend
    receivableMeaning.creditorParty = Household

    noRelationFact.unitRef = u
    noRelationFact.meaningRef = NoRelation
    receivableFact.unitRef = u
    receivableFact.meaningRef = receivableMeaning

    Left.units = u
    Right.units = u
    Left.burdenBearer = u->friend
    Right.burdenBearer = u->friend

    Left.relationFacts = noRelationFact
    Right.relationFacts = receivableFact
    no Left.relationCorrections
    no Right.relationCorrections

    Left.semanticRelation = u->NoRelation
    Right.semanticRelation = u->receivableMeaning

    u in knownNoRelation[Left]
    u in knownReceivable[Right]
  }
}

// With no relation evidence at all, identical physical/burden meaning can admit
// both an actually absent relation and an actually present receivable relation.
// Therefore missing evidence is not equivalent to known zero relation.
pred absenceSupportsNoneAndSome {
  some effectRef: Effect, u: Unit, friend: Outside,
       receivableMeaning: DirectedRelation | {
    u.sourceEffect = effectRef
    receivableMeaning.debtorParty = friend
    receivableMeaning.creditorParty = Household

    Left.units = u
    Right.units = u
    Left.burdenBearer = u->friend
    Right.burdenBearer = u->friend
    no Left.relationFacts
    no Right.relationFacts
    no Left.relationCorrections
    no Right.relationCorrections

    Left.semanticRelation = u->NoRelation
    Right.semanticRelation = u->receivableMeaning

    u in unknownRelation[Left]
    u in unknownRelation[Right]
  }
}

// Explicit known-none is observably different from mere lack of evidence even
// when the latent relation meaning is NoRelation in both worlds.
pred explicitNoneDiffersFromAbsence {
  some effectRef: Effect, u: Unit, noRelationFact: RelationFact | {
    u.sourceEffect = effectRef
    noRelationFact.unitRef = u
    noRelationFact.meaningRef = NoRelation

    Left.units = u
    Right.units = u
    Left.burdenBearer = u->Household
    Right.burdenBearer = u->Household

    no Left.relationFacts
    no Left.relationCorrections
    Right.relationFacts = noRelationFact
    no Right.relationCorrections

    Left.semanticRelation = u->NoRelation
    Right.semanticRelation = u->NoRelation

    u in unknownRelation[Left]
    u in knownNoRelation[Right]
  }
}

// Household burden can coexist with a Household -> outside payable, as in a
// deferred card purchase. So Household burden does not imply no open relation.
pred householdBurdenCanHavePayable {
  some effectRef: Effect, u: Unit, issuer: Outside,
       payableFact: RelationFact, payableMeaning: DirectedRelation | {
    u.sourceEffect = effectRef
    payableMeaning.debtorParty = Household
    payableMeaning.creditorParty = issuer
    payableFact.unitRef = u
    payableFact.meaningRef = payableMeaning

    Left.units = u
    Left.burdenBearer = u->Household
    Left.relationFacts = payableFact
    no Left.relationCorrections
    Left.semanticRelation = u->payableMeaning

    u in knownPayable[Left]
  }
}

// Relation interpretation may be corrected append-only without replacing the
// physical source or changing burden allocation.
pred correctionChangesRelationNotBurden {
  some effectRef: Effect, u: Unit, friend: Outside,
       oldFact, revisedFact: RelationFact,
       revision: RelationCorrection,
       receivableMeaning: DirectedRelation | {
    u.sourceEffect = effectRef
    receivableMeaning.debtorParty = friend
    receivableMeaning.creditorParty = Household

    oldFact.unitRef = u
    oldFact.meaningRef = NoRelation
    revisedFact.unitRef = u
    revisedFact.meaningRef = receivableMeaning
    revision.targetFact = oldFact
    revision.replacementFact = revisedFact

    Left.units = u
    Left.burdenBearer = u->friend
    Left.relationFacts = oldFact
    no Left.relationCorrections
    Left.semanticRelation = u->NoRelation

    Right.units = u
    Right.burdenBearer = u->friend
    Right.relationFacts = oldFact + revisedFact
    Right.relationCorrections = revision
    Right.semanticRelation = u->receivableMeaning

    currentRelationFor[Left, u] = oldFact
    currentRelationFor[Right, u] = revisedFact
    Left.burdenBearer = Right.burdenBearer
    u.sourceEffect = effectRef
  }
}

// Sibling relation corrections remain unresolved. No arrival-order rule picks
// between receivable and payable candidates.
pred siblingRelationCorrectionRemainsConflict {
  some effectRef: Effect, u: Unit, friend, issuer: Outside,
       baseFact, receivableFact, payableFact: RelationFact,
       disj firstRevision, secondRevision: RelationCorrection,
       receivableMeaning, payableMeaning: DirectedRelation | {
    friend != issuer
    u.sourceEffect = effectRef

    receivableMeaning.debtorParty = friend
    receivableMeaning.creditorParty = Household
    payableMeaning.debtorParty = Household
    payableMeaning.creditorParty = issuer

    baseFact.unitRef = u
    baseFact.meaningRef = NoRelation
    receivableFact.unitRef = u
    receivableFact.meaningRef = receivableMeaning
    payableFact.unitRef = u
    payableFact.meaningRef = payableMeaning

    firstRevision.targetFact = baseFact
    firstRevision.replacementFact = receivableFact
    secondRevision.targetFact = baseFact
    secondRevision.replacementFact = payableFact

    Left.units = u
    Left.burdenBearer = u->Household
    Left.relationFacts = baseFact + receivableFact + payableFact
    Left.relationCorrections = firstRevision + secondRevision
    Left.semanticRelation = u->receivableMeaning

    currentRelationFor[Left, u] = receivableFact + payableFact
    u in conflictingRelation[Left]
  }
}

// Deliberately too strong: no current relation evidence does not mean the true
// relation is definitely NoRelation.
assert AbsenceMeansNoRelation {
  all w: World, u: Unit |
    u in w.units and no currentRelationFor[w, u]
    implies
      u.(w.semanticRelation) = NoRelation
}

// Deliberately too strong: outside burden does not force a receivable edge.
assert OutsideBurdenImpliesReceivable {
  all w: World, u: Unit |
    u in w.units and u.(w.burdenBearer) != Household
    implies
      some directed: DirectedRelation |
        u.(w.semanticRelation) = directed and
        directed.debtorParty != Household and
        directed.creditorParty = Household
}

// One current relation fact determines the admitted relation meaning.
assert SingleCurrentRelationFactDeterminesMeaning {
  all w: World, u: Unit |
    u in w.units and one currentRelationFor[w, u]
    implies
      u.(w.semanticRelation) = currentRelationFor[w, u].meaningRef
}

// A relation correction stays anchored to the same quantity Unit and therefore
// the same existing source Effect.
assert RelationCorrectionPreservesSourceAnchor {
  all w: World, c: w.relationCorrections |
    c.targetFact.unitRef.sourceEffect = c.replacementFact.unitRef.sourceEffect
}

run outsideBurdenDoesNotDetermineReceivable for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 Unit, exactly 4 Outside, exactly 4 DirectedRelation, exactly 5 RelationFact, exactly 3 RelationCorrection, exactly 2 World
run absenceSupportsNoneAndSome for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 Unit, exactly 4 Outside, exactly 4 DirectedRelation, exactly 4 RelationFact, exactly 3 RelationCorrection, exactly 2 World
run explicitNoneDiffersFromAbsence for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 Unit, exactly 4 Outside, exactly 4 DirectedRelation, exactly 4 RelationFact, exactly 3 RelationCorrection, exactly 2 World
run householdBurdenCanHavePayable for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 Unit, exactly 4 Outside, exactly 4 DirectedRelation, exactly 4 RelationFact, exactly 3 RelationCorrection, exactly 2 World
run correctionChangesRelationNotBurden for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 Unit, exactly 4 Outside, exactly 4 DirectedRelation, exactly 5 RelationFact, exactly 4 RelationCorrection, exactly 2 World
run siblingRelationCorrectionRemainsConflict for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 Unit, exactly 4 Outside, exactly 5 DirectedRelation, exactly 6 RelationFact, exactly 4 RelationCorrection, exactly 2 World

check AbsenceMeansNoRelation for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 Unit, exactly 4 Outside, exactly 4 DirectedRelation, exactly 5 RelationFact, exactly 3 RelationCorrection, exactly 2 World
check OutsideBurdenImpliesReceivable for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 Unit, exactly 4 Outside, exactly 4 DirectedRelation, exactly 5 RelationFact, exactly 3 RelationCorrection, exactly 2 World
check SingleCurrentRelationFactDeterminesMeaning for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 4 Unit, exactly 4 Outside, exactly 5 DirectedRelation, exactly 6 RelationFact, exactly 4 RelationCorrection, exactly 2 World
check RelationCorrectionPreservesSourceAnchor for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 4 Unit, exactly 4 Outside, exactly 5 DirectedRelation, exactly 6 RelationFact, exactly 4 RelationCorrection, exactly 2 World
