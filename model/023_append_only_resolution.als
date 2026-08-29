abstract sig Meaning {}
one sig M0, MA, MB, MR extends Meaning {}

abstract sig Interpretation {
  means: one Meaning
}

one sig C0 extends Interpretation {}

abstract sig Correction extends Interpretation {
  target: one Interpretation
}

one sig KA, KB extends Correction {}

abstract sig Resolution extends Interpretation {
  parents: some Interpretation
}

one sig R0 extends Resolution {}

fact Meanings {
  C0.means = M0
  KA.means = MA
  KB.means = MB
  R0.means = MR
}

fun supersedes : Interpretation -> Interpretation {
  target + parents
}

pred terminalIn[seen: set Interpretation, i: Interpretation] {
  i in seen
  no (i.~supersedes & seen)
}

fun frontier[seen: set Interpretation] : set Interpretation {
  {i: seen | terminalIn[seen, i]}
}

pred branchingCorrections {
  KA.target = C0
  KB.target = C0
}

pred resolvesWholeFrontier[before: set Interpretation, r: Resolution] {
  r not in before
  r.parents = frontier[before]
}

pred fullResolution {
  branchingCorrections
  resolvesWholeFrontier[C0 + KA + KB, R0]
}

pred partialResolution {
  branchingCorrections
  R0.parents = KA
}

run conflictBeforeResolution {
  branchingCorrections
  frontier[C0 + KA + KB] = KA + KB
} for exactly 4 Interpretation, exactly 4 Meaning

run fullResolutionSettles {
  fullResolution
  frontier[Interpretation] = R0
} for exactly 4 Interpretation, exactly 4 Meaning

run partialResolutionLeavesConflict {
  partialResolution
  frontier[Interpretation] = KB + R0
} for exactly 4 Interpretation, exactly 4 Meaning

assert WholeFrontierResolutionSettles {
  fullResolution implies frontier[Interpretation] = R0
}

assert WholeFrontierResolutionHasUniqueTip {
  fullResolution implies one frontier[Interpretation]
}

assert PartialResolutionDoesNotSettle {
  partialResolution implies frontier[Interpretation] = KB + R0
}

check WholeFrontierResolutionSettles for exactly 4 Interpretation, exactly 4 Meaning
check WholeFrontierResolutionHasUniqueTip for exactly 4 Interpretation, exactly 4 Meaning
check PartialResolutionDoesNotSettle for exactly 4 Interpretation, exactly 4 Meaning
