module experiments/observation_374_settlement_commitment_version_identity

sig CommitmentVersion {
  quantity: one Int
}

sig CommitmentRevision {
  target: one CommitmentVersion,
  replacement: one CommitmentVersion
}

sig SettlementUse {
  target: one CommitmentVersion,
  quantity: one Int
}

sig LogicalCommitment {}

sig World {
  versions: set CommitmentVersion,
  revisions: set CommitmentRevision,
  uses: set SettlementUse,
  logical: CommitmentVersion -> lone LogicalCommitment
}

fact QuantityShape {
  all version: CommitmentVersion | {
    version.quantity > 0
    version.quantity <= 10
  }

  all use: SettlementUse | {
    use.quantity > 0
    use.quantity <= 10
  }
}

fun successorRelation[w: World]: CommitmentVersion -> CommitmentVersion {
  { oldVersion, newVersion: CommitmentVersion |
    some revision: w.revisions |
      revision.target = oldVersion and
      revision.replacement = newVersion
  }
}

fun supersededVersions[w: World]: set CommitmentVersion {
  w.revisions.target
}

fun currentVersions[w: World]: set CommitmentVersion {
  w.versions - supersededVersions[w]
}

fun terminalTargets[w: World, version: CommitmentVersion]: set CommitmentVersion {
  version.*(successorRelation[w]) & currentVersions[w]
}

pred structurallyAdmissible[w: World] {
  w.revisions.target in w.versions
  w.revisions.replacement in w.versions
  w.uses.target in w.versions

  all revision: w.revisions |
    revision.target != revision.replacement

  all disj left, right: w.revisions | {
    left.target != right.target
    left.replacement != right.replacement
  }

  no iden & ^(successorRelation[w])

  all version: w.versions |
    one terminalTargets[w, version]
}

fun chasedSettledQuantity[w: World, current: CommitmentVersion]: one Int {
  sum use: {
    row: w.uses |
      current in terminalTargets[w, row.target]
  } | use.quantity
}

fun directSettledQuantity[w: World, current: CommitmentVersion]: one Int {
  sum use: {
    row: w.uses |
      row.target = current
  } | use.quantity
}

fun chasedOutstanding[w: World, current: CommitmentVersion]: one Int {
  sub[current.quantity, chasedSettledQuantity[w, current]]
}

fun directOutstanding[w: World, current: CommitmentVersion]: one Int {
  sub[current.quantity, directSettledQuantity[w, current]]
}

pred semanticallyAdmissible[w: World] {
  structurallyAdmissible[w]
  all current: currentVersions[w] |
    chasedSettledQuantity[w, current] <= current.quantity
}

pred sameOperationalEvidence[a, b: World] {
  a.versions = b.versions
  a.revisions = b.revisions
  a.uses = b.uses
}

pred benignCorrectionCarriesUse {
  some w: World,
       disj oldVersion, newVersion: CommitmentVersion,
       revision: CommitmentRevision,
       use: SettlementUse | {
    w.versions = oldVersion + newVersion
    w.revisions = revision
    w.uses = use

    oldVersion.quantity = 8
    newVersion.quantity = 10

    revision.target = oldVersion
    revision.replacement = newVersion

    use.target = oldVersion
    use.quantity = 3

    semanticallyAdmissible[w]

    chasedOutstanding[w, newVersion] = 7
    directOutstanding[w, newVersion] = 10
  }
}

pred multiStepCorrectionCarriesUse {
  some w: World,
       disj v1, v2, v3: CommitmentVersion,
       disj r1, r2: CommitmentRevision,
       use: SettlementUse | {
    w.versions = v1 + v2 + v3
    w.revisions = r1 + r2
    w.uses = use

    v1.quantity = 6
    v2.quantity = 8
    v3.quantity = 10

    r1.target = v1
    r1.replacement = v2
    r2.target = v2
    r2.replacement = v3

    use.target = v1
    use.quantity = 4

    semanticallyAdmissible[w]
    terminalTargets[w, v1] = v3
    chasedOutstanding[w, v3] = 6
  }
}

pred unsafeCarryRawWitness {
  some w: World,
       disj oldVersion, newVersion: CommitmentVersion,
       revision: CommitmentRevision,
       use: SettlementUse | {
    w.versions = oldVersion + newVersion
    w.revisions = revision
    w.uses = use

    oldVersion.quantity = 10
    newVersion.quantity = 2

    revision.target = oldVersion
    revision.replacement = newVersion

    use.target = oldVersion
    use.quantity = 3

    structurallyAdmissible[w]
    not semanticallyAdmissible[w]
    chasedSettledQuantity[w, newVersion] = 3
  }
}

pred equalPayloadIndependentVersionsRemainDistinct {
  some w: World,
       disj first, second: CommitmentVersion | {
    w.versions = first + second
    no w.revisions
    no w.uses

    first.quantity = 5
    second.quantity = 5

    semanticallyAdmissible[w]
    first in currentVersions[w]
    second in currentVersions[w]
    terminalTargets[w, first] = first
    terminalTargets[w, second] = second
  }
}

pred sameOperationalDifferentLogicalLabels {
  some disj a, b: World,
       disj oldVersion, newVersion: CommitmentVersion,
       revision: CommitmentRevision,
       use: SettlementUse,
       disj logicalA, logicalB: LogicalCommitment | {
    a.versions = oldVersion + newVersion
    b.versions = oldVersion + newVersion
    a.revisions = revision
    b.revisions = revision
    a.uses = use
    b.uses = use

    oldVersion.quantity = 8
    newVersion.quantity = 10
    revision.target = oldVersion
    revision.replacement = newVersion
    use.target = oldVersion
    use.quantity = 3

    semanticallyAdmissible[a]
    semanticallyAdmissible[b]

    oldVersion.(a.logical) = logicalA
    newVersion.(a.logical) = logicalA

    oldVersion.(b.logical) = logicalB
    newVersion.(b.logical) = logicalB

    a.logical != b.logical
    sameOperationalEvidence[a, b]

    chasedOutstanding[a, newVersion] =
      chasedOutstanding[b, newVersion]
  }
}

assert AdmittedChaseNeverOverSettles {
  all w: World, current: currentVersions[w] |
    semanticallyAdmissible[w]
    implies chasedSettledQuantity[w, current] <= current.quantity
}

assert DirectTargetingEqualsChasedTargeting {
  all w: World, current: currentVersions[w] |
    semanticallyAdmissible[w]
    implies
      directOutstanding[w, current] = chasedOutstanding[w, current]
}

assert CurrentProjectionIndependentOfLogicalLabels {
  all a, b: World |
    semanticallyAdmissible[a] and
    semanticallyAdmissible[b] and
    sameOperationalEvidence[a, b]
    implies
      all current: currentVersions[a] |
        current in currentVersions[b]
        implies
          chasedOutstanding[a, current] =
            chasedOutstanding[b, current]
}

assert OperationalEvidenceDeterminesLogicalLabels {
  all a, b: World |
    semanticallyAdmissible[a] and
    semanticallyAdmissible[b] and
    sameOperationalEvidence[a, b]
    implies a.logical = b.logical
}

run benignCorrectionCarriesUse
  for 6 but exactly 2 CommitmentVersion, exactly 1 CommitmentRevision,
    exactly 1 SettlementUse, exactly 1 World, exactly 0 LogicalCommitment, 8 Int

run multiStepCorrectionCarriesUse
  for 7 but exactly 3 CommitmentVersion, exactly 2 CommitmentRevision,
    exactly 1 SettlementUse, exactly 1 World, exactly 0 LogicalCommitment, 8 Int

run unsafeCarryRawWitness
  for 6 but exactly 2 CommitmentVersion, exactly 1 CommitmentRevision,
    exactly 1 SettlementUse, exactly 1 World, exactly 0 LogicalCommitment, 8 Int

run equalPayloadIndependentVersionsRemainDistinct
  for 5 but exactly 2 CommitmentVersion, exactly 0 CommitmentRevision,
    exactly 0 SettlementUse, exactly 1 World, exactly 0 LogicalCommitment, 8 Int

run sameOperationalDifferentLogicalLabels
  for 8 but exactly 2 CommitmentVersion, exactly 1 CommitmentRevision,
    exactly 1 SettlementUse, exactly 2 World, exactly 2 LogicalCommitment, 8 Int

check AdmittedChaseNeverOverSettles
  for 8 but 8 Int

check DirectTargetingEqualsChasedTargeting
  for 8 but 8 Int

check CurrentProjectionIndependentOfLogicalLabels
  for 8 but 8 Int

check OperationalEvidenceDeterminesLogicalLabels
  for 8 but 8 Int
