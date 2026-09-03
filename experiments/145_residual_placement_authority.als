module residual_placement_authority

abstract sig WholeValue {}
one sig WholeZero extends WholeValue {}

abstract sig ResidualValue {}
one sig ResidualOne extends ResidualValue {}

abstract sig Piece {
  whole : one WholeValue,
  residual : one ResidualValue
}
one sig A, B, C extends Piece {}

abstract sig PlacementDefinition {
  carrier : one Piece
}
one sig PlaceA, PlaceB, PlaceC, PlaceACopy extends PlacementDefinition {}

abstract sig World {
  retained : set Piece,
  placement : lone PlacementDefinition
}
one sig CandidateWorld, AWorld, BWorld, CWorld, ACopyWorld extends World {}

fact SymmetricOneCarrySpecimen {
  all p : Piece | {
    p.whole = WholeZero
    p.residual = ResidualOne
  }

  PlaceA.carrier = A
  PlaceB.carrier = B
  PlaceC.carrier = C
  PlaceACopy.carrier = A

  CandidateWorld.retained = Piece
  no CandidateWorld.placement

  AWorld.retained = Piece
  AWorld.placement = PlaceA

  BWorld.retained = Piece
  BWorld.placement = PlaceB

  CWorld.retained = Piece
  CWorld.placement = PlaceC

  ACopyWorld.retained = Piece
  ACopyWorld.placement = PlaceACopy
}

/--
Observation 144 already proved the arithmetic outside this bounded model:
three independent 1/3 conversions may expose three residual units whose
normalized aggregate contains one target quantum. In this symmetric specimen,
any retained piece is therefore a mathematically admissible carrier for that
one visible quantum.
-/
fun candidateCarriers[w : World] : set Piece {
  w.retained
}

fun selectedCarrier[w : World] : set Piece {
  w.placement.carrier
}

pred samePlacementMeaning[d1, d2 : PlacementDefinition] {
  d1.carrier = d2.carrier
}

pred sameExactResidualSeveralPlacements {
  # candidateCarriers[CandidateWorld] = 3
  A in candidateCarriers[CandidateWorld]
  B in candidateCarriers[CandidateWorld]
  C in candidateCarriers[CandidateWorld]
}

pred sameEvidenceDifferentPlacementAuthority {
  AWorld.retained = BWorld.retained
  BWorld.retained = CWorld.retained

  selectedCarrier[AWorld] = A
  selectedCarrier[BWorld] = B
  selectedCarrier[CWorld] = C
}

pred noPlacementAuthorityLeavesCarrierUnselected {
  no CandidateWorld.placement
  # candidateCarriers[CandidateWorld] = 3
  no selectedCarrier[CandidateWorld]
}

pred equalPlacementMeaningDifferentIdentitySameCarrier {
  PlaceA != PlaceACopy
  samePlacementMeaning[PlaceA, PlaceACopy]
  selectedCarrier[AWorld] = selectedCarrier[ACopyWorld]
  selectedCarrier[AWorld] = A
}

assert ExactResidualEvidenceAloneDeterminesOneCarrier {
  all w : World |
    some candidateCarriers[w]
    implies one selectedCarrier[w]
}

assert SameRetainedEvidenceForcesSameCarrier {
  all disj w1, w2 : World |
    w1.retained = w2.retained
    implies selectedCarrier[w1] = selectedCarrier[w2]
}

assert EqualPlacementMeaningDeterminesCarrier {
  all w1, w2 : World |
    some w1.placement
    and some w2.placement
    and w1.retained = w2.retained
    and samePlacementMeaning[w1.placement, w2.placement]
    implies selectedCarrier[w1] = selectedCarrier[w2]
}

assert SelectedCarrierComesFromCandidatesAndIsScalar {
  all w : World |
    selectedCarrier[w] in candidateCarriers[w]
    and # selectedCarrier[w] <= 1
}

run sameExactResidualSeveralPlacements
run sameEvidenceDifferentPlacementAuthority
run noPlacementAuthorityLeavesCarrierUnselected
run equalPlacementMeaningDifferentIdentitySameCarrier

check ExactResidualEvidenceAloneDeterminesOneCarrier
check SameRetainedEvidenceForcesSameCarrier
check EqualPlacementMeaningDeterminesCarrier
check SelectedCarrierComesFromCandidatesAndIsScalar
