module model/observation_015_commitment_identity_summary

open util/ordering[Time] as ord

sig Time {}
sig Purpose {}
sig Unit {}

one sig Origin {
  initial: set Unit
}

abstract sig World {
  at: Time -> Unit -> Purpose,
  used: Time -> Unit -> Purpose,
  declared: Time -> Unit -> Purpose,
  released: Time -> Unit -> Purpose
}

one sig Left, Right extends World {}

fact ClosedResourceWorld {
  Origin.initial = Unit
}

fun present: one Time {
  ord/next[ord/next[ord/first]]
}

fun futureBeforeHorizon: set Time {
  present.^(ord/next) - ord/last
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
    some earlier: t.^(ord/prev), p: Purpose |
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

fun activeBefore[w: World, t: Time]: Unit -> Purpose {
  { u: Unit, p: Purpose |
    some d: t.^(ord/prev) |
      d->u->p in w.declared and
      no r: t.^(ord/prev) & d.^(ord/next) |
        r->u->p in w.released
  }
}

fun activeCommitment[w: World, t: Time]: Unit -> Purpose {
  { u: Unit, p: Purpose |
    some d: t.*(ord/prev) |
      d->u->p in w.declared and
      no r: t.*(ord/prev) & d.^(ord/next) |
        r->u->p in w.released
  }
}

fun committedUnits[w: World, t: Time]: set Unit {
  { u: Unit |
    some u.(activeCommitment[w, t])
  }
}

fun reconstructedActive[w: World, t: Time]: Unit -> Purpose {
  { u: Unit, p: Purpose |
    u in committedUnits[w, t] and
    p in purposeAt[w, t, u]
  }
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

pred intentionalHistoryIsCoherent[w: World] {
  no w.declared & w.released

  all t: Time, u: Unit |
    lone u.(activeCommitment[w, t])

  all t: Time, u: Unit, p: Purpose |
    t->u->p in w.declared
    implies
    (no u.(activeBefore[w, t]) and
     u in liveAtPurpose[w, t, p] and
     u not in usedAt[w, t])

  all t: Time, u: Unit, p: Purpose |
    t->u->p in w.released
    implies
    u->p in activeBefore[w, t]
}

pred activeCommitmentSemantics[w: World] {
  all u: Unit, p: Purpose |
    u->p in activeCommitment[w, present]
    implies
    (u in liveAtPurpose[w, present, p] and
     u not in usedAt[w, present] and
     all t: present.*(ord/next) |
       p in purposeAt[w, t, u] and
     all t: futureBeforeHorizon |
       u not in usedAt[w, t])
}

pred worldLaws[w: World] {
  totalPlacement[w]
  usesRespectUnderlyingBoundary[w]
  intentionalHistoryIsCoherent[w]
  activeCommitmentSemantics[w]
}

pred modelLaws {
  all w: World |
    worldLaws[w]
}

pred samePhysicalTrace[a, b: World] {
  a.at = b.at
  a.used = b.used
}

pred mayReassignNow[w: World, u: Unit, q: Purpose] {
  u in derivedAvailable[w, present]
  u not in usedAt[w, present]
  q not in purposeAt[w, present, u]
  no u.(activeCommitment[w, present])
}

pred releaseEnabledNow[w: World, u: Unit, p: Purpose] {
  u->p in activeCommitment[w, present]
}

pred samePhysicalSameCountDifferentCommittedIdentity {
  modelLaws
  samePhysicalTrace[Left, Right]
  #committedUnits[Left, present] = #committedUnits[Right, present]
  committedUnits[Left, present] != committedUnits[Right, present]

  some u: committedUnits[Left, present] - committedUnits[Right, present], q: Purpose |
    mayReassignNow[Right, u, q] and
    not mayReassignNow[Left, u, q]
}

assert PhysicalTraceDeterminesCommittedUnits {
  (modelLaws and samePhysicalTrace[Left, Right])
  implies
  committedUnits[Left, present] = committedUnits[Right, present]
}

assert CommittedCountDeterminesPermission {
  (modelLaws and
   samePhysicalTrace[Left, Right] and
   #committedUnits[Left, present] = #committedUnits[Right, present])
  implies
  all u: Unit, q: Purpose |
    (mayReassignNow[Left, u, q] iff
     mayReassignNow[Right, u, q])
}

assert CommittedUnitsPlusPlacementReconstructsActive {
  modelLaws implies
    all w: World |
      reconstructedActive[w, present] = activeCommitment[w, present]
}

assert CommittedUnitsDetermineActiveGivenPhysicalTrace {
  (modelLaws and
   samePhysicalTrace[Left, Right] and
   committedUnits[Left, present] = committedUnits[Right, present])
  implies
  activeCommitment[Left, present] = activeCommitment[Right, present]
}

assert CommittedUnitsDeterminePermission {
  (modelLaws and
   samePhysicalTrace[Left, Right] and
   committedUnits[Left, present] = committedUnits[Right, present])
  implies
  all u: Unit, q: Purpose |
    (mayReassignNow[Left, u, q] iff
     mayReassignNow[Right, u, q])
}

assert CommittedUnitsDetermineReleaseEnabled {
  (modelLaws and
   samePhysicalTrace[Left, Right] and
   committedUnits[Left, present] = committedUnits[Right, present])
  implies
  all u: Unit, p: Purpose |
    (releaseEnabledNow[Left, u, p] iff
     releaseEnabledNow[Right, u, p])
}

run samePhysicalSameCountDifferentCommittedIdentity for exactly 5 Time, exactly 2 Purpose, exactly 4 Unit
check PhysicalTraceDeterminesCommittedUnits for exactly 5 Time, exactly 2 Purpose, exactly 4 Unit
check CommittedCountDeterminesPermission for exactly 5 Time, exactly 2 Purpose, exactly 4 Unit
check CommittedUnitsPlusPlacementReconstructsActive for exactly 5 Time, exactly 2 Purpose, exactly 4 Unit
check CommittedUnitsDetermineActiveGivenPhysicalTrace for exactly 5 Time, exactly 2 Purpose, exactly 4 Unit
check CommittedUnitsDeterminePermission for exactly 5 Time, exactly 2 Purpose, exactly 4 Unit
check CommittedUnitsDetermineReleaseEnabled for exactly 5 Time, exactly 2 Purpose, exactly 4 Unit
