module experiments/observation_076_retire_external_identity_aid

abstract sig Occurrence {}
one sig Before extends Occurrence {}
abstract sig Current extends Occurrence {}
one sig CurrentA, CurrentB extends Current {}

abstract sig Snapshot {}
one sig SameSnapshot extends Snapshot {}

abstract sig StableSourceId {}
one sig SourceIdA, SourceIdB extends StableSourceId {}

abstract sig ExternalAid {}
one sig AidA, AidB extends ExternalAid {}

abstract sig LoamId {}
one sig AdmittedId extends LoamId {}

abstract sig Authority {}
one sig SourceAuthority, LoamAuthority extends Authority {}

abstract sig World {
  snapshot: Current -> one Snapshot,
  sourceId: Occurrence -> lone StableSourceId,
  aid: Occurrence -> lone ExternalAid,
  loamId: Occurrence -> lone LoamId,
  authority: one Authority,
  needsSourceReattachment: set Occurrence,
  continuesTo: Occurrence -> lone Current,
  reconciledTo: Occurrence -> lone Current
}

one sig RetiredLeft, RetiredRight,
        SourcePromoted,
        AuthorityTransferred,
        ManualReconciliation extends World {}

fact RepresentativeVisibleShape {
  all w: World | {
    CurrentA.(w.snapshot) = SameSnapshot
    CurrentB.(w.snapshot) = SameSnapshot
  }
}

pred sourceIdentityConformance[w: World] {
  w.authority = SourceAuthority
  Before in w.needsSourceReattachment
  one Before.(w.sourceId)
  all c: Current |
    c in Before.(w.continuesTo) iff
      c.(w.sourceId) = Before.(w.sourceId)
}

pred safeCurrentReconciliation[w: World] {
  all o: w.needsSourceReattachment |
    one o.(w.reconciledTo) and
    o.(w.reconciledTo) = o.(w.continuesTo)
}

pred retiredAidAmbiguity {
  RetiredLeft.authority = SourceAuthority
  RetiredRight.authority = SourceAuthority

  Before in RetiredLeft.needsSourceReattachment
  Before in RetiredRight.needsSourceReattachment

  no RetiredLeft.aid
  no RetiredRight.aid
  no RetiredLeft.sourceId
  no RetiredRight.sourceId
  no RetiredLeft.loamId
  no RetiredRight.loamId
  no RetiredLeft.reconciledTo
  no RetiredRight.reconciledTo

  RetiredLeft.snapshot = RetiredRight.snapshot
  RetiredLeft.sourceId = RetiredRight.sourceId
  RetiredLeft.aid = RetiredRight.aid
  RetiredLeft.loamId = RetiredRight.loamId

  Before.(RetiredLeft.continuesTo) = CurrentA
  Before.(RetiredRight.continuesTo) = CurrentB
}

pred sourceIdentityExit {
  SourcePromoted.authority = SourceAuthority
  Before in SourcePromoted.needsSourceReattachment
  no SourcePromoted.aid
  no SourcePromoted.loamId
  no SourcePromoted.reconciledTo

  Before.(SourcePromoted.sourceId) = SourceIdA
  CurrentA.(SourcePromoted.sourceId) = SourceIdA
  CurrentB.(SourcePromoted.sourceId) = SourceIdB
  Before.(SourcePromoted.continuesTo) = CurrentA

  sourceIdentityConformance[SourcePromoted]
}

pred authorityTransferExit {
  AuthorityTransferred.authority = LoamAuthority
  no AuthorityTransferred.needsSourceReattachment
  no AuthorityTransferred.aid
  no AuthorityTransferred.sourceId
  no AuthorityTransferred.reconciledTo
  Before.(AuthorityTransferred.loamId) = AdmittedId
}

pred explicitReconciliationExit {
  ManualReconciliation.authority = SourceAuthority
  Before in ManualReconciliation.needsSourceReattachment
  no ManualReconciliation.aid
  no ManualReconciliation.sourceId
  no ManualReconciliation.loamId

  Before.(ManualReconciliation.continuesTo) = CurrentA
  Before.(ManualReconciliation.reconciledTo) = CurrentA
  safeCurrentReconciliation[ManualReconciliation]
}

assert RetiredAidAloneDeterminesOngoingReattachment {
  all w1, w2: World |
    w1.authority = SourceAuthority and
    w2.authority = SourceAuthority and
    Before in w1.needsSourceReattachment and
    Before in w2.needsSourceReattachment and
    no w1.aid and
    no w2.aid and
    no w1.sourceId and
    no w2.sourceId and
    no w1.reconciledTo and
    no w2.reconciledTo and
    w1.snapshot = w2.snapshot and
    w1.loamId = w2.loamId implies
      Before.(w1.continuesTo) = Before.(w2.continuesTo)
}

assert SourceIdentityMakesAidUnnecessary {
  all w1, w2: World |
    sourceIdentityConformance[w1] and
    sourceIdentityConformance[w2] and
    w1.sourceId = w2.sourceId and
    w1.snapshot = w2.snapshot implies
      Before.(w1.continuesTo) = Before.(w2.continuesTo)
}

assert NoPermanentAidForcesSourceOwnedIdentity {
  all w: World |
    no w.aid and
    (w.authority = LoamAuthority or safeCurrentReconciliation[w]) implies
      some Before.(w.sourceId)
}

assert OngoingAutomaticShadowWithoutAidNeedsStableSourceIdentityOrReconciliation {
  all w: World |
    w.authority = SourceAuthority and
    Before in w.needsSourceReattachment and
    no w.aid and
    no Before.(w.sourceId) implies
      one Before.(w.reconciledTo)
}

run retiredAidAmbiguity for exactly 2 Current, exactly 1 Snapshot, exactly 2 StableSourceId, exactly 2 ExternalAid, exactly 1 LoamId, exactly 2 Authority, exactly 5 World
run sourceIdentityExit for exactly 2 Current, exactly 1 Snapshot, exactly 2 StableSourceId, exactly 2 ExternalAid, exactly 1 LoamId, exactly 2 Authority, exactly 5 World
run authorityTransferExit for exactly 2 Current, exactly 1 Snapshot, exactly 2 StableSourceId, exactly 2 ExternalAid, exactly 1 LoamId, exactly 2 Authority, exactly 5 World
run explicitReconciliationExit for exactly 2 Current, exactly 1 Snapshot, exactly 2 StableSourceId, exactly 2 ExternalAid, exactly 1 LoamId, exactly 2 Authority, exactly 5 World
check RetiredAidAloneDeterminesOngoingReattachment for exactly 2 Current, exactly 1 Snapshot, exactly 2 StableSourceId, exactly 2 ExternalAid, exactly 1 LoamId, exactly 2 Authority, exactly 5 World
check SourceIdentityMakesAidUnnecessary for exactly 2 Current, exactly 1 Snapshot, exactly 2 StableSourceId, exactly 2 ExternalAid, exactly 1 LoamId, exactly 2 Authority, exactly 5 World
check NoPermanentAidForcesSourceOwnedIdentity for exactly 2 Current, exactly 1 Snapshot, exactly 2 StableSourceId, exactly 2 ExternalAid, exactly 1 LoamId, exactly 2 Authority, exactly 5 World
check OngoingAutomaticShadowWithoutAidNeedsStableSourceIdentityOrReconciliation for exactly 2 Current, exactly 1 Snapshot, exactly 2 StableSourceId, exactly 2 ExternalAid, exactly 1 LoamId, exactly 2 Authority, exactly 5 World
