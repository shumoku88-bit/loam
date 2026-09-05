module experiments/observation_167_burden_authority_absence

sig Event {}
sig Key {}

sig Effect {
  event: one Event,
  key: one Key
}

sig Unit {
  source: one Effect
}

abstract sig Bearer {}
one sig Household extends Bearer {}
sig Outside extends Bearer {}

sig BurdenFact {
  unit: one Unit,
  bearer: one Bearer
}

sig BurdenCorrection {
  target: one BurdenFact,
  replacement: one BurdenFact
}

sig World {
  units: set Unit,
  facts: set BurdenFact,
  corrections: set BurdenCorrection,

  // Observation-only latent meaning. Current admitted evidence must remain
  // compatible with it; absence deliberately leaves it unconstrained.
  semanticBearer: Unit -> lone Bearer
}

one sig Left, Right extends World {}

fact EffectKeyScopedIdentity {
  all disj left, right: Effect |
    left.event = right.event implies left.key != right.key
}

fun currentFacts[w: World]: set BurdenFact {
  { f: w.facts |
    no c: w.corrections | c.target = f
  }
}

fun currentFor[w: World, u: Unit]: set BurdenFact {
  { f: currentFacts[w] | f.unit = u }
}

fun currentBearers[w: World, u: Unit]: set Bearer {
  currentFor[w, u].bearer
}

fact WellFormedEvidence {
  all w: World | {
    w.semanticBearer in w.units -> Bearer
    all u: w.units | one u.(w.semanticBearer)
    all u: Unit - w.units | no u.(w.semanticBearer)

    w.facts.unit in w.units

    w.corrections.target in w.facts
    w.corrections.replacement in w.facts

    all c: w.corrections | {
      c.target != c.replacement
      c.target.unit = c.replacement.unit
    }

    // Correction ancestry is append-only and acyclic. Storage/arrival order is
    // not represented and therefore cannot choose a current winner.
    let edge = { target, replacement: w.facts |
      some c: w.corrections |
        c.target = target and c.replacement = replacement
    } |
      no iden & ^edge

    // No current evidence means unknown. One current fact is authoritative.
    // Multiple current facts remain candidates and do not gain a winner here.
    all u: w.units |
      let current = currentFor[w, u] | {
        some current implies u.(w.semanticBearer) in current.bearer
        one current implies u.(w.semanticBearer) = current.bearer
      }
  }
}

// The same physical source with no burden evidence admits both household and
// outside-borne semantic completions. Absence therefore cannot universally
// mean "Household bears it".
pred absenceSupportsDifferentMeanings {
  some event: Event, key: Key, effect: Effect, u: Unit, friend: Outside | {
    effect.event = event
    effect.key = key
    u.source = effect

    Left.units = u
    Right.units = u
    no Left.facts
    no Right.facts
    no Left.corrections
    no Right.corrections

    Left.semanticBearer = u->Household
    Right.semanticBearer = u->friend

    no currentFor[Left, u]
    no currentFor[Right, u]
  }
}

// Explicit household evidence is observably different from mere absence even
// when both worlds happen to have household semantic meaning.
pred explicitHouseholdDiffersFromAbsence {
  some effect: Effect, u: Unit, burdenFact: BurdenFact | {
    u.source = effect
    burdenFact.unit = u
    burdenFact.bearer = Household

    Left.units = u
    Right.units = u
    no Left.facts
    no Left.corrections
    Right.facts = burdenFact
    no Right.corrections

    Left.semanticBearer = u->Household
    Right.semanticBearer = u->Household

    no currentFor[Left, u]
    currentFor[Right, u] = burdenFact
  }
}

// Correcting burden does not require replacing or mutating the source Event or
// Effect. Both burden facts remain retained and the correction relation changes
// only the current burden frontier.
pred correctionChangesCurrentNotSource {
  some effect: Effect, u: Unit,
       oldFact, revisedFact: BurdenFact,
       correction: BurdenCorrection,
       friend: Outside | {
    u.source = effect
    oldFact.unit = u
    revisedFact.unit = u
    oldFact.bearer = Household
    revisedFact.bearer = friend

    correction.target = oldFact
    correction.replacement = revisedFact

    Left.units = u
    Left.facts = oldFact
    no Left.corrections
    Left.semanticBearer = u->Household

    Right.units = u
    Right.facts = oldFact + revisedFact
    Right.corrections = correction
    Right.semanticBearer = u->friend

    currentFor[Left, u] = oldFact
    currentFor[Right, u] = revisedFact
    oldFact in Right.facts
    revisedFact in Right.facts
    u.source = effect
  }
}

// Two sibling corrections of one prior burden fact remain a conflict. The
// model contains no learned-later or storage-later authority rule.
pred siblingCorrectionRemainsConflict {
  some effect: Effect, u: Unit,
       baseFact, householdCandidate, outsideCandidate: BurdenFact,
       disj leftCorrection, rightCorrection: BurdenCorrection,
       friend: Outside | {
    u.source = effect

    baseFact.unit = u
    householdCandidate.unit = u
    outsideCandidate.unit = u
    baseFact.bearer = Household
    householdCandidate.bearer = Household
    outsideCandidate.bearer = friend

    leftCorrection.target = baseFact
    leftCorrection.replacement = householdCandidate
    rightCorrection.target = baseFact
    rightCorrection.replacement = outsideCandidate

    Left.units = u
    Left.facts = baseFact + householdCandidate + outsideCandidate
    Left.corrections = leftCorrection + rightCorrection
    Left.semanticBearer = u->Household

    currentFor[Left, u] = householdCandidate + outsideCandidate
    currentBearers[Left, u] = Household + friend
  }
}

// A direct current fact and an append-only corrected history can have the same
// current answer while preserving different provenance.
pred sameCurrentBurdenDifferentHistory {
  some effect: Effect, u: Unit,
       directOutside, oldHousehold, revisedOutside: BurdenFact,
       correction: BurdenCorrection,
       friend: Outside | {
    u.source = effect

    directOutside.unit = u
    oldHousehold.unit = u
    revisedOutside.unit = u
    directOutside.bearer = friend
    oldHousehold.bearer = Household
    revisedOutside.bearer = friend

    correction.target = oldHousehold
    correction.replacement = revisedOutside

    Left.units = u
    Left.facts = directOutside
    no Left.corrections
    Left.semanticBearer = u->friend

    Right.units = u
    Right.facts = oldHousehold + revisedOutside
    Right.corrections = correction
    Right.semanticBearer = u->friend

    currentBearers[Left, u] = friend
    currentBearers[Right, u] = friend
    Left.facts != Right.facts
  }
}

// One Effect may itself contain multiple exact quantity Units with different
// bearers. A future retained burden fact therefore cannot be assumed to be one
// scalar bearer label for the entire Effect.
pred splitBurdenWithinOneEffect {
  some effect: Effect,
       disj ownUnit, sharedUnit: Unit,
       ownFact, sharedFact: BurdenFact,
       friend: Outside | {
    ownUnit.source = effect
    sharedUnit.source = effect

    ownFact.unit = ownUnit
    sharedFact.unit = sharedUnit
    ownFact.bearer = Household
    sharedFact.bearer = friend

    Left.units = ownUnit + sharedUnit
    Left.facts = ownFact + sharedFact
    no Left.corrections
    Left.semanticBearer = ownUnit->Household + sharedUnit->friend

    currentBearers[Left, ownUnit] = Household
    currentBearers[Left, sharedUnit] = friend
  }
}

// Deliberately too strong: identical absence of burden evidence does not force
// the same bearer meaning.
assert AbsenceDeterminesBearer {
  all left, right: World, u: Unit |
    u in left.units and
    u in right.units and
    left.facts = right.facts and
    left.corrections = right.corrections and
    no currentFor[left, u] and
    no currentFor[right, u]
    implies
      u.(left.semanticBearer) = u.(right.semanticBearer)
}

// Once exactly one current burden fact exists, its bearer is authoritative in
// this observation-local evidence model.
assert SingleCurrentFactDeterminesBearer {
  all w: World, u: Unit |
    u in w.units and one currentFor[w, u]
    implies
      u.(w.semanticBearer) = currentFor[w, u].bearer
}

// A burden correction preserves the source quantity Unit, and therefore its
// existing Effect anchor, rather than implicitly replacing the Event/Effect.
assert BurdenCorrectionPreservesSourceAnchor {
  all w: World, c: w.corrections |
    c.target.unit.source = c.replacement.unit.source
}

run absenceSupportsDifferentMeanings for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 Unit, exactly 3 BurdenFact, exactly 2 BurdenCorrection, exactly 2 Outside, exactly 2 World
run explicitHouseholdDiffersFromAbsence for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 Unit, exactly 3 BurdenFact, exactly 2 BurdenCorrection, exactly 2 Outside, exactly 2 World
run correctionChangesCurrentNotSource for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 Unit, exactly 4 BurdenFact, exactly 3 BurdenCorrection, exactly 2 Outside, exactly 2 World
run siblingCorrectionRemainsConflict for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 Unit, exactly 5 BurdenFact, exactly 4 BurdenCorrection, exactly 2 Outside, exactly 2 World
run sameCurrentBurdenDifferentHistory for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 Unit, exactly 5 BurdenFact, exactly 3 BurdenCorrection, exactly 2 Outside, exactly 2 World
run splitBurdenWithinOneEffect for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 4 Unit, exactly 5 BurdenFact, exactly 3 BurdenCorrection, exactly 2 Outside, exactly 2 World

check AbsenceDeterminesBearer for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 Unit, exactly 3 BurdenFact, exactly 2 BurdenCorrection, exactly 2 Outside, exactly 2 World
check SingleCurrentFactDeterminesBearer for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 4 Unit, exactly 5 BurdenFact, exactly 4 BurdenCorrection, exactly 2 Outside, exactly 2 World
check BurdenCorrectionPreservesSourceAnchor for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 4 Unit, exactly 5 BurdenFact, exactly 4 BurdenCorrection, exactly 2 Outside, exactly 2 World
