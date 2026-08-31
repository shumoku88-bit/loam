module experiments/observation_075_imported_identity_ownership

abstract sig Slot {}
abstract sig BeforeSlot extends Slot {}
one sig BeforeA, BeforeB extends BeforeSlot {}
abstract sig AfterSlot extends Slot {}
one sig AfterA, AfterB extends AfterSlot {}

abstract sig Content {}
one sig ContentA, ContentB extends Content {}

abstract sig Position {}
one sig Position1, Position2 extends Position {}

abstract sig StableSourceId {}
one sig SourceId1, SourceId2 extends StableSourceId {}

abstract sig AdmissionAnchor {}
one sig Anchor1, Anchor2 extends AdmissionAnchor {}

abstract sig World {
  content: Slot -> one Content,
  position: Slot -> one Position,
  continues: BeforeSlot -> lone AfterSlot,
  sourceId: Slot -> lone StableSourceId,
  admissionAnchor: Slot -> lone AdmissionAnchor
}
one sig Left, Right extends World {}

fact RepresentativePositions {
  all w: World | {
    BeforeA.(w.position) = Position1
    BeforeB.(w.position) = Position2
    AfterA.(w.position) = Position1
    AfterB.(w.position) = Position2
  }
}

pred sameVisibleSnapshot[w1, w2: World] {
  w1.content = w2.content
  w1.position = w2.position
}

pred sourceIdentityDefinesContinuity[w: World] {
  all s: Slot | one s.(w.sourceId)

  all disj a, b: BeforeSlot |
    a.(w.sourceId) != b.(w.sourceId)

  all disj a, b: AfterSlot |
    a.(w.sourceId) != b.(w.sourceId)

  all b: BeforeSlot, a: AfterSlot |
    (b -> a in w.continues) iff
      (b.(w.sourceId) = a.(w.sourceId))
}

pred admissionAnchorDefinesContinuity[w: World] {
  all s: Slot | one s.(w.admissionAnchor)

  all disj a, b: BeforeSlot |
    a.(w.admissionAnchor) != b.(w.admissionAnchor)

  all disj a, b: AfterSlot |
    a.(w.admissionAnchor) != b.(w.admissionAnchor)

  all b: BeforeSlot, a: AfterSlot |
    (b -> a in w.continues) iff
      (b.(w.admissionAnchor) = a.(w.admissionAnchor))
}

pred duplicateSnapshotAmbiguity {
  sameVisibleSnapshot[Left, Right]

  all s: Slot |
    s.(Left.content) = ContentA

  Left.continues =
    BeforeA -> AfterA +
    BeforeB -> AfterB

  Right.continues =
    BeforeA -> AfterB +
    BeforeB -> AfterA

  no Left.sourceId
  no Right.sourceId
  no Left.admissionAnchor
  no Right.admissionAnchor
}

pred contentChangesAcrossContinuation {
  BeforeA -> AfterA in Left.continues
  BeforeA.(Left.content) = ContentA
  AfterA.(Left.content) = ContentB
}

pred positionChangesAcrossContinuation {
  BeforeA -> AfterB in Left.continues
}

pred sourceOwnedIdentitySurvivesEditAndReorder {
  sourceIdentityDefinesContinuity[Left]

  BeforeA -> AfterB in Left.continues
  BeforeA.(Left.content) = ContentA
  AfterB.(Left.content) = ContentB
}

pred externalAnchorSurvivesEditAndReorder {
  admissionAnchorDefinesContinuity[Left]

  BeforeA -> AfterB in Left.continues
  BeforeA.(Left.content) = ContentA
  AfterB.(Left.content) = ContentB
}

assert VisibleSnapshotDeterminesContinuity {
  sameVisibleSnapshot[Left, Right] implies
    Left.continues = Right.continues
}

assert ContentDeterminesStableContinuity {
  all w: World, b: BeforeSlot, a: AfterSlot |
    b -> a in w.continues implies
      b.(w.content) = a.(w.content)
}

assert PositionDeterminesStableContinuity {
  all w: World, b: BeforeSlot, a: AfterSlot |
    b -> a in w.continues implies
      b.(w.position) = a.(w.position)
}

assert StableSourceIdentityMakesContinuityDeterminate {
  Left.sourceId = Right.sourceId and
  sourceIdentityDefinesContinuity[Left] and
  sourceIdentityDefinesContinuity[Right] implies
    Left.continues = Right.continues
}

assert StableAdmissionAnchorMakesContinuityDeterminate {
  Left.admissionAnchor = Right.admissionAnchor and
  admissionAnchorDefinesContinuity[Left] and
  admissionAnchorDefinesContinuity[Right] implies
    Left.continues = Right.continues
}

run duplicateSnapshotAmbiguity for exactly 4 Slot, exactly 2 Content, exactly 2 Position, exactly 2 StableSourceId, exactly 2 AdmissionAnchor, exactly 2 World
run contentChangesAcrossContinuation for exactly 4 Slot, exactly 2 Content, exactly 2 Position, exactly 2 StableSourceId, exactly 2 AdmissionAnchor, exactly 2 World
run positionChangesAcrossContinuation for exactly 4 Slot, exactly 2 Content, exactly 2 Position, exactly 2 StableSourceId, exactly 2 AdmissionAnchor, exactly 2 World
run sourceOwnedIdentitySurvivesEditAndReorder for exactly 4 Slot, exactly 2 Content, exactly 2 Position, exactly 2 StableSourceId, exactly 2 AdmissionAnchor, exactly 2 World
run externalAnchorSurvivesEditAndReorder for exactly 4 Slot, exactly 2 Content, exactly 2 Position, exactly 2 StableSourceId, exactly 2 AdmissionAnchor, exactly 2 World
check VisibleSnapshotDeterminesContinuity for exactly 4 Slot, exactly 2 Content, exactly 2 Position, exactly 2 StableSourceId, exactly 2 AdmissionAnchor, exactly 2 World
check ContentDeterminesStableContinuity for exactly 4 Slot, exactly 2 Content, exactly 2 Position, exactly 2 StableSourceId, exactly 2 AdmissionAnchor, exactly 2 World
check PositionDeterminesStableContinuity for exactly 4 Slot, exactly 2 Content, exactly 2 Position, exactly 2 StableSourceId, exactly 2 AdmissionAnchor, exactly 2 World
check StableSourceIdentityMakesContinuityDeterminate for exactly 4 Slot, exactly 2 Content, exactly 2 Position, exactly 2 StableSourceId, exactly 2 AdmissionAnchor, exactly 2 World
check StableAdmissionAnchorMakesContinuityDeterminate for exactly 4 Slot, exactly 2 Content, exactly 2 Position, exactly 2 StableSourceId, exactly 2 AdmissionAnchor, exactly 2 World
