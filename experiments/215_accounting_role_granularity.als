module experiments/observation_215_accounting_role_granularity

-- Observation 215 is triggered by real migration pressure after Observation 214.
-- A legacy source Locus may have bundled more than one household meaning. We ask
-- whether that forces production AccountingRole down to Effect granularity, or
-- whether a migration-time split can recover clean Loci with stable roles.

abstract sig AccountingRole {}
one sig AssetRole, ExpenseRole extends AccountingRole {}

abstract sig LegacyLocus {}
one sig MixedLegacy, StableLegacy extends LegacyLocus {}

abstract sig NewLocus {}
one sig HoldingNew, ExpenseNew, StableExpenseNew extends NewLocus {}

abstract sig Effect {
  at: one LegacyLocus,
  intendedRole: one AccountingRole
}

one sig MixedHoldingEffect, MixedExpenseEffect,
        StableExpenseEffectA, StableExpenseEffectB extends Effect {}

fact HouseholdShapedSpecimen {
  MixedHoldingEffect.at = MixedLegacy
  MixedHoldingEffect.intendedRole = AssetRole

  MixedExpenseEffect.at = MixedLegacy
  MixedExpenseEffect.intendedRole = ExpenseRole

  StableExpenseEffectA.at = StableLegacy
  StableExpenseEffectA.intendedRole = ExpenseRole

  StableExpenseEffectB.at = StableLegacy
  StableExpenseEffectB.intendedRole = ExpenseRole
}

-- All candidate planes are observation scaffolding. A successful result does not
-- mean all of them should be persisted in production.
sig Candidate {
  legacyRole: LegacyLocus -> one AccountingRole,
  effectRole: Effect -> one AccountingRole,
  rekeyByLegacy: LegacyLocus -> one NewLocus,
  splitByEffect: Effect -> one NewLocus,
  newRole: NewLocus -> one AccountingRole
}

fun legacyRoleOf[c: Candidate, l: LegacyLocus]: one AccountingRole {
  l.(c.legacyRole)
}

fun effectRoleOf[c: Candidate, e: Effect]: one AccountingRole {
  e.(c.effectRole)
}

fun legacyTargetOf[c: Candidate, l: LegacyLocus]: one NewLocus {
  l.(c.rekeyByLegacy)
}

fun splitTargetOf[c: Candidate, e: Effect]: one NewLocus {
  e.(c.splitByEffect)
}

fun newRoleOf[c: Candidate, n: NewLocus]: one AccountingRole {
  n.(c.newRole)
}

pred permanentLegacyRolePreservesAt[c: Candidate, l: LegacyLocus] {
  all e: Effect |
    e.at = l implies legacyRoleOf[c, l] = e.intendedRole
}

pred effectRelativeRolePreserves[c: Candidate] {
  all e: Effect | effectRoleOf[c, e] = e.intendedRole
}

pred legacyRekeyPreservesAt[c: Candidate, l: LegacyLocus] {
  all e: Effect |
    e.at = l implies
      newRoleOf[c, legacyTargetOf[c, l]] = e.intendedRole
}

pred splitMigrationPreserves[c: Candidate] {
  all e: Effect |
    newRoleOf[c, splitTargetOf[c, e]] = e.intendedRole
}

-- A role-homogeneous legacy coordinate does not create pressure for finer role
-- granularity. One stable role is sufficient for the selected specimen.
pred stableLegacyPermanentRoleWorks {
  some c: Candidate |
    permanentLegacyRolePreservesAt[c, StableLegacy]
}

-- The mixed legacy coordinate asks one permanent role to equal both Asset and
-- Expense. This should be UNSAT.
pred mixedLegacyPermanentRoleWorks {
  some c: Candidate |
    permanentLegacyRolePreservesAt[c, MixedLegacy]
}

-- Effect-relative role is sufficient, but this predicate only establishes an
-- available representation. It does not establish that production must retain it.
pred effectRelativeRoleCanPreserveWholeSpecimen {
  some c: Candidate |
    effectRelativeRolePreserves[c]
}

-- A conventional one-Legacy-Locus -> one-New-Locus re-key cannot repair mixed
-- semantics. Both mixed Effects still land on one new Locus with one new role.
pred oneTargetLegacyRekeyCanRepairMixedSpecimen {
  some c: Candidate |
    legacyRekeyPreservesAt[c, MixedLegacy]
}

-- Migration may instead translate individual retained Effects to distinct clean
-- new coordinates. After the cut, ordinary new-Locus roles are sufficient for
-- the selected accounting classification.
pred effectSplitMigrationCanRepairWholeSpecimen {
  some c: Candidate |
    splitMigrationPreserves[c] and
    splitTargetOf[c, MixedHoldingEffect] != splitTargetOf[c, MixedExpenseEffect] and
    newRoleOf[c, splitTargetOf[c, MixedHoldingEffect]] = AssetRole and
    newRoleOf[c, splitTargetOf[c, MixedExpenseEffect]] = ExpenseRole
}

-- Once the source is role-homogeneous, a normal Locus re-key remains sufficient.
pred stableLegacyRekeyWorks {
  some c: Candidate |
    legacyRekeyPreservesAt[c, StableLegacy]
}

-- Fixing the split destination and the role of each new Locus fixes the selected
-- role answer for every migrated Effect. No extra runtime EffectRole bit is needed
-- to determine this bounded post-migration view.
assert SplitTargetsPlusNewRolesDetermineClassification {
  all disj left, right: Candidate |
    left.splitByEffect = right.splitByEffect and
    left.newRole = right.newRole
    implies
    all e: Effect |
      newRoleOf[left, splitTargetOf[left, e]] =
      newRoleOf[right, splitTargetOf[right, e]]
}

-- This deliberately SHOULD have a counterexample. A mixed source coordinate does
-- not imply that every post-migration target must also be mixed. Migration can
-- split its retained Effects into clean identities.
assert MixedLegacyForcesMixedNewLocus {
  all c: Candidate |
    splitMigrationPreserves[c] implies
    splitTargetOf[c, MixedHoldingEffect] = splitTargetOf[c, MixedExpenseEffect]
}

run stableLegacyPermanentRoleWorks for 6 but exactly 2 LegacyLocus, exactly 3 NewLocus, exactly 4 Effect, exactly 2 Candidate
run mixedLegacyPermanentRoleWorks for 6 but exactly 2 LegacyLocus, exactly 3 NewLocus, exactly 4 Effect, exactly 2 Candidate
run effectRelativeRoleCanPreserveWholeSpecimen for 6 but exactly 2 LegacyLocus, exactly 3 NewLocus, exactly 4 Effect, exactly 2 Candidate
run oneTargetLegacyRekeyCanRepairMixedSpecimen for 6 but exactly 2 LegacyLocus, exactly 3 NewLocus, exactly 4 Effect, exactly 2 Candidate
run effectSplitMigrationCanRepairWholeSpecimen for 6 but exactly 2 LegacyLocus, exactly 3 NewLocus, exactly 4 Effect, exactly 2 Candidate
run stableLegacyRekeyWorks for 6 but exactly 2 LegacyLocus, exactly 3 NewLocus, exactly 4 Effect, exactly 2 Candidate

check SplitTargetsPlusNewRolesDetermineClassification for 6 but exactly 2 LegacyLocus, exactly 3 NewLocus, exactly 4 Effect, exactly 2 Candidate
check MixedLegacyForcesMixedNewLocus for 6 but exactly 2 LegacyLocus, exactly 3 NewLocus, exactly 4 Effect, exactly 2 Candidate
