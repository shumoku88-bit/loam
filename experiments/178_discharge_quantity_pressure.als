module experiments/observation_178_discharge_quantity_pressure

sig Event {}

sig RelationUnit {
  sourceEvent: one Event,
  quantity: one Int
}

// Candidate quantified discharge evidence. The Alloy atom is only a modeling
// row; Observation 178 does not assume a production DischargeId.
sig Discharge {
  event: one Event,
  target: one RelationUnit,
  quantity: one Int
}

// Deliberately weaker projection that remembers only Event -> RelationUnit.
sig BareDischarge {
  event: one Event,
  target: one RelationUnit
}

sig World {
  events: set Event,
  relations: set RelationUnit,
  discharges: set Discharge,
  bare: set BareDischarge
}

fact QuantityShape {
  all relation: RelationUnit | {
    relation.quantity > 0
    relation.quantity <= 10
  }

  all discharge: Discharge | {
    discharge.quantity > 0
    discharge.quantity <= 10
  }
}

fact WorldShape {
  all world: World | {
    world.relations.sourceEvent in world.events
    world.discharges.event in world.events
    world.discharges.target in world.relations
    world.bare.event in world.events
    world.bare.target in world.relations

    // A discharge occurrence is distinct from the Event that established the
    // open relation. No temporal ordering beyond identity distinction is added.
    all discharge: world.discharges |
      discharge.event != discharge.target.sourceEvent

    // For the current bounded query, one Event/RelationUnit pair is normalized
    // to at most one exact discharge row. This avoids needing a new row identity
    // merely to distinguish several pieces inside the same occurrence.
    all disj first, second: world.discharges |
      first.event != second.event or first.target != second.target

    // Bare evidence is exactly the pair projection of quantified discharge.
    all discharge: world.discharges |
      one pairEvidence: world.bare |
        pairEvidence.event = discharge.event and pairEvidence.target = discharge.target
    all pairEvidence: world.bare |
      one discharge: world.discharges |
        discharge.event = pairEvidence.event and discharge.target = pairEvidence.target

    // Current positive discharge evidence cannot settle more than the retained
    // RelationUnit quantity. Over-discharge is a fail-closed candidate.
    all relation: world.relations |
      (sum discharge: { d: world.discharges | d.target = relation } |
        discharge.quantity) <= relation.quantity
  }
}

fun dischargedQuantity[world: World, relation: RelationUnit]: one Int {
  sum discharge: { d: world.discharges | d.target = relation } |
    discharge.quantity
}

fun outstandingQuantity[world: World, relation: RelationUnit]: one Int {
  sub[relation.quantity, dischargedQuantity[world, relation]]
}

// What a quantity-free Event -> RelationUnit interpretation can express if the
// mere existence of a pair is treated as whole-relation settlement.
fun bareOutstandingQuantity[world: World, relation: RelationUnit]: one Int {
  (some pairEvidence: world.bare | pairEvidence.target = relation) => 0 else relation.quantity
}

pred partialQuantifiedWitness {
  some world: World,
       disj origin, receipt: Event,
       relation: RelationUnit,
       discharge: Discharge,
       pairEvidence: BareDischarge | {
    world.events = origin + receipt
    world.relations = relation
    world.discharges = discharge
    world.bare = pairEvidence

    relation.sourceEvent = origin
    relation.quantity = 10
    discharge.event = receipt
    discharge.target = relation
    discharge.quantity = 4
    pairEvidence.event = receipt
    pairEvidence.target = relation

    outstandingQuantity[world, relation] = 6
    bareOutstandingQuantity[world, relation] = 0
  }
}

pred fullAcrossTwoEventsWitness {
  some world: World,
       disj origin, receiptA, receiptB: Event,
       relation: RelationUnit,
       disj dischargeA, dischargeB: Discharge,
       disj bareA, bareB: BareDischarge | {
    world.events = origin + receiptA + receiptB
    world.relations = relation
    world.discharges = dischargeA + dischargeB
    world.bare = bareA + bareB

    relation.sourceEvent = origin
    relation.quantity = 10

    dischargeA.event = receiptA
    dischargeA.target = relation
    dischargeA.quantity = 4
    dischargeB.event = receiptB
    dischargeB.target = relation
    dischargeB.quantity = 6

    bareA.event = receiptA
    bareA.target = relation
    bareB.event = receiptB
    bareB.target = relation

    outstandingQuantity[world, relation] = 0
  }
}

pred batchEventWitness {
  some world: World,
       disj originA, originB, receipt: Event,
       disj relationA, relationB: RelationUnit,
       disj dischargeA, dischargeB: Discharge,
       disj bareA, bareB: BareDischarge | {
    world.events = originA + originB + receipt
    world.relations = relationA + relationB
    world.discharges = dischargeA + dischargeB
    world.bare = bareA + bareB

    relationA.sourceEvent = originA
    relationA.quantity = 4
    relationB.sourceEvent = originB
    relationB.quantity = 5

    dischargeA.event = receipt
    dischargeA.target = relationA
    dischargeA.quantity = 4
    dischargeB.event = receipt
    dischargeB.target = relationB
    dischargeB.quantity = 5

    bareA.event = receipt
    bareA.target = relationA
    bareB.event = receipt
    bareB.target = relationB

    outstandingQuantity[world, relationA] = 0
    outstandingQuantity[world, relationB] = 0
  }
}

// Same Event/RelationUnit pair can carry different exact discharge meaning in
// two otherwise pair-identical worlds. The quantity is therefore independent
// evidence rather than derivable from the bare correspondence.
pred sameBareDifferentOutstandingWitness {
  some disj left, right: World,
       disj origin, receipt: Event,
       relation: RelationUnit,
       disj leftDischarge, rightDischarge: Discharge,
       pairEvidence: BareDischarge | {
    left.events = right.events
    left.events = origin + receipt
    left.relations = right.relations
    left.relations = relation
    left.bare = right.bare
    left.bare = pairEvidence

    relation.sourceEvent = origin
    relation.quantity = 10
    pairEvidence.event = receipt
    pairEvidence.target = relation

    left.discharges = leftDischarge
    leftDischarge.event = receipt
    leftDischarge.target = relation
    leftDischarge.quantity = 4

    right.discharges = rightDischarge
    rightDischarge.event = receipt
    rightDischarge.target = relation
    rightDischarge.quantity = 7

    outstandingQuantity[left, relation] = 6
    outstandingQuantity[right, relation] = 3
  }
}

// Several conceptual pieces inside one later occurrence do not force several
// persisted rows when no query distinguishes them: their exact sum fits one
// Event/RelationUnit correspondence.
pred sameEventSameRelationAggregatesWitness {
  some world: World,
       disj origin, receipt: Event,
       relation: RelationUnit,
       discharge: Discharge,
       pairEvidence: BareDischarge,
       firstPiece, secondPiece: Int | {
    world.events = origin + receipt
    world.relations = relation
    world.discharges = discharge
    world.bare = pairEvidence

    relation.sourceEvent = origin
    relation.quantity = 10
    firstPiece = 2
    secondPiece = 3

    discharge.event = receipt
    discharge.target = relation
    discharge.quantity = add[firstPiece, secondPiece]
    pairEvidence.event = receipt
    pairEvidence.target = relation

    outstandingQuantity[world, relation] = 5
  }
}

// Deliberately impossible under the candidate aggregate bound.
pred overDischargeRejected {
  some world: World,
       disj origin, receiptA, receiptB: Event,
       relation: RelationUnit,
       disj dischargeA, dischargeB: Discharge,
       disj bareA, bareB: BareDischarge | {
    world.events = origin + receiptA + receiptB
    world.relations = relation
    world.discharges = dischargeA + dischargeB
    world.bare = bareA + bareB

    relation.sourceEvent = origin
    relation.quantity = 10
    dischargeA.event = receiptA
    dischargeA.target = relation
    dischargeA.quantity = 6
    dischargeB.event = receiptB
    dischargeB.target = relation
    dischargeB.quantity = 5
    bareA.event = receiptA
    bareA.target = relation
    bareB.event = receiptB
    bareB.target = relation
  }
}

assert OutstandingNeverNegative {
  all world: World, relation: world.relations |
    outstandingQuantity[world, relation] >= 0
}

assert FullyDischargedExactlyAtQuantity {
  all world: World, relation: world.relations |
    outstandingQuantity[world, relation] = 0 iff
      dischargedQuantity[world, relation] = relation.quantity
}

// Deliberately too strong: pair-only evidence loses partial-settlement amount.
assert BarePairProjectionDeterminesOutstanding {
  all left, right: World, relation: left.relations & right.relations |
    left.events = right.events and
    left.relations = right.relations and
    left.bare = right.bare
    implies
      outstandingQuantity[left, relation] = outstandingQuantity[right, relation]
}

// Deliberately too strong: a discharge can be partial.
assert AnyDischargeMeansFullySettled {
  all world: World, relation: world.relations |
    (some discharge: world.discharges | discharge.target = relation)
    implies outstandingQuantity[world, relation] = 0
}

assert OneEventRelationPairPerWorld {
  all world: World, disj first, second: world.discharges |
    first.event != second.event or first.target != second.target
}

run partialQuantifiedWitness for 4 but exactly 2 Event, exactly 1 RelationUnit, exactly 1 Discharge, exactly 1 BareDischarge, exactly 1 World, 8 Int
run fullAcrossTwoEventsWitness for 5 but exactly 3 Event, exactly 1 RelationUnit, exactly 2 Discharge, exactly 2 BareDischarge, exactly 1 World, 8 Int
run batchEventWitness for 5 but exactly 3 Event, exactly 2 RelationUnit, exactly 2 Discharge, exactly 2 BareDischarge, exactly 1 World, 8 Int
run sameBareDifferentOutstandingWitness for 5 but exactly 2 Event, exactly 1 RelationUnit, exactly 2 Discharge, exactly 1 BareDischarge, exactly 2 World, 8 Int
run sameEventSameRelationAggregatesWitness for 4 but exactly 2 Event, exactly 1 RelationUnit, exactly 1 Discharge, exactly 1 BareDischarge, exactly 1 World, 8 Int
run overDischargeRejected for 5 but exactly 3 Event, exactly 1 RelationUnit, exactly 2 Discharge, exactly 2 BareDischarge, exactly 1 World, 8 Int

check OutstandingNeverNegative for 5 but 8 Int
check FullyDischargedExactlyAtQuantity for 5 but 8 Int
check BarePairProjectionDeterminesOutstanding for 5 but 8 Int
check AnyDischargeMeansFullySettled for 5 but 8 Int
check OneEventRelationPairPerWorld for 5 but 8 Int
