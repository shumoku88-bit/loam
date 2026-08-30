sig Revision {
  parent: set Revision
}

sig View {
  known: set Revision
}

fun frontier[v: View]: set Revision {
  v.known - v.known.parent
}

pred closed[v: View] {
  v.known.parent in v.known
}

pred acyclic[v: View] {
  all r: v.known | r not in r.^parent
}

pred oneRevisionStep[prior, later: View, r: Revision] {
  closed[prior]
  r not in prior.known
  later.known = prior.known + r
  r.parent in frontier[prior]
}

pred genericForkPartialAndSettlement {
  some disj root, left, right, partial, settle: Revision |
    some disj initial, fork, partialView, settled: View |
      no root.parent
      and left.parent = root
      and right.parent = root
      and partial.parent = left
      and settle.parent = left + right
      and initial.known = root
      and fork.known = root + left + right
      and partialView.known = root + left + right + partial
      and settled.known = root + left + right + settle
      and frontier[fork] = left + right
      and frontier[partialView] = partial + right
      and frontier[settled] = settle
}

assert SoleFrontierRequiresWholePriorFrontier {
  all prior, later: View, r: Revision |
    oneRevisionStep[prior, later, r] and frontier[later] = r
      implies r.parent = frontier[prior]
}

assert WholePriorFrontierIsEnoughToSettle {
  all prior, later: View, r: Revision |
    oneRevisionStep[prior, later, r] and r.parent = frontier[prior]
      implies frontier[later] = r
}

assert WholeSettlementPreservesPriorKnownAncestry {
  all prior, later: View, r: Revision |
    oneRevisionStep[prior, later, r]
      and acyclic[prior]
      and frontier[later] = r
      implies prior.known in r.^parent
}

run genericForkPartialAndSettlement for exactly 5 Revision, exactly 4 View
check SoleFrontierRequiresWholePriorFrontier for 6 Revision, 4 View
check WholePriorFrontierIsEnoughToSettle for 6 Revision, 4 View
check WholeSettlementPreservesPriorKnownAncestry for 6 Revision, 4 View
