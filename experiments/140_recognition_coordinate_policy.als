module recognition_coordinate_policy

open util/integer

abstract sig Coordinate {}
one sig C0, C1, C2, C3, C4 extends Coordinate {}

abstract sig DateRange {
  members : set Coordinate
}
one sig ServiceRange, FirstServicePeriod, LaterServicePeriods, WholeServiceRange extends DateRange {}

one sig TimingEvidence {
  invoicedAt : one Coordinate,
  paidAt : one Coordinate,
  dueAt : one Coordinate,
  serviceRange : one DateRange,
  quantity : one Int
}

abstract sig RecognitionKind {}
one sig ImmediateKind, SpreadKind extends RecognitionKind {}

abstract sig RecognitionDefinition {
  kind : one RecognitionKind
}
one sig ImmediateDefinition, SpreadDefinition, ImmediateDefinitionCopy extends RecognitionDefinition {}

abstract sig World {
  definition : one RecognitionDefinition
}
one sig ImmediateWorld, SpreadWorld, ImmediateWorldCopy extends World {}

fact Specimen {
  ServiceRange.members = C1 + C2 + C3 + C4
  FirstServicePeriod.members = C1
  LaterServicePeriods.members = C2 + C3 + C4
  WholeServiceRange.members = ServiceRange.members

  TimingEvidence.invoicedAt = C0
  TimingEvidence.paidAt = C1
  TimingEvidence.dueAt = C2
  TimingEvidence.serviceRange = ServiceRange
  TimingEvidence.quantity = 12

  ImmediateDefinition.kind = ImmediateKind
  SpreadDefinition.kind = SpreadKind
  ImmediateDefinitionCopy.kind = ImmediateKind

  ImmediateWorld.definition = ImmediateDefinition
  SpreadWorld.definition = SpreadDefinition
  ImmediateWorldCopy.definition = ImmediateDefinitionCopy
}

fun recognisedAt[w : World, c : Coordinate] : one Int {
  (w.definition.kind = ImmediateKind)
    => ((c = C1) => TimingEvidence.quantity else 0)
    else ((c in TimingEvidence.serviceRange.members) => 3 else 0)
}

fun recognisedIn[w : World, r : DateRange] : one Int {
  sum c : r.members | recognisedAt[w, c]
}

pred sameRecognitionDefinition[d1, d2 : RecognitionDefinition] {
  d1.kind = d2.kind
}

pred sameTimingEvidenceDifferentRecognitionProjection {
  recognisedIn[ImmediateWorld, FirstServicePeriod] = 12
  recognisedIn[SpreadWorld, FirstServicePeriod] = 3

  recognisedIn[ImmediateWorld, LaterServicePeriods] = 0
  recognisedIn[SpreadWorld, LaterServicePeriods] = 9

  recognisedIn[ImmediateWorld, WholeServiceRange] = 12
  recognisedIn[SpreadWorld, WholeServiceRange] = 12
}

pred recognitionCanRemainAfterPaymentCoordinate {
  TimingEvidence.paidAt = C1
  recognisedAt[SpreadWorld, C2] = 3
  recognisedAt[SpreadWorld, C3] = 3
  recognisedAt[SpreadWorld, C4] = 3
}

pred equalDefinitionDifferentIdentitySameProjection {
  ImmediateDefinition != ImmediateDefinitionCopy
  sameRecognitionDefinition[ImmediateDefinition, ImmediateDefinitionCopy]

  all r : DateRange |
    recognisedIn[ImmediateWorld, r] = recognisedIn[ImmediateWorldCopy, r]
}

assert TimingEvidenceDeterminesRecognitionProjection {
  all w1, w2 : World, r : DateRange |
    recognisedIn[w1, r] = recognisedIn[w2, r]
}

assert PaymentCoordinateContainsAllRecognition {
  all w : World |
    recognisedAt[w, TimingEvidence.paidAt] = TimingEvidence.quantity
    and
    (all c : Coordinate - TimingEvidence.paidAt | recognisedAt[w, c] = 0)
}

assert RecognitionDefinitionDeterminesProjection {
  all w1, w2 : World |
    sameRecognitionDefinition[w1.definition, w2.definition]
    implies
    (all r : DateRange | recognisedIn[w1, r] = recognisedIn[w2, r])
}

assert WholeServiceRecognitionConservesQuantity {
  all w : World |
    recognisedIn[w, WholeServiceRange] = TimingEvidence.quantity
}

run sameTimingEvidenceDifferentRecognitionProjection for 5 Int
run recognitionCanRemainAfterPaymentCoordinate for 5 Int
run equalDefinitionDifferentIdentitySameProjection for 5 Int

check TimingEvidenceDeterminesRecognitionProjection for 5 Int
check PaymentCoordinateContainsAllRecognition for 5 Int
check RecognitionDefinitionDeterminesProjection for 5 Int
check WholeServiceRecognitionConservesQuantity for 5 Int
