module model/observation_016_commitment_vocabulary_quotient

abstract sig Purpose {}
one sig P0, P1 extends Purpose {}

abstract sig Unit {}
one sig U0, U1, U2, U3 extends Unit {}

one sig Physical {
  at: Unit -> one Purpose
}

abstract sig View {
  committed: set Unit
}
one sig Left, Right extends View {}

fact FixedPlacement {
  Physical.at =
    U0->P0 + U1->P0 +
    U2->P1 + U3->P1
}

fun unitsAt[p: Purpose]: set Unit {
  p.~(Physical.at)
}

fun committedAt[v: View, p: Purpose]: set Unit {
  v.committed & unitsAt[p]
}

fun movableFrom[v: View, p: Purpose]: set Unit {
  unitsAt[p] - v.committed
}

pred mayReassignNamed[v: View, u: Unit, q: Purpose] {
  u not in v.committed
  q not in u.(Physical.at)
}

pred samePurposeProfile[a, b: View] {
  all p: Purpose |
    #committedAt[a, p] = #committedAt[b, p]
}

pred sameNamedPermission[a, b: View] {
  all u: Unit, q: Purpose |
    (mayReassignNamed[a, u, q] iff
     mayReassignNamed[b, u, q])
}

pred sameTotalDifferentPurposeProfile {
  #Left.committed = #Right.committed
  not samePurposeProfile[Left, Right]
}

pred samePurposeProfileDifferentIdentity {
  samePurposeProfile[Left, Right]
  Left.committed != Right.committed
  not sameNamedPermission[Left, Right]
}

assert TotalCountDeterminesTotalMovable {
  #Left.committed = #Right.committed
  implies
  #(Unit - Left.committed) = #(Unit - Right.committed)
}

assert TotalCountDeterminesPurposeAnonymousPermission {
  #Left.committed = #Right.committed
  implies
  all p: Purpose |
    #movableFrom[Left, p] = #movableFrom[Right, p]
}

assert PurposeProfileDeterminesPurposeAnonymousPermission {
  samePurposeProfile[Left, Right]
  implies
  all p: Purpose |
    #movableFrom[Left, p] = #movableFrom[Right, p]
}

assert PurposeProfileDeterminesNamedPermission {
  samePurposeProfile[Left, Right]
  implies
  sameNamedPermission[Left, Right]
}

assert MembershipDeterminesNamedPermission {
  Left.committed = Right.committed
  implies
  sameNamedPermission[Left, Right]
}

assert NamedPermissionDeterminesMembership {
  sameNamedPermission[Left, Right]
  implies
  Left.committed = Right.committed
}

run sameTotalDifferentPurposeProfile for 4 Int
run samePurposeProfileDifferentIdentity for 4 Int
check TotalCountDeterminesTotalMovable for 4 Int
check TotalCountDeterminesPurposeAnonymousPermission for 4 Int
check PurposeProfileDeterminesPurposeAnonymousPermission for 4 Int
check PurposeProfileDeterminesNamedPermission for 4 Int
check MembershipDeterminesNamedPermission for 4 Int
check NamedPermissionDeterminesMembership for 4 Int
