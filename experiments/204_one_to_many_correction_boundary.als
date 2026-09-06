module experiments/observation_204_one_to_many_correction_boundary

-- F113 concept-pressure probe.
--
-- Production EventCorrection is a one-target / one-replacement fact and the
-- CorrectionFrontier admission boundary rejects sibling corrections from one
-- target. EventResolution is the opposite many-parent / one-replacement shape.
--
-- This bounded model asks two separate questions:
--
-- 1. Can current Correction alone explicitly retain one parent -> two jointly
--    effective replacement identities while preserving its admitted shape?
-- 2. If not, can a separate additive refinement relation retain exactly that
--    provenance without changing Correction's meaning or admission rule?
--
-- `RefinementFact` is experiment-local vocabulary. It is not a production type
-- proposal and does not imply that every split correction should use one shape.

abstract sig Event {}
one sig Parent, ChildA, ChildB, Old, New extends Event {}

abstract sig CorrectionFact {
  target: one Event,
  replacement: one Event
}
one sig Existing, SplitLeft, SplitRight extends CorrectionFact {}

one sig RefinementFact {
  parent: one Event,
  children: some Event
}

fun correctionEdges[cs: set CorrectionFact]: Event -> Event {
  { from, to: Event |
      some c: cs |
        c.target = from and c.replacement = to }
}

fun correctionChildren[cs: set CorrectionFact, parent: Event]: set Event {
  parent.(correctionEdges[cs])
}

-- Structural fragment of current CorrectionFrontier admission relevant to F113:
-- one target has at most one replacement, one replacement at most one target,
-- and correction paths do not cycle.
pred correctionAdmissible[cs: set CorrectionFact] {
  all e: Event | lone e.(correctionEdges[cs])
  all e: Event | lone (correctionEdges[cs]).e
  no iden & ^(correctionEdges[cs])
}

pred rawSiblingF113 {
  SplitLeft.target = Parent
  SplitLeft.replacement = ChildA
  SplitRight.target = Parent
  SplitRight.replacement = ChildB
}

-- Raw sibling correction facts can name the F113 topology, but current
-- Correction admission must reject them rather than treating both as effective.
pred siblingPairRejectedByCorrectionAdmission {
  rawSiblingF113
  not correctionAdmissible[SplitLeft + SplitRight]
}

-- Deliberately impossible under current admitted Correction shape.
pred correctionOnlyJointReplacement {
  rawSiblingF113
  correctionAdmissible[SplitLeft + SplitRight]
  correctionChildren[SplitLeft + SplitRight, Parent] = ChildA + ChildB
}

assert AdmittedCorrectionNamesAtMostOneChild {
  all cs: set CorrectionFact, parent: Event |
    correctionAdmissible[cs] implies
      lone correctionChildren[cs, parent]
}

pred refinementAdmissible[r: RefinementFact] {
  r.parent not in r.children
  #r.children >= 2
}

fun refinementChildren[r: RefinementFact, parent: Event]: set Event {
  (r.parent = parent) => r.children else none
}

-- The additive candidate retains the two child identities explicitly while an
-- unrelated ordinary Correction remains admissible under its existing rules.
-- Nothing about Correction is weakened or generalized to make the split fit.
pred additiveRefinementWitness {
  Existing.target = Old
  Existing.replacement = New
  correctionAdmissible[Existing]

  RefinementFact.parent = Parent
  RefinementFact.children = ChildA + ChildB
  refinementAdmissible[RefinementFact]

  no correctionChildren[Existing, Parent]
  refinementChildren[RefinementFact, Parent] = ChildA + ChildB
}

-- With the same admitted Correction evidence, refinement provenance can still
-- be independently present or absent. Therefore the F113 relation is not
-- derivable from Correction alone.
pred sameCorrectionDifferentRefinementProvenance {
  Existing.target = Old
  Existing.replacement = New
  correctionAdmissible[Existing]

  RefinementFact.parent = Parent
  RefinementFact.children = ChildA + ChildB
  refinementAdmissible[RefinementFact]

  no correctionChildren[Existing, Parent]
  some refinementChildren[RefinementFact, Parent]
}

run rawSiblingF113 for exactly 5 Event, exactly 3 CorrectionFact, exactly 1 RefinementFact
run siblingPairRejectedByCorrectionAdmission for exactly 5 Event, exactly 3 CorrectionFact, exactly 1 RefinementFact
run correctionOnlyJointReplacement for exactly 5 Event, exactly 3 CorrectionFact, exactly 1 RefinementFact
check AdmittedCorrectionNamesAtMostOneChild for exactly 5 Event, exactly 3 CorrectionFact, exactly 1 RefinementFact
run additiveRefinementWitness for exactly 5 Event, exactly 3 CorrectionFact, exactly 1 RefinementFact
run sameCorrectionDifferentRefinementProvenance for exactly 5 Event, exactly 3 CorrectionFact, exactly 1 RefinementFact
