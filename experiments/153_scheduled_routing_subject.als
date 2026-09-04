module experiments/observation_153_scheduled_routing_subject

sig Purpose {}
sig Locus {}
sig Unit {}
sig Scheduled {}

-- A CoordinateClaim is not proposed canonical identity. It is the quantity-bearing
-- Scheduled × Locus coordinate obtained after aggregating duplicate movement
-- changes at the same Locus, matching BalancedMovement.quantityAt.
sig CoordinateClaim {
  scheduled: one Scheduled,
  locus: one Locus,
  units: some Unit
}

-- Deliberately competing fresh identity candidate. The bijection below gives it
-- no information beyond one CoordinateClaim.
sig ClaimId {
  coordinate: one CoordinateClaim
}

sig ScheduledRoute {
  scheduledSubject: one Scheduled,
  purpose: one Purpose
}

sig LocusRoute {
  locusSubject: one Locus,
  purpose: one Purpose
}

sig CoordinateRoute {
  coordinateSubject: one CoordinateClaim,
  purpose: one Purpose
}

sig ClaimRoute {
  claimSubject: one ClaimId,
  purpose: one Purpose
}

fact UnitOwnership {
  all u: Unit | one c: CoordinateClaim | u in c.units
}

fact CoordinateClaimIsScheduledLocusPair {
  all s: Scheduled, l: Locus |
    lone { c: CoordinateClaim | c.scheduled = s and c.locus = l }
}

fact ClaimIdentityIsOnlyABijection {
  all c: CoordinateClaim | one i: ClaimId | i.coordinate = c
}

fact FunctionalCandidateRoutes {
  all s: Scheduled |
    lone { r: ScheduledRoute | r.scheduledSubject = s }
  all l: Locus |
    lone { r: LocusRoute | r.locusSubject = l }
  all c: CoordinateClaim |
    lone { r: CoordinateRoute | r.coordinateSubject = c }
  all i: ClaimId |
    lone { r: ClaimRoute | r.claimSubject = i }
}

fun scheduledCommitment: Unit -> Purpose {
  { u: Unit, p: Purpose |
    some c: CoordinateClaim, r: ScheduledRoute |
      u in c.units and
      r.scheduledSubject = c.scheduled and
      r.purpose = p
  }
}

fun locusCommitment: Unit -> Purpose {
  { u: Unit, p: Purpose |
    some c: CoordinateClaim, r: LocusRoute |
      u in c.units and
      r.locusSubject = c.locus and
      r.purpose = p
  }
}

fun coordinateCommitment: Unit -> Purpose {
  { u: Unit, p: Purpose |
    some c: CoordinateClaim, r: CoordinateRoute |
      u in c.units and
      r.coordinateSubject = c and
      r.purpose = p
  }
}

fun claimCommitment: Unit -> Purpose {
  { u: Unit, p: Purpose |
    some c: CoordinateClaim, i: ClaimId, r: ClaimRoute |
      u in c.units and
      i.coordinate = c and
      r.claimSubject = i and
      r.purpose = p
  }
}

-- One Scheduled occurrence can contain two independently routed quantity
-- coordinates. This is the pressure against routing only by ScheduledId.
pred splitWithinScheduledWitness {
  some s: Scheduled |
    some disj c1, c2: CoordinateClaim |
      some disj p1, p2: Purpose |
        some disj u1, u2: Unit | {
          c1.scheduled = s
          c2.scheduled = s
          c1.locus != c2.locus
          u1 in c1.units
          u2 in c2.units
          some r1: CoordinateRoute |
            r1.coordinateSubject = c1 and r1.purpose = p1
          some r2: CoordinateRoute |
            r2.coordinateSubject = c2 and r2.purpose = p2
          u1->p1 in coordinateCommitment
          u2->p2 in coordinateCommitment
        }
}

-- The same Locus can participate in different Scheduled identities whose
-- household intent differs. This is the pressure against reusing bare Locus as
-- the Scheduled routing subject.
pred crossScheduledSameLocusWitness {
  some disj s1, s2: Scheduled |
    some disj c1, c2: CoordinateClaim |
      some disj p1, p2: Purpose |
        some disj u1, u2: Unit | {
          c1.scheduled = s1
          c2.scheduled = s2
          c1.locus = c2.locus
          u1 in c1.units
          u2 in c2.units
          some r1: CoordinateRoute |
            r1.coordinateSubject = c1 and r1.purpose = p1
          some r2: CoordinateRoute |
            r2.coordinateSubject = c2 and r2.purpose = p2
          u1->p1 in coordinateCommitment
          u2->p2 in coordinateCommitment
        }
}

pred claimRoutesMirrorCoordinates {
  all c: CoordinateClaim, p: Purpose |
    ((some r: CoordinateRoute |
        r.coordinateSubject = c and r.purpose = p)
      iff
     (some i: ClaimId, r: ClaimRoute |
        i.coordinate = c and
        r.claimSubject = i and
        r.purpose = p))
}

pred claimIdentityMirrorWitness {
  claimRoutesMirrorCoordinates
  some coordinateCommitment
  coordinateCommitment = claimCommitment
}

assert ScheduledOnlyCannotMatchSplitCoordinateView {
  all s: Scheduled, disj c1, c2: CoordinateClaim,
      disj p1, p2: Purpose, disj u1, u2: Unit |
    c1.scheduled = s and
    c2.scheduled = s and
    c1.locus != c2.locus and
    u1 in c1.units and
    u2 in c2.units and
    (some r1: CoordinateRoute |
      r1.coordinateSubject = c1 and r1.purpose = p1) and
    (some r2: CoordinateRoute |
      r2.coordinateSubject = c2 and r2.purpose = p2)
    implies
      scheduledCommitment != coordinateCommitment
}

assert LocusOnlyCannotMatchCrossScheduledCoordinateView {
  all disj s1, s2: Scheduled, disj c1, c2: CoordinateClaim,
      disj p1, p2: Purpose, disj u1, u2: Unit |
    c1.scheduled = s1 and
    c2.scheduled = s2 and
    c1.locus = c2.locus and
    u1 in c1.units and
    u2 in c2.units and
    (some r1: CoordinateRoute |
      r1.coordinateSubject = c1 and r1.purpose = p1) and
    (some r2: CoordinateRoute |
      r2.coordinateSubject = c2 and r2.purpose = p2)
    implies
      locusCommitment != coordinateCommitment
}

assert MirroredClaimIdentityAddsNoCommitmentAnswer {
  claimRoutesMirrorCoordinates implies
    claimCommitment = coordinateCommitment
}

run splitWithinScheduledWitness for
  exactly 3 Scheduled, exactly 3 Purpose, exactly 3 Locus,
  exactly 5 CoordinateClaim, exactly 8 Unit, exactly 5 ClaimId,
  exactly 3 ScheduledRoute, exactly 3 LocusRoute,
  exactly 5 CoordinateRoute, exactly 5 ClaimRoute

run crossScheduledSameLocusWitness for
  exactly 3 Scheduled, exactly 3 Purpose, exactly 3 Locus,
  exactly 5 CoordinateClaim, exactly 8 Unit, exactly 5 ClaimId,
  exactly 3 ScheduledRoute, exactly 3 LocusRoute,
  exactly 5 CoordinateRoute, exactly 5 ClaimRoute

run claimIdentityMirrorWitness for
  exactly 3 Scheduled, exactly 3 Purpose, exactly 3 Locus,
  exactly 5 CoordinateClaim, exactly 8 Unit, exactly 5 ClaimId,
  exactly 3 ScheduledRoute, exactly 3 LocusRoute,
  exactly 5 CoordinateRoute, exactly 5 ClaimRoute

check ScheduledOnlyCannotMatchSplitCoordinateView for
  exactly 3 Scheduled, exactly 3 Purpose, exactly 3 Locus,
  exactly 5 CoordinateClaim, exactly 8 Unit, exactly 5 ClaimId,
  exactly 3 ScheduledRoute, exactly 3 LocusRoute,
  exactly 5 CoordinateRoute, exactly 5 ClaimRoute

check LocusOnlyCannotMatchCrossScheduledCoordinateView for
  exactly 3 Scheduled, exactly 3 Purpose, exactly 3 Locus,
  exactly 5 CoordinateClaim, exactly 8 Unit, exactly 5 ClaimId,
  exactly 3 ScheduledRoute, exactly 3 LocusRoute,
  exactly 5 CoordinateRoute, exactly 5 ClaimRoute

check MirroredClaimIdentityAddsNoCommitmentAnswer for
  exactly 3 Scheduled, exactly 3 Purpose, exactly 3 Locus,
  exactly 5 CoordinateClaim, exactly 8 Unit, exactly 5 ClaimId,
  exactly 3 ScheduledRoute, exactly 3 LocusRoute,
  exactly 5 CoordinateRoute, exactly 5 ClaimRoute
