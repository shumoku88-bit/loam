module experiments/observation_217_partial_accounting_role_quantity

-- Observation 217 adds signed quantity pressure to Observation 216. A partial
-- role-aware report must not become "complete" merely because unresolved Effects
-- happen to cancel numerically, and role totals alone must not erase the
-- completeness frontier.

abstract sig AccountingRole {}
one sig AssetRole, ExpenseRole extends AccountingRole {}

abstract sig Locus {}
one sig AssetLocus, ExpenseLocus,
        CancelLossyLocus, NonzeroLossyLocus extends Locus {}

abstract sig Effect {
  at: one Locus,
  quantity: one Int
}
one sig AssetEffect, ExpenseEffect,
        CancelLossyPlus, CancelLossyMinus,
        NonzeroLossyEffect extends Effect {}

fact QuantitySpecimen {
  AssetEffect.at = AssetLocus
  AssetEffect.quantity = 10

  ExpenseEffect.at = ExpenseLocus
  ExpenseEffect.quantity = 7

  CancelLossyPlus.at = CancelLossyLocus
  CancelLossyPlus.quantity = 5

  CancelLossyMinus.at = CancelLossyLocus
  CancelLossyMinus.quantity = -5

  NonzeroLossyEffect.at = NonzeroLossyLocus
  NonzeroLossyEffect.quantity = 3
}

sig World {
  role: Locus -> lone AccountingRole
}

fun roleOf[w: World, l: Locus]: lone AccountingRole {
  l.(w.role)
}

fun effectsForRole[w: World, r: AccountingRole]: set Effect {
  { e: Effect | roleOf[w, e.at] = r }
}

fun classifiedEffects[w: World]: set Effect {
  { e: Effect | some roleOf[w, e.at] }
}

fun unresolvedEffects[w: World]: set Effect {
  { e: Effect | no roleOf[w, e.at] }
}

fun roleTotal[w: World, r: AccountingRole]: Int {
  sum e: effectsForRole[w, r] | e.quantity
}

fun unresolvedTotal[w: World]: Int {
  sum e: unresolvedEffects[w] | e.quantity
}

pred cleanRolesKnown[w: World] {
  roleOf[w, AssetLocus] = AssetRole
  roleOf[w, ExpenseLocus] = ExpenseRole
}

pred bothLossyUnresolved[w: World] {
  cleanRolesKnown[w]
  no roleOf[w, CancelLossyLocus]
  no roleOf[w, NonzeroLossyLocus]
}

-- Ordinary role totals can coexist with an explicit unresolved quantity frontier.
pred partialQuantityReportWitness {
  some w: World |
    bothLossyUnresolved[w] and
    roleTotal[w, AssetRole] = 10 and
    roleTotal[w, ExpenseRole] = 7 and
    unresolvedEffects[w] =
      CancelLossyPlus + CancelLossyMinus + NonzeroLossyEffect and
    unresolvedTotal[w] = 3
}

-- Two unresolved Effects may cancel exactly. Zero unresolved quanta is therefore
-- not evidence that the report is complete.
pred zeroUnresolvedQuantityCanStillBePartial {
  some w: World |
    cleanRolesKnown[w] and
    no roleOf[w, CancelLossyLocus] and
    roleOf[w, NonzeroLossyLocus] = ExpenseRole and
    unresolvedEffects[w] = CancelLossyPlus + CancelLossyMinus and
    unresolvedTotal[w] = 0
}

-- Assigning a nonzero unresolved Locus to a role changes the resolved quantity.
-- Such completion is semantic, not a formatting default.
pred arbitraryCompletionCanChangeResolvedQuantity {
  some disj partial, filled: World |
    bothLossyUnresolved[partial] and
    filled.role = partial.role + (NonzeroLossyLocus -> ExpenseRole) and
    roleTotal[partial, ExpenseRole] != roleTotal[filled, ExpenseRole]
}

-- More subtly, assigning a canceling unresolved Locus may leave every displayed
-- role total numerically identical while changing report completeness. Totals
-- alone therefore cannot carry the uncertainty boundary.
pred sameRoleTotalsCanHideDifferentCompleteness {
  some disj partial, filled: World |
    cleanRolesKnown[partial] and
    roleOf[partial, NonzeroLossyLocus] = ExpenseRole and
    no roleOf[partial, CancelLossyLocus] and
    filled.role = partial.role + (CancelLossyLocus -> ExpenseRole) and
    all r: AccountingRole |
      roleTotal[partial, r] = roleTotal[filled, r] and
    some unresolvedEffects[partial] and
    no unresolvedEffects[filled]
}

assert ClassifiedAndUnresolvedQuantityPartition {
  all w: World |
    Effect = classifiedEffects[w] + unresolvedEffects[w] and
    no (classifiedEffects[w] & unresolvedEffects[w])
}

-- Deliberately false. A canceling unresolved frontier provides a counterexample.
assert ZeroUnresolvedQuantityMeansComplete {
  all w: World |
    unresolvedTotal[w] = 0 implies no unresolvedEffects[w]
}

-- Deliberately false. Two worlds may publish identical role totals while one
-- still carries unresolved evidence and the other is fully classified.
assert SameRoleTotalsDetermineCompleteness {
  all disj left, right: World |
    (all r: AccountingRole |
      roleTotal[left, r] = roleTotal[right, r])
    implies
      (no unresolvedEffects[left] iff no unresolvedEffects[right])
}

-- Once every Effect is classified, the role totals account for the complete
-- specimen quantity. This is a quantity law, not an authorization for any real
-- lossy row to receive a role.
assert FullyClassifiedRoleTotalsCoverQuantity {
  all w: World |
    no unresolvedEffects[w] implies
      (sum r: AccountingRole | roleTotal[w, r]) =
      (sum e: Effect | e.quantity)
}

assert SameRoleMapDeterminesSameQuantityReport {
  all disj left, right: World |
    left.role = right.role implies {
      unresolvedEffects[left] = unresolvedEffects[right]
      unresolvedTotal[left] = unresolvedTotal[right]
      all r: AccountingRole |
        roleTotal[left, r] = roleTotal[right, r]
    }
}

run partialQuantityReportWitness for 7 but exactly 2 World, 6 Int
run zeroUnresolvedQuantityCanStillBePartial for 7 but exactly 2 World, 6 Int
run arbitraryCompletionCanChangeResolvedQuantity for 7 but exactly 2 World, 6 Int
run sameRoleTotalsCanHideDifferentCompleteness for 7 but exactly 2 World, 6 Int

check ClassifiedAndUnresolvedQuantityPartition for 7 but exactly 2 World, 6 Int
check ZeroUnresolvedQuantityMeansComplete for 7 but exactly 2 World, 6 Int
check SameRoleTotalsDetermineCompleteness for 7 but exactly 2 World, 6 Int
check FullyClassifiedRoleTotalsCoverQuantity for 7 but exactly 2 World, 6 Int
check SameRoleMapDeterminesSameQuantityReport for 7 but exactly 2 World, 6 Int
