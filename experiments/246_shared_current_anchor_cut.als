module experiments/observation_246_shared_current_anchor_cut

sig Coordinate {}
sig Root {}
sig Session {}

abstract sig World {
  -- A quantity explicitly observed for one coordinate at one reconciliation
  -- boundary. Presence is support evidence; absence remains unknown.
  asserted: Coordinate -> lone Int,

  -- One reconciliation-session cut shared by every asserted coordinate. A root
  -- in this set is already reflected by the observed quantities and therefore
  -- must not be added again, even if its current correction terminal changes.
  reflected: set Root,

  -- Current correction-selected contribution of each stable Event correction
  -- root to each coordinate. The root is stable; this quantity may change when
  -- an old Event is corrected or reclassified.
  effective: Root -> Coordinate -> one Int,

  -- Comparison-only representation of duplicated coordinate-local cuts.
  -- It is not the candidate production shape.
  perCoordinateReflected: Coordinate -> Root,

  -- Follow-up comparison shape: several reconciliation sessions may coexist in
  -- one current-support image. A supported coordinate belongs to at most one
  -- session; the session carries the shared reflected-root cut.
  sessionOf: Coordinate -> lone Session,
  sessionReflected: Session -> Root,

  -- Comparison-only relaxed membership used to show why one current coordinate
  -- cannot belong to two live sessions at once.
  candidateSessions: Coordinate -> Session,

  -- Independent historical-origin evidence. Current assertions must not imply
  -- this stronger fact.
  originComplete: set Coordinate
}

one sig Left, Right extends World {}

fun assertedAt[w: World, c: Coordinate]: one Int {
  sum { i: Int | c->i in w.asserted }
}

fun effectiveAt[w: World, r: Root, c: Coordinate]: one Int {
  sum { i: Int | r->c->i in w.effective }
}

pred supported[w: World, c: Coordinate] {
  some c.(w.asserted)
}

fun sharedCurrent[w: World, c: Coordinate]: one Int {
  add[
    assertedAt[w, c],
    sum r: Root - w.reflected | effectiveAt[w, r, c]
  ]
}

fun localCurrent[w: World, c: Coordinate]: one Int {
  add[
    assertedAt[w, c],
    sum r: Root - c.(w.perCoordinateReflected) | effectiveAt[w, r, c]
  ]
}

fun sessionCut[w: World, c: Coordinate]: set Root {
  c.(w.sessionOf).(w.sessionReflected)
}

pred groupedSupported[w: World, c: Coordinate] {
  supported[w, c]
  one c.(w.sessionOf)
}

fun groupedCurrent[w: World, c: Coordinate]: one Int {
  add[
    assertedAt[w, c],
    sum r: Root - sessionCut[w, c] | effectiveAt[w, r, c]
  ]
}

fun candidateCurrent[w: World, c: Coordinate, s: Session]: one Int {
  add[
    assertedAt[w, c],
    sum r: Root - s.(w.sessionReflected) | effectiveAt[w, r, c]
  ]
}

fun currentWithCut[w: World, c: Coordinate, cut: set Root]: one Int {
  add[
    assertedAt[w, c],
    sum r: Root - cut | effectiveAt[w, r, c]
  ]
}

fact SmallQuantities {
  all w: World, c: Coordinate | {
    all i: c.(w.asserted) | i >= -3 and i <= 3
    all r: Root |
      let q = effectiveAt[w, r, c] | q >= -3 and q <= 3
  }
}

-- One reconciliation session can observe multiple coordinates while retaining
-- only one reflected-root cut.
pred sharedCutSupportsMultipleCoordinates {
  some disj a, b: Coordinate | {
    supported[Left, a]
    supported[Left, b]
    some Left.reflected
    sharedCurrent[Left, a] != sharedCurrent[Left, b]
  }
}

-- The root cut is independent information: equal observed quantities and equal
-- current root contributions can produce a different answer when the cut differs.
pred cutIsIndependentEvidence {
  Left.asserted = Right.asserted
  Left.effective = Right.effective
  Left.reflected != Right.reflected
  some c: Coordinate | {
    supported[Left, c]
    supported[Right, c]
    sharedCurrent[Left, c] != sharedCurrent[Right, c]
  }
}

-- A correction/reclassification of a root already reflected by the observation
-- must not move the anchored current answer. Only uncovered roots are deltas.
pred coveredRootCorrectionIsAbsorbed {
  Left.asserted = Right.asserted
  Left.reflected = Right.reflected
  some Left.reflected
  all r: Root - Left.reflected, c: Coordinate |
    effectiveAt[Left, r, c] = effectiveAt[Right, r, c]
  some r: Left.reflected, c: Coordinate |
    effectiveAt[Left, r, c] != effectiveAt[Right, r, c]
  all c: Coordinate |
    supported[Left, c] implies sharedCurrent[Left, c] = sharedCurrent[Right, c]
}

-- A genuinely post-anchor root is outside the shared cut and therefore changes
-- the current answer when its effective quantity changes.
pred uncoveredRootContributes {
  Left.asserted = Right.asserted
  Left.reflected = Right.reflected
  some r: Root - Left.reflected, c: Coordinate | {
    supported[Left, c]
    all other: Root - r, d: Coordinate |
      effectiveAt[Left, other, d] = effectiveAt[Right, other, d]
    effectiveAt[Left, r, c] != effectiveAt[Right, r, c]
    sharedCurrent[Left, c] != sharedCurrent[Right, c]
  }
}

-- If every coordinate was observed in the same reconciliation session,
-- duplicating the same cut per coordinate carries no extra answer information.
pred sharedAndDuplicatedCutAgree {
  some c: Coordinate | supported[Left, c]
  all c: Coordinate |
    supported[Left, c] implies c.(Left.perCoordinateReflected) = Left.reflected
}

-- Negative control: if coordinates came from different boundaries, forcing one
-- of those cuts to be shared can change another coordinate's answer. A shared
-- cut is therefore a session fact, not a universal replacement for all anchors.
pred differentBoundariesNeedDistinctCuts {
  some disj a, b: Coordinate | {
    supported[Left, a]
    supported[Left, b]
    a.(Left.perCoordinateReflected) != b.(Left.perCoordinateReflected)
    Left.reflected = a.(Left.perCoordinateReflected)
    sharedCurrent[Left, b] != localCurrent[Left, b]
  }
}

-- Follow-up: different observation sessions can coexist without duplicating a
-- reflected-root cut per coordinate.
pred multipleSessionsSupportDifferentCuts {
  some disj a, b: Coordinate, disj sa, sb: Session | {
    groupedSupported[Left, a]
    groupedSupported[Left, b]
    a.(Left.sessionOf) = sa
    b.(Left.sessionOf) = sb
    sessionCut[Left, a] != sessionCut[Left, b]
    groupedCurrent[Left, a] != groupedCurrent[Left, b]
  }
}

-- A later independently observed coordinate can be added under a new session
-- without changing an older coordinate's assertion or reflected-root cut.
pred incrementalSessionPreservesExisting {
  Left.effective = Right.effective
  some disj old, fresh: Coordinate, disj oldSession, freshSession: Session | {
    groupedSupported[Left, old]
    not supported[Left, fresh]
    groupedSupported[Right, old]
    groupedSupported[Right, fresh]

    old.(Left.sessionOf) = oldSession
    old.(Right.sessionOf) = oldSession
    fresh.(Right.sessionOf) = freshSession

    old.(Left.asserted) = old.(Right.asserted)
    oldSession.(Left.sessionReflected) = oldSession.(Right.sessionReflected)
    some sessionCut[Right, fresh] - sessionCut[Right, old]

    groupedCurrent[Left, old] = groupedCurrent[Right, old]
  }
}

-- Session atoms are grouping/compression carriers, not stable semantic identity.
-- Two worlds can use different Session atoms while retaining the same
-- coordinate-local cut and therefore the same current answer.
pred differentSessionIdentitySameAnswer {
  Left.asserted = Right.asserted
  Left.effective = Right.effective
  some c: Coordinate, disj sa, sb: Session | {
    groupedSupported[Left, c]
    groupedSupported[Right, c]
    c.(Left.sessionOf) = sa
    c.(Right.sessionOf) = sb
    sessionCut[Left, c] = sessionCut[Right, c]
    groupedCurrent[Left, c] = groupedCurrent[Right, c]
  }
}

-- Relaxing one coordinate to two simultaneous live sessions is ambiguous when
-- those sessions carry observably different cuts.
pred duplicateSessionMembershipCanDisagree {
  some w: World, c: Coordinate, disj sa, sb: Session | {
    supported[w, c]
    sa in c.(w.candidateSessions)
    sb in c.(w.candidateSessions)
    sa.(w.sessionReflected) != sb.(w.sessionReflected)
    candidateCurrent[w, c, sa] != candidateCurrent[w, c, sb]
  }
}

-- A current assertion says nothing about complete origin history.
pred currentSupportWithoutOriginCompleteness {
  some c: Coordinate | {
    supported[Left, c]
    c not in Left.originComplete
  }
}

assert CoveredRootChangesDoNotChangeCurrent {
  (Left.asserted = Right.asserted and
   Left.reflected = Right.reflected and
   all r: Root - Left.reflected, c: Coordinate |
     effectiveAt[Left, r, c] = effectiveAt[Right, r, c]) implies
    all c: Coordinate |
      supported[Left, c] implies
        sharedCurrent[Left, c] = sharedCurrent[Right, c]
}

assert SharedCutEqualsDuplicatedEqualCuts {
  all w: World |
    (all c: Coordinate |
      supported[w, c] implies c.(w.perCoordinateReflected) = w.reflected) implies
        all c: Coordinate |
          supported[w, c] implies sharedCurrent[w, c] = localCurrent[w, c]
}

assert GroupedSessionsEqualDuplicatedCuts {
  all w: World, c: Coordinate |
    (groupedSupported[w, c] and
      c.(w.perCoordinateReflected) = sessionCut[w, c]) implies
        groupedCurrent[w, c] = localCurrent[w, c]
}

assert ExistingGroupedAnswerPreserved {
  (Left.effective = Right.effective and
    all c: Coordinate |
      groupedSupported[Left, c] implies {
        groupedSupported[Right, c]
        c.(Left.asserted) = c.(Right.asserted)
        sessionCut[Left, c] = sessionCut[Right, c]
      }) implies
    all c: Coordinate |
      groupedSupported[Left, c] implies
        groupedCurrent[Left, c] = groupedCurrent[Right, c]
}

assert CoordinateCutsDetermineGroupedCurrent {
  (Left.asserted = Right.asserted and
    Left.effective = Right.effective and
    (all c: Coordinate |
      groupedSupported[Left, c] iff groupedSupported[Right, c]) and
    (all c: Coordinate |
      groupedSupported[Left, c] implies
        sessionCut[Left, c] = sessionCut[Right, c])) implies
    all c: Coordinate |
      groupedSupported[Left, c] implies
        groupedCurrent[Left, c] = groupedCurrent[Right, c]
}

assert OneSharedCutAlwaysRepresentsGroupedSessions {
  all w: World |
    (some c: Coordinate | groupedSupported[w, c]) implies
      some cut: set Root |
        all c: Coordinate |
          groupedSupported[w, c] implies
            currentWithCut[w, c, cut] = groupedCurrent[w, c]
}

assert MissingAssertionRemainsUnsupported {
  all w: World, c: Coordinate |
    no c.(w.asserted) implies not supported[w, c]
}

assert CurrentAssertionImpliesOriginCompleteness {
  all w: World, c: Coordinate |
    supported[w, c] implies c in w.originComplete
}

run sharedCutSupportsMultipleCoordinates for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, 5 Int
run cutIsIndependentEvidence for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, 5 Int
run coveredRootCorrectionIsAbsorbed for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, 5 Int
run uncoveredRootContributes for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, 5 Int
run sharedAndDuplicatedCutAgree for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, 5 Int
run differentBoundariesNeedDistinctCuts for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, 5 Int
run currentSupportWithoutOriginCompleteness for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, 5 Int
run multipleSessionsSupportDifferentCuts for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, exactly 2 Session, 5 Int
run incrementalSessionPreservesExisting for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, exactly 2 Session, 5 Int
run differentSessionIdentitySameAnswer for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, exactly 2 Session, 5 Int
run duplicateSessionMembershipCanDisagree for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, exactly 2 Session, 5 Int
check GroupedSessionsEqualDuplicatedCuts for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, exactly 2 Session, 5 Int
check ExistingGroupedAnswerPreserved for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, exactly 2 Session, 5 Int
check CoordinateCutsDetermineGroupedCurrent for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, exactly 2 Session, 5 Int
check OneSharedCutAlwaysRepresentsGroupedSessions for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, exactly 2 Session, 5 Int
check CoveredRootChangesDoNotChangeCurrent for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, 5 Int
check SharedCutEqualsDuplicatedEqualCuts for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, 5 Int
check MissingAssertionRemainsUnsupported for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, 5 Int
check CurrentAssertionImpliesOriginCompleteness for exactly 2 World, exactly 2 Coordinate, exactly 3 Root, 5 Int
