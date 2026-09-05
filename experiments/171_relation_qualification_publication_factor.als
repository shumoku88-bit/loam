module relation_qualification_publication_factor

abstract sig Meaning {}
one sig NoEdge, HasEdge extends Meaning {}

abstract sig OpKind {}
one sig Movement, ScheduledCompletion, CorrectionReplacement,
        DateCorrection, HistoricalPublish extends OpKind {}

abstract sig Protocol {}
one sig EventLast, ValidityOnly, BulkApprovedBytes extends Protocol {}

sig Operation {
  kind: one OpKind,
  protocol: one Protocol,
  meaning: one Meaning,
  replaces: lone Operation
}

sig World {
  operations: set Operation,
  covered: set Operation,
  qualified: set Operation,
  positive: set Operation
}

fact ProtocolShape {
  all op: Operation | {
    op.kind = Movement implies op.protocol = EventLast
    op.kind = ScheduledCompletion implies op.protocol = EventLast
    op.kind = CorrectionReplacement implies op.protocol = EventLast
    op.kind = DateCorrection implies op.protocol = ValidityOnly
    op.kind = HistoricalPublish implies op.protocol = BulkApprovedBytes

    some op.replaces implies {
      op.kind = CorrectionReplacement
      op.replaces != op
    }
  }
}

fact WorldShape {
  all w: World | {
    w.covered + w.qualified + w.positive in w.operations

    -- Observation 171 candidate: one source-neutral qualification law.
    -- Publication protocol stays outside this law.
    all op: w.covered & w.qualified |
      ((op in w.positive) iff (op.meaning = HasEdge))
  }
}

pred projectedNone[w: World, op: Operation] {
  op in w.operations
  op in w.covered
  op not in w.positive
}

pred allFiveKindsShareQualificationLaw {
  some w: World |
    all opKind: OpKind | some op: w.operations | {
      op.kind = opKind
      op in w.covered
      op in w.qualified
    }
    some op: w.covered & w.qualified | op.meaning = HasEdge
    some op: w.covered & w.qualified | op.meaning = NoEdge
}

pred sameQualificationDifferentPublicationProtocols {
  some w: World, eventOp, dateOp, historicalOp: Operation | {
    eventOp + dateOp + historicalOp in w.operations
    eventOp.kind = Movement
    dateOp.kind = DateCorrection
    historicalOp.kind = HistoricalPublish
    eventOp + dateOp + historicalOp in w.covered
    eventOp + dateOp + historicalOp in w.qualified
    eventOp.meaning = NoEdge
    dateOp.meaning = NoEdge
    historicalOp.meaning = NoEdge
    no (eventOp + dateOp + historicalOp) & w.positive
    eventOp.protocol != dateOp.protocol
    dateOp.protocol != historicalOp.protocol
    eventOp.protocol != historicalOp.protocol
  }
}

pred operationKindDoesNotDetermineRelationMeaning {
  some w: World, a, b: Operation | {
    a != b
    a + b in w.operations
    a.kind = b.kind
    a + b in w.covered
    a + b in w.qualified
    a.meaning = HasEdge
    b.meaning = NoEdge
    a in w.positive
    b not in w.positive
  }
}

pred correctionReplacementNeedsFreshMeaningDecision {
  some w: World, target, replacement: Operation | {
    target != replacement
    target + replacement in w.operations
    target.kind = Movement
    replacement.kind = CorrectionReplacement
    replacement.replaces = target
    target + replacement in w.covered
    target + replacement in w.qualified

    target.meaning = HasEdge
    target in w.positive
    replacement.meaning = NoEdge
    replacement not in w.positive
  }
}

pred historicalLegacyCanStayOutsideSharedQualification {
  some w: World, op: Operation | {
    op in w.operations
    op.kind = HistoricalPublish
    op not in w.covered
    op not in w.qualified
    op.meaning = HasEdge
    op not in w.positive
  }
}

pred unqualifiedCoveredOperationCanBreakKnownNone {
  some w: World, op: Operation | {
    op in w.operations
    op in w.covered
    op not in w.qualified
    op.meaning = HasEdge
    op not in w.positive
    projectedNone[w, op]
  }
}

assert QualifiedCoveredAbsenceMeansNoEdge {
  all w: World, op: Operation |
    op in w.covered and
    op in w.qualified and
    op not in w.positive implies
      op.meaning = NoEdge
}

assert AllCoveredQualifiedMakesProjectionSound {
  all w: World |
    w.covered in w.qualified implies
      all op: w.operations |
        projectedNone[w, op] implies op.meaning = NoEdge
}

assert CoveredQualificationForcesEventLast {
  all w: World, op: Operation |
    op in w.covered and op in w.qualified implies
      op.protocol = EventLast
}

assert OperationKindDeterminesRelationMeaning {
  all w: World, a, b: Operation |
    a in w.covered and b in w.covered and
    a in w.qualified and b in w.qualified and
    a.kind = b.kind implies
      a.meaning = b.meaning
}

assert CorrectionTargetDeterminesReplacementMeaning {
  all w: World, replacement: Operation |
    replacement in w.covered and replacement in w.qualified and
    some replacement.replaces and
    replacement.replaces in w.covered and
    replacement.replaces in w.qualified implies
      replacement.meaning = replacement.replaces.meaning
}

run allFiveKindsShareQualificationLaw for 12 but exactly 5 OpKind, exactly 3 Protocol, 8 Operation, 3 World
run sameQualificationDifferentPublicationProtocols for 12 but exactly 5 OpKind, exactly 3 Protocol, 6 Operation, 3 World
run operationKindDoesNotDetermineRelationMeaning for 12 but exactly 5 OpKind, exactly 3 Protocol, 6 Operation, 3 World
run correctionReplacementNeedsFreshMeaningDecision for 12 but exactly 5 OpKind, exactly 3 Protocol, 6 Operation, 3 World
run historicalLegacyCanStayOutsideSharedQualification for 12 but exactly 5 OpKind, exactly 3 Protocol, 5 Operation, 3 World
run unqualifiedCoveredOperationCanBreakKnownNone for 12 but exactly 5 OpKind, exactly 3 Protocol, 5 Operation, 3 World

check QualifiedCoveredAbsenceMeansNoEdge for 12 but exactly 5 OpKind, exactly 3 Protocol, 8 Operation, 4 World
check AllCoveredQualifiedMakesProjectionSound for 12 but exactly 5 OpKind, exactly 3 Protocol, 8 Operation, 4 World
check CoveredQualificationForcesEventLast for 12 but exactly 5 OpKind, exactly 3 Protocol, 8 Operation, 4 World
check OperationKindDeterminesRelationMeaning for 12 but exactly 5 OpKind, exactly 3 Protocol, 8 Operation, 4 World
check CorrectionTargetDeterminesReplacementMeaning for 12 but exactly 5 OpKind, exactly 3 Protocol, 8 Operation, 4 World
