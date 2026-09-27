module experiments/observation_374_settlement_commitment_identity

sig CommitmentVersion {}

sig CommitmentRevision {
  target: one CommitmentVersion,
  replacement: one CommitmentVersion
}

// Existing direct correspondence / netting member targets are abstracted here as
// retained references to one exact commitment row identity.
sig SettlementReference {
  target: one CommitmentVersion
}

// Retraction remains semantically distinct from replacement. It closes a current
// commitment lineage without inventing a successor row.
sig CommitmentRetraction {
  target: one CommitmentVersion
}

sig World {
  versions: set CommitmentVersion,
  revisions: set CommitmentRevision,
  references: set SettlementReference,
  retractions: set CommitmentRetraction
}

fun successorRel[w: World]: CommitmentVersion -> CommitmentVersion {
  { source, nextVersion: CommitmentVersion |
    some r: w.revisions |
      r.target = source and r.replacement = nextVersion
  }
}

fun superseded[w: World]: set CommitmentVersion {
  w.revisions.target
}

fun terminalVersions[w: World]: set CommitmentVersion {
  { version: w.versions |
    no version.(successorRel[w])
  }
}

fun retractedVersions[w: World]: set CommitmentVersion {
  w.retractions.target
}

// Current projection for any retained commitment version.
//
// No separately stored logical identity is used. One-to-one acyclic replacement
// lineage plus optional terminal retraction determines whether that lineage has
// a current version and, if so, which exact retained row it is.
fun currentVersionOf[w: World, version: CommitmentVersion]: lone CommitmentVersion {
  { terminal: w.versions |
    terminal in version.*(successorRel[w])
    and terminal in terminalVersions[w]
    and terminal not in retractedVersions[w]
  }
}

pred sameLineage[w: World, left, right: CommitmentVersion] {
  some left.*(successorRel[w]) & right.*(successorRel[w])
}

fun resolvedReferenceTarget[w: World, reference: SettlementReference]:
    lone CommitmentVersion {
  currentVersionOf[w, reference.target]
}

// Deliberately weaker current projection: preserve only references whose exact
// stored target is itself current. This models the tempting implementation that
// adds a commitment frontier but does not resolve old settlement targets through
// the commitment revision lineage.
fun exactCurrentReferences[w: World]: set SettlementReference {
  { reference: w.references |
    reference.target in terminalVersions[w]
    and reference.target not in retractedVersions[w]
  }
}

fun resolvedCurrentReferences[w: World]: set SettlementReference {
  { reference: w.references |
    some resolvedReferenceTarget[w, reference]
  }
}

fact WorldShape {
  all w: World | {
    w.revisions.target in w.versions
    w.revisions.replacement in w.versions
    w.references.target in w.versions
    w.retractions.target in w.versions

    // Same structural shape already qualified by ReplacementFrontier:
    // finite partial injection, no merge, no sibling successor conflict.
    all disj left, right: w.revisions | {
      left.target != right.target
      left.replacement != right.replacement
    }

    all revision: w.revisions |
      revision.target != revision.replacement

    // Acyclic replacement lineage.
    no version: w.versions |
      version in version.^(successorRel[w])

    // Retraction is terminal evidence. A superseded historical version cannot
    // also be the current retraction target.
    all retraction: w.retractions |
      no retraction.target.(successorRel[w])

    all disj left, right: w.retractions |
      left.target != right.target
  }
}

// One old reference survives a commitment correction without rewriting the
// reference row itself.
pred oldReferenceFollowsCorrectionWitness {
  some w: World,
       disj oldVersion, newVersion: CommitmentVersion,
       revision: CommitmentRevision,
       reference: SettlementReference | {
    w.versions = oldVersion + newVersion
    w.revisions = revision
    w.references = reference
    no w.retractions

    revision.target = oldVersion
    revision.replacement = newVersion
    reference.target = oldVersion

    resolvedReferenceTarget[w, reference] = newVersion
  }
}

// References recorded before and after correction coalesce on the same current
// commitment lineage.
pred mixedVersionReferencesCoalesceWitness {
  some w: World,
       disj oldVersion, newVersion: CommitmentVersion,
       revision: CommitmentRevision,
       disj oldReference, newReference: SettlementReference | {
    w.versions = oldVersion + newVersion
    w.revisions = revision
    w.references = oldReference + newReference
    no w.retractions

    revision.target = oldVersion
    revision.replacement = newVersion
    oldReference.target = oldVersion
    newReference.target = newVersion

    resolvedReferenceTarget[w, oldReference] = newVersion
    resolvedReferenceTarget[w, newReference] = newVersion
  }
}

// A correction chain can continue more than one step without adding a stored
// logical commitment identifier.
pred multiStepLineageWitness {
  some w: World,
       disj v1, v2, v3: CommitmentVersion,
       disj r12, r23: CommitmentRevision,
       reference: SettlementReference | {
    w.versions = v1 + v2 + v3
    w.revisions = r12 + r23
    w.references = reference
    no w.retractions

    r12.target = v1
    r12.replacement = v2
    r23.target = v2
    r23.replacement = v3
    reference.target = v1

    resolvedReferenceTarget[w, reference] = v3
  }
}

// Retraction after correction closes the whole lineage for current projection,
// including old references, without rewriting historical reference rows.
pred correctedThenRetractedWitness {
  some w: World,
       disj oldVersion, newVersion: CommitmentVersion,
       revision: CommitmentRevision,
       retraction: CommitmentRetraction,
       disj oldReference, newReference: SettlementReference | {
    w.versions = oldVersion + newVersion
    w.revisions = revision
    w.references = oldReference + newReference
    w.retractions = retraction

    revision.target = oldVersion
    revision.replacement = newVersion
    retraction.target = newVersion

    oldReference.target = oldVersion
    newReference.target = newVersion

    no resolvedReferenceTarget[w, oldReference]
    no resolvedReferenceTarget[w, newReference]
  }
}

// Independent one-to-one lineages remain distinguishable.
pred independentLineagesStayDistinctWitness {
  some w: World,
       disj oldA, newA, oldB, newB: CommitmentVersion,
       disj revisionA, revisionB: CommitmentRevision,
       disj referenceA, referenceB: SettlementReference | {
    w.versions = oldA + newA + oldB + newB
    w.revisions = revisionA + revisionB
    w.references = referenceA + referenceB
    no w.retractions

    revisionA.target = oldA
    revisionA.replacement = newA
    revisionB.target = oldB
    revisionB.replacement = newB

    referenceA.target = oldA
    referenceB.target = oldB

    resolvedReferenceTarget[w, referenceA] = newA
    resolvedReferenceTarget[w, referenceB] = newB
    newA != newB
  }
}

// The exact-target-only projection loses valid pre-correction references. This
// is the production pressure: commitment revisions require reference resolution
// through the lineage if old settlement evidence is meant to remain attached.
pred exactTargetProjectionDropsOldReferenceWitness {
  some w: World,
       disj oldVersion, newVersion: CommitmentVersion,
       revision: CommitmentRevision,
       reference: SettlementReference | {
    w.versions = oldVersion + newVersion
    w.revisions = revision
    w.references = reference
    no w.retractions

    revision.target = oldVersion
    revision.replacement = newVersion
    reference.target = oldVersion

    reference not in exactCurrentReferences[w]
    reference in resolvedCurrentReferences[w]
  }
}

// Deliberately impossible under one-to-one successor identity. Two historical
// roots cannot merge into one replacement row, because that would make lineage
// identity ambiguous.
pred mergeWouldAmbiguateLineage {
  some w: World,
       disj oldA, oldB, merged: CommitmentVersion,
       disj leftRevision, rightRevision: CommitmentRevision | {
    w.versions = oldA + oldB + merged
    w.revisions = leftRevision + rightRevision

    leftRevision.target = oldA
    leftRevision.replacement = merged
    rightRevision.target = oldB
    rightRevision.replacement = merged
  }
}

// Deliberately impossible under the acyclic lineage law.
pred cycleWouldDestroyCurrentIdentity {
  some w: World,
       disj first, second: CommitmentVersion,
       disj forward, backward: CommitmentRevision | {
    w.versions = first + second
    w.revisions = forward + backward

    forward.target = first
    forward.replacement = second
    backward.target = second
    backward.replacement = first
  }
}

assert CurrentVersionIsUnique {
  all w: World, version: w.versions |
    lone currentVersionOf[w, version]
}

assert SameLineageSharesCurrentProjection {
  all w: World, left, right: w.versions |
    sameLineage[w, left, right]
    implies currentVersionOf[w, left] = currentVersionOf[w, right]
}

assert ReferenceResolutionPreservesLineage {
  all w: World, reference: w.references |
    some resolvedReferenceTarget[w, reference]
    implies sameLineage[
      w,
      reference.target,
      resolvedReferenceTarget[w, reference]
    ]
}

// Deliberately too strong. A correction can leave an old exact target
// superseded while lineage resolution still keeps the reference current.
assert ExactTargetProjectionIsEnough {
  all w: World |
    exactCurrentReferences[w] = resolvedCurrentReferences[w]
}

run oldReferenceFollowsCorrectionWitness
  for exactly 2 CommitmentVersion, exactly 1 CommitmentRevision,
      exactly 1 SettlementReference, exactly 0 CommitmentRetraction,
      exactly 1 World

run mixedVersionReferencesCoalesceWitness
  for exactly 2 CommitmentVersion, exactly 1 CommitmentRevision,
      exactly 2 SettlementReference, exactly 0 CommitmentRetraction,
      exactly 1 World

run multiStepLineageWitness
  for exactly 3 CommitmentVersion, exactly 2 CommitmentRevision,
      exactly 1 SettlementReference, exactly 0 CommitmentRetraction,
      exactly 1 World

run correctedThenRetractedWitness
  for exactly 2 CommitmentVersion, exactly 1 CommitmentRevision,
      exactly 2 SettlementReference, exactly 1 CommitmentRetraction,
      exactly 1 World

run independentLineagesStayDistinctWitness
  for exactly 4 CommitmentVersion, exactly 2 CommitmentRevision,
      exactly 2 SettlementReference, exactly 0 CommitmentRetraction,
      exactly 1 World

run exactTargetProjectionDropsOldReferenceWitness
  for exactly 2 CommitmentVersion, exactly 1 CommitmentRevision,
      exactly 1 SettlementReference, exactly 0 CommitmentRetraction,
      exactly 1 World

run mergeWouldAmbiguateLineage
  for exactly 3 CommitmentVersion, exactly 2 CommitmentRevision,
      exactly 0 SettlementReference, exactly 0 CommitmentRetraction,
      exactly 1 World

run cycleWouldDestroyCurrentIdentity
  for exactly 2 CommitmentVersion, exactly 2 CommitmentRevision,
      exactly 0 SettlementReference, exactly 0 CommitmentRetraction,
      exactly 1 World

check CurrentVersionIsUnique
  for 6 CommitmentVersion, 5 CommitmentRevision,
      5 SettlementReference, 2 CommitmentRetraction, 2 World

check SameLineageSharesCurrentProjection
  for 6 CommitmentVersion, 5 CommitmentRevision,
      5 SettlementReference, 2 CommitmentRetraction, 2 World

check ReferenceResolutionPreservesLineage
  for 6 CommitmentVersion, 5 CommitmentRevision,
      5 SettlementReference, 2 CommitmentRetraction, 2 World

check ExactTargetProjectionIsEnough
  for 5 CommitmentVersion, 4 CommitmentRevision,
      4 SettlementReference, 2 CommitmentRetraction, 2 World
