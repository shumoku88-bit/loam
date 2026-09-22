module experiments/observation_269_suspense_known_unknown

one sig Measure {}

abstract sig Locus {}
one sig Source, KnownA, KnownB, Suspense extends Locus {}

abstract sig Snapshot {
  quantity: Locus -> one Int
}
one sig Before, After extends Snapshot {}

fun q[s: Snapshot, l: Locus]: one Int {
  sum l.(s.quantity)
}

fact BoundedQuantities {
  all s: Snapshot, l: Locus | {
    q[s, l] >= -7
    q[s, l] <= 7
  }
}

pred conserved[s: Snapshot] {
  (sum l: Locus | q[s, l]) = 0
}

pred physicalShape[s: Snapshot] {
  q[s, Source] < 0
  q[s, KnownA] >= 0
  q[s, KnownB] >= 0
  q[s, Suspense] >= 0
}

pred admitted[s: Snapshot] {
  conserved[s]
  physicalShape[s]
}

pred unresolved[s: Snapshot] {
  admitted[s]
  q[s, Suspense] > 0
}

pred partiallyKnown[s: Snapshot] {
  unresolved[s]
  q[s, KnownA] + q[s, KnownB] > 0
}

pred resolved[s: Snapshot] {
  admitted[s]
  q[s, Suspense] = 0
}

pred invalid[s: Snapshot] {
  not admitted[s]
}

// Classification refinement may move quantity only out of Suspense and into
// already-declared known Loci. It deliberately does not constrain Source.
// The assertions below test whether conservation forces Source to stay fixed.
pred classificationRedistribution[a, b: Snapshot] {
  admitted[a]
  admitted[b]

  q[b, KnownA] >= q[a, KnownA]
  q[b, KnownB] >= q[a, KnownB]
  q[b, Suspense] <= q[a, Suspense]

  let movedA = q[b, KnownA] - q[a, KnownA] |
  let movedB = q[b, KnownB] - q[a, KnownB] |
  let removed = q[a, Suspense] - q[b, Suspense] | {
    movedA >= 0
    movedB >= 0
    removed >= 0
    removed = movedA + movedB
  }
}

pred validUnknownExists {
  some s: Snapshot | unresolved[s]
}

pred validPartialClassificationExists {
  some s: Snapshot | partiallyKnown[s]
}

pred partialResolutionExists {
  partiallyKnown[Before]
  classificationRedistribution[Before, After]
  unresolved[After]
  q[After, Suspense] < q[Before, Suspense]
}

pred fullResolutionExists {
  unresolved[Before]
  classificationRedistribution[Before, After]
  resolved[After]
}

pred invalidImbalanceExists {
  some s: Snapshot | {
    q[s, Source] = -5
    q[s, KnownA] = 2
    q[s, KnownB] = 1
    q[s, Suspense] = 1
    invalid[s]
  }
}

assert UnknownIsNotInvalid {
  all s: Snapshot |
    unresolved[s] implies not invalid[s]
}

assert RedistributionPreservesPhysicalPayment {
  all a, b: Snapshot |
    classificationRedistribution[a, b] implies
      q[a, Source] = q[b, Source]
}

assert RedistributionPreservesDestinationTotal {
  all a, b: Snapshot |
    classificationRedistribution[a, b] implies
      q[a, KnownA] + q[a, KnownB] + q[a, Suspense] =
        q[b, KnownA] + q[b, KnownB] + q[b, Suspense]
}

assert FullResolutionLeavesNoUnresolvedQuantity {
  all a, b: Snapshot |
    (unresolved[a] and
     classificationRedistribution[a, b] and
     resolved[b]) implies
      q[b, Suspense] = 0
}

run validUnknownExists for exactly 2 Snapshot, exactly 4 Locus, exactly 1 Measure, 6 Int
run validPartialClassificationExists for exactly 2 Snapshot, exactly 4 Locus, exactly 1 Measure, 6 Int
run partialResolutionExists for exactly 2 Snapshot, exactly 4 Locus, exactly 1 Measure, 6 Int
run fullResolutionExists for exactly 2 Snapshot, exactly 4 Locus, exactly 1 Measure, 6 Int
run invalidImbalanceExists for exactly 2 Snapshot, exactly 4 Locus, exactly 1 Measure, 6 Int

check UnknownIsNotInvalid for exactly 2 Snapshot, exactly 4 Locus, exactly 1 Measure, 6 Int
check RedistributionPreservesPhysicalPayment for exactly 2 Snapshot, exactly 4 Locus, exactly 1 Measure, 6 Int
check RedistributionPreservesDestinationTotal for exactly 2 Snapshot, exactly 4 Locus, exactly 1 Measure, 6 Int
check FullResolutionLeavesNoUnresolvedQuantity for exactly 2 Snapshot, exactly 4 Locus, exactly 1 Measure, 6 Int
