module experiments/observation_157_actual_authority_topology

abstract sig Family {}
one sig EventMemory, ActualValidity, EventDescription, EventCorrection, ActualRouting extends Family {}

sig Authority {}

abstract sig Topology {
  authorityOf: Family -> one Authority
}

one sig Unified, Sidecars, Intermediate extends Topology {}

fact UnifiedShape {
  all f, g: Family |
    Unified.authorityOf[f] = Unified.authorityOf[g]
}

fact SidecarShape {
  all disj f, g: Family |
    Sidecars.authorityOf[f] != Sidecars.authorityOf[g]
}

fun rewriteScope[t: Topology, changed: Family]: set Family {
  { f: Family | t.authorityOf[f] = t.authorityOf[changed] }
}

pred singleFamilyLocality[t: Topology] {
  all changed: Family |
    rewriteScope[t, changed] = changed
}

pred wholeImageOneAuthority[t: Topology] {
  one a: Authority |
    all f: Family | t.authorityOf[f] = a
}

pred routingOnlyContrast {
  rewriteScope[Unified, ActualRouting] = Family
  rewriteScope[Sidecars, ActualRouting] = ActualRouting
}

pred intermediatePartitionWitness {
  some disj groupedA, groupedB: Family |
    Intermediate.authorityOf[groupedA] = Intermediate.authorityOf[groupedB]
  some disj splitA, splitB: Family |
    Intermediate.authorityOf[splitA] != Intermediate.authorityOf[splitB]
}

assert RewriteScopeContainsChangedFamily {
  all t: Topology, changed: Family |
    changed in rewriteScope[t, changed]
}

assert UnifiedWholeImageOneAuthority {
  wholeImageOneAuthority[Unified]
}

assert SidecarsSingleFamilyLocality {
  singleFamilyLocality[Sidecars]
}

assert UnifiedSingleFamilyLocality {
  singleFamilyLocality[Unified]
}

assert SidecarsWholeImageOneAuthority {
  wholeImageOneAuthority[Sidecars]
}

assert NoTopologyHasBothStrictProperties {
  all t: Topology |
    not (wholeImageOneAuthority[t] and singleFamilyLocality[t])
}

run routingOnlyContrast for exactly 5 Authority
run intermediatePartitionWitness for exactly 5 Authority
check RewriteScopeContainsChangedFamily for exactly 5 Authority
check UnifiedWholeImageOneAuthority for exactly 5 Authority
check SidecarsSingleFamilyLocality for exactly 5 Authority
check UnifiedSingleFamilyLocality for exactly 5 Authority
check SidecarsWholeImageOneAuthority for exactly 5 Authority
check NoTopologyHasBothStrictProperties for exactly 5 Authority
