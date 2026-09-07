module experiments/observation_216_partial_accounting_role_report

-- Observation 216 is triggered by the concrete loam-data split review after
-- Observation 215. Some historical Loci are not safely classifiable without
-- manufacturing evidence. We ask whether production needs an `UnknownRole`
-- ontology value, or whether a partial Locus -> AccountingRole relation plus an
-- explicit unresolved Effect set is already sufficient for a truthful report.

abstract sig AccountingRole {}
one sig AssetRole, ExpenseRole extends AccountingRole {}

abstract sig Locus {}
one sig AssetLocus, ExpenseLocus, LossyLocus extends Locus {}

abstract sig Effect {
  at: one Locus
}
one sig AssetEffect, ExpenseEffect, LossyEffectA, LossyEffectB extends Effect {}

fact HouseholdShapedSpecimen {
  AssetEffect.at = AssetLocus
  ExpenseEffect.at = ExpenseLocus
  LossyEffectA.at = LossyLocus
  LossyEffectB.at = LossyLocus
}

-- `lone` is deliberate. Absence means classification is unresolved at this
-- observation boundary. It does not mean zero, irrelevant, or a sixth role.
sig World {
  role: Locus -> lone AccountingRole
}

fun roleOf[w: World, l: Locus]: lone AccountingRole {
  l.(w.role)
}

fun effectsAt[l: Locus]: set Effect {
  { e: Effect | e.at = l }
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

pred cleanRolesKnown[w: World] {
  roleOf[w, AssetLocus] = AssetRole
  roleOf[w, ExpenseLocus] = ExpenseRole
}

-- The lossy historical coordinate remains visible without assigning it a fake
-- role. A report can carry the ordinary role-selected evidence and the exact
-- unresolved witness set side by side.
pred partialRoleReportKeepsLossyEvidence {
  some w: World |
    cleanRolesKnown[w] and
    no roleOf[w, LossyLocus] and
    effectsForRole[w, AssetRole] = AssetEffect and
    effectsForRole[w, ExpenseRole] = ExpenseEffect and
    unresolvedEffects[w] = LossyEffectA + LossyEffectB
}

-- If independent evidence later resolves every observed Locus, the same partial
-- representation collapses naturally to an ordinary complete role report. This
-- establishes representational sufficiency only; it does not authorize this
-- particular classification for real lossy household history.
pred completeRoleMapCanResolveAllEffects {
  some w: World |
    cleanRolesKnown[w] and
    roleOf[w, LossyLocus] = ExpenseRole and
    no unresolvedEffects[w]
}

-- Filling a missing role is a semantic decision, not a harmless display default.
-- The exact same Effects move from the unresolved witness set into one selected
-- accounting report when the role relation is completed.
pred arbitraryCompletionChangesSelectedEvidence {
  some disj partial, filled: World |
    cleanRolesKnown[partial] and
    no roleOf[partial, LossyLocus] and
    cleanRolesKnown[filled] and
    filled.role = partial.role + (LossyLocus -> ExpenseRole) and
    effectsForRole[partial, ExpenseRole] != effectsForRole[filled, ExpenseRole] and
    unresolvedEffects[partial] != unresolvedEffects[filled]
}

-- Classified and unresolved Effects form an exact partition. An Effect lacking a
-- role is therefore not silently dropped by this projection.
assert ClassifiedAndUnresolvedPartition {
  all w: World |
    Effect = classifiedEffects[w] + unresolvedEffects[w] and
    no (classifiedEffects[w] & unresolvedEffects[w])
}

-- This deliberately SHOULD have a counterexample. Missing classification says
-- nothing about whether evidence exists at that Locus.
assert MissingRoleMeansNoEvidence {
  all w: World, l: Locus |
    no roleOf[w, l] implies no effectsAt[l]
}

-- For this fully observed specimen, an empty unresolved set is exactly the case
-- where every observed Locus has a role. No additional UnknownRole atom is needed
-- to state report completeness.
assert NoUnresolvedIffEveryObservedLocusClassified {
  all w: World |
    no unresolvedEffects[w] iff
      all l: Locus | some effectsAt[l] implies some roleOf[w, l]
}

-- The report projection is determined by the explicit role relation. There is no
-- hidden token-prefix fallback or presentation-time classifier.
assert SameRoleMapDeterminesSamePartialReport {
  all disj left, right: World |
    left.role = right.role implies
      unresolvedEffects[left] = unresolvedEffects[right] and
      all r: AccountingRole |
        effectsForRole[left, r] = effectsForRole[right, r]
}

run partialRoleReportKeepsLossyEvidence for 6 but exactly 2 World
run completeRoleMapCanResolveAllEffects for 6 but exactly 2 World
run arbitraryCompletionChangesSelectedEvidence for 6 but exactly 2 World

check ClassifiedAndUnresolvedPartition for 6 but exactly 2 World
check MissingRoleMeansNoEvidence for 6 but exactly 2 World
check NoUnresolvedIffEveryObservedLocusClassified for 6 but exactly 2 World
check SameRoleMapDeterminesSamePartialReport for 6 but exactly 2 World
