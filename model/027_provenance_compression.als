module model/observation_027_provenance_compression

abstract sig Meaning {}
one sig M0, MA, MB, MX extends Meaning {}

abstract sig Interpretation {}
one sig C0, KA, KB, R0 extends Interpretation {}

abstract sig OriginMark {}
one sig MarkA, MarkB extends OriginMark {}
one sig Hidden0, Hidden1 extends OriginMark {}

abstract sig Origin {
  marks: set OriginMark
}
one sig O0, O1, O2 extends Origin {}

abstract sig OriginCriterion {
  requiredMark: one OriginMark
}
one sig CriterionA, CriterionB extends OriginCriterion {}

abstract sig World {
  means: Interpretation -> one Meaning,
  offered: one Meaning,
  origin: one Origin
}

one sig Left, Right extends World {}

fun meaning[w: World, i: Interpretation]: one Meaning {
  i.(w.means)
}

fun supersedes: Interpretation -> Interpretation {
  KA->C0 + KB->C0 + R0->KA + R0->KB
}

pred terminal[i: Interpretation] {
  no i.~supersedes
}

fun frontier: set Interpretation {
  { i: Interpretation | terminal[i] }
}

fun observableMarks: set OriginMark {
  OriginCriterion.requiredMark
}

fun relevantProvenance[o: Origin]: set OriginMark {
  o.marks & observableMarks
}

fun coarseSummary[o: Origin]: one Int {
  #relevantProvenance[o]
}

fact SharedPriorMeanings {
  all w: World | {
    meaning[w, C0] = M0
    meaning[w, KA] = MA
    meaning[w, KB] = MB
  }
}

fact SharedFreshResolution {
  all w: World | {
    w.offered = MX
    w.offered not in meaning[w, KA] + meaning[w, KB]
    meaning[w, R0] = w.offered
  }
}

fact FixedAcceptanceVocabulary {
  CriterionA.requiredMark = MarkA
  CriterionB.requiredMark = MarkB
}

fact CandidateOrigins {
  O0.marks = MarkA + Hidden0
  O1.marks = MarkA + Hidden1
  O2.marks = MarkB + Hidden0
}

pred accepted[w: World, c: OriginCriterion] {
  meaning[w, R0] = MX
  c.requiredMark in relevantProvenance[w.origin]
}

pred distinctOriginSameRelevantSameAcceptance {
  Left.origin != Right.origin
  relevantProvenance[Left.origin] = relevantProvenance[Right.origin]
  all c: OriginCriterion |
    (accepted[Left, c] iff accepted[Right, c])
}

pred sameFullOriginDifferentAcceptance {
  Left.origin = Right.origin
  some c: OriginCriterion |
    (accepted[Left, c] and not accepted[Right, c]) or
    (accepted[Right, c] and not accepted[Left, c])
}

pred sameRelevantDifferentAcceptance {
  relevantProvenance[Left.origin] = relevantProvenance[Right.origin]
  some c: OriginCriterion |
    (accepted[Left, c] and not accepted[Right, c]) or
    (accepted[Right, c] and not accepted[Left, c])
}

pred sameCoarseDifferentRelevantDifferentAcceptance {
  coarseSummary[Left.origin] = coarseSummary[Right.origin]
  relevantProvenance[Left.origin] != relevantProvenance[Right.origin]
  some c: OriginCriterion |
    (accepted[Left, c] and not accepted[Right, c]) or
    (accepted[Right, c] and not accepted[Left, c])
}

assert FullOriginDeterminesAcceptance {
  Left.origin = Right.origin implies
    all c: OriginCriterion |
      (accepted[Left, c] iff accepted[Right, c])
}

assert RelevantProvenanceDeterminesAcceptance {
  relevantProvenance[Left.origin] = relevantProvenance[Right.origin] implies
    all c: OriginCriterion |
      (accepted[Left, c] iff accepted[Right, c])
}

assert CoarseSummaryDeterminesAcceptance {
  coarseSummary[Left.origin] = coarseSummary[Right.origin] implies
    all c: OriginCriterion |
      (accepted[Left, c] iff accepted[Right, c])
}

assert OriginDoesNotChangeResolutionMeaning {
  Left.offered = Right.offered implies
    meaning[Left, R0] = meaning[Right, R0]
}

assert WholeFrontierResolutionStillSettles {
  frontier = R0
}

run distinctOriginSameRelevantSameAcceptance for exactly 4 Interpretation, exactly 4 Meaning, exactly 3 Origin, exactly 4 OriginMark, exactly 2 OriginCriterion, exactly 2 World, 4 Int
run sameFullOriginDifferentAcceptance for exactly 4 Interpretation, exactly 4 Meaning, exactly 3 Origin, exactly 4 OriginMark, exactly 2 OriginCriterion, exactly 2 World, 4 Int
run sameRelevantDifferentAcceptance for exactly 4 Interpretation, exactly 4 Meaning, exactly 3 Origin, exactly 4 OriginMark, exactly 2 OriginCriterion, exactly 2 World, 4 Int
run sameCoarseDifferentRelevantDifferentAcceptance for exactly 4 Interpretation, exactly 4 Meaning, exactly 3 Origin, exactly 4 OriginMark, exactly 2 OriginCriterion, exactly 2 World, 4 Int
check FullOriginDeterminesAcceptance for exactly 4 Interpretation, exactly 4 Meaning, exactly 3 Origin, exactly 4 OriginMark, exactly 2 OriginCriterion, exactly 2 World, 4 Int
check RelevantProvenanceDeterminesAcceptance for exactly 4 Interpretation, exactly 4 Meaning, exactly 3 Origin, exactly 4 OriginMark, exactly 2 OriginCriterion, exactly 2 World, 4 Int
check CoarseSummaryDeterminesAcceptance for exactly 4 Interpretation, exactly 4 Meaning, exactly 3 Origin, exactly 4 OriginMark, exactly 2 OriginCriterion, exactly 2 World, 4 Int
check OriginDoesNotChangeResolutionMeaning for exactly 4 Interpretation, exactly 4 Meaning, exactly 3 Origin, exactly 4 OriginMark, exactly 2 OriginCriterion, exactly 2 World, 4 Int
check WholeFrontierResolutionStillSettles for exactly 4 Interpretation, exactly 4 Meaning, exactly 3 Origin, exactly 4 OriginMark, exactly 2 OriginCriterion, exactly 2 World, 4 Int
