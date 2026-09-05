module experiments/observation_199_shared_refund_composition

-- F076 asks whether a later full refund of a shared expense requires a new
-- second-order refund primitive, or whether already-earned evidence composes:
--
--   refund source provenance          (Observation 065)
--   burden allocation                 (Observation 163)
--   prior discharge / settlement      (Observation 165)
--
-- This model uses unit-count quantities only. It is not a production proposal.

sig Cost {}

sig Unit {
  cost: one Cost
}

abstract sig Participant {}
one sig Household, OutsideA, OutsideB extends Participant {}

sig Refund {}

sig World {
  bearer: Unit -> one Participant,
  settledOutside: set Unit,
  refundOf: Refund -> lone Cost
}

one sig Left, Right extends World {}
one sig C1, C2 extends Cost {}
one sig U1, U2, U3, U4 extends Unit {}
one sig R extends Refund {}

fact UnitCoordinates {
  U1.cost = C1
  U2.cost = C1
  U3.cost = C2
  U4.cost = C2
}

fact WellFormed {
  all w: World | {
    all u: w.settledOutside | w.bearer[u] != Household
  }
}

fun refundedUnits[w: World, r: Refund]: set Unit {
  { u: Unit | u.cost in r.(w.refundOf) }
}

fun householdRefundShare[w: World, r: Refund]: set Unit {
  { u: refundedUnits[w, r] | w.bearer[u] = Household }
}

-- If an outside-borne unit was already settled before the merchant refund,
-- the household has received that participant's share already. The later
-- refund therefore creates value that must be returned outward.
fun reverseObligationUnits[w: World, r: Refund]: set Unit {
  { u: refundedUnits[w, r] |
      w.bearer[u] != Household and u in w.settledOutside }
}

-- If the outside-borne unit was not settled yet, the merchant refund removes
-- the still-open amount instead of creating a reverse payment obligation.
fun extinguishedReceivableUnits[w: World, r: Refund]: set Unit {
  { u: refundedUnits[w, r] |
      w.bearer[u] != Household and u not in w.settledOutside }
}

fun refundOwedTo[w: World, r: Refund, p: Participant]: set Unit {
  { u: reverseObligationUnits[w, r] | w.bearer[u] = p }
}

pred representativeSettledSharedRefund {
  Left.bearer[U1] = Household
  Left.bearer[U2] = OutsideA
  U2 in Left.settledOutside
  Left.refundOf[R] = C1

  householdRefundShare[Left, R] = U1
  reverseObligationUnits[Left, R] = U2
  refundOwedTo[Left, R, OutsideA] = U2
  no extinguishedReceivableUnits[Left, R]
}

-- Same physical full-refund amount and the same burden/discharge graph, but a
-- different source cost changes which outside participant is entitled to the
-- returned value. This is the already-earned Observation-065 provenance seam
-- appearing through the burden graph.
pred samePhysicalRefundDifferentSourceChangesBeneficiary {
  Left.bearer = Right.bearer
  Left.settledOutside = Right.settledOutside

  Left.bearer[U1] = Household
  Left.bearer[U2] = OutsideA
  Left.bearer[U3] = Household
  Left.bearer[U4] = OutsideB
  U2 + U4 in Left.settledOutside

  Left.refundOf[R] = C1
  Right.refundOf[R] = C2

  refundOwedTo[Left, R, OutsideA] != refundOwedTo[Right, R, OutsideA]
  refundOwedTo[Left, R, OutsideB] != refundOwedTo[Right, R, OutsideB]
}

-- With refund source and burden fixed, prior settlement still changes whether
-- the outside share is extinguished or becomes a reverse obligation. This is
-- the already-earned discharge seam from Observation 165.
pred sameSourceAndBurdenDifferentDischargeChangesConsequence {
  Left.bearer = Right.bearer
  Left.refundOf = Right.refundOf

  Left.bearer[U1] = Household
  Left.bearer[U2] = OutsideA
  Left.refundOf[R] = C1

  U2 in Left.settledOutside
  U2 not in Right.settledOutside

  U2 in reverseObligationUnits[Left, R]
  U2 in extinguishedReceivableUnits[Right, R]
}

-- Too small: burden and discharge do not reconstruct which cost the return
-- belongs to.
assert BurdenAndDischargeWithoutRefundSourceDetermineRefundConsequences {
  Left.bearer = Right.bearer and
  Left.settledOutside = Right.settledOutside implies {
    householdRefundShare[Left, R] = householdRefundShare[Right, R]
    reverseObligationUnits[Left, R] = reverseObligationUnits[Right, R]
    all p: Participant |
      refundOwedTo[Left, R, p] = refundOwedTo[Right, R, p]
  }
}

-- Too small: source provenance and burden do not reconstruct whether an
-- outside share had already been discharged before the refund.
assert RefundSourceAndBurdenWithoutDischargeDetermineDirection {
  Left.bearer = Right.bearer and
  Left.refundOf = Right.refundOf implies {
    reverseObligationUnits[Left, R] = reverseObligationUnits[Right, R]
    extinguishedReceivableUnits[Left, R] = extinguishedReceivableUnits[Right, R]
  }
}

-- Composition sufficiency for the selected bounded vocabulary. Once the three
-- already-earned evidence families are fixed, there is no remaining degree of
-- freedom in the selected refund consequences.
assert ExistingEvidenceDeterminesRefundConsequences {
  Left.bearer = Right.bearer and
  Left.settledOutside = Right.settledOutside and
  Left.refundOf = Right.refundOf implies {
    householdRefundShare[Left, R] = householdRefundShare[Right, R]
    reverseObligationUnits[Left, R] = reverseObligationUnits[Right, R]
    extinguishedReceivableUnits[Left, R] = extinguishedReceivableUnits[Right, R]
    all p: Participant |
      refundOwedTo[Left, R, p] = refundOwedTo[Right, R, p]
  }
}

run representativeSettledSharedRefund for exactly 2 Cost, exactly 4 Unit, exactly 3 Participant, exactly 1 Refund, exactly 2 World
run samePhysicalRefundDifferentSourceChangesBeneficiary for exactly 2 Cost, exactly 4 Unit, exactly 3 Participant, exactly 1 Refund, exactly 2 World
run sameSourceAndBurdenDifferentDischargeChangesConsequence for exactly 2 Cost, exactly 4 Unit, exactly 3 Participant, exactly 1 Refund, exactly 2 World
check BurdenAndDischargeWithoutRefundSourceDetermineRefundConsequences for exactly 2 Cost, exactly 4 Unit, exactly 3 Participant, exactly 1 Refund, exactly 2 World
check RefundSourceAndBurdenWithoutDischargeDetermineDirection for exactly 2 Cost, exactly 4 Unit, exactly 3 Participant, exactly 1 Refund, exactly 2 World
check ExistingEvidenceDeterminesRefundConsequences for exactly 2 Cost, exactly 4 Unit, exactly 3 Participant, exactly 1 Refund, exactly 2 World
