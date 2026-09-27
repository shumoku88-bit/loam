module experiments/observation_374_settlement_commitment_correction_targeting

sig Measure {}
one sig MeasureA, MeasureB extends Measure {}

abstract sig Direction {}
one sig DebitLike, CreditLike extends Direction {}

sig Commitment {
  quantity: one Int,
  measure: one Measure,
  direction: one Direction
}

sig CommitmentRevision {
  target: one Commitment,
  replacement: one Commitment
}

sig CommitmentRetraction {
  target: one Commitment
}

// Simplified current settlement evidence. In production the same compatibility
// pressure comes from correspondence physical Effect measure/sign and from
// netting member direction/quantity conservation.
sig SettlementUse {
  target: one Commitment,
  quantity: one Int,
  measure: one Measure,
  direction: one Direction
}

sig World {
  commitments: set Commitment,
  revisions: set CommitmentRevision,
  retractions: set CommitmentRetraction,
  uses: set SettlementUse
}

fact QuantityShape {
  all c: Commitment | {
    c.quantity > 0
    c.quantity <= 10
  }
  all u: SettlementUse | {
    u.quantity > 0
    u.quantity <= 10
  }
}

fun replacementRelation[w: World]: Commitment -> Commitment {
  { oldCommitment, newCommitment: Commitment |
    some r: w.revisions |
      r.target = oldCommitment and r.replacement = newCommitment
  }
}

fun revisedTargets[w: World]: set Commitment {
  w.revisions.target
}

fun retractedTargets[w: World]: set Commitment {
  w.retractions.target
}

fun currentCommitments[w: World]: set Commitment {
  w.commitments - revisedTargets[w] - retractedTargets[w]
}

// Resolve a retained historical commitment row through its correction lineage.
// The result may be empty after explicit retraction.
fun currentDescendant[w: World, c: Commitment]: set Commitment {
  c.*(replacementRelation[w]) & currentCommitments[w]
}

fun exactUsed[w: World, c: Commitment]: one Int {
  sum u: { row: w.uses | row.target = c } | u.quantity
}

fun followedUsed[w: World, c: Commitment]: one Int {
  sum u: { row: w.uses | c in currentDescendant[w, row.target] } | u.quantity
}

fun exactOutstanding[w: World, c: Commitment]: one Int {
  sub[c.quantity, exactUsed[w, c]]
}

fun followedOutstanding[w: World, c: Commitment]: one Int {
  sub[c.quantity, followedUsed[w, c]]
}

pred useCompatibleWithCurrent[w: World, u: SettlementUse] {
  one current: currentDescendant[w, u.target] | {
    u.measure = current.measure
    u.direction = current.direction
    u.quantity <= current.quantity
  }
}

pred qualifiedFollowAdmissible[w: World] {
  all u: w.uses | useCompatibleWithCurrent[w, u]
  all c: currentCommitments[w] |
    followedUsed[w, c] <= c.quantity
}

fact WorldShape {
  all w: World | {
    w.revisions.target in w.commitments
    w.revisions.replacement in w.commitments
    w.retractions.target in w.commitments
    w.uses.target in w.commitments

    // One linear correction lineage per retained commitment version.
    all disj first, second: w.revisions |
      first.target != second.target and
      first.replacement != second.replacement

    // Retraction is terminal authority for that version, not another positive
    // successor from the same row.
    no revisedTargets[w] & retractedTargets[w]

    // Replacement lineage is acyclic.
    no c: w.commitments | c in c.^(replacementRelation[w])

    // A retained row resolves to at most one current descendant.
    all c: w.commitments |
      lone currentDescendant[w, c]
  }
}

// A compatible typo correction should not force every dependent settlement row
// to be rewritten merely to keep the same semantic attribution.
pred compatibleCorrectionPreservesHistoricalTargetWitness {
  some w: World,
       disj oldCommitment, correctedCommitment: Commitment,
       revision: CommitmentRevision,
       use: SettlementUse | {
    w.commitments = oldCommitment + correctedCommitment
    w.revisions = revision
    no w.retractions
    w.uses = use

    oldCommitment.quantity = 10
    oldCommitment.measure = MeasureA
    oldCommitment.direction = DebitLike

    correctedCommitment.quantity = 7
    correctedCommitment.measure = MeasureA
    correctedCommitment.direction = DebitLike

    revision.target = oldCommitment
    revision.replacement = correctedCommitment

    use.target = oldCommitment
    use.quantity = 3
    use.measure = MeasureA
    use.direction = DebitLike

    qualifiedFollowAdmissible[w]

    // Exact-row binding loses the attribution after the replacement.
    exactOutstanding[w, correctedCommitment] = 7

    // Frontier-following retains it and revalidates against the current row.
    followedOutstanding[w, correctedCommitment] = 4
  }
}

// A chain of corrections must still permit old retained settlement evidence to
// resolve to the one current version without a separately stored logical ID.
pred multiVersionLineageWitness {
  some w: World,
       disj firstVersion, secondVersion, currentVersion: Commitment,
       disj firstRevision, secondRevision: CommitmentRevision,
       use: SettlementUse | {
    w.commitments = firstVersion + secondVersion + currentVersion
    w.revisions = firstRevision + secondRevision
    no w.retractions
    w.uses = use

    firstVersion.quantity = 10
    secondVersion.quantity = 9
    currentVersion.quantity = 8

    firstVersion.measure = MeasureA
    secondVersion.measure = MeasureA
    currentVersion.measure = MeasureA

    firstVersion.direction = DebitLike
    secondVersion.direction = DebitLike
    currentVersion.direction = DebitLike

    firstRevision.target = firstVersion
    firstRevision.replacement = secondVersion
    secondRevision.target = secondVersion
    secondRevision.replacement = currentVersion

    use.target = firstVersion
    use.quantity = 3
    use.measure = MeasureA
    use.direction = DebitLike

    currentDescendant[w, firstVersion] = currentVersion
    qualifiedFollowAdmissible[w]
    followedOutstanding[w, currentVersion] = 5
  }
}

// Blindly following replacement is unsafe. A correction that changes settlement
// Measure must cause retained dependent evidence to fail admission rather than
// silently moving with the replacement.
pred incompatibleMeasureCorrectionRejectedWitness {
  some w: World,
       disj oldCommitment, correctedCommitment: Commitment,
       revision: CommitmentRevision,
       use: SettlementUse | {
    w.commitments = oldCommitment + correctedCommitment
    w.revisions = revision
    no w.retractions
    w.uses = use

    oldCommitment.quantity = 10
    oldCommitment.measure = MeasureA
    oldCommitment.direction = DebitLike

    correctedCommitment.quantity = 10
    correctedCommitment.measure = MeasureB
    correctedCommitment.direction = DebitLike

    revision.target = oldCommitment
    revision.replacement = correctedCommitment

    use.target = oldCommitment
    use.quantity = 3
    use.measure = MeasureA
    use.direction = DebitLike

    followedUsed[w, correctedCommitment] = 3
    not qualifiedFollowAdmissible[w]
  }
}

// The same pressure exists when debtor/creditor direction changes.
pred incompatibleDirectionCorrectionRejectedWitness {
  some w: World,
       disj oldCommitment, correctedCommitment: Commitment,
       revision: CommitmentRevision,
       use: SettlementUse | {
    w.commitments = oldCommitment + correctedCommitment
    w.revisions = revision
    no w.retractions
    w.uses = use

    oldCommitment.quantity = 10
    oldCommitment.measure = MeasureA
    oldCommitment.direction = DebitLike

    correctedCommitment.quantity = 10
    correctedCommitment.measure = MeasureA
    correctedCommitment.direction = CreditLike

    revision.target = oldCommitment
    revision.replacement = correctedCommitment

    use.target = oldCommitment
    use.quantity = 3
    use.measure = MeasureA
    use.direction = DebitLike

    followedUsed[w, correctedCommitment] = 3
    not qualifiedFollowAdmissible[w]
  }
}

// Reducing the corrected commitment below already-attributed settlement must
// fail the whole candidate rather than produce negative outstanding.
pred overSettledCorrectionRejectedWitness {
  some w: World,
       disj oldCommitment, correctedCommitment: Commitment,
       revision: CommitmentRevision,
       use: SettlementUse | {
    w.commitments = oldCommitment + correctedCommitment
    w.revisions = revision
    no w.retractions
    w.uses = use

    oldCommitment.quantity = 10
    correctedCommitment.quantity = 2
    oldCommitment.measure = MeasureA
    correctedCommitment.measure = MeasureA
    oldCommitment.direction = DebitLike
    correctedCommitment.direction = DebitLike

    revision.target = oldCommitment
    revision.replacement = correctedCommitment

    use.target = oldCommitment
    use.quantity = 3
    use.measure = MeasureA
    use.direction = DebitLike

    not qualifiedFollowAdmissible[w]
  }
}

// Retraction deliberately resolves the historical commitment to no current
// target. Existing current settlement evidence cannot silently survive it.
pred retractionWithDependentUseRejectedWitness {
  some w: World,
       commitment: Commitment,
       retraction: CommitmentRetraction,
       use: SettlementUse | {
    w.commitments = commitment
    no w.revisions
    w.retractions = retraction
    w.uses = use

    commitment.quantity = 10
    commitment.measure = MeasureA
    commitment.direction = DebitLike

    retraction.target = commitment

    use.target = commitment
    use.quantity = 3
    use.measure = MeasureA
    use.direction = DebitLike

    no currentDescendant[w, commitment]
    not qualifiedFollowAdmissible[w]
  }
}

// Deliberately too strong: exact version identity alone loses valid dependent
// attribution across a compatible correction.
assert ExactTargetingAlwaysPreservesCompatibleAttribution {
  all w: World, oldCommitment, currentCommitment: w.commitments |
    currentCommitment in currentDescendant[w, oldCommitment] and
    qualifiedFollowAdmissible[w]
    implies
      exactUsed[w, currentCommitment] = followedUsed[w, currentCommitment]
}

// Deliberately too strong: following the replacement chain without semantic
// re-admission can accept incompatible measure/direction/quantity changes.
assert BlindReplacementFollowingIsAlwaysSafe {
  all w: World |
    (all u: w.uses | one currentDescendant[w, u.target])
    implies qualifiedFollowAdmissible[w]
}

// Candidate safety law for the middle design.
assert QualifiedFollowNeverProducesNegativeOutstanding {
  all w: World |
    qualifiedFollowAdmissible[w]
    implies
      all c: currentCommitments[w] |
        followedOutstanding[w, c] >= 0
}

// If a world is admitted, every current dependent use has one current target and
// agrees with that target's current semantic coordinates.
assert QualifiedFollowClosesCurrentTargets {
  all w: World |
    qualifiedFollowAdmissible[w]
    implies
      all u: w.uses | useCompatibleWithCurrent[w, u]
}

run compatibleCorrectionPreservesHistoricalTargetWitness
  for 6 but exactly 2 Commitment, exactly 1 CommitmentRevision,
  exactly 0 CommitmentRetraction, exactly 1 SettlementUse, exactly 1 World, 8 Int

run multiVersionLineageWitness
  for 7 but exactly 3 Commitment, exactly 2 CommitmentRevision,
  exactly 0 CommitmentRetraction, exactly 1 SettlementUse, exactly 1 World, 8 Int

run incompatibleMeasureCorrectionRejectedWitness
  for 6 but exactly 2 Commitment, exactly 1 CommitmentRevision,
  exactly 0 CommitmentRetraction, exactly 1 SettlementUse, exactly 1 World, 8 Int

run incompatibleDirectionCorrectionRejectedWitness
  for 6 but exactly 2 Commitment, exactly 1 CommitmentRevision,
  exactly 0 CommitmentRetraction, exactly 1 SettlementUse, exactly 1 World, 8 Int

run overSettledCorrectionRejectedWitness
  for 6 but exactly 2 Commitment, exactly 1 CommitmentRevision,
  exactly 0 CommitmentRetraction, exactly 1 SettlementUse, exactly 1 World, 8 Int

run retractionWithDependentUseRejectedWitness
  for 5 but exactly 1 Commitment, exactly 0 CommitmentRevision,
  exactly 1 CommitmentRetraction, exactly 1 SettlementUse, exactly 1 World, 8 Int

check ExactTargetingAlwaysPreservesCompatibleAttribution for 7 but 8 Int
check BlindReplacementFollowingIsAlwaysSafe for 7 but 8 Int
check QualifiedFollowNeverProducesNegativeOutstanding for 7 but 8 Int
check QualifiedFollowClosesCurrentTargets for 7 but 8 Int
