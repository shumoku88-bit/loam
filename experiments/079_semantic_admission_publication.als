module experiments/observation_079_semantic_admission_publication

abstract sig MatterKind {}
one sig ShadowProjection, CorrectionChange extends MatterKind {}

sig Matter {
  kind: one MatterKind
}

sig World {
  observed: set Matter,
  proposed: set Matter,
  checked: set Matter,
  admitted: set Matter,
  published: set Matter
}

fact BoundaryDependencies {
  all w: World | {
    w.proposed in w.observed
    w.checked in w.proposed
    w.admitted in w.checked
    w.published in w.checked
  }
}

pred shadowStopsAtCheck {
  some w: World, m: Matter | {
    m.kind = ShadowProjection
    m in w.checked
    m not in w.admitted
    m not in w.published
  }
}

pred correctionAdmittedWithoutPublication {
  some w: World, m: Matter | {
    m.kind = CorrectionChange
    m in w.admitted
    m not in w.published
  }
}

pred correctionPublishedWithoutAdmission {
  some w: World, m: Matter | {
    m.kind = CorrectionChange
    m in w.published
    m not in w.admitted
  }
}

pred correctionCrossesBothBoundaries {
  some w: World, m: Matter | {
    m.kind = CorrectionChange
    m in w.admitted
    m in w.published
  }
}

pred sameCheckedDifferentBoundaryState {
  some disj left, right: World, m: Matter | {
    left.observed = right.observed
    left.proposed = right.proposed
    left.checked = right.checked
    m in left.checked

    m in left.admitted
    m not in left.published

    m in right.published
    m not in right.admitted
  }
}

assert CheckForcesAdmission {
  all w: World, m: Matter |
    m in w.checked implies m in w.admitted
}

assert CheckForcesPublication {
  all w: World, m: Matter |
    m in w.checked implies m in w.published
}

assert AdmissionForcesPublication {
  all w: World, m: Matter |
    m in w.admitted implies m in w.published
}

assert PublicationForcesAdmission {
  all w: World, m: Matter |
    m in w.published implies m in w.admitted
}

assert CheckedStateDeterminesBoundaryState {
  all left, right: World |
    left.observed = right.observed and
    left.proposed = right.proposed and
    left.checked = right.checked implies {
      left.admitted = right.admitted
      left.published = right.published
    }
}

assert UncheckedAdmissionImpossible {
  all w: World |
    w.admitted in w.checked
}

assert UncheckedPublicationImpossible {
  all w: World |
    w.published in w.checked
}

run shadowStopsAtCheck for exactly 2 Matter, exactly 1 World
run correctionAdmittedWithoutPublication for exactly 2 Matter, exactly 1 World
run correctionPublishedWithoutAdmission for exactly 2 Matter, exactly 1 World
run correctionCrossesBothBoundaries for exactly 2 Matter, exactly 1 World
run sameCheckedDifferentBoundaryState for exactly 2 Matter, exactly 2 World

check CheckForcesAdmission for exactly 2 Matter, exactly 1 World
check CheckForcesPublication for exactly 2 Matter, exactly 1 World
check AdmissionForcesPublication for exactly 2 Matter, exactly 1 World
check PublicationForcesAdmission for exactly 2 Matter, exactly 1 World
check CheckedStateDeterminesBoundaryState for exactly 2 Matter, exactly 2 World
check UncheckedAdmissionImpossible for exactly 2 Matter, exactly 1 World
check UncheckedPublicationImpossible for exactly 2 Matter, exactly 1 World
