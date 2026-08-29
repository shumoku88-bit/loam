module model/observation_013_commitment_not_projection

open util/ordering[Time]

sig Time {}
sig Purpose {}
sig Unit {}

one sig Origin {
  initial: set Unit
}

abstract sig World {
  at: Time -> Unit -> Purpose,
  used: Time -> Unit -> Purpose,
  commitment: Unit -> Purpose
}

one sig Left, Right extends World {}

fact ClosedResourceWorld {
  Origin.initial = Unit
}

fun present: one Time {
  next[first]
}

fun observedThroughPresent: set Time {
  present.*prev
}

fun futureBeforeHorizon: set Time {
  present.^next - last
}

fun purposeAt[w: World, t: Time, u: Unit]: set Purpose {
  u.(t.(w.at))
}

fun usedAt[w: World, t: Time]: set Unit {
  { u: Unit |
    some p: Purpose |
      t->u->p in w.used
  }
}

fun usedBefore[w: World, t: Time]: set Unit {
  { u: Unit |
    some earlier: t.^prev, p: Purpose |
      earlier->u->p in w.used
  }
}

fun derivedAvailable[w: World, t: Time]: set Unit {
  Origin.initial - usedBefore[w, t]
}

fun liveAtPurpose[w: World, t: Time, p: Purpose]: set Unit {
  { u: Unit |
    u in derivedAvailable[w, t] and
    p in purposeAt[w, t, u]
  }
}

fun commitmentPurpose[w: World, u: Unit]: set Purpose {
  u.(w.commitment)
}

pred totalPlacement[w: World] {
  all t: Time, u: Unit |
    one purposeAt[w, t, u]
}

pred usesRespectUnderlyingBoundary[w: World] {
  all t: Time, u: Unit |
    lone p: Purpose |
      t->u->p in w.used

  all t: Time, u: Unit, p: Purpose |
    t->u->p in w.used
    implies
    (u in derivedAvailable[w, t] and
     p in purposeAt[w, t, u])
}

pred commitmentSemantics[w: World] {
  all u: Unit |
    lone commitmentPurpose[w, u]

  all u: Unit, p: Purpose |
    p in commitmentPurpose[w, u]
    implies
    (u in liveAtPurpose[w, present, p] and
     u not in usedAt[w, present] and
     all t: present.*next |
       p in purposeAt[w, t, u] and
     all t: futureBeforeHorizon |
       u not in usedAt[w, t])
}

pred worldLaws[w: World] {
  totalPlacement[w]
  usesRespectUnderlyingBoundary[w]
  commitmentSemantics[w]
}

pred modelLaws {
  all w: World |
    worldLaws[w]
}

pred sameCurrentLiveView[a, b: World] {
  all p: Purpose |
    liveAtPurpose[a, present, p] = liveAtPurpose[b, present, p]
}

pred sameObservedHistory[a, b: World] {
  all t: observedThroughPresent |
    t.(a.at) = t.(b.at) and
    t.(a.used) = t.(b.used)
}

pred samePhysicalTrace[a, b: World] {
  a.at = b.at
  a.used = b.used
}

pred mayReassignNow[w: World, u: Unit, q: Purpose] {
  u in derivedAvailable[w, present]
  u not in usedAt[w, present]
  q not in purposeAt[w, present, u]
  no commitmentPurpose[w, u]
}

pred sameHistoryDifferentPermission {
  modelLaws
  sameObservedHistory[Left, Right]
  some usedBefore[Left, present]

  some u: Unit, p, q: Purpose |
    p in commitmentPurpose[Left, u] and
    no commitmentPurpose[Right, u] and
    q != p and
    mayReassignNow[Right, u, q] and
    not mayReassignNow[Left, u, q]
}

pred sameTraceDifferentCommitment {
  modelLaws
  samePhysicalTrace[Left, Right]
  some usedBefore[Left, present]

  some u: Unit, p: Purpose |
    p in commitmentPurpose[Left, u] and
    no commitmentPurpose[Right, u]
}

assert CurrentLiveViewDeterminesCommitment {
  (modelLaws and sameCurrentLiveView[Left, Right])
  implies
  Left.commitment = Right.commitment
}

assert ObservedHistoryDeterminesCommitment {
  (modelLaws and sameObservedHistory[Left, Right])
  implies
  Left.commitment = Right.commitment
}

assert FullPhysicalTraceDeterminesCommitment {
  (modelLaws and samePhysicalTrace[Left, Right])
  implies
  Left.commitment = Right.commitment
}

assert CommitmentNamesPresentLiveHolding {
  modelLaws implies
    all w: World, u: Unit, p: Purpose |
      p in commitmentPurpose[w, u]
      implies
      u in liveAtPurpose[w, present, p]
}

assert CommitmentIsHonoredThroughHorizon {
  modelLaws implies
    all w: World, u: Unit, p: Purpose |
      p in commitmentPurpose[w, u]
      implies
      (all t: present.*next |
         p in purposeAt[w, t, u])
}

run sameHistoryDifferentPermission for exactly 4 Time, exactly 2 Purpose, exactly 4 Unit
run sameTraceDifferentCommitment for exactly 4 Time, exactly 2 Purpose, exactly 4 Unit
check CurrentLiveViewDeterminesCommitment for exactly 4 Time, exactly 2 Purpose, exactly 4 Unit
check ObservedHistoryDeterminesCommitment for exactly 4 Time, exactly 2 Purpose, exactly 4 Unit
check FullPhysicalTraceDeterminesCommitment for exactly 4 Time, exactly 2 Purpose, exactly 4 Unit
check CommitmentNamesPresentLiveHolding for exactly 4 Time, exactly 2 Purpose, exactly 4 Unit
check CommitmentIsHonoredThroughHorizon for exactly 4 Time, exactly 2 Purpose, exactly 4 Unit
