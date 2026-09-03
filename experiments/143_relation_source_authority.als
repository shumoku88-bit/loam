module relation_source_authority

abstract sig Coordinate {}
one sig C2 extends Coordinate {}

abstract sig Measure {}
one sig ForeignMeasure, BaseMeasure extends Measure {}

abstract sig Source {}
one sig BankSource, ProviderSource, UserSource extends Source {}

abstract sig RelationValue {}
one sig V5, V6, V7 extends RelationValue {}

abstract sig RelationObservation {
  sourceMeasure : one Measure,
  targetMeasure : one Measure,
  effectiveAt : one Coordinate,
  source : one Source,
  value : one RelationValue
}
one sig BankObservation, ProviderObservation, UserObservation extends RelationObservation {}

abstract sig SelectionDefinition {
  acceptedSource : one Source
}
one sig BankSelection, ProviderSelection, UserSelection, BankSelectionCopy extends SelectionDefinition {}

abstract sig World {
  retained : set RelationObservation,
  selection : lone SelectionDefinition
}
one sig CandidateWorld, BankWorld, ProviderWorld, UserWorld, BankCopyWorld extends World {}

fact Specimen {
  all r : RelationObservation | {
    r.sourceMeasure = ForeignMeasure
    r.targetMeasure = BaseMeasure
    r.effectiveAt = C2
  }

  BankObservation.source = BankSource
  BankObservation.value = V5

  ProviderObservation.source = ProviderSource
  ProviderObservation.value = V6

  UserObservation.source = UserSource
  UserObservation.value = V7

  BankSelection.acceptedSource = BankSource
  ProviderSelection.acceptedSource = ProviderSource
  UserSelection.acceptedSource = UserSource
  BankSelectionCopy.acceptedSource = BankSource

  CandidateWorld.retained = RelationObservation
  no CandidateWorld.selection

  BankWorld.retained = RelationObservation
  BankWorld.selection = BankSelection

  ProviderWorld.retained = RelationObservation
  ProviderWorld.selection = ProviderSelection

  UserWorld.retained = RelationObservation
  UserWorld.selection = UserSelection

  BankCopyWorld.retained = RelationObservation
  BankCopyWorld.selection = BankSelectionCopy
}

fun candidatesAt[w : World, c : Coordinate] : set RelationObservation {
  { r : w.retained |
      r.effectiveAt = c
      and r.sourceMeasure = ForeignMeasure
      and r.targetMeasure = BaseMeasure }
}

fun candidateValuesAt[w : World, c : Coordinate] : set RelationValue {
  candidatesAt[w, c].value
}

fun selectedObservationsAt[w : World, c : Coordinate] : set RelationObservation {
  { r : candidatesAt[w, c] |
      some w.selection
      and r.source = w.selection.acceptedSource }
}

fun selectedValuesAt[w : World, c : Coordinate] : set RelationValue {
  selectedObservationsAt[w, c].value
}

pred sameSelectionDefinition[d1, d2 : SelectionDefinition] {
  d1.acceptedSource = d2.acceptedSource
}

pred sameCoordinateExposesSeveralSourceDistinguishedCandidates {
  # candidatesAt[CandidateWorld, C2] = 3
  # candidateValuesAt[CandidateWorld, C2] = 3
  BankObservation.source != ProviderObservation.source
  ProviderObservation.source != UserObservation.source
  BankObservation.source != UserObservation.source
}

pred sameEvidenceDifferentAuthorityDifferentScalar {
  BankWorld.retained = ProviderWorld.retained
  ProviderWorld.retained = UserWorld.retained

  selectedValuesAt[BankWorld, C2] = V5
  selectedValuesAt[ProviderWorld, C2] = V6
  selectedValuesAt[UserWorld, C2] = V7
}

pred provenanceWithoutAuthorityLeavesCandidateSetUncollapsed {
  no CandidateWorld.selection
  # candidateValuesAt[CandidateWorld, C2] = 3
  no selectedValuesAt[CandidateWorld, C2]
}

pred equalAuthorityDefinitionDifferentIdentitySameSelection {
  BankSelection != BankSelectionCopy
  sameSelectionDefinition[BankSelection, BankSelectionCopy]
  selectedValuesAt[BankWorld, C2] = selectedValuesAt[BankCopyWorld, C2]
  selectedValuesAt[BankWorld, C2] = V5
}

assert EffectiveCoordinateDeterminesOneRelationValue {
  all w : World, c : Coordinate |
    # candidateValuesAt[w, c] <= 1
}

assert ProvenanceAloneAlwaysSelectsScalar {
  all w : World, c : Coordinate |
    some candidateValuesAt[w, c]
    implies one selectedValuesAt[w, c]
}

assert EqualAuthorityDefinitionDeterminesScalar {
  all w1, w2 : World, c : Coordinate |
    some w1.selection
    and some w2.selection
    and sameSelectionDefinition[w1.selection, w2.selection]
    and w1.retained = w2.retained
    implies selectedValuesAt[w1, c] = selectedValuesAt[w2, c]
}

assert SelectedValueComesFromCandidateSetAndIsScalar {
  all w : World, c : Coordinate |
    selectedValuesAt[w, c] in candidateValuesAt[w, c]
    and # selectedValuesAt[w, c] <= 1
}

run sameCoordinateExposesSeveralSourceDistinguishedCandidates
run sameEvidenceDifferentAuthorityDifferentScalar
run provenanceWithoutAuthorityLeavesCandidateSetUncollapsed
run equalAuthorityDefinitionDifferentIdentitySameSelection

check EffectiveCoordinateDeterminesOneRelationValue
check ProvenanceAloneAlwaysSelectsScalar
check EqualAuthorityDefinitionDeterminesScalar
check SelectedValueComesFromCandidateSetAndIsScalar
