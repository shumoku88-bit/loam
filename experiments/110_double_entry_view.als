module experiments/observation_110_double_entry_view

abstract sig PostingSide {}
one sig Debit, Credit extends PostingSide {}

abstract sig AccountingRole {}
one sig AssetRole, LiabilityRole, EquityRole, IncomeRole, ExpenseRole extends AccountingRole {}

sig Locus {}
sig HoldingLocus in Locus {}

sig Movement {}

sig Effect {
  movement: one Movement,
  locus: one Locus,
  quantity: one Int
}

abstract sig OpeningLine {
  quantity: one Int
}

sig QuantityBasis extends OpeningLine {
  locus: one Locus
}

sig World {
  sideOf: Effect -> one PostingSide,
  roleOf: Locus -> one AccountingRole,
  boundaryRole: one AccountingRole
}

one sig Left, Right extends World {}

sig BoundaryPosting extends OpeningLine {
  world: one World
}

fact BalancedPracticalMovements {
  all e: Effect | e.quantity != 0

  all m: Movement | {
    #m.~movement >= 2
    (sum e: m.~movement | e.quantity) = 0
    some e: m.~movement | e.quantity > 0
    some e: m.~movement | e.quantity < 0
    all disj e1, e2: m.~movement | e1.locus != e2.locus
  }
}

fact BasisShape {
  all b: QuantityBasis | b.quantity != 0
  all disj b1, b2: QuantityBasis | b1.locus != b2.locus
}

fact OneDerivedBoundaryPostingPerWorld {
  all w: World | one { p: BoundaryPosting | p.world = w }
}

fun boundaryPosting[w: World]: one BoundaryPosting {
  { p: BoundaryPosting | p.world = w }
}

fact DerivedOpeningViewCloses {
  all w: World |
    (sum line: QuantityBasis + boundaryPosting[w] | line.quantity) = 0
}

fact DebitCreditPresentationFollowsSignedEffects {
  all w: World, e: Effect | {
    e.quantity > 0 iff e->Debit in w.sideOf
    e.quantity < 0 iff e->Credit in w.sideOf
  }
}

fun debitEffects[w: World, m: Movement]: set Effect {
  { e: m.~movement | e->Debit in w.sideOf }
}

fun creditEffects[w: World, m: Movement]: set Effect {
  { e: m.~movement | e->Credit in w.sideOf }
}

fun holdingEffects[m: Movement]: set Effect {
  { e: m.~movement | e.locus in HoldingLocus }
}

pred representativeDerivedAccountingView {
  some HoldingLocus
  some Locus - HoldingLocus
  some QuantityBasis
  (sum b: QuantityBasis | b.quantity) != 0

  some m: Movement | #m.~movement >= 3

  Left.boundaryRole = EquityRole

  some m: Movement, sourceEffect, targetEffect: m.~movement | {
    sourceEffect.locus not in HoldingLocus
    sourceEffect.quantity < 0
    targetEffect.locus in HoldingLocus
    targetEffect.quantity > 0
  }
}

pred balancedMovementCanChangeHoldingProjection {
  some m: Movement |
    (sum e: holdingEffects[m] | e.quantity) != 0
}

pred sameDebitCreditSidesDifferentAccountingRoles {
  Left.sideOf = Right.sideOf
  Left.roleOf != Right.roleOf
}

pred sameBasisDifferentBoundaryMeaning {
  boundaryPosting[Left].quantity = boundaryPosting[Right].quantity
  Left.roleOf = Right.roleOf
  Left.boundaryRole != Right.boundaryRole
}

assert SignedEffectsDetermineDebitCreditSide {
  Left.sideOf = Right.sideOf
}

assert DebitCreditSidesPartitionMovementEffects {
  all w: World, m: Movement | {
    debitEffects[w, m] + creditEffects[w, m] = m.~movement
    no debitEffects[w, m] & creditEffects[w, m]
  }
}

assert BasisDeterminesBoundaryQuantity {
  boundaryPosting[Left].quantity = boundaryPosting[Right].quantity
}

assert PhysicalBasisDeterminesBoundaryAccountingMeaning {
  Left.boundaryRole = Right.boundaryRole
}

assert DerivedOpeningViewRemainsBalanced {
  all w: World |
    (sum line: QuantityBasis + boundaryPosting[w] | line.quantity) = 0
}

run representativeDerivedAccountingView for exactly 3 Movement, exactly 8 Effect, exactly 4 Locus, exactly 2 HoldingLocus, exactly 2 QuantityBasis, exactly 2 BoundaryPosting, exactly 2 World, 7 Int
run balancedMovementCanChangeHoldingProjection for exactly 3 Movement, exactly 8 Effect, exactly 4 Locus, exactly 2 HoldingLocus, exactly 2 QuantityBasis, exactly 2 BoundaryPosting, exactly 2 World, 7 Int
run sameDebitCreditSidesDifferentAccountingRoles for exactly 3 Movement, exactly 8 Effect, exactly 4 Locus, exactly 2 HoldingLocus, exactly 2 QuantityBasis, exactly 2 BoundaryPosting, exactly 2 World, 7 Int
run sameBasisDifferentBoundaryMeaning for exactly 3 Movement, exactly 8 Effect, exactly 4 Locus, exactly 2 HoldingLocus, exactly 2 QuantityBasis, exactly 2 BoundaryPosting, exactly 2 World, 7 Int
check SignedEffectsDetermineDebitCreditSide for exactly 3 Movement, exactly 8 Effect, exactly 4 Locus, exactly 2 HoldingLocus, exactly 2 QuantityBasis, exactly 2 BoundaryPosting, exactly 2 World, 7 Int
check DebitCreditSidesPartitionMovementEffects for exactly 3 Movement, exactly 8 Effect, exactly 4 Locus, exactly 2 HoldingLocus, exactly 2 QuantityBasis, exactly 2 BoundaryPosting, exactly 2 World, 7 Int
check BasisDeterminesBoundaryQuantity for exactly 3 Movement, exactly 8 Effect, exactly 4 Locus, exactly 2 HoldingLocus, exactly 2 QuantityBasis, exactly 2 BoundaryPosting, exactly 2 World, 7 Int
check PhysicalBasisDeterminesBoundaryAccountingMeaning for exactly 3 Movement, exactly 8 Effect, exactly 4 Locus, exactly 2 HoldingLocus, exactly 2 QuantityBasis, exactly 2 BoundaryPosting, exactly 2 World, 7 Int
check DerivedOpeningViewRemainsBalanced for exactly 3 Movement, exactly 8 Effect, exactly 4 Locus, exactly 2 HoldingLocus, exactly 2 QuantityBasis, exactly 2 BoundaryPosting, exactly 2 World, 7 Int
