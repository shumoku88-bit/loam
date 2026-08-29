module model/observation_014_commitment_as_history

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

fun observedThroughPresent: set Time {
  present.*(ord/prev)
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

pred sameIntentionalHistory[a, b: World] {
  a.declared = b.declared
  a.released = b.released
}

pred mayReassignNow[w: World, u: Unit, q: Purpose] {
  u in derivedAvailable[w, present]
  u not in usedAt[w, present]
  q not in purposeAt[w, present, u]
  no u.(activeCommitment[w, present])
}

pred samePhysicalTraceDifferentIntent {
  modelLaws
  samePhysicalTrace[Left, Right]
  some usedBefore[Left, present]

  some u: Unit, p, q: Purpose |
    u->p in activeCommitment[Left, present] and
    no u.(activeCommitment[Right, present]) and
    q != p and
    mayReassignNow[Right, u, q] and
    not mayReassignNow[Left, u, q]
}

pred declareReleaseRedeclare {
  modelLaws

  some w: World, u: Unit, p: Purpose |
    ord/first->u->p in w.declared and
    ord/next[ord/first]->u->p in w.released and
    present->u->p in w.declared and
    u->p in activeCommitment[w, present]
}

assert PhysicalTraceDeterminesActiveCommitment {
  (modelLaws and samePhysicalTrace[Left, Right])
  implies
  activeCommitment[Left, present] = activeCommitment[Right, present]
}

assert IntentionalHistoryDeterminesActiveCommitment {
  sameIntentionalHistory[Left, Right]
  implies
  all t: Time |
    activeCommitment[Left, t] = activeCommitment[Right, t]
}

assert CombinedHistoryDeterminesPermission {
  (modelLaws and
   samePhysicalTrace[Left, Right] and
   sameIntentionalHistory[Left, Right])
  implies
  all u: Unit, q: Purpose |
    (mayReassignNow[Left, u, q] iff
     mayReassignNow[Right, u, q])
}

assert ActiveCommitmentIsHonoredThroughHorizon {
  modelLaws implies
    all w: World, u: Unit, p: Purpose |
      u->p in activeCommitment[w, present]
      implies
      all t: present.*(ord/next) |
        p in purposeAt[w, t, u]
}

run samePhysicalTraceDifferentIntent for exactly 5 Time, exactly 2 Purpose, exactly 4 Unit
run declareReleaseRedeclare for exactly 5 Time, exactly 2 Purpose, exactly 4 Unit
check PhysicalTraceDeterminesActiveCommitment for exactly 5 Time, exactly 2 Purpose, exactly 4 Unit
check IntentionalHistoryDeterminesActiveCommitment for exactly 5 Time, exactly 2 Purpose, exactly 4 Unit
check CombinedHistoryDeterminesPermission for exactly 5 Time, exactly 2 Purpose, exactly 4 Unit
check ActiveCommitmentIsHonoredThroughHorizon for exactly 5 Time, exactly 2 Purpose, exactly 4 Unit
