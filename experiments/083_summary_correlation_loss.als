module experiments/observation_083_summary_correlation_loss

sig Link {}

abstract sig TimeBucket {}
one sig Earlier, Later extends TimeBucket {}

abstract sig DeltaBucket {}
one sig Exact, Different extends DeltaBucket {}

sig World {
  timeOf: Link -> one TimeBucket,
  deltaOf: Link -> one DeltaBucket
}

one sig Left, Right extends World {}

fun timeCount[w: World, t: TimeBucket]: Int {
  #{ l: Link | t in l.(w.timeOf) }
}

fun deltaCount[w: World, d: DeltaBucket]: Int {
  #{ l: Link | d in l.(w.deltaOf) }
}

fun jointCount[w: World, t: TimeBucket, d: DeltaBucket]: Int {
  #{ l: Link |
      t in l.(w.timeOf) and
      d in l.(w.deltaOf) }
}

pred sameMarginals[w1, w2: World] {
  all t: TimeBucket |
    timeCount[w1, t] = timeCount[w2, t]
  all d: DeltaBucket |
    deltaCount[w1, d] = deltaCount[w2, d]
}

pred sameJointSummary[w1, w2: World] {
  all t: TimeBucket, d: DeltaBucket |
    jointCount[w1, t, d] = jointCount[w2, t, d]
}

pred allMarginalBucketsOccupied[w: World] {
  all t: TimeBucket | timeCount[w, t] > 0
  all d: DeltaBucket | deltaCount[w, d] > 0
}

pred sameMarginalsDifferentJoint {
  #Link = 4
  Left.timeOf = Right.timeOf
  Left.deltaOf != Right.deltaOf
  sameMarginals[Left, Right]
  allMarginalBucketsOccupied[Left]
  allMarginalBucketsOccupied[Right]
  not sameJointSummary[Left, Right]
}

assert SeparateMarginalsDetermineJoint {
  sameMarginals[Left, Right] implies
    sameJointSummary[Left, Right]
}

assert JointSummaryDeterminesMarginals {
  sameJointSummary[Left, Right] implies
    sameMarginals[Left, Right]
}

assert SameLinkClassificationsDetermineJoint {
  Left.timeOf = Right.timeOf and
  Left.deltaOf = Right.deltaOf implies
    sameJointSummary[Left, Right]
}

run sameMarginalsDifferentJoint for exactly 4 Link, exactly 2 TimeBucket, exactly 2 DeltaBucket, exactly 2 World, 5 Int
check SeparateMarginalsDetermineJoint for exactly 4 Link, exactly 2 TimeBucket, exactly 2 DeltaBucket, exactly 2 World, 5 Int
check JointSummaryDeterminesMarginals for exactly 4 Link, exactly 2 TimeBucket, exactly 2 DeltaBucket, exactly 2 World, 5 Int
check SameLinkClassificationsDetermineJoint for exactly 4 Link, exactly 2 TimeBucket, exactly 2 DeltaBucket, exactly 2 World, 5 Int
