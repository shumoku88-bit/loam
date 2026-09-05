module experiments/observation_172_relation_endpoint_identity_pressure

sig Event {}
sig Key {}

sig Effect {
  sourceEvent: one Event,
  sourceKey: one Key
}

fact EffectKeyScopedIdentity {
  all disj firstEffect, secondEffect: Effect |
    firstEffect.sourceEvent = secondEffect.sourceEvent implies
      firstEffect.sourceKey != secondEffect.sourceKey
}

abstract sig Endpoint {}
one sig Household extends Endpoint {}
sig ExternalEndpoint extends Endpoint {}

abstract sig Side {}
one sig HouseholdSide, OutsideSide extends Side {}

fun sideOf[e: Endpoint]: one Side {
  { s: Side |
    (e = Household and s = HouseholdSide) or
    (e in ExternalEndpoint and s = OutsideSide)
  }
}

sig Label {}

sig NameFact {
  namedEndpoint: one ExternalEndpoint,
  displayLabel: one Label
}

sig RelationUnit {
  sourceEffect: one Effect,
  debtorEndpoint: one Endpoint,
  creditorEndpoint: one Endpoint
}

fact RelationDirection {
  all relation: RelationUnit |
    relation.debtorEndpoint != relation.creditorEndpoint
}

sig Discharge {
  dischargeEvent: one Event,
  relationRef: one RelationUnit
}

// One stable opaque external endpoint can connect multiple source relations.
// This is the pressure created by recurring settlement with the same friend.
pred sameEndpointAcrossMultipleOrigins {
  some external: ExternalEndpoint,
       disj firstRelation, secondRelation: RelationUnit | {
    firstRelation.sourceEffect != secondRelation.sourceEffect
    firstRelation.debtorEndpoint = external
    secondRelation.debtorEndpoint = external
    firstRelation.creditorEndpoint = Household
    secondRelation.creditorEndpoint = Household
  }
}

// Display labels are not identity. Two distinct counterparties may have the
// same presentation label without becoming the same endpoint.
pred sameDisplayLabelCanNameDistinctEndpoints {
  some disj firstEndpoint, secondEndpoint: ExternalEndpoint,
       firstName, secondName: NameFact,
       label: Label | {
    firstName != secondName
    firstName.namedEndpoint = firstEndpoint
    secondName.namedEndpoint = secondEndpoint
    firstName.displayLabel = label
    secondName.displayLabel = label
  }
}

// Renaming presentation does not require changing endpoint identity.
pred renamePreservesEndpointIdentity {
  some endpoint: ExternalEndpoint,
       disj firstName, secondName: NameFact | {
    firstName.namedEndpoint = endpoint
    secondName.namedEndpoint = endpoint
    firstName.displayLabel != secondName.displayLabel
  }
}

// Relation direction is a role in one relation, not endpoint identity.
// The same outside endpoint may owe the household in one relation and be owed
// by the household in another.
pred sameEndpointCanAppearInBothDirections {
  some endpoint: ExternalEndpoint,
       disj receivable, payable: RelationUnit | {
    receivable.debtorEndpoint = endpoint
    receivable.creditorEndpoint = Household
    payable.debtorEndpoint = Household
    payable.creditorEndpoint = endpoint
  }
}

// Coarse Household/Outside projection deliberately forgets exact counterparty.
// Different external endpoints therefore remain observationally equal at this
// aggregate side level while still being distinct identities.
pred distinctEndpointsShareCoarseOutsideProjection {
  some disj firstEndpoint, secondEndpoint: ExternalEndpoint | {
    sideOf[firstEndpoint] = OutsideSide
    sideOf[secondEndpoint] = OutsideSide
  }
}

// A discharge can name the exact open relation unit without repeating its
// counterparty endpoint. Two units may share endpoints while one later event
// discharges only one of them.
pred relationUnitIdentityIsEnoughForExactDischarge {
  some endpoint: ExternalEndpoint,
       disj firstRelation, secondRelation: RelationUnit,
       discharge: Discharge | {
    firstRelation.debtorEndpoint = endpoint
    secondRelation.debtorEndpoint = endpoint
    firstRelation.creditorEndpoint = Household
    secondRelation.creditorEndpoint = Household
    firstRelation.sourceEffect != secondRelation.sourceEffect

    discharge.relationRef = firstRelation
    discharge.relationRef != secondRelation
  }
}

// Deliberately too strong: all External endpoints collapse to the same coarse
// side, so side classification cannot identify one counterparty.
assert SideDeterminesEndpointIdentity {
  all firstEndpoint, secondEndpoint: Endpoint |
    sideOf[firstEndpoint] = sideOf[secondEndpoint] implies
      firstEndpoint = secondEndpoint
}

// Deliberately too strong: relation direction alone does not tell us which
// external counterparty participates in a receivable-like relation.
assert ReceivableDirectionDeterminesCounterparty {
  all firstRelation, secondRelation: RelationUnit |
    firstRelation.debtorEndpoint in ExternalEndpoint and
    secondRelation.debtorEndpoint in ExternalEndpoint and
    firstRelation.creditorEndpoint = Household and
    secondRelation.creditorEndpoint = Household implies
      firstRelation.debtorEndpoint = secondRelation.debtorEndpoint
}

// Deliberately too strong: identical endpoints do not identify one open unit.
// Multiple claims against the same counterparty may coexist.
assert EndpointPairDeterminesRelationUnit {
  all firstRelation, secondRelation: RelationUnit |
    firstRelation.debtorEndpoint = secondRelation.debtorEndpoint and
    firstRelation.creditorEndpoint = secondRelation.creditorEndpoint implies
      firstRelation = secondRelation
}

// Referencing one relation unit is sufficient to recover its exact endpoints;
// a Discharge does not need a second endpoint identity field merely for that.
assert RelationReferenceDeterminesDischargeEndpoints {
  all firstDischarge, secondDischarge: Discharge |
    firstDischarge.relationRef = secondDischarge.relationRef implies {
      firstDischarge.relationRef.debtorEndpoint =
        secondDischarge.relationRef.debtorEndpoint
      firstDischarge.relationRef.creditorEndpoint =
        secondDischarge.relationRef.creditorEndpoint
    }
}

run sameEndpointAcrossMultipleOrigins for exactly 3 Event, exactly 3 Key, exactly 4 Effect, exactly 4 ExternalEndpoint, exactly 4 Label, exactly 4 NameFact, exactly 6 RelationUnit, exactly 3 Discharge
run sameDisplayLabelCanNameDistinctEndpoints for exactly 3 Event, exactly 3 Key, exactly 4 Effect, exactly 4 ExternalEndpoint, exactly 4 Label, exactly 5 NameFact, exactly 5 RelationUnit, exactly 3 Discharge
run renamePreservesEndpointIdentity for exactly 3 Event, exactly 3 Key, exactly 4 Effect, exactly 4 ExternalEndpoint, exactly 4 Label, exactly 5 NameFact, exactly 5 RelationUnit, exactly 3 Discharge
run sameEndpointCanAppearInBothDirections for exactly 3 Event, exactly 3 Key, exactly 4 Effect, exactly 4 ExternalEndpoint, exactly 4 Label, exactly 4 NameFact, exactly 6 RelationUnit, exactly 3 Discharge
run distinctEndpointsShareCoarseOutsideProjection for exactly 3 Event, exactly 3 Key, exactly 4 Effect, exactly 4 ExternalEndpoint, exactly 4 Label, exactly 4 NameFact, exactly 5 RelationUnit, exactly 3 Discharge
run relationUnitIdentityIsEnoughForExactDischarge for exactly 3 Event, exactly 3 Key, exactly 4 Effect, exactly 4 ExternalEndpoint, exactly 4 Label, exactly 4 NameFact, exactly 6 RelationUnit, exactly 3 Discharge

check SideDeterminesEndpointIdentity for exactly 3 Event, exactly 3 Key, exactly 4 Effect, exactly 4 ExternalEndpoint, exactly 4 Label, exactly 4 NameFact, exactly 6 RelationUnit, exactly 3 Discharge
check ReceivableDirectionDeterminesCounterparty for exactly 3 Event, exactly 3 Key, exactly 4 Effect, exactly 4 ExternalEndpoint, exactly 4 Label, exactly 4 NameFact, exactly 6 RelationUnit, exactly 3 Discharge
check EndpointPairDeterminesRelationUnit for exactly 3 Event, exactly 3 Key, exactly 4 Effect, exactly 4 ExternalEndpoint, exactly 4 Label, exactly 4 NameFact, exactly 6 RelationUnit, exactly 3 Discharge
check RelationReferenceDeterminesDischargeEndpoints for exactly 3 Event, exactly 3 Key, exactly 4 Effect, exactly 4 ExternalEndpoint, exactly 4 Label, exactly 4 NameFact, exactly 6 RelationUnit, exactly 4 Discharge
