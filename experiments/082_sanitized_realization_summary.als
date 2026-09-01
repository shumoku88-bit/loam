module experiments/observation_082_sanitized_realization_summary

sig Plan {}
sig Event {}

abstract sig Bucket {}
one sig BeforeExact,
        BeforeQuantityDifferent,
        BeforeShapeDifferent,
        SameDayExact,
        SameDayQuantityDifferent,
        SameDayShapeDifferent,
        AfterExact,
        AfterQuantityDifferent,
        AfterShapeDifferent extends Bucket {}

sig Candidate {
  plan: one Plan,
  event: one Event,
  bucket: one Bucket
}

sig World {
  realizes: set Candidate
}

one sig Left, Right extends World {}

fact OneCandidatePerPlanEventPair {
  all p: Plan, e: Event |
    one c: Candidate | c.plan = p and c.event = e
}

fact RealizationIsPartialMatching {
  all w: World, p: Plan |
    lone { c: w.realizes | c.plan = p }
  all w: World, e: Event |
    lone { c: w.realizes | c.event = e }
}

fun bucketCount[w: World, b: Bucket]: Int {
  #{ c: w.realizes | c.bucket = b }
}

pred sameSanitizedSummary[w1, w2: World] {
  all b: Bucket |
    bucketCount[w1, b] = bucketCount[w2, b]
}

pred multiCellSummary[w: World] {
  some disj b1, b2: Bucket |
    bucketCount[w, b1] > 0 and
    bucketCount[w, b2] > 0
}

pred sameSummaryDifferentProvenance {
  #Left.realizes = 2
  #Right.realizes = 2
  sameSanitizedSummary[Left, Right]
  multiCellSummary[Left]
  Left.realizes != Right.realizes
}

assert SanitizedSummaryDeterminesRealization {
  sameSanitizedSummary[Left, Right] implies
    Left.realizes = Right.realizes
}

assert ExplicitRealizationDeterminesSanitizedSummary {
  Left.realizes = Right.realizes implies
    sameSanitizedSummary[Left, Right]
}

assert SanitizedSummaryDeterminesLinkCount {
  sameSanitizedSummary[Left, Right] implies
    #Left.realizes = #Right.realizes
}

run sameSummaryDifferentProvenance for exactly 2 Plan, exactly 2 Event, exactly 4 Candidate, exactly 2 World, 5 Int
check SanitizedSummaryDeterminesRealization for exactly 2 Plan, exactly 2 Event, exactly 4 Candidate, exactly 2 World, 5 Int
check ExplicitRealizationDeterminesSanitizedSummary for exactly 2 Plan, exactly 2 Event, exactly 4 Candidate, exactly 2 World, 5 Int
check SanitizedSummaryDeterminesLinkCount for exactly 2 Plan, exactly 2 Event, exactly 4 Candidate, exactly 2 World, 5 Int
