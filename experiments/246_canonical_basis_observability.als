module experiments/canonical_basis_observability_246

-- Observation 246
--
-- Canonical-data minimality is tested against observable answers, not
-- against current file/type boundaries. A retained distinction is earned
-- only when changing that distinction can change an intended answer.

abstract sig Coordinate {}
one sig Cash, PayPay, Smbc, Yucho, AllCountry extends Coordinate {}

abstract sig MutationFamily {}
one sig RelationUnit, RelationDischarge, ActualReversal extends MutationFamily {}

abstract sig Presence {}
one sig Absent, KnownEmpty extends Presence {}

sig World {
  zeroCovered : set Coordinate,
  mutationPresence : MutationFamily -> one Presence
}

fun qReadCoverage[w : World] : set Coordinate {
  w.zeroCovered
}

pred sameQRead[w1, w2 : World] {
  qReadCoverage[w1] = qReadCoverage[w2]
}

fun knownEmptyMutationFamilies[w : World] : set MutationFamily {
  { f : MutationFamily | w.mutationPresence[f] = KnownEmpty }
}

pred sameQWrite[w1, w2 : World] {
  knownEmptyMutationFamilies[w1] = knownEmptyMutationFamilies[w2]
}

pred differOnlyMutationPresence[w1, w2 : World, f : MutationFamily] {
  w1.zeroCovered = w2.zeroCovered
  all other : MutationFamily - f |
    w1.mutationPresence[other] = w2.mutationPresence[other]
  w1.mutationPresence[f] != w2.mutationPresence[f]
}

pred differOnlyZeroCoverage[w1, w2 : World, c : Coordinate] {
  w1.mutationPresence = w2.mutationPresence
  w1.zeroCovered - c = w2.zeroCovered - c
  (c in w1.zeroCovered and c not in w2.zeroCovered)
  or
  (c not in w1.zeroCovered and c in w2.zeroCovered)
}

pred zeroCoverageHasReadWitness {
  some disj w1, w2 : World, c : Coordinate |
    differOnlyZeroCoverage[w1, w2, c]
    and not sameQRead[w1, w2]
}

pred mutationPresenceCanBeReadInvisible {
  some disj w1, w2 : World, f : MutationFamily |
    differOnlyMutationPresence[w1, w2, f]
    and sameQRead[w1, w2]
}

pred mutationPresenceCanBeWriteVisible {
  some disj w1, w2 : World, f : MutationFamily |
    differOnlyMutationPresence[w1, w2, f]
    and not sameQWrite[w1, w2]
}

run zeroCoverageHasReadWitness for 2 World
run mutationPresenceCanBeReadInvisible for 2 World
run mutationPresenceCanBeWriteVisible for 2 World
