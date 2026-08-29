module model/observation_024_resolution_meaning

abstract sig Meaning {}
one sig M0, MA, MB, MX extends Meaning {}

abstract sig Interpretation {}
one sig C0, KA, KB, R0 extends Interpretation {}

abstract sig World {
  means: Interpretation -> one Meaning
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

pred sameConflictDifferentResolutionMeaning {
  meaning[Left, R0] != meaning[Right, R0]
}

pred sameConflictSameResolutionMeaning {
  meaning[Left, R0] = meaning[Right, R0]
}

pred parentMeaningResolution {
  some w: World |
    meaning[w, R0] in meaning[w, KA] + meaning[w, KB]
}

pred thirdMeaningResolution {
  some w: World |
    meaning[w, R0] = MX
}

assert ConflictHistoryDeterminesResolutionMeaning {
  meaning[Left, R0] = meaning[Right, R0]
}

assert ResolutionMeaningMustBeParentMeaning {
  all w: World |
    meaning[w, R0] in meaning[w, KA] + meaning[w, KB]
}

assert ResolutionMeaningMustBeNewMeaning {
  all w: World |
    meaning[w, R0] not in meaning[w, KA] + meaning[w, KB]
}

assert WholeFrontierResolutionStillSettles {
  frontier = R0
}

run sameConflictDifferentResolutionMeaning for exactly 4 Interpretation, exactly 4 Meaning, exactly 2 World
run sameConflictSameResolutionMeaning for exactly 4 Interpretation, exactly 4 Meaning, exactly 2 World
run parentMeaningResolution for exactly 4 Interpretation, exactly 4 Meaning, exactly 2 World
run thirdMeaningResolution for exactly 4 Interpretation, exactly 4 Meaning, exactly 2 World
check ConflictHistoryDeterminesResolutionMeaning for exactly 4 Interpretation, exactly 4 Meaning, exactly 2 World
check ResolutionMeaningMustBeParentMeaning for exactly 4 Interpretation, exactly 4 Meaning, exactly 2 World
check ResolutionMeaningMustBeNewMeaning for exactly 4 Interpretation, exactly 4 Meaning, exactly 2 World
check WholeFrontierResolutionStillSettles for exactly 4 Interpretation, exactly 4 Meaning, exactly 2 World
