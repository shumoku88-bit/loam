module experiments/observation_377_settlement_extinguishment_identity

sig Commitment {
  quantity: one Int
}

sig ExtinguishmentId {}

sig Extinguishment {
  id: one ExtinguishmentId,
  target: one Commitment,
  quantity: one Int
}

// Evidence-side correction/retraction of an extinguishment row.
//
// replacement present = corrected row
// replacement absent  = explicit retraction of erroneous extinguishment evidence
sig ExtinguishmentRevision {
  target: one ExtinguishmentId,
  replacement: lone ExtinguishmentId
}

sig World {
  commitments: set Commitment,
  extinguishments: set Extinguishment,
  revisions: set ExtinguishmentRevision
}

fact QuantityShape {
  all c: Commitment | {
    c.quantity > 0
    c.quantity <= 10
  }

  all e: Extinguishment | {
    e.quantity > 0
    e.quantity <= 10
  }
}

fun rowIds[w: World]: set ExtinguishmentId {
  w.extinguishments.id
}

fun revisionTargets[w: World]: set ExtinguishmentId {
  w.revisions.target
}

fun replacementRelation[w: World]: ExtinguishmentId -> ExtinguishmentId {
  { oldId, newId: ExtinguishmentId |
    some r: w.revisions |
      r.target = oldId and r.replacement = newId
  }
}

pred structurallyAdmissible[w: World] {
  w.extinguishments.target in w.commitments

  // Retained row identity is unique.
  all disj left, right: w.extinguishments |
    left.id != right.id

  // One evidence lifecycle decision per retained row.
  all disj left, right: w.revisions |
    left.target != right.target

  // Every revision endpoint closes over retained row identity.
  w.revisions.target in rowIds[w]
  w.revisions.replacement in rowIds[w]

  // Positive replacement is one-to-one.
  all disj left, right: w.revisions |
    some left.replacement and some right.replacement
    implies left.replacement != right.replacement

  // No self replacement and no positive replacement cycles.
  no iden & ^(replacementRelation[w])
}

fun currentExtinguishments[w: World]: set Extinguishment {
  { e: w.extinguishments | e.id not in revisionTargets[w] }
}

fun totalQuantity[rows: set Extinguishment]: one Int {
  sum e: rows | e.quantity
}

fun currentTotal[w: World]: one Int {
  totalQuantity[currentExtinguishments[w]]
}

// Deliberately identity-free projection. Multiple rows with the same target and
// quantity collapse to one coordinate.
fun coordinateView[w: World]: Commitment -> Int {
  { c: Commitment, q: Int |
    some e: w.extinguishments |
      e.target = c and e.quantity = q
  }
}

fun coordinateRemainingForRevision
    [w: World, r: ExtinguishmentRevision]: set Extinguishment {
  { e: w.extinguishments |
    all victim: w.extinguishments |
      victim.id = r.target implies
        (e.target != victim.target or e.quantity != victim.quantity)
  }
}

pred duplicateCoordinateWitness {
  some w: World,
       commitment: Commitment,
       disj first, second: Extinguishment | {
    w.commitments = commitment
    w.extinguishments = first + second
    no w.revisions

    commitment.quantity = 10
    first.target = commitment
    second.target = commitment
    first.quantity = 2
    second.quantity = 2

    structurallyAdmissible[w]
    currentTotal[w] = 4
  }
}

pred sameCoordinateDifferentMultiplicityWitness {
  some disj oneRowWorld, twoRowWorld: World,
       commitment: Commitment,
       disj first, second: Extinguishment | {
    oneRowWorld.commitments = commitment
    twoRowWorld.commitments = commitment

    oneRowWorld.extinguishments = first
    twoRowWorld.extinguishments = first + second

    no oneRowWorld.revisions
    no twoRowWorld.revisions

    commitment.quantity = 10
    first.target = commitment
    second.target = commitment
    first.quantity = 2
    second.quantity = 2

    structurallyAdmissible[oneRowWorld]
    structurallyAdmissible[twoRowWorld]

    coordinateView[oneRowWorld] = coordinateView[twoRowWorld]
    currentTotal[oneRowWorld] = 2
    currentTotal[twoRowWorld] = 4
  }
}

pred correctionWitness {
  some w: World,
       commitment: Commitment,
       disj wrong, corrected: Extinguishment,
       revision: ExtinguishmentRevision | {
    w.commitments = commitment
    w.extinguishments = wrong + corrected
    w.revisions = revision

    commitment.quantity = 10

    wrong.target = commitment
    wrong.quantity = 4

    corrected.target = commitment
    corrected.quantity = 2

    revision.target = wrong.id
    revision.replacement = corrected.id

    structurallyAdmissible[w]
    currentExtinguishments[w] = corrected
    currentTotal[w] = 2
  }
}

pred retractionWitness {
  some w: World,
       commitment: Commitment,
       wrong: Extinguishment,
       revision: ExtinguishmentRevision | {
    w.commitments = commitment
    w.extinguishments = wrong
    w.revisions = revision

    commitment.quantity = 10
    wrong.target = commitment
    wrong.quantity = 3

    revision.target = wrong.id
    no revision.replacement

    structurallyAdmissible[w]
    no currentExtinguishments[w]
    currentTotal[w] = 0
  }
}

// Two independent real-world extinguishments happen to share the same semantic
// coordinate. Retracting one erroneous row by stable identity leaves the other
// current. Coordinate-only retraction cannot express that result.
pred retractOneDuplicateCoordinateWitness {
  some w: World,
       commitment: Commitment,
       disj first, second: Extinguishment,
       revision: ExtinguishmentRevision | {
    w.commitments = commitment
    w.extinguishments = first + second
    w.revisions = revision

    commitment.quantity = 10
    first.target = commitment
    second.target = commitment
    first.quantity = 2
    second.quantity = 2

    revision.target = first.id
    no revision.replacement

    structurallyAdmissible[w]

    currentExtinguishments[w] = second
    currentTotal[w] = 2
    no coordinateRemainingForRevision[w, revision]
  }
}

assert CurrentRowsHaveUniqueIdentity {
  all w: World |
    structurallyAdmissible[w]
    implies
      all disj left, right: currentExtinguishments[w] |
        left.id != right.id
}

// Deliberately too strong. The coordinate set loses multiplicity.
assert CoordinateViewDeterminesCurrentTotal {
  all a, b: World |
    structurallyAdmissible[a] and
    structurallyAdmissible[b] and
    a.commitments = b.commitments and
    coordinateView[a] = coordinateView[b]
    implies currentTotal[a] = currentTotal[b]
}

// Deliberately too strong. If two distinct rows share target + quantity,
// coordinate-only retraction removes both while ID-based retraction can remove
// exactly one.
assert CoordinateRetractionMatchesIdentityRetraction {
  all w: World, r: w.revisions |
    structurallyAdmissible[w] and
    no r.replacement
    implies
      totalQuantity[currentExtinguishments[w]] =
        totalQuantity[coordinateRemainingForRevision[w, r]]
}

run duplicateCoordinateWitness
  for 6 but exactly 1 Commitment, exactly 2 Extinguishment,
    exactly 2 ExtinguishmentId, exactly 0 ExtinguishmentRevision,
    exactly 1 World, 8 Int

run sameCoordinateDifferentMultiplicityWitness
  for 7 but exactly 1 Commitment, exactly 2 Extinguishment,
    exactly 2 ExtinguishmentId, exactly 0 ExtinguishmentRevision,
    exactly 2 World, 8 Int

run correctionWitness
  for 7 but exactly 1 Commitment, exactly 2 Extinguishment,
    exactly 2 ExtinguishmentId, exactly 1 ExtinguishmentRevision,
    exactly 1 World, 8 Int

run retractionWitness
  for 6 but exactly 1 Commitment, exactly 1 Extinguishment,
    exactly 1 ExtinguishmentId, exactly 1 ExtinguishmentRevision,
    exactly 1 World, 8 Int

run retractOneDuplicateCoordinateWitness
  for 7 but exactly 1 Commitment, exactly 2 Extinguishment,
    exactly 2 ExtinguishmentId, exactly 1 ExtinguishmentRevision,
    exactly 1 World, 8 Int

check CurrentRowsHaveUniqueIdentity for 5 but 8 Int
check CoordinateViewDeterminesCurrentTotal for 5 but 8 Int
check CoordinateRetractionMatchesIdentityRetraction for 5 but 8 Int
