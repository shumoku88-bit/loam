module model/observation_025_resolution_recoverability

abstract sig Meaning {}
one sig M0, MA, MB, MX, MY extends Meaning {}

abstract sig Interpretation {}
one sig C0, KA, KB, R0 extends Interpretation {}

abstract sig Rule {}
one sig TakeKA, TakeKB, TakeOffered extends Rule {}

abstract sig World {
  means: Interpretation -> one Meaning,
  rule: one Rule,
  offered: lone Meaning
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

fact ResolutionSemantics {
  all w: World | {
    (w.rule = TakeKA) implies {
      no w.offered
      meaning[w, R0] = meaning[w, KA]
    }

    (w.rule = TakeKB) implies {
      no w.offered
      meaning[w, R0] = meaning[w, KB]
    }

    (w.rule = TakeOffered) implies {
      one w.offered
      w.offered not in meaning[w, KA] + meaning[w, KB]
      meaning[w, R0] = w.offered
    }
  }
}

pred sameRuleDifferentMeaning {
  Left.rule = Right.rule
  meaning[Left, R0] != meaning[Right, R0]
}

pred sameInheritedRuleDifferentMeaning {
  Left.rule = Right.rule
  Left.rule in TakeKA + TakeKB
  meaning[Left, R0] != meaning[Right, R0]
}

pred sameOfferedRuleDifferentInputDifferentMeaning {
  Left.rule = TakeOffered
  Right.rule = TakeOffered
  Left.offered != Right.offered
  meaning[Left, R0] != meaning[Right, R0]
}

pred sameRuleAndInputDifferentMeaning {
  Left.rule = Right.rule
  Left.offered = Right.offered
  meaning[Left, R0] != meaning[Right, R0]
}

assert RuleAloneDeterminesResolutionMeaning {
  Left.rule = Right.rule implies
    meaning[Left, R0] = meaning[Right, R0]
}

assert InheritedRuleDeterminesResolutionMeaning {
  Left.rule = Right.rule and Left.rule in TakeKA + TakeKB implies
    meaning[Left, R0] = meaning[Right, R0]
}

assert RuleAndInputDetermineResolutionMeaning {
  Left.rule = Right.rule and Left.offered = Right.offered implies
    meaning[Left, R0] = meaning[Right, R0]
}

assert FreshMeaningRequiresOfferedInput {
  all w: World |
    meaning[w, R0] not in meaning[w, KA] + meaning[w, KB] implies {
      w.rule = TakeOffered
      one w.offered
      meaning[w, R0] = w.offered
    }
}

assert WholeFrontierResolutionStillSettles {
  frontier = R0
}

run sameRuleDifferentMeaning for exactly 4 Interpretation, exactly 5 Meaning, exactly 3 Rule, exactly 2 World
run sameInheritedRuleDifferentMeaning for exactly 4 Interpretation, exactly 5 Meaning, exactly 3 Rule, exactly 2 World
run sameOfferedRuleDifferentInputDifferentMeaning for exactly 4 Interpretation, exactly 5 Meaning, exactly 3 Rule, exactly 2 World
run sameRuleAndInputDifferentMeaning for exactly 4 Interpretation, exactly 5 Meaning, exactly 3 Rule, exactly 2 World
check RuleAloneDeterminesResolutionMeaning for exactly 4 Interpretation, exactly 5 Meaning, exactly 3 Rule, exactly 2 World
check InheritedRuleDeterminesResolutionMeaning for exactly 4 Interpretation, exactly 5 Meaning, exactly 3 Rule, exactly 2 World
check RuleAndInputDetermineResolutionMeaning for exactly 4 Interpretation, exactly 5 Meaning, exactly 3 Rule, exactly 2 World
check FreshMeaningRequiresOfferedInput for exactly 4 Interpretation, exactly 5 Meaning, exactly 3 Rule, exactly 2 World
check WholeFrontierResolutionStillSettles for exactly 4 Interpretation, exactly 5 Meaning, exactly 3 Rule, exactly 2 World
