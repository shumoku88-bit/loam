module experiments/observation_214_accounting_role_migration_separation

-- Observation 214 asks a migration question, not whether AccountingRole exists.
-- Observations 049/062 already established that role is independent of physical
-- placement and useful for accounting-shaped reports. Here we ask what must be
-- preserved if HRA/hledger-shaped Locus spelling is removed from canonical data.

abstract sig AccountingRole {}
one sig AssetRole, LiabilityRole, EquityRole, IncomeRole, ExpenseRole extends AccountingRole {}

sig OldLocus {}
sig NewLocus {}

-- Effect identity survives the candidate Locus re-key. `at` is the old
-- coordinate; the migrated coordinate is obtained only through Migration.rekey.
sig Effect {
  at: one OldLocus
}

sig Migration {
  rekey: OldLocus -> one NewLocus,
  oldRole: OldLocus -> one AccountingRole,
  newRole: NewLocus -> lone AccountingRole
}

-- Every modeled old coordinate is observable in at least one Effect. This keeps
-- merge attacks from hiding a conflicting role on an unused coordinate.
fact EveryOldLocusObserved {
  all o: OldLocus | some e: Effect | e.at = o
}

fun newOf[m: Migration, o: OldLocus]: one NewLocus {
  o.(m.rekey)
}

fun oldRoleOf[m: Migration, o: OldLocus]: one AccountingRole {
  o.(m.oldRole)
}

fun newRoleOf[m: Migration, n: NewLocus]: lone AccountingRole {
  n.(m.newRole)
}

fun beforeEffects[m: Migration, r: AccountingRole]: set Effect {
  { e: Effect | oldRoleOf[m, e.at] = r }
}

fun afterEffects[m: Migration, r: AccountingRole]: set Effect {
  { e: Effect | newRoleOf[m, newOf[m, e.at]] = r }
}

pred roleTransported[m: Migration] {
  all o: OldLocus |
    newRoleOf[m, newOf[m, o]] = oldRoleOf[m, o]
}

pred selectedReportsPreserved[m: Migration] {
  all r: AccountingRole |
    beforeEffects[m, r] = afterEffects[m, r]
}

pred injectiveRekey[m: Migration] {
  all disj a, b: OldLocus |
    newOf[m, a] != newOf[m, b]
}

-- A one-to-one spelling change can carry role separately from the token and
-- preserve every role-selected Effect set.
pred injectiveRoleTransportPreservesReports {
  some m: Migration |
    injectiveRekey[m] and
    roleTransported[m] and
    selectedReportsPreserved[m] and
    some disj a, b, c: OldLocus |
      oldRoleOf[m, a] != oldRoleOf[m, b] and
      oldRoleOf[m, b] != oldRoleOf[m, c] and
      oldRoleOf[m, a] != oldRoleOf[m, c]
}

-- The same flat identities and same old evidence do not determine accounting
-- answers if the explicit post-migration role relation is allowed to vary.
pred sameFlatIdentitiesDifferentRoleAnswers {
  some disj left, right: Migration |
    left.rekey = right.rekey and
    left.oldRole = right.oldRole and
    left.newRole != right.newRole and
    some r: AccountingRole |
      afterEffects[left, r] != afterEffects[right, r]
}

-- Two old Loci with the same role can be merged and still preserve the selected
-- role-report Effect sets. That does NOT preserve per-Locus identity.
pred sameRoleMergePreservesAccountingButLosesIdentity {
  some m: Migration |
    roleTransported[m] and
    selectedReportsPreserved[m] and
    not injectiveRekey[m] and
    some disj a, b: OldLocus |
      oldRoleOf[m, a] = oldRoleOf[m, b] and
      newOf[m, a] = newOf[m, b]
}

-- A candidate mapping is allowed to try collapsing two differently classified
-- source Loci. The next assertion should show that one-role-per-new-Locus cannot
-- preserve both selected report answers in that case.
pred differentRoleMergeCandidate {
  some m: Migration, disj a, b: OldLocus |
    newOf[m, a] = newOf[m, b] and
    oldRoleOf[m, a] != oldRoleOf[m, b]
}

assert RoleTransportDeterminesSelectedReports {
  all m: Migration |
    roleTransported[m] implies selectedReportsPreserved[m]
}

assert DifferentRoleMergeCannotPreserveSelectedReports {
  all m: Migration |
    (some disj a, b: OldLocus |
      newOf[m, a] = newOf[m, b] and
      oldRoleOf[m, a] != oldRoleOf[m, b])
    implies not selectedReportsPreserved[m]
}

-- This deliberately SHOULD have a counterexample: accounting aggregate/report
-- parity is weaker than preserving stable coordinate identity.
assert AccountingParityImpliesIdentityPreservation {
  all m: Migration |
    selectedReportsPreserved[m] implies injectiveRekey[m]
}

run injectiveRoleTransportPreservesReports for 6 but
  exactly 4 OldLocus, exactly 4 NewLocus, exactly 4 Effect, exactly 2 Migration
run sameFlatIdentitiesDifferentRoleAnswers for 6 but
  exactly 4 OldLocus, exactly 4 NewLocus, exactly 4 Effect, exactly 2 Migration
run sameRoleMergePreservesAccountingButLosesIdentity for 6 but
  exactly 4 OldLocus, exactly 4 NewLocus, exactly 4 Effect, exactly 2 Migration
run differentRoleMergeCandidate for 6 but
  exactly 4 OldLocus, exactly 4 NewLocus, exactly 4 Effect, exactly 2 Migration

check RoleTransportDeterminesSelectedReports for 6 but
  exactly 4 OldLocus, exactly 4 NewLocus, exactly 4 Effect, exactly 2 Migration
check DifferentRoleMergeCannotPreserveSelectedReports for 6 but
  exactly 4 OldLocus, exactly 4 NewLocus, exactly 4 Effect, exactly 2 Migration
check AccountingParityImpliesIdentityPreservation for 6 but
  exactly 4 OldLocus, exactly 4 NewLocus, exactly 4 Effect, exactly 2 Migration
