module experiments/observation_373_settlement_commitment_lifecycle

sig Commitment {
  quantity: one Int
}

// Evidence-side correction. A missing replacement is explicit retraction of the
// retained commitment row, not real-world fulfillment or release.
sig CommitmentRevision {
  target: one Commitment,
  replacement: lone Commitment
}

// Real-world disappearance of some or all of a valid commitment without
// physical settlement. A successor is allowed only when the old commitment is
// extinguished in full and a new obligation replaces it in reality.
sig Extinguishment {
  target: one Commitment,
  quantity: one Int,
  successor: lone Commitment
}

// Physical/net settlement amount is deliberately modeled separately from
// non-settlement extinguishment.
sig SettlementUse {
  target: one Commitment,
  quantity: one Int
}

sig World {
  commitments: set Commitment,
  revisions: set CommitmentRevision,
  extinguishments: set Extinguishment,
  settlements: set SettlementUse
}

fact QuantityShape {
  all commitment: Commitment | {
    commitment.quantity > 0
    commitment.quantity <= 10
  }

  all extinguishment: Extinguishment | {
    extinguishment.quantity > 0
    extinguishment.quantity <= 10
  }

  all settlement: SettlementUse | {
    settlement.quantity > 0
    settlement.quantity <= 10
  }
}

fun revisionTargets[w: World]: set Commitment {
  w.revisions.target
}

fun revisionSuccessors[w: World]: set Commitment {
  w.revisions.replacement
}

fun extinguishmentTargets[w: World]: set Commitment {
  w.extinguishments.target
}

fun fullExtinguishmentTargets[w: World]: set Commitment {
  { c: w.commitments |
    some e: w.extinguishments |
      e.target = c and e.quantity = c.quantity
  }
}

fun currentEvidenceCommitments[w: World]: set Commitment {
  w.commitments - revisionTargets[w]
}

fun settledQuantity[w: World, c: Commitment]: one Int {
  sum s: { row: w.settlements | row.target = c } | s.quantity
}

fun extinguishedQuantity[w: World, c: Commitment]: one Int {
  sum e: { row: w.extinguishments | row.target = c } | e.quantity
}

fun outstandingQuantity[w: World, c: Commitment]: one Int {
  c in revisionTargets[w] => 0 else
    sub[sub[c.quantity, settledQuantity[w, c]], extinguishedQuantity[w, c]]
}

fun totalOutstanding[w: World]: one Int {
  sum c: w.commitments | outstandingQuantity[w, c]
}

// Deliberately weaker candidate: one terminal "cancel" operation can remember
// only which commitment stops being current and, optionally, which commitment
// succeeds it. It erases whether the transition was evidence correction or a
// real-world extinguishment.
fun collapsedTerminalTargets[w: World]: set Commitment {
  revisionTargets[w] + fullExtinguishmentTargets[w]
}

fun revisionSuccessorRelation[w: World]: Commitment -> Commitment {
  { oldCommitment, newCommitment: Commitment |
    some r: w.revisions |
      r.target = oldCommitment and r.replacement = newCommitment
  }
}

fun extinguishmentSuccessorRelation[w: World]: Commitment -> Commitment {
  { oldCommitment, newCommitment: Commitment |
    some e: w.extinguishments |
      e.target = oldCommitment and e.successor = newCommitment
  }
}

fun collapsedTerminalSuccessors[w: World]: Commitment -> Commitment {
  revisionSuccessorRelation[w] + extinguishmentSuccessorRelation[w]
}

pred sameCollapsedCancelView[a, b: World] {
  a.commitments = b.commitments
  collapsedTerminalTargets[a] = collapsedTerminalTargets[b]
  collapsedTerminalSuccessors[a] = collapsedTerminalSuccessors[b]
}

pred sameReductionMeaning[a, b: World] {
  a.revisions = b.revisions
  a.extinguishments = b.extinguishments
  a.settlements = b.settlements
}

fact WorldShape {
  all w: World | {
    w.revisions.target in w.commitments
    w.revisions.replacement in w.commitments

    w.extinguishments.target in w.commitments
    w.extinguishments.successor in w.commitments

    w.settlements.target in w.commitments

    // Keep this bounded observation on one-step lifecycle changes. Structural
    // replacement graph mechanics are already owned elsewhere by LOAM.
    all disj left, right: w.revisions |
      left.target != right.target

    all revision: w.revisions | {
      revision.target not in revision.replacement
      no revision.target & revisionSuccessors[w]
    }

    // Correction/retraction and real-world extinguishment are competing semantic
    // authorities for the same target in one observation world.
    no revisionTargets[w] & extinguishmentTargets[w]
    no revisionTargets[w] & w.settlements.target

    // One row per target is enough for this bounded distinguishability question.
    all disj left, right: w.extinguishments |
      left.target != right.target
    all disj left, right: w.settlements |
      left.target != right.target

    // A successor means a real-world replacement after full extinguishment,
    // never a partial release.
    all e: w.extinguishments |
      some e.successor implies {
        e.quantity = e.target.quantity
        e.successor != e.target
      }

    // Settlement and non-settlement extinguishment can coexist, but the current
    // commitment may never be reduced below zero.
    all c: currentEvidenceCommitments[w] |
      add[settledQuantity[w, c], extinguishedQuantity[w, c]] <= c.quantity
  }
}

// A. The recorded 10 was wrong; the corrected commitment is 1.
pred correctionWitness {
  some w: World,
       disj wrong, corrected: Commitment,
       revision: CommitmentRevision | {
    w.commitments = wrong + corrected
    w.revisions = revision
    no w.extinguishments
    no w.settlements

    wrong.quantity = 10
    corrected.quantity = 1
    revision.target = wrong
    revision.replacement = corrected

    totalOutstanding[w] = 1
  }
}

// B. The commitment row itself was erroneous/duplicated and is explicitly
// retracted with no positive replacement.
pred retractionWitness {
  some w: World,
       wrong: Commitment,
       revision: CommitmentRevision | {
    w.commitments = wrong
    w.revisions = revision
    no w.extinguishments
    no w.settlements

    wrong.quantity = 10
    revision.target = wrong
    no revision.replacement

    totalOutstanding[w] = 0
  }
}

// C. The 10 commitment was valid, but later the whole obligation disappeared
// without physical settlement.
pred fullExtinguishmentWitness {
  some w: World,
       valid: Commitment,
       release: Extinguishment | {
    w.commitments = valid
    no w.revisions
    w.extinguishments = release
    no w.settlements

    valid.quantity = 10
    release.target = valid
    release.quantity = 10
    no release.successor

    totalOutstanding[w] = 0
  }
}

// D. The commitment remains valid, but only 3 of 10 is released.
pred partialExtinguishmentWitness {
  some w: World,
       valid: Commitment,
       release: Extinguishment | {
    w.commitments = valid
    no w.revisions
    w.extinguishments = release
    no w.settlements

    valid.quantity = 10
    release.target = valid
    release.quantity = 3
    no release.successor

    totalOutstanding[w] = 7
  }
}

// E. The old 10 was valid and is fully extinguished; a new real-world
// commitment of 7 succeeds it.
pred successorExtinguishmentWitness {
  some w: World,
       disj old, successor: Commitment,
       transition: Extinguishment | {
    w.commitments = old + successor
    no w.revisions
    w.extinguishments = transition
    no w.settlements

    old.quantity = 10
    successor.quantity = 7
    transition.target = old
    transition.quantity = 10
    transition.successor = successor

    totalOutstanding[w] = 7
  }
}

// The crucial counterexample: evidence correction and real-world replacement can
// have the same "cancel old -> successor" projection and the same current
// outstanding amount while answering a different historical/semantic question.
pred sameCancelDifferentMeaningWitness {
  some disj correctionWorld, realityWorld: World,
       disj old, successor: Commitment,
       revision: CommitmentRevision,
       transition: Extinguishment | {
    correctionWorld.commitments = old + successor
    realityWorld.commitments = old + successor

    old.quantity = 10
    successor.quantity = 7

    correctionWorld.revisions = revision
    no correctionWorld.extinguishments
    no correctionWorld.settlements
    revision.target = old
    revision.replacement = successor

    no realityWorld.revisions
    realityWorld.extinguishments = transition
    no realityWorld.settlements
    transition.target = old
    transition.quantity = 10
    transition.successor = successor

    sameCollapsedCancelView[correctionWorld, realityWorld]
    totalOutstanding[correctionWorld] = 7
    totalOutstanding[realityWorld] = 7

    revisionTargets[correctionWorld] = old
    no revisionTargets[realityWorld]
    fullExtinguishmentTargets[realityWorld] = old
    no fullExtinguishmentTargets[correctionWorld]
  }
}

// Payment and release can also yield the same remaining quantity. Outstanding
// alone therefore cannot reconstruct why the commitment shrank.
pred sameOutstandingSettlementVsExtinguishmentWitness {
  some disj settlementWorld, releaseWorld: World,
       commitment: Commitment,
       payment: SettlementUse,
       release: Extinguishment | {
    settlementWorld.commitments = commitment
    releaseWorld.commitments = commitment
    no settlementWorld.revisions
    no releaseWorld.revisions

    commitment.quantity = 10

    settlementWorld.settlements = payment
    no settlementWorld.extinguishments
    payment.target = commitment
    payment.quantity = 3

    no releaseWorld.settlements
    releaseWorld.extinguishments = release
    release.target = commitment
    release.quantity = 3
    no release.successor

    totalOutstanding[settlementWorld] = 7
    totalOutstanding[releaseWorld] = 7
  }
}

assert OutstandingNeverNegative {
  all w: World, c: currentEvidenceCommitments[w] |
    outstandingQuantity[w, c] >= 0
}

assert CurrentCommitmentPartition {
  all w: World, c: currentEvidenceCommitments[w] |
    add[
      add[settledQuantity[w, c], extinguishedQuantity[w, c]],
      outstandingQuantity[w, c]
    ] = c.quantity
}

// Deliberately too strong: partial non-settlement extinguishment exists, so a
// whole-target terminal cancel cannot represent every lifecycle change.
assert EveryExtinguishmentIsTerminal {
  all w: World, e: w.extinguishments |
    e.quantity = e.target.quantity
}

// Deliberately too strong: the flattened terminal target/successor view cannot
// tell evidence correction from a real-world extinguishment/replacement.
assert CollapsedCancelDeterminesLifecycleMeaning {
  all disj a, b: World |
    sameCollapsedCancelView[a, b]
    implies sameReductionMeaning[a, b]
}

// Deliberately too strong: equal outstanding does not determine whether the
// reduction came from physical settlement or non-settlement extinguishment.
assert OutstandingDeterminesReductionMeaning {
  all disj a, b: World |
    a.commitments = b.commitments and
    totalOutstanding[a] = totalOutstanding[b]
    implies sameReductionMeaning[a, b]
}

run correctionWitness for 5 but exactly 2 Commitment, exactly 1 CommitmentRevision, exactly 0 Extinguishment, exactly 0 SettlementUse, exactly 1 World, 8 Int
run retractionWitness for 4 but exactly 1 Commitment, exactly 1 CommitmentRevision, exactly 0 Extinguishment, exactly 0 SettlementUse, exactly 1 World, 8 Int
run fullExtinguishmentWitness for 4 but exactly 1 Commitment, exactly 0 CommitmentRevision, exactly 1 Extinguishment, exactly 0 SettlementUse, exactly 1 World, 8 Int
run partialExtinguishmentWitness for 4 but exactly 1 Commitment, exactly 0 CommitmentRevision, exactly 1 Extinguishment, exactly 0 SettlementUse, exactly 1 World, 8 Int
run successorExtinguishmentWitness for 5 but exactly 2 Commitment, exactly 0 CommitmentRevision, exactly 1 Extinguishment, exactly 0 SettlementUse, exactly 1 World, 8 Int
run sameCancelDifferentMeaningWitness for 6 but exactly 2 Commitment, exactly 1 CommitmentRevision, exactly 1 Extinguishment, exactly 0 SettlementUse, exactly 2 World, 8 Int
run sameOutstandingSettlementVsExtinguishmentWitness for 6 but exactly 1 Commitment, exactly 0 CommitmentRevision, exactly 1 Extinguishment, exactly 1 SettlementUse, exactly 2 World, 8 Int

check OutstandingNeverNegative for 6 but 8 Int
check CurrentCommitmentPartition for 6 but 8 Int
check EveryExtinguishmentIsTerminal for 6 but 8 Int
check CollapsedCancelDeterminesLifecycleMeaning for 6 but 8 Int
check OutstandingDeterminesReductionMeaning for 6 but 8 Int
