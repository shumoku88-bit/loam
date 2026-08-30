module model/observation_051_reconciliation_evidence

sig Locus {}
sig Measure {}

sig Claim {
  claimLocus: one Locus,
  claimMeasure: one Measure,
  claimQuantity: one Int
}

sig Evidence {
  evidenceLocus: one Locus,
  evidenceMeasure: one Measure,
  evidenceQuantity: one Int
}

abstract sig World {
  supports: Evidence -> Claim
}

one sig Left, Right extends World {}

fact BoundedQuantities {
  all c: Claim | {
    c.claimQuantity >= -3
    c.claimQuantity <= 3
  }

  all e: Evidence | {
    e.evidenceQuantity >= -3
    e.evidenceQuantity <= 3
  }
}

pred matches[e: Evidence, c: Claim] {
  e.evidenceLocus = c.claimLocus
  e.evidenceMeasure = c.claimMeasure
  e.evidenceQuantity = c.claimQuantity
}

fact SupportRequiresMatchingContent {
  all w: World, e: Evidence, c: Claim |
    e->c in w.supports implies matches[e, c]
}

fun reconciledClaims[w: World]: set Claim {
  { c: Claim | some e: Evidence | e->c in w.supports }
}

fun unreconciledClaims[w: World]: set Claim {
  Claim - reconciledClaims[w]
}

pred coincidentMatchNeedNotReconcile {
  some c: Claim, e: Evidence | {
    matches[e, c]
    no Left.supports
    c in unreconciledClaims[Left]
  }
}

pred explicitSupportCanDistinguishIdenticalClaims {
  some disj a, b: Claim, e: Evidence | {
    a.claimLocus = b.claimLocus
    a.claimMeasure = b.claimMeasure
    a.claimQuantity = b.claimQuantity
    matches[e, a]
    matches[e, b]

    e->a in Left.supports
    e->b not in Left.supports

    a in reconciledClaims[Left]
    b in unreconciledClaims[Left]
  }
}

pred supportOverlayCanChangeReconciliation {
  some c: Claim, e: Evidence | {
    matches[e, c]
    e->c in Left.supports
    no Right.supports
  }

  reconciledClaims[Left] != reconciledClaims[Right]
}

assert MatchingContentDeterminesReconciliation {
  all c: Claim |
    (some e: Evidence | matches[e, c]) implies
      c in reconciledClaims[Left]
}

assert ReconciledClaimsHaveMatchingSupport {
  all w: World, c: Claim |
    c in reconciledClaims[w] implies
      some e: Evidence | e->c in w.supports and matches[e, c]
}

assert SameSupportDeterminesSelectedReconciliation {
  Left.supports = Right.supports implies {
    reconciledClaims[Left] = reconciledClaims[Right]
    unreconciledClaims[Left] = unreconciledClaims[Right]
  }
}

run coincidentMatchNeedNotReconcile for exactly 1 Claim, exactly 1 Evidence, exactly 1 Locus, exactly 1 Measure, exactly 2 World, 5 Int
run explicitSupportCanDistinguishIdenticalClaims for exactly 2 Claim, exactly 1 Evidence, exactly 1 Locus, exactly 1 Measure, exactly 2 World, 5 Int
run supportOverlayCanChangeReconciliation for exactly 1 Claim, exactly 1 Evidence, exactly 1 Locus, exactly 1 Measure, exactly 2 World, 5 Int
check MatchingContentDeterminesReconciliation for exactly 1 Claim, exactly 1 Evidence, exactly 1 Locus, exactly 1 Measure, exactly 2 World, 5 Int
check ReconciledClaimsHaveMatchingSupport for exactly 2 Claim, exactly 2 Evidence, exactly 1 Locus, exactly 1 Measure, exactly 2 World, 5 Int
check SameSupportDeterminesSelectedReconciliation for exactly 2 Claim, exactly 2 Evidence, exactly 1 Locus, exactly 1 Measure, exactly 2 World, 5 Int
