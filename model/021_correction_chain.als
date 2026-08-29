module correction_chain

abstract sig Purpose {}
one sig P0, P1 extends Purpose {}

abstract sig Interpretation {}
one sig C0, K0, K1 extends Interpretation {}

one sig View {
  parent: Interpretation -> lone Interpretation,
  meaning: Interpretation -> one Purpose
}

fun tips[v: View] : set Interpretation {
  Interpretation - Interpretation.(v.parent)
}

pred weakBranchingWorld {
  View.parent = K0->C0 + K1->C0
  View.meaning = C0->P0 + K0->P1 + K1->P0
}

pred linearChainWorld {
  View.parent = K0->C0 + K1->K0
  View.meaning = C0->P0 + K0->P1 + K1->P0
}

pred branchingAmbiguity {
  weakBranchingWorld
  #tips[View] = 2
  K0 in tips[View]
  K1 in tips[View]
  K0.(View.meaning) != K1.(View.meaning)
}

assert LinearChainHasUniqueTip {
  linearChainWorld implies one tips[View]
}

assert LinearChainTipIsK1 {
  linearChainWorld implies tips[View] = K1
}

run branchingAmbiguity for exactly 2 Purpose, exactly 3 Interpretation, exactly 1 View expect 1
check LinearChainHasUniqueTip for exactly 2 Purpose, exactly 3 Interpretation, exactly 1 View expect 0
check LinearChainTipIsK1 for exactly 2 Purpose, exactly 3 Interpretation, exactly 1 View expect 0
