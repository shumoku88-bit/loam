module experiments/observation_174_signed_quantity_orientation_pressure

sig Event {}
sig Key {}

abstract sig SourceSign {}
one sig PositiveSource, NegativeSource extends SourceSign {}

// Observation 174 is about orientation, not arithmetic. Each Effect therefore
// has the same representative exact magnitude (10) and varies only in source
// sign. Production Quantity remains a signed exact Int; this model isolates the
// sign bit that might otherwise be mistaken for semantic direction.
sig Effect {
  sourceEvent: one Event,
  sourceKey: one Key,
  sourceSign: one SourceSign
}

fact EffectKeyScopedIdentity {
  all disj firstEffect, secondEffect: Effect |
    firstEffect.sourceEvent = secondEffect.sourceEvent implies
      firstEffect.sourceKey != secondEffect.sourceKey
}

abstract sig BurdenBearer {}
one sig HouseholdBearer, OutsideBearer extends BurdenBearer {}

sig BurdenAllocation {
  burdenSource: one Effect,
  amount: BurdenBearer -> one Int
}

fact OneKnownBurdenAllocationPerEffect {
  all effect: Effect |
    one allocation: BurdenAllocation |
      allocation.burdenSource = effect
}

fact ExactRepresentativeBurdenMagnitude {
  all allocation: BurdenAllocation | {
    all bearer: BurdenBearer |
      allocation.amount[bearer] >= 0
    (sum bearer: BurdenBearer | allocation.amount[bearer]) = 10
  }
}

fun burdenFor[effect: Effect]: one BurdenAllocation {
  { allocation: BurdenAllocation |
    allocation.burdenSource = effect
  }
}

abstract sig Endpoint {}
one sig Household extends Endpoint {}
one sig External extends Endpoint {}

// Observation 173 already qualified plane-local exact magnitude. Here each
// relation uses representative magnitude 4 so the solver can focus only on
// orientation independence.
sig RelationUnit {
  relationSource: one Effect,
  debtorEndpoint: one Endpoint,
  creditorEndpoint: one Endpoint
}

fact RelationUnitShape {
  all relation: RelationUnit | {
    relation.debtorEndpoint != relation.creditorEndpoint
    (relation.debtorEndpoint = Household and relation.creditorEndpoint = External)
    or
    (relation.debtorEndpoint = External and relation.creditorEndpoint = Household)
  }
}

pred negativeSourceReceivable {
  some effect: Effect, relation: RelationUnit | {
    effect.sourceSign = NegativeSource
    relation.relationSource = effect
    relation.debtorEndpoint = External
    relation.creditorEndpoint = Household
  }
}

pred positiveSourceReceivable {
  some effect: Effect, relation: RelationUnit | {
    effect.sourceSign = PositiveSource
    relation.relationSource = effect
    relation.debtorEndpoint = External
    relation.creditorEndpoint = Household
  }
}

pred sameSourceSignSupportsOppositeDirections {
  some disj firstEffect, secondEffect: Effect,
       receivable, payable: RelationUnit | {
    firstEffect.sourceSign = NegativeSource
    secondEffect.sourceSign = NegativeSource

    receivable.relationSource = firstEffect
    receivable.debtorEndpoint = External
    receivable.creditorEndpoint = Household

    payable.relationSource = secondEffect
    payable.debtorEndpoint = Household
    payable.creditorEndpoint = External
  }
}

pred sameRelationDirectionAcrossOppositeSourceSigns {
  some disj positiveEffect, negativeEffect: Effect,
       positiveRelation, negativeRelation: RelationUnit | {
    positiveEffect.sourceSign = PositiveSource
    negativeEffect.sourceSign = NegativeSource

    positiveRelation.relationSource = positiveEffect
    negativeRelation.relationSource = negativeEffect
    positiveRelation.debtorEndpoint = External
    negativeRelation.debtorEndpoint = External
    positiveRelation.creditorEndpoint = Household
    negativeRelation.creditorEndpoint = Household
  }
}

pred sameBurdenAcrossOppositeSourceSigns {
  some disj positiveEffect, negativeEffect: Effect | {
    positiveEffect.sourceSign = PositiveSource
    negativeEffect.sourceSign = NegativeSource

    burdenFor[positiveEffect].amount[HouseholdBearer] = 6
    burdenFor[positiveEffect].amount[OutsideBearer] = 4
    burdenFor[negativeEffect].amount[HouseholdBearer] = 6
    burdenFor[negativeEffect].amount[OutsideBearer] = 4
  }
}

// Candidate representation that stores both endpoint order and a signed-edge
// polarity. Positive means first -> second; negative reverses it. The sign is
// intentionally separate from source sign.
abstract sig EncodingSign {}
one sig PositiveEncoding, NegativeEncoding extends EncodingSign {}

sig SignedEdgeEncoding {
  encodedSource: one Effect,
  firstEndpoint: one Endpoint,
  secondEndpoint: one Endpoint,
  encodingSign: one EncodingSign
}

fact SignedEdgeEncodingShape {
  all encoding: SignedEdgeEncoding | {
    encoding.firstEndpoint != encoding.secondEndpoint
    (encoding.firstEndpoint = Household and encoding.secondEndpoint = External)
    or
    (encoding.firstEndpoint = External and encoding.secondEndpoint = Household)
  }

  // Do not let two atoms duplicate the same raw encoding tuple. Any remaining
  // semantic duplication is therefore caused by sign + endpoint-order freedom.
  all disj firstEncoding, secondEncoding: SignedEdgeEncoding |
    not (
      firstEncoding.encodedSource = secondEncoding.encodedSource and
      firstEncoding.firstEndpoint = secondEncoding.firstEndpoint and
      firstEncoding.secondEndpoint = secondEncoding.secondEndpoint and
      firstEncoding.encodingSign = secondEncoding.encodingSign
    )
}

fun encodedDebtor[encoding: SignedEdgeEncoding]: one Endpoint {
  encoding.encodingSign = PositiveEncoding =>
    encoding.firstEndpoint
  else
    encoding.secondEndpoint
}

fun encodedCreditor[encoding: SignedEdgeEncoding]: one Endpoint {
  encoding.encodingSign = PositiveEncoding =>
    encoding.secondEndpoint
  else
    encoding.firstEndpoint
}

pred sameSemanticEdgeTwoSignedEncodings {
  some effect: Effect,
       disj positiveEncoding, negativeEncoding: SignedEdgeEncoding | {
    positiveEncoding.encodedSource = effect
    positiveEncoding.firstEndpoint = External
    positiveEncoding.secondEndpoint = Household
    positiveEncoding.encodingSign = PositiveEncoding

    negativeEncoding.encodedSource = effect
    negativeEncoding.firstEndpoint = Household
    negativeEncoding.secondEndpoint = External
    negativeEncoding.encodingSign = NegativeEncoding

    encodedDebtor[positiveEncoding] = encodedDebtor[negativeEncoding]
    encodedCreditor[positiveEncoding] = encodedCreditor[negativeEncoding]
  }
}

// Deliberately too strong: a common source sign does not force one relation
// direction.
assert SourceSignDeterminesRelationDirection {
  all firstRelation, secondRelation: RelationUnit |
    firstRelation.relationSource.sourceSign =
      secondRelation.relationSource.sourceSign implies
      ((firstRelation.debtorEndpoint = Household and
        secondRelation.debtorEndpoint = Household)
       or
       (firstRelation.creditorEndpoint = Household and
        secondRelation.creditorEndpoint = Household))
}

// Deliberately too strong: one relation direction can occur over either source
// sign.
assert RelationDirectionDeterminesSourceSign {
  all firstRelation, secondRelation: RelationUnit |
    firstRelation.debtorEndpoint = secondRelation.debtorEndpoint and
    firstRelation.creditorEndpoint = secondRelation.creditorEndpoint implies
      firstRelation.relationSource.sourceSign =
        secondRelation.relationSource.sourceSign
}

// Deliberately too strong: source sign does not determine the bearer split.
assert SourceSignDeterminesBurdenSplit {
  all firstEffect, secondEffect: Effect |
    firstEffect.sourceSign = secondEffect.sourceSign implies
      burdenFor[firstEffect].amount = burdenFor[secondEffect].amount
}

// Deliberately too strong: sign plus endpoint order admits two raw encodings for
// the same semantic edge even after exact raw duplicate tuples are forbidden.
assert SignedEncodingUniqueForSemanticEdge {
  all firstEncoding, secondEncoding: SignedEdgeEncoding |
    firstEncoding.encodedSource = secondEncoding.encodedSource and
    encodedDebtor[firstEncoding] = encodedDebtor[secondEncoding] and
    encodedCreditor[firstEncoding] = encodedCreditor[secondEncoding] implies
      firstEncoding = secondEncoding
}

run negativeSourceReceivable for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 BurdenAllocation, exactly 2 RelationUnit, exactly 2 SignedEdgeEncoding, 6 Int
run positiveSourceReceivable for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 BurdenAllocation, exactly 2 RelationUnit, exactly 2 SignedEdgeEncoding, 6 Int
run sameSourceSignSupportsOppositeDirections for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 BurdenAllocation, exactly 2 RelationUnit, exactly 2 SignedEdgeEncoding, 6 Int
run sameRelationDirectionAcrossOppositeSourceSigns for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 BurdenAllocation, exactly 2 RelationUnit, exactly 2 SignedEdgeEncoding, 6 Int
run sameBurdenAcrossOppositeSourceSigns for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 BurdenAllocation, exactly 2 RelationUnit, exactly 2 SignedEdgeEncoding, 6 Int
run sameSemanticEdgeTwoSignedEncodings for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 BurdenAllocation, exactly 2 RelationUnit, exactly 2 SignedEdgeEncoding, 6 Int

check SourceSignDeterminesRelationDirection for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 BurdenAllocation, exactly 2 RelationUnit, exactly 2 SignedEdgeEncoding, 6 Int
check RelationDirectionDeterminesSourceSign for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 BurdenAllocation, exactly 2 RelationUnit, exactly 2 SignedEdgeEncoding, 6 Int
check SourceSignDeterminesBurdenSplit for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 BurdenAllocation, exactly 2 RelationUnit, exactly 2 SignedEdgeEncoding, 6 Int
check SignedEncodingUniqueForSemanticEdge for exactly 2 Event, exactly 3 Key, exactly 3 Effect, exactly 3 BurdenAllocation, exactly 2 RelationUnit, exactly 2 SignedEdgeEncoding, 6 Int
