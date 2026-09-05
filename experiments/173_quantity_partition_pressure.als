module experiments/observation_173_quantity_partition_pressure

sig Event {}
sig Key {}

sig Effect {
  sourceEvent: one Event,
  sourceKey: one Key,
  magnitude: one Int
}

fact EffectShape {
  all effect: Effect | {
    effect.magnitude > 0
    effect.magnitude <= 12
  }

  all disj firstEffect, secondEffect: Effect |
    firstEffect.sourceEvent = secondEffect.sourceEvent implies
      firstEffect.sourceKey != secondEffect.sourceKey
}

abstract sig BurdenBearer {}
one sig HouseholdBearer, OutsideBearer extends BurdenBearer {}

// Observation-local known burden allocation for one Effect. The mapping carries
// exact scalar quantities directly; there is deliberately no shared
// QuantityPart / Unit identity beneath it.
sig BurdenAllocation {
  burdenSource: one Effect,
  amount: BurdenBearer -> one Int
}

fact OneKnownBurdenAllocationPerEffect {
  all effect: Effect |
    one allocation: BurdenAllocation |
      allocation.burdenSource = effect
}

fact ExactBurdenPartition {
  all allocation: BurdenAllocation | {
    all bearer: BurdenBearer |
      allocation.amount[bearer] >= 0

    (sum bearer: BurdenBearer | allocation.amount[bearer]) =
      allocation.burdenSource.magnitude
  }
}

abstract sig Endpoint {}
one sig Household extends Endpoint {}
sig ExternalEndpoint extends Endpoint {}

// Relation identity remains family-specific, as Observation 172 already
// required. Its exact quantity is anchored directly to the source Effect; it
// does not reference a generic quantity-part entity shared with burden.
sig RelationUnit {
  relationSource: one Effect,
  debtorEndpoint: one Endpoint,
  creditorEndpoint: one Endpoint,
  quantity: one Int
}

fact RelationUnitShape {
  all relation: RelationUnit | {
    relation.quantity > 0
    relation.quantity <= relation.relationSource.magnitude
    relation.debtorEndpoint != relation.creditorEndpoint

    (relation.debtorEndpoint = Household and
      relation.creditorEndpoint in ExternalEndpoint)
    or
    (relation.creditorEndpoint = Household and
      relation.debtorEndpoint in ExternalEndpoint)
  }
}

fun burdenFor[effect: Effect]: one BurdenAllocation {
  { allocation: BurdenAllocation |
    allocation.burdenSource = effect
  }
}

fun burdenCoverage[effect: Effect]: one Int {
  sum bearer: BurdenBearer | burdenFor[effect].amount[bearer]
}

fun outsideBurden[effect: Effect]: one Int {
  burdenFor[effect].amount[OutsideBearer]
}

fun householdBurden[effect: Effect]: one Int {
  burdenFor[effect].amount[HouseholdBearer]
}

fun relationUnitsFor[effect: Effect]: set RelationUnit {
  { relation: RelationUnit |
    relation.relationSource = effect
  }
}

fun relationCoverage[effect: Effect]: one Int {
  sum relation: relationUnitsFor[effect] | relation.quantity
}

// Relation units form a partial partition within the relation plane. They may
// cover none, some, or all of the source Effect, but cannot allocate more than
// the source magnitude inside that plane.
fact RelationPlaneBoundedBySource {
  all effect: Effect |
    relationCoverage[effect] <= effect.magnitude
}

// The recurring shared-cost shape can be expressed with exact scalar amounts:
// the whole source Effect is partitioned on the burden plane while only the
// outside share participates in a receivable-like relation.
pred sharedCostExactSplit {
  some effect: Effect,
       endpoint: ExternalEndpoint,
       relation: RelationUnit | {
    effect.magnitude = 10
    householdBurden[effect] = 6
    outsideBurden[effect] = 4

    relation.relationSource = effect
    relation.quantity = 4
    relation.debtorEndpoint = endpoint
    relation.creditorEndpoint = Household
    relationCoverage[effect] = 4
  }
}

// Open-relation meaning need not cover the whole Effect. The remainder is not
// a second relation merely because the burden plane is total.
pred relationCanCoverStrictSubset {
  some effect: Effect | {
    effect.magnitude = 10
    relationCoverage[effect] = 3
    relationCoverage[effect] < effect.magnitude
  }
}

// Burden and relation cuts are independent. An outside-borne quantity need not
// equal the amount currently represented by open relations.
pred burdenAndRelationCutsNeedNotCoincide {
  some effect: Effect | {
    effect.magnitude = 10
    householdBurden[effect] = 6
    outsideBurden[effect] = 4
    relationCoverage[effect] = 3
  }
}

// Two relation units can share source Effect, endpoints, and scalar quantity
// while remaining distinct relation identities. Quantity is not identity.
pred equalQuantityDoesNotCollapseRelationIdentity {
  some effect: Effect,
       endpoint: ExternalEndpoint,
       disj firstRelation, secondRelation: RelationUnit | {
    effect.magnitude = 10

    firstRelation.relationSource = effect
    secondRelation.relationSource = effect
    firstRelation.debtorEndpoint = endpoint
    secondRelation.debtorEndpoint = endpoint
    firstRelation.creditorEndpoint = Household
    secondRelation.creditorEndpoint = Household
    firstRelation.quantity = 2
    secondRelation.quantity = 2
  }
}

// Outside burden may be known even when this Effect carries no open relation.
// This preserves Observation 168's independence while using scalar quantities.
pred outsideBurdenWithoutRelation {
  some effect: Effect | {
    effect.magnitude = 10
    householdBurden[effect] = 4
    outsideBurden[effect] = 6
    no relationUnitsFor[effect]
  }
}

// A household-borne quantity may simultaneously participate in a payable-like
// relation. The same source quantity therefore carries meaning on both planes.
pred householdBurdenWithPayableOverlap {
  some effect: Effect,
       endpoint: ExternalEndpoint,
       relation: RelationUnit | {
    effect.magnitude = 10
    householdBurden[effect] = 10
    outsideBurden[effect] = 0

    relation.relationSource = effect
    relation.quantity = 10
    relation.debtorEndpoint = Household
    relation.creditorEndpoint = endpoint
  }
}

// Retained law: a known burden allocation is an exact partition of the source
// magnitude within the burden plane.
assert BurdenAllocationExactlyCoversSource {
  all effect: Effect |
    burdenCoverage[effect] = effect.magnitude
}

// Retained law: relation units may partition only up to the source magnitude
// within the relation plane.
assert RelationCoverageNeverExceedsSource {
  all effect: Effect |
    relationCoverage[effect] <= effect.magnitude
}

// Deliberately too strong: open-relation evidence need not cover every unit of
// the source Effect.
assert RelationCoverageMustEqualSource {
  all effect: Effect |
    relationCoverage[effect] = effect.magnitude
}

// Deliberately too strong: burden allocation does not determine relation
// quantity, even when the outside share happens to motivate the relation.
assert OutsideBurdenEqualsRelationCoverage {
  all effect: Effect |
    outsideBurden[effect] = relationCoverage[effect]
}

// Deliberately too strong: treating all semantic quantities as one globally
// disjoint partition double-counts the fact that burden and relation are
// independent planes over the same source quantity.
assert AllSemanticQuantitiesAreGloballyDisjoint {
  all effect: Effect |
    add[burdenCoverage[effect], relationCoverage[effect]] <= effect.magnitude
}

// Deliberately too strong: even source Effect + endpoints + exact scalar amount
// do not replace relation-unit identity.
assert EffectEndpointsAndQuantityDetermineRelationUnit {
  all firstRelation, secondRelation: RelationUnit |
    firstRelation.relationSource = secondRelation.relationSource and
    firstRelation.debtorEndpoint = secondRelation.debtorEndpoint and
    firstRelation.creditorEndpoint = secondRelation.creditorEndpoint and
    firstRelation.quantity = secondRelation.quantity implies
      firstRelation = secondRelation
}

run sharedCostExactSplit for exactly 2 Event, exactly 3 Key, exactly 2 Effect, exactly 2 BurdenAllocation, exactly 3 ExternalEndpoint, exactly 5 RelationUnit, 7 Int
run relationCanCoverStrictSubset for exactly 2 Event, exactly 3 Key, exactly 2 Effect, exactly 2 BurdenAllocation, exactly 3 ExternalEndpoint, exactly 5 RelationUnit, 7 Int
run burdenAndRelationCutsNeedNotCoincide for exactly 2 Event, exactly 3 Key, exactly 2 Effect, exactly 2 BurdenAllocation, exactly 3 ExternalEndpoint, exactly 5 RelationUnit, 7 Int
run equalQuantityDoesNotCollapseRelationIdentity for exactly 2 Event, exactly 3 Key, exactly 2 Effect, exactly 2 BurdenAllocation, exactly 3 ExternalEndpoint, exactly 5 RelationUnit, 7 Int
run outsideBurdenWithoutRelation for exactly 2 Event, exactly 3 Key, exactly 2 Effect, exactly 2 BurdenAllocation, exactly 3 ExternalEndpoint, exactly 5 RelationUnit, 7 Int
run householdBurdenWithPayableOverlap for exactly 2 Event, exactly 3 Key, exactly 2 Effect, exactly 2 BurdenAllocation, exactly 3 ExternalEndpoint, exactly 5 RelationUnit, 7 Int

check BurdenAllocationExactlyCoversSource for exactly 2 Event, exactly 3 Key, exactly 2 Effect, exactly 2 BurdenAllocation, exactly 3 ExternalEndpoint, exactly 5 RelationUnit, 7 Int
check RelationCoverageNeverExceedsSource for exactly 2 Event, exactly 3 Key, exactly 2 Effect, exactly 2 BurdenAllocation, exactly 3 ExternalEndpoint, exactly 5 RelationUnit, 7 Int
check RelationCoverageMustEqualSource for exactly 2 Event, exactly 3 Key, exactly 2 Effect, exactly 2 BurdenAllocation, exactly 3 ExternalEndpoint, exactly 5 RelationUnit, 7 Int
check OutsideBurdenEqualsRelationCoverage for exactly 2 Event, exactly 3 Key, exactly 2 Effect, exactly 2 BurdenAllocation, exactly 3 ExternalEndpoint, exactly 5 RelationUnit, 7 Int
check AllSemanticQuantitiesAreGloballyDisjoint for exactly 2 Event, exactly 3 Key, exactly 2 Effect, exactly 2 BurdenAllocation, exactly 3 ExternalEndpoint, exactly 5 RelationUnit, 7 Int
check EffectEndpointsAndQuantityDetermineRelationUnit for exactly 2 Event, exactly 3 Key, exactly 2 Effect, exactly 2 BurdenAllocation, exactly 3 ExternalEndpoint, exactly 5 RelationUnit, 7 Int
