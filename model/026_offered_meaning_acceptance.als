module model/observation_026_offered_meaning_acceptance

abstract sig Meaning {}
one sig M0, MA, MB, MX extends Meaning {}

abstract sig Interpretation {}
one sig C0, KA, KB, R0 extends Interpretation {}

abstract sig Origin {}
one sig O0, O1 extends Origin {}

one sig ContentCriterion {
  requiredMeaning: one Meaning
}

one sig OriginCriterion {
  requiredOrigin: one Origin
}

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

fact FixedCriteria {
  ContentCriterion.requiredMeaning = MX
  OriginCriterion.requiredOrigin = O0
}

pred acceptedByContent[w: World] {
  w.offered = ContentCriterion.requiredMeaning
}

pred acceptedByOrigin[w: World] {
  acceptedByContent[w]
  w.origin = OriginCriterion.requiredOrigin
}

pred sameOfferedDifferentOriginDifferentAcceptance {
  Left.offered = Right.offered
  Left.origin != Right.origin
  (acceptedByOrigin[Left] and not acceptedByOrigin[Right]) or
  (acceptedByOrigin[Right] and not acceptedByOrigin[Left])
}

pred sameOfferedSameOriginDifferentAcceptance {
  Left.offered = Right.offered
  Left.origin = Right.origin
  (acceptedByOrigin[Left] and not acceptedByOrigin[Right]) or
  (acceptedByOrigin[Right] and not acceptedByOrigin[Left])
}

pred sameResolutionDifferentAcceptance {
  meaning[Left, R0] = meaning[Right, R0]
  (acceptedByOrigin[Left] and not acceptedByOrigin[Right]) or
  (acceptedByOrigin[Right] and not acceptedByOrigin[Left])
}

pred sameOfferedDifferentOriginSameContentAcceptance {
  Left.offered = Right.offered
  Left.origin != Right.origin
  acceptedByContent[Left]
  acceptedByContent[Right]
}

assert OfferedMeaningDeterminesContentAcceptance {
  Left.offered = Right.offered implies
    (acceptedByContent[Left] iff acceptedByContent[Right])
}

assert OfferedMeaningDeterminesOriginAcceptance {
  Left.offered = Right.offered implies
    (acceptedByOrigin[Left] iff acceptedByOrigin[Right])
}

assert OfferedMeaningAndOriginDetermineOriginAcceptance {
  Left.offered = Right.offered and Left.origin = Right.origin implies
    (acceptedByOrigin[Left] iff acceptedByOrigin[Right])
}

assert OriginDoesNotChangeResolutionMeaning {
  Left.offered = Right.offered implies
    meaning[Left, R0] = meaning[Right, R0]
}

assert WholeFrontierResolutionStillSettles {
  frontier = R0
}

run sameOfferedDifferentOriginDifferentAcceptance for exactly 4 Interpretation, exactly 4 Meaning, exactly 2 Origin, exactly 2 World
run sameOfferedSameOriginDifferentAcceptance for exactly 4 Interpretation, exactly 4 Meaning, exactly 2 Origin, exactly 2 World
run sameResolutionDifferentAcceptance for exactly 4 Interpretation, exactly 4 Meaning, exactly 2 Origin, exactly 2 World
run sameOfferedDifferentOriginSameContentAcceptance for exactly 4 Interpretation, exactly 4 Meaning, exactly 2 Origin, exactly 2 World
check OfferedMeaningDeterminesContentAcceptance for exactly 4 Interpretation, exactly 4 Meaning, exactly 2 Origin, exactly 2 World
check OfferedMeaningDeterminesOriginAcceptance for exactly 4 Interpretation, exactly 4 Meaning, exactly 2 Origin, exactly 2 World
check OfferedMeaningAndOriginDetermineOriginAcceptance for exactly 4 Interpretation, exactly 4 Meaning, exactly 2 Origin, exactly 2 World
check OriginDoesNotChangeResolutionMeaning for exactly 4 Interpretation, exactly 4 Meaning, exactly 2 Origin, exactly 2 World
check WholeFrontierResolutionStillSettles for exactly 4 Interpretation, exactly 4 Meaning, exactly 2 Origin, exactly 2 World
