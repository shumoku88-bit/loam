module experiments/observation_120_split_merged_realization

abstract sig Scheduled {
  expected: one Int
}
one sig SplitTen, MergeThree, MergeTwo, AmbigTwo, AmbigFour extends Scheduled {}

abstract sig Actual {
  observed: one Int
}
one sig ActualSix, ActualFour, ActualFive extends Actual {}

abstract sig World {
  shares: Scheduled -> Actual -> lone Int
}
one sig Left, Right extends World {}

fun allocated[w: World, s: Scheduled, a: Actual]: one Int {
  sum q: Int | s->a->q in w.shares
}

fun realized[w: World, s: Scheduled]: one Int {
  sum a: Actual | allocated[w, s, a]
}

fun used[w: World, a: Actual]: one Int {
  sum s: Scheduled | allocated[w, s, a]
}

pred linked[w: World, s: Scheduled, a: Actual] {
  some q: Int | s->a->q in w.shares
}

fun topology[w: World]: Scheduled -> Actual {
  { s: Scheduled, a: Actual | linked[w, s, a] }
}

fun linkedActuals[w: World, s: Scheduled]: set Actual {
  { a: Actual | linked[w, s, a] }
}

fun wholeActualRealized[w: World, s: Scheduled]: one Int {
  sum a: linkedActuals[w, s] | a.observed
}

pred fulfilled[w: World, s: Scheduled] {
  realized[w, s] = s.expected
}

pred oneToOne[w: World] {
  all s: Scheduled | lone { a: Actual | linked[w, s, a] }
  all a: Actual | lone { s: Scheduled | linked[w, s, a] }
}

fact SpecimenQuantities {
  SplitTen.expected = 10
  MergeThree.expected = 3
  MergeTwo.expected = 2
  AmbigTwo.expected = 2
  AmbigFour.expected = 4

  ActualSix.observed = 6
  ActualFour.observed = 4
  ActualFive.observed = 5
}

fact PositiveRealizationShares {
  all w: World, s: Scheduled, a: Actual, q: Int |
    s->a->q in w.shares implies q > 0
}

fact SharesDoNotInventEndpointQuantity {
  all w: World, a: Actual | used[w, a] <= a.observed
  all w: World, s: Scheduled | realized[w, s] <= s.expected
}

pred splitWitnessAt[w: World] {
  w.shares =
    SplitTen->ActualSix->6 +
    SplitTen->ActualFour->4

  realized[w, SplitTen] = 10
  fulfilled[w, SplitTen]
}

pred mergedWitnessAt[w: World] {
  w.shares =
    MergeThree->ActualFive->3 +
    MergeTwo->ActualFive->2

  used[w, ActualFive] = 5
  fulfilled[w, MergeThree]
  fulfilled[w, MergeTwo]
}

pred partialWitnessAt[w: World] {
  w.shares = SplitTen->ActualSix->6

  realized[w, SplitTen] = 6
  not fulfilled[w, SplitTen]
}

pred splitWitness {
  splitWitnessAt[Left]
}

pred mergedWitness {
  mergedWitnessAt[Left]
}

pred partialWitness {
  partialWitnessAt[Left]
}

pred splitAndMergedCoexistWitness {
  Left.shares =
    SplitTen->ActualSix->6 +
    SplitTen->ActualFour->4 +
    MergeThree->ActualFive->3 +
    MergeTwo->ActualFive->2

  fulfilled[Left, SplitTen]
  fulfilled[Left, MergeThree]
  fulfilled[Left, MergeTwo]
}

pred oneToOneSplitWitness {
  splitWitnessAt[Left]
  oneToOne[Left]
}

pred oneToOneMergedWitness {
  mergedWitnessAt[Left]
  oneToOne[Left]
}

pred mergedWholeActualProjectionOvercounts {
  mergedWitnessAt[Left]
  wholeActualRealized[Left, MergeThree] = 5
  wholeActualRealized[Left, MergeTwo] = 5
  wholeActualRealized[Left, MergeThree] != realized[Left, MergeThree]
  wholeActualRealized[Left, MergeTwo] != realized[Left, MergeTwo]
}

pred sameTopologyDifferentRealizationWitness {
  Left.shares =
    AmbigTwo->ActualFive->2 +
    AmbigFour->ActualFive->3

  Right.shares =
    AmbigTwo->ActualFive->1 +
    AmbigFour->ActualFive->4

  topology[Left] = topology[Right]
  used[Left, ActualFive] = ActualFive.observed
  used[Right, ActualFive] = ActualFive.observed

  realized[Left, AmbigTwo] != realized[Right, AmbigTwo]
  realized[Left, AmbigFour] != realized[Right, AmbigFour]
  fulfilled[Left, AmbigTwo]
  not fulfilled[Right, AmbigTwo]
  not fulfilled[Left, AmbigFour]
  fulfilled[Right, AmbigFour]
}

assert TopologyAloneDeterminesRealizedQuantity {
  topology[Left] = topology[Right] implies
    all s: Scheduled | realized[Left, s] = realized[Right, s]
}

assert TopologyAloneDeterminesFulfillment {
  topology[Left] = topology[Right] implies
    all s: Scheduled | (fulfilled[Left, s] iff fulfilled[Right, s])
}

assert QuantitySharesDetermineRealizedQuantity {
  Left.shares = Right.shares implies
    all s: Scheduled | realized[Left, s] = realized[Right, s]
}

assert QuantitySharesDetermineFulfillment {
  Left.shares = Right.shares implies
    all s: Scheduled | (fulfilled[Left, s] iff fulfilled[Right, s])
}

run splitWitness for exactly 5 Scheduled, exactly 3 Actual, exactly 2 World, 5 Int
run mergedWitness for exactly 5 Scheduled, exactly 3 Actual, exactly 2 World, 5 Int
run partialWitness for exactly 5 Scheduled, exactly 3 Actual, exactly 2 World, 5 Int
run splitAndMergedCoexistWitness for exactly 5 Scheduled, exactly 3 Actual, exactly 2 World, 5 Int
run oneToOneSplitWitness for exactly 5 Scheduled, exactly 3 Actual, exactly 2 World, 5 Int
run oneToOneMergedWitness for exactly 5 Scheduled, exactly 3 Actual, exactly 2 World, 5 Int
run mergedWholeActualProjectionOvercounts for exactly 5 Scheduled, exactly 3 Actual, exactly 2 World, 5 Int
run sameTopologyDifferentRealizationWitness for exactly 5 Scheduled, exactly 3 Actual, exactly 2 World, 5 Int

check TopologyAloneDeterminesRealizedQuantity for exactly 5 Scheduled, exactly 3 Actual, exactly 2 World, 5 Int
check TopologyAloneDeterminesFulfillment for exactly 5 Scheduled, exactly 3 Actual, exactly 2 World, 5 Int
check QuantitySharesDetermineRealizedQuantity for exactly 5 Scheduled, exactly 3 Actual, exactly 2 World, 5 Int
check QuantitySharesDetermineFulfillment for exactly 5 Scheduled, exactly 3 Actual, exactly 2 World, 5 Int
