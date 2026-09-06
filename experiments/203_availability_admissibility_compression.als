module experiments/observation_203_availability_admissibility_compression

open util/integer

-- Post-counterexample compression probe for F001 + F033.
--
-- F001 showed that temporary reservation can change available quantity while
-- physical holding and lifecycle evidence stay fixed.
-- F033 showed that operation-specific future movement rights can differ while
-- quantity and broad allocation eligibility stay fixed.
--
-- This model asks whether both can be replaced, for the selected future-use
-- queries, by one flat operation -> usable quantity envelope.
--
-- `reserved` and `allowed` remain experiment-local evidence. This is not a
-- proposal for Hold, WalletKind, Capability, or production account state.

abstract sig Operation {}
one sig Spend, Send, Withdraw extends Operation {}

abstract sig World {
  held: one Int,
  reserved: one Int,
  allowed: set Operation
}

one sig Left, Right extends World {}

fact WellFormed {
  all w: World | {
    w.held >= 0
    w.reserved >= 0
    w.reserved <= w.held
  }
}

fun unencumbered[w: World]: one Int {
  w.held.sub[w.reserved]
}

fun usable[w: World, op: Operation]: one Int {
  (op in w.allowed) => unencumbered[w] else 0
}

pred sameOperationalEnvelope {
  all op: Operation | usable[Left, op] = usable[Right, op]
}

-- The same flat envelope can arise for fundamentally different reasons:
-- one world is fully reserved while every operation remains permitted;
-- the other has no reservation but every operation is prohibited.
pred reservationVsPolicyCollision {
  Left.held = 10
  Left.reserved = 10
  Left.allowed = Operation

  Right.held = 10
  Right.reserved = 0
  no Right.allowed

  sameOperationalEnvelope
}

-- With zero physical quantity, a flat usable-quantity answer cannot preserve
-- whether an operation is permitted for future quantity that may arrive later.
pred zeroHoldingMasksRights {
  Left.held = 0
  Right.held = 0
  Left.reserved = 0
  Right.reserved = 0

  Left.allowed = Operation
  no Right.allowed

  sameOperationalEnvelope
}

-- Conversely, if every operation is prohibited, the flat envelope cannot tell
-- whether physical quantity is also temporarily encumbered.
pred blockedOperationsMaskReservation {
  Left.held = 10
  Right.held = 10
  Left.reserved = 3
  Right.reserved = 0

  no Left.allowed
  no Right.allowed

  sameOperationalEnvelope
}

-- F001 pressure survives in the joint vocabulary: with the same rights and
-- holding, reservation can still change a selected usable quantity.
pred sameRightsDifferentReservationChangesEnvelope {
  Left.held = 10
  Right.held = 10
  Left.reserved = 3
  Right.reserved = 0
  Left.allowed = Operation
  Right.allowed = Operation

  some op: Operation | usable[Left, op] != usable[Right, op]
}

-- F033 pressure also survives: with the same holding and reservation,
-- operation-specific rights can change a selected usable quantity.
pred sameReservationDifferentRightsChangesEnvelope {
  Left.held = 10
  Right.held = 10
  Left.reserved = 0
  Right.reserved = 0
  Left.allowed = Operation
  Right.allowed = Spend + Send

  usable[Left, Withdraw] != usable[Right, Withdraw]
}

-- Deliberately too strong. A flat operation -> usable quantity envelope cannot
-- reconstruct the independent future-right evidence in all states.
assert OperationalEnvelopeDeterminesRights {
  Left.held = Right.held and sameOperationalEnvelope implies
    Left.allowed = Right.allowed
}

-- Also deliberately too strong. The same envelope cannot reconstruct temporary
-- reservation evidence when policy already blocks the selected operations.
assert OperationalEnvelopeDeterminesReservation {
  Left.held = Right.held and sameOperationalEnvelope implies
    Left.reserved = Right.reserved
}

-- Strongest flat-compression claim for the selected provenance vocabulary.
assert OperationalEnvelopeDeterminesSelectedEvidence {
  Left.held = Right.held and sameOperationalEnvelope implies {
    Left.allowed = Right.allowed
    Left.reserved = Right.reserved
  }
}

-- Positive sufficiency boundary: once both independent dimensions are held
-- equal, the selected operation-wise usable quantities are equal.
assert ExplicitDimensionsDetermineEnvelope {
  Left.held = Right.held and
  Left.reserved = Right.reserved and
  Left.allowed = Right.allowed implies
    sameOperationalEnvelope
}

run reservationVsPolicyCollision for exactly 3 Operation, exactly 2 World, 5 Int
run zeroHoldingMasksRights for exactly 3 Operation, exactly 2 World, 5 Int
run blockedOperationsMaskReservation for exactly 3 Operation, exactly 2 World, 5 Int
run sameRightsDifferentReservationChangesEnvelope for exactly 3 Operation, exactly 2 World, 5 Int
run sameReservationDifferentRightsChangesEnvelope for exactly 3 Operation, exactly 2 World, 5 Int
check OperationalEnvelopeDeterminesRights for exactly 3 Operation, exactly 2 World, 5 Int
check OperationalEnvelopeDeterminesReservation for exactly 3 Operation, exactly 2 World, 5 Int
check OperationalEnvelopeDeterminesSelectedEvidence for exactly 3 Operation, exactly 2 World, 5 Int
check ExplicitDimensionsDetermineEnvelope for exactly 3 Operation, exactly 2 World, 5 Int
