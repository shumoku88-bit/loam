abstract sig Meaning {}
one sig A, B, C extends Meaning {}

abstract sig Claim {
  parent: set Claim,
  meaning: one Meaning
}

one sig E0, KA, KB, Partial, Resolve extends Claim {}

abstract sig View {
  known: set Claim
}

one sig Initial, Conflict, PartialView, Resolved extends View {}

fact ExplanationInterpretationShape {
  no E0.parent

  KA.parent = E0
  KB.parent = E0
  Partial.parent = KA
  Resolve.parent = KA + KB

  E0.meaning = A
  KA.meaning = B
  KB.meaning = C
  Partial.meaning = B
  Resolve.meaning = B

  Initial.known = E0
  Conflict.known = E0 + KA + KB
  PartialView.known = E0 + KA + KB + Partial
  Resolved.known = E0 + KA + KB + Resolve
}

fun frontier[v: View]: set Claim {
  v.known - v.known.parent
}

pred explanationSiblingConflict {
  frontier[Conflict] = KA + KB
}

pred partialExplanationResolutionStillConflicts {
  frontier[PartialView] = Partial + KB
  #frontier[PartialView] = 2
}

pred wholeFrontierExplanationResolutionSettles {
  frontier[Resolved] = Resolve
}

pred oneClaimStep[prior, nextView: View, r: Claim] {
  r not in prior.known
  nextView.known = prior.known + r
  r.parent in frontier[prior]
}

assert SettlementRequiresWholeExplanationFrontier {
  all prior, nextView: View, r: Claim |
    oneClaimStep[prior, nextView, r] and frontier[nextView] = r
      implies r.parent = frontier[prior]
}

assert WholeResolutionPreservesBothBranches {
  KA + KB + E0 in Resolve.^parent
}

run explanationSiblingConflict for exactly 5 Claim, exactly 3 Meaning, exactly 4 View
run partialExplanationResolutionStillConflicts for exactly 5 Claim, exactly 3 Meaning, exactly 4 View
run wholeFrontierExplanationResolutionSettles for exactly 5 Claim, exactly 3 Meaning, exactly 4 View
check SettlementRequiresWholeExplanationFrontier for exactly 5 Claim, exactly 3 Meaning, exactly 4 View
check WholeResolutionPreservesBothBranches for exactly 5 Claim, exactly 3 Meaning, exactly 4 View
