module experiments/observation_376_settlement_commitment_authority_split

sig Commitment {
  quantity: one Int
}

// One evidence-side revision authority.
//
// replacement = one commitment  => correction / positive replacement
// replacement = none            => explicit retraction
sig CommitmentRevision {
  target: one Commitment,
  replacement: lone Commitment
}

// Physical or net fulfillment stays a distinct real-world reduction source.
sig SettlementUse {
  target: one Commitment,
  quantity: one Int
}

// Valid commitment quantity that later ceases to bind without settlement.
// This remains distinct from evidence retraction.
sig Extinguishment {
  target: one Commitment,
  quantity: one Int
}

sig World {
  commitments: set Commitment,
  revisions: set CommitmentRevision,
  settlements: set SettlementUse,
  extinguishments: set Extinguishment
}

fact QuantityShape {
  all c: Commitment | {
    c.quantity > 0
    c.quantity <= 10
  }

  all s: SettlementUse | {
    s.quantity > 0
    s.quantity <= 10
  }

  all e: Extinguishment | {
    e.quantity > 0
    e.quantity <= 10
  }
}

fun replacementRelation[w: World]: Commitment -> Commitment {
  { source, nextVersion: Commitment |
    some r: w.revisions |
      r.target = source and r.replacement = nextVersion
  }
}

fun revisionTargets[w: World]: set Commitment {
  w.revisions.target
}

fun correctionTargets[w: World]: set Commitment {
  { c: w.commitments |
    some r: w.revisions |
      r.target = c and some r.replacement
  }
}

fun retractionTargets[w: World]: set Commitment {
  { c: w.commitments |
    some r: w.revisions |
      r.target = c and no r.replacement
  }
}

fun currentCommitments[w: World]: set Commitment {
  w.commitments - revisionTargets[w]
}

// One retained historical version either resolves to one current descendant or,
// after explicit retraction, to none.
fun currentDescendant[w: World, c: Commitment]: set Commitment {
  c.*(replacementRelation[w]) & currentCommitments[w]
}

pred structurallyAdmissible[w: World] {
  w.revisions.target in w.commitments
  w.revisions.replacement in w.commitments
  w.settlements.target in w.commitments
  w.extinguishments.target in w.commitments

  // One evidence-side lifecycle decision per target version.
  all disj left, right: w.revisions |
    left.target != right.target

  // Positive replacement remains one-to-one. Retraction has no successor.
  all disj left, right: w.revisions |
    some left.replacement and some right.replacement
    implies left.replacement != right.replacement

  // No positive self replacement.
  all r: w.revisions |
    r.target not in r.replacement

  // Positive replacement lineage remains acyclic.
  no c: w.commitments |
    c in c.^(replacementRelation[w])

  // A retained historical row can never resolve to two current descendants.
  all c: w.commitments |
    lone currentDescendant[w, c]
}

fun settledQuantity[w: World, current: Commitment]: one Int {
  sum row: {
    s: w.settlements |
      current in currentDescendant[w, s.target]
  } | row.quantity
}

fun extinguishedQuantity[w: World, current: Commitment]: one Int {
  sum row: {
    e: w.extinguishments |
      current in currentDescendant[w, e.target]
  } | row.quantity
}

fun outstandingQuantity[w: World, current: Commitment]: one Int {
  sub[
    sub[current.quantity, settledQuantity[w, current]],
    extinguishedQuantity[w, current]
  ]
}

fun openQuantityForHistoricalTarget[w: World, historical: Commitment]: one Int {
  sum current: currentDescendant[w, historical] |
    outstandingQuantity[w, current]
}

pred reductionsAdmissible[w: World] {
  // Retraction removes the current semantic target. Existing dependent
  // reductions therefore cannot silently remain current after retraction.
  all s: w.settlements |
    one currentDescendant[w, s.target]

  all e: w.extinguishments |
    one currentDescendant[w, e.target]

  // Settlement and non-settlement extinguishment share the same conservation
  // boundary but retain different provenance.
  all current: currentCommitments[w] |
    add[
      settledQuantity[w, current],
      extinguishedQuantity[w, current]
    ] <= current.quantity
}

// Positive correction and no-successor retraction coexist in one revision
// authority without adding a second Retraction row family.
pred correctionWitness {
  some w: World,
       disj oldVersion, correctedVersion: Commitment,
       revision: CommitmentRevision | {
    w.commitments = oldVersion + correctedVersion
    w.revisions = revision
    no w.settlements
    no w.extinguishments

    oldVersion.quantity = 10
    correctedVersion.quantity = 7

    revision.target = oldVersion
    revision.replacement = correctedVersion

    structurallyAdmissible[w]
    currentDescendant[w, oldVersion] = correctedVersion
    oldVersion in correctionTargets[w]
    oldVersion not in retractionTargets[w]
  }
}

pred retractionWitness {
  some w: World,
       commitment: Commitment,
       revision: CommitmentRevision | {
    w.commitments = commitment
    w.revisions = revision
    no w.settlements
    no w.extinguishments

    commitment.quantity = 10

    revision.target = commitment
    no revision.replacement

    structurallyAdmissible[w]
    no currentDescendant[w, commitment]
    commitment in retractionTargets[w]
    commitment not in correctionTargets[w]
  }
}

// A correction lineage can later terminate in explicit retraction while using
// the same revision family throughout.
pred correctionThenRetractionWitness {
  some w: World,
       disj firstVersion, secondVersion: Commitment,
       disj correctionRevision, retractionRevision: CommitmentRevision | {
    w.commitments = firstVersion + secondVersion
    w.revisions = correctionRevision + retractionRevision
    no w.settlements
    no w.extinguishments

    firstVersion.quantity = 10
    secondVersion.quantity = 7

    correctionRevision.target = firstVersion
    correctionRevision.replacement = secondVersion

    retractionRevision.target = secondVersion
    no retractionRevision.replacement

    structurallyAdmissible[w]
    no currentDescendant[w, firstVersion]
    no currentDescendant[w, secondVersion]
  }
}

// A valid commitment may be only partly extinguished without settlement.
// The commitment remains current evidence and retains its original quantity.
pred partialExtinguishmentWitness {
  some w: World,
       commitment: Commitment,
       release: Extinguishment | {
    w.commitments = commitment
    no w.revisions
    no w.settlements
    w.extinguishments = release

    commitment.quantity = 10
    release.target = commitment
    release.quantity = 3

    structurallyAdmissible[w]
    reductionsAdmissible[w]

    currentDescendant[w, commitment] = commitment
    extinguishedQuantity[w, commitment] = 3
    outstandingQuantity[w, commitment] = 7
  }
}

// Full extinguishment and retraction can both produce zero open quantity, but
// they answer different historical questions.
pred fullExtinguishmentWitness {
  some w: World,
       commitment: Commitment,
       release: Extinguishment | {
    w.commitments = commitment
    no w.revisions
    no w.settlements
    w.extinguishments = release

    commitment.quantity = 10
    release.target = commitment
    release.quantity = 10

    structurallyAdmissible[w]
    reductionsAdmissible[w]

    currentDescendant[w, commitment] = commitment
    outstandingQuantity[w, commitment] = 0
    openQuantityForHistoricalTarget[w, commitment] = 0
  }
}

pred settlementPlusExtinguishmentWitness {
  some w: World,
       commitment: Commitment,
       payment: SettlementUse,
       release: Extinguishment | {
    w.commitments = commitment
    no w.revisions
    w.settlements = payment
    w.extinguishments = release

    commitment.quantity = 10

    payment.target = commitment
    payment.quantity = 2

    release.target = commitment
    release.quantity = 3

    structurallyAdmissible[w]
    reductionsAdmissible[w]

    settledQuantity[w, commitment] = 2
    extinguishedQuantity[w, commitment] = 3
    outstandingQuantity[w, commitment] = 5
  }
}

// Same retained commitment and same numeric open quantity zero, but one world
// says the commitment evidence was retracted while the other says it was valid
// and later fully extinguished.
pred sameZeroOpenDifferentAuthorityWitness {
  some disj retractionWorld, extinguishmentWorld: World,
       commitment: Commitment,
       revision: CommitmentRevision,
       release: Extinguishment | {
    commitment.quantity = 10

    retractionWorld.commitments = commitment
    retractionWorld.revisions = revision
    no retractionWorld.settlements
    no retractionWorld.extinguishments

    revision.target = commitment
    no revision.replacement

    extinguishmentWorld.commitments = commitment
    no extinguishmentWorld.revisions
    no extinguishmentWorld.settlements
    extinguishmentWorld.extinguishments = release

    release.target = commitment
    release.quantity = 10

    structurallyAdmissible[retractionWorld]
    structurallyAdmissible[extinguishmentWorld]
    reductionsAdmissible[retractionWorld]
    reductionsAdmissible[extinguishmentWorld]

    openQuantityForHistoricalTarget[retractionWorld, commitment] = 0
    openQuantityForHistoricalTarget[extinguishmentWorld, commitment] = 0

    no currentDescendant[retractionWorld, commitment]
    currentDescendant[extinguishmentWorld, commitment] = commitment
  }
}

// The optional successor representation loses no evidence-frontier distinction
// between positive correction and explicit retraction.
assert UnifiedRevisionMatchesDerivedSplitFrontier {
  all w: World |
    currentCommitments[w] =
      w.commitments - correctionTargets[w] - retractionTargets[w]
}

// A structurally valid revision can always be classified from its retained
// successor cardinality without another kind tag.
assert RevisionKindRecoverable {
  all w: World, r: w.revisions | {
    some r.replacement iff r.target in correctionTargets[w]
    no r.replacement iff r.target in retractionTargets[w]
  }
}

assert AdmittedOutstandingNeverNegative {
  all w: World |
    structurallyAdmissible[w] and reductionsAdmissible[w]
    implies
      all current: currentCommitments[w] |
        outstandingQuantity[w, current] >= 0
}

assert CurrentReductionPartition {
  all w: World |
    structurallyAdmissible[w] and reductionsAdmissible[w]
    implies
      all current: currentCommitments[w] |
        add[
          add[
            settledQuantity[w, current],
            extinguishedQuantity[w, current]
          ],
          outstandingQuantity[w, current]
        ] = current.quantity
}

// Deliberately too strong: zero open quantity does not imply that the retained
// commitment evidence was retracted. Full real-world extinguishment leaves the
// valid commitment in the evidence frontier.
assert ZeroOpenMeansNoCurrentCommitment {
  all w: World, historical: w.commitments |
    structurallyAdmissible[w] and
    reductionsAdmissible[w] and
    openQuantityForHistoricalTarget[w, historical] = 0
    implies no currentDescendant[w, historical]
}

// Deliberately too strong: a real-world extinguishment need not consume the
// whole commitment.
assert EveryExtinguishmentIsTerminal {
  all w: World, e: w.extinguishments |
    some current: currentDescendant[w, e.target] |
      e.quantity = current.quantity
}

// Deliberately too strong: with no physical settlement, every reduction in open
// quantity would have to be explainable by evidence revision alone.
// Partial extinguishment refutes this.
assert RevisionAuthorityExplainsEveryNonSettlementReduction {
  all w: World, historical: w.commitments |
    structurallyAdmissible[w] and
    reductionsAdmissible[w] and
    no w.settlements and
    openQuantityForHistoricalTarget[w, historical] > 0 and
    openQuantityForHistoricalTarget[w, historical] < historical.quantity
    implies historical in revisionTargets[w]
}

run correctionWitness
  for 6 but exactly 2 Commitment, exactly 1 CommitmentRevision,
    exactly 0 SettlementUse, exactly 0 Extinguishment, exactly 1 World, 8 Int

run retractionWitness
  for 5 but exactly 1 Commitment, exactly 1 CommitmentRevision,
    exactly 0 SettlementUse, exactly 0 Extinguishment, exactly 1 World, 8 Int

run correctionThenRetractionWitness
  for 6 but exactly 2 Commitment, exactly 2 CommitmentRevision,
    exactly 0 SettlementUse, exactly 0 Extinguishment, exactly 1 World, 8 Int

run partialExtinguishmentWitness
  for 5 but exactly 1 Commitment, exactly 0 CommitmentRevision,
    exactly 0 SettlementUse, exactly 1 Extinguishment, exactly 1 World, 8 Int

run fullExtinguishmentWitness
  for 5 but exactly 1 Commitment, exactly 0 CommitmentRevision,
    exactly 0 SettlementUse, exactly 1 Extinguishment, exactly 1 World, 8 Int

run settlementPlusExtinguishmentWitness
  for 6 but exactly 1 Commitment, exactly 0 CommitmentRevision,
    exactly 1 SettlementUse, exactly 1 Extinguishment, exactly 1 World, 8 Int

run sameZeroOpenDifferentAuthorityWitness
  for 7 but exactly 1 Commitment, exactly 1 CommitmentRevision,
    exactly 0 SettlementUse, exactly 1 Extinguishment, exactly 2 World, 8 Int

check UnifiedRevisionMatchesDerivedSplitFrontier for 6 but 8 Int
check RevisionKindRecoverable for 6 but 8 Int
check AdmittedOutstandingNeverNegative for 6 but 8 Int
check CurrentReductionPartition for 6 but 8 Int
check ZeroOpenMeansNoCurrentCommitment for 6 but 8 Int
check EveryExtinguishmentIsTerminal for 6 but 8 Int
check RevisionAuthorityExplainsEveryNonSettlementReduction for 6 but 8 Int
