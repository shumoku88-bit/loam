module experiments/observation_084_query_shaped_joint_summary

sig Link {}

abstract sig RowBucket {}
one sig Row0, Row1, Row2 extends RowBucket {}

abstract sig ColBucket {}
one sig Col0, Col1, Col2 extends ColBucket {}

sig World {
  rowOf: Link -> one RowBucket,
  colOf: Link -> one ColBucket
}

one sig Left, Right extends World {}

fun rowCount[w: World, r: RowBucket]: Int {
  #{ l: Link | r in l.(w.rowOf) }
}

fun colCount[w: World, c: ColBucket]: Int {
  #{ l: Link | c in l.(w.colOf) }
}

fun jointCount[w: World, r: RowBucket, c: ColBucket]: Int {
  #{ l: Link |
      r in l.(w.rowOf) and
      c in l.(w.colOf) }
}

pred sameMarginals[w1, w2: World] {
  all r: RowBucket |
    rowCount[w1, r] = rowCount[w2, r]
  all c: ColBucket |
    colCount[w1, c] = colCount[w2, c]
}

pred sameAnchor[w1, w2: World] {
  jointCount[w1, Row0, Col0] = jointCount[w2, Row0, Col0]
}

pred sameJointSummary[w1, w2: World] {
  all r: RowBucket, c: ColBucket |
    jointCount[w1, r, c] = jointCount[w2, r, c]
}

pred allMarginalBucketsOccupied[w: World] {
  all r: RowBucket | rowCount[w, r] > 0
  all c: ColBucket | colCount[w, c] > 0
}

pred sameMarginalsSameAnchorDifferentJoint {
  #Link = 6
  sameMarginals[Left, Right]
  sameAnchor[Left, Right]
  jointCount[Left, Row0, Col0] > 0
  allMarginalBucketsOccupied[Left]
  allMarginalBucketsOccupied[Right]
  not sameJointSummary[Left, Right]
}

assert MarginalsPlusOneAnchorDetermineThreeByThreeJoint {
  sameMarginals[Left, Right] and
  sameAnchor[Left, Right] implies
    sameJointSummary[Left, Right]
}

run sameMarginalsSameAnchorDifferentJoint for exactly 6 Link, exactly 3 RowBucket, exactly 3 ColBucket, exactly 2 World, 5 Int
check MarginalsPlusOneAnchorDetermineThreeByThreeJoint for exactly 6 Link, exactly 3 RowBucket, exactly 3 ColBucket, exactly 2 World, 5 Int
