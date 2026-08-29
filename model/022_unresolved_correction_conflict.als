abstract sig Meaning {}
one sig M0, MA, MB extends Meaning {}

abstract sig Interpretation {
  means: one Meaning
}

one sig C0 extends Interpretation {}

abstract sig Correction extends Interpretation {
  target: one Interpretation
}

one sig KA, KB extends Correction {}

fact DistinctMeanings {
  C0.means = M0
  KA.means = MA
  KB.means = MB
}

pred terminal[i: Interpretation] {
  no i.~target
}

fun terminals : set Interpretation {
  {i: Interpretation | terminal[i]}
}

pred weakBranching {
  KA.target = C0
  KB.target = C0
}

pred linearChain {
  KA.target = C0
  KB.target = KA
}

pred unresolved {
  #terminals > 1
}

run branchingAmbiguity {
  weakBranching
  unresolved
  terminals = KA + KB
} for exactly 3 Interpretation, exactly 3 Meaning

assert WeakBranchIsUnresolved {
  weakBranching implies
    unresolved and terminals = KA + KB
}

assert LinearChainHasUniqueTip {
  linearChain implies one terminals
}

assert LinearChainTipIsKB {
  linearChain implies terminals = KB
}

check WeakBranchIsUnresolved for exactly 3 Interpretation, exactly 3 Meaning
check LinearChainHasUniqueTip for exactly 3 Interpretation, exactly 3 Meaning
check LinearChainTipIsKB for exactly 3 Interpretation, exactly 3 Meaning
