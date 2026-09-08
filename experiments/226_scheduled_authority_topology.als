module experiments/observation_226_scheduled_authority_topology

abstract sig Family {}
one sig Occurrence, Completion, Retirement, Replacement, Routing extends Family {}

sig CommitUnit {}
sig RewriteUnit {}

abstract sig Topology {
  commitOf: Family -> one CommitUnit,
  rewriteOf: Family -> one RewriteUnit,
  missingMeansEmpty: set Family
}

one sig Sidecars, Monolith, ManifestAll, LifecycleSplit extends Topology {}

fun lifecycle : set Family {
  Occurrence + Completion + Retirement + Replacement
}

fact SidecarShape {
  all disj f, g: Family |
    Sidecars.commitOf[f] != Sidecars.commitOf[g]
  all disj f, g: Family |
    Sidecars.rewriteOf[f] != Sidecars.rewriteOf[g]
  Sidecars.missingMeansEmpty = Completion + Retirement + Replacement + Routing
}

fact MonolithShape {
  all f, g: Family |
    Monolith.commitOf[f] = Monolith.commitOf[g]
  all f, g: Family |
    Monolith.rewriteOf[f] = Monolith.rewriteOf[g]
  no Monolith.missingMeansEmpty
}

fact ManifestAllShape {
  all f, g: Family |
    ManifestAll.commitOf[f] = ManifestAll.commitOf[g]
  all disj f, g: Family |
    ManifestAll.rewriteOf[f] != ManifestAll.rewriteOf[g]
  no ManifestAll.missingMeansEmpty
}

fact LifecycleSplitShape {
  all f: lifecycle |
    LifecycleSplit.commitOf[f] = LifecycleSplit.commitOf[Occurrence]
  LifecycleSplit.commitOf[Routing] != LifecycleSplit.commitOf[Occurrence]

  all f: lifecycle |
    LifecycleSplit.rewriteOf[f] = LifecycleSplit.rewriteOf[Occurrence]
  LifecycleSplit.rewriteOf[Routing] != LifecycleSplit.rewriteOf[Occurrence]

  no LifecycleSplit.missingMeansEmpty
}

fun rewriteScope[t: Topology, changed: Family]: set Family {
  { f: Family | t.rewriteOf[f] = t.rewriteOf[changed] }
}

pred explicitMissingDistinction[t: Topology] {
  no t.missingMeansEmpty
}

pred lifecycleAtomic[t: Topology] {
  all f: lifecycle |
    t.commitOf[f] = t.commitOf[Occurrence]
}

pred routingCommitIndependent[t: Topology] {
  all f: lifecycle |
    t.commitOf[Routing] != t.commitOf[f]
}

pred routingRewriteLocal[t: Topology] {
  rewriteScope[t, Routing] = Routing
}

pred selectedProperties[t: Topology] {
  explicitMissingDistinction[t]
  lifecycleAtomic[t]
  routingCommitIndependent[t]
  routingRewriteLocal[t]
}

sig StorageState {
  present: set Family,
  evidence: set Family
} {
  evidence in present
}

pred readable[t: Topology, s: StorageState] {
  Family - t.missingMeansEmpty in s.present
}

fun decodedEvidence[t: Topology, s: StorageState]: set Family {
  s.evidence
}

pred completionDeletionBecomesEmptyWorld {
  some disj before, after, explicitEmpty: StorageState |
    before.present = Family and
    before.evidence = Completion and
    after.present = Family - Completion and
    no after.evidence and
    explicitEmpty.present = Family and
    no explicitEmpty.evidence and
    readable[Sidecars, before] and
    readable[Sidecars, after] and
    readable[Sidecars, explicitEmpty] and
    decodedEvidence[Sidecars, after] = decodedEvidence[Sidecars, explicitEmpty]
}

pred lifecycleSplitWitness {
  selectedProperties[LifecycleSplit]
}

assert SidecarsDistinguishMissingFromEmpty {
  explicitMissingDistinction[Sidecars]
}

assert SidecarsRefuseDeletedCompletion {
  all s: StorageState |
    Completion not in s.present implies not readable[Sidecars, s]
}

assert SidecarsHaveLifecycleAtomicity {
  lifecycleAtomic[Sidecars]
}

assert MonolithKeepsRoutingCommitIndependent {
  routingCommitIndependent[Monolith]
}

assert MonolithKeepsRoutingRewriteLocal {
  routingRewriteLocal[Monolith]
}

assert ManifestKeepsRoutingCommitIndependent {
  routingCommitIndependent[ManifestAll]
}

assert ManifestKeepsRoutingRewriteLocal {
  routingRewriteLocal[ManifestAll]
}

assert LifecycleSplitRefusesDeletedCompletion {
  all s: StorageState |
    Completion not in s.present implies not readable[LifecycleSplit, s]
}

assert LifecycleSplitMeetsSelectedProperties {
  selectedProperties[LifecycleSplit]
}

assert OnlyLifecycleSplitMeetsSelectedProperties {
  all t: Topology |
    selectedProperties[t] iff t = LifecycleSplit
}

run completionDeletionBecomesEmptyWorld for exactly 5 CommitUnit, exactly 5 RewriteUnit, exactly 3 StorageState
run lifecycleSplitWitness for exactly 5 CommitUnit, exactly 5 RewriteUnit, exactly 0 StorageState
check SidecarsDistinguishMissingFromEmpty for exactly 5 CommitUnit, exactly 5 RewriteUnit, exactly 0 StorageState
check SidecarsRefuseDeletedCompletion for exactly 5 CommitUnit, exactly 5 RewriteUnit, exactly 1 StorageState
check SidecarsHaveLifecycleAtomicity for exactly 5 CommitUnit, exactly 5 RewriteUnit, exactly 0 StorageState
check MonolithKeepsRoutingCommitIndependent for exactly 5 CommitUnit, exactly 5 RewriteUnit, exactly 0 StorageState
check MonolithKeepsRoutingRewriteLocal for exactly 5 CommitUnit, exactly 5 RewriteUnit, exactly 0 StorageState
check ManifestKeepsRoutingCommitIndependent for exactly 5 CommitUnit, exactly 5 RewriteUnit, exactly 0 StorageState
check ManifestKeepsRoutingRewriteLocal for exactly 5 CommitUnit, exactly 5 RewriteUnit, exactly 0 StorageState
check LifecycleSplitRefusesDeletedCompletion for exactly 5 CommitUnit, exactly 5 RewriteUnit, exactly 1 StorageState
check LifecycleSplitMeetsSelectedProperties for exactly 5 CommitUnit, exactly 5 RewriteUnit, exactly 0 StorageState
check OnlyLifecycleSplitMeetsSelectedProperties for exactly 5 CommitUnit, exactly 5 RewriteUnit, exactly 0 StorageState
