module experiments/observation_086_anchored_selection_evidence

sig Coordinate {}

sig Facts {
  basis: set Coordinate,
  active: set Coordinate
}

sig AnchoredQuestion {
  facts: one Facts,
  selected: set Coordinate
}

one sig Snapshot extends Facts {}
one sig LeftQuestion, RightQuestion extends AnchoredQuestion {}

fact SharedSnapshot {
  LeftQuestion.facts = Snapshot
  RightQuestion.facts = Snapshot
}

pred sameLocalEvidence[f: Facts, a, b: Coordinate] {
  (a in f.basis iff b in f.basis)
  (a in f.active iff b in f.active)
}

pred answerable[q: AnchoredQuestion] {
  q.selected in q.facts.basis
}

pred basisOnly[q: AnchoredQuestion] {
  q.selected = q.facts.basis
}

pred allRepresented[q: AnchoredQuestion] {
  q.selected = q.facts.basis + q.facts.active
}

pred samePhysicalSignatureDifferentSelection {
  #Coordinate = 3
  some disj anchored, activityOnly, laterCurrent: Coordinate | {
    Snapshot.basis = anchored
    Snapshot.active = anchored + activityOnly + laterCurrent

    anchored in LeftQuestion.selected
    activityOnly not in LeftQuestion.selected
    laterCurrent in LeftQuestion.selected

    sameLocalEvidence[Snapshot, activityOnly, laterCurrent]
  }
}

pred basisOnlyCanHideSelectedBasislessActivity {
  #Coordinate = 2
  some anchored, laterCurrent: Coordinate | {
    anchored != laterCurrent
    Snapshot.basis = anchored
    Snapshot.active = anchored + laterCurrent

    LeftQuestion.selected = anchored + laterCurrent
    laterCurrent not in Snapshot.basis
    not basisOnly[LeftQuestion]
  }
}

pred allRepresentedCanForceMissingBasis {
  #Coordinate = 2
  some anchored, activityOnly: Coordinate | {
    anchored != activityOnly
    Snapshot.basis = anchored
    Snapshot.active = anchored + activityOnly

    allRepresented[LeftQuestion]
    not answerable[LeftQuestion]
  }
}

pred sameFactsDifferentAnchoredQuestions {
  #Coordinate = 2
  Snapshot.basis = none
  Snapshot.active = Coordinate
  LeftQuestion.selected != RightQuestion.selected
  some LeftQuestion.selected
  some RightQuestion.selected
}

assert BasisOnlyQueriesAreAnswerable {
  all q: AnchoredQuestion |
    basisOnly[q] implies answerable[q]
}

assert AllRepresentedQueriesAreAnswerable {
  all q: AnchoredQuestion |
    allRepresented[q] implies answerable[q]
}

assert PhysicalFactsDetermineSelection {
  all disj a, b: AnchoredQuestion |
    a.facts = b.facts implies a.selected = b.selected
}

run samePhysicalSignatureDifferentSelection for exactly 3 Coordinate, exactly 1 Facts, exactly 2 AnchoredQuestion
run basisOnlyCanHideSelectedBasislessActivity for exactly 2 Coordinate, exactly 1 Facts, exactly 2 AnchoredQuestion
run allRepresentedCanForceMissingBasis for exactly 2 Coordinate, exactly 1 Facts, exactly 2 AnchoredQuestion
run sameFactsDifferentAnchoredQuestions for exactly 2 Coordinate, exactly 1 Facts, exactly 2 AnchoredQuestion
check BasisOnlyQueriesAreAnswerable for exactly 3 Coordinate, exactly 1 Facts, exactly 2 AnchoredQuestion
check AllRepresentedQueriesAreAnswerable for exactly 3 Coordinate, exactly 1 Facts, exactly 2 AnchoredQuestion
check PhysicalFactsDetermineSelection for exactly 3 Coordinate, exactly 1 Facts, exactly 2 AnchoredQuestion
