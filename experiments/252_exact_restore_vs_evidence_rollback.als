module experiments/observation_252_exact_restore_vs_evidence_rollback

-- Observation 252
--
-- Determine whether today's exact retained-generation restore and the recomposed
-- evidence rollback studied by Observation 251 are the same operation under a
-- smaller representation, or observably different operations that must not be
-- silently substituted for one another.

sig Evidence {}
sig Locus {}
sig Policy {
  approved : set Locus
}

sig Generation {
  evidence : one Evidence,
  policy : one Policy
}

sig Draft {
  uses : some Locus
}

sig Case {
  current : one Generation,
  historical : one Generation,
  draft : one Draft
}

sig Selection {
  evidence : one Evidence,
  policy : one Policy
}

pred exactRestore[c : Case, s : Selection] {
  s.evidence = c.historical.evidence
  s.policy = c.historical.policy
}

pred evidenceRollback[c : Case, s : Selection] {
  s.evidence = c.historical.evidence
  s.policy = c.current.policy
}

pred admitted[p : Policy, d : Draft] {
  d.uses in p.approved
}

pred laterPolicyGrowth[c : Case] {
  c.historical.policy.approved in c.current.policy.approved
  c.historical.policy.approved != c.current.policy.approved
}

-- Both operations agree on the household evidence target.
assert BothRestoreTheSameHistoricalEvidence {
  all c : Case, exact, rollback : Selection |
    exactRestore[c, exact] and evidenceRollback[c, rollback]
      implies exact.evidence = rollback.evidence
}

-- But a later policy addition makes their selected authority observably
-- different even though the recovered household evidence is identical.
pred exactAndRollbackCanSelectDifferentPolicy {
  some c : Case, exact, rollback : Selection |
    laterPolicyGrowth[c]
    and exactRestore[c, exact]
    and evidenceRollback[c, rollback]
    and exact.policy != rollback.policy
}

-- The difference reaches Q_write: one and the same draft can be refused by the
-- exact historical authority and admitted by evidence rollback preserving the
-- current operational policy.
pred exactAndRollbackCanDisagreeOnWriteAdmission {
  some c : Case, exact, rollback : Selection |
    laterPolicyGrowth[c]
    and exactRestore[c, exact]
    and evidenceRollback[c, rollback]
    and not admitted[exact.policy, c.draft]
    and admitted[rollback.policy, c.draft]
}

-- Exact restore has a stronger identity promise: both retained components match
-- the historical selected generation. Evidence rollback intentionally does not
-- satisfy that promise when policy changed later.
assert ExactRestoreReconstructsHistoricalSelection {
  all c : Case, s : Selection |
    exactRestore[c, s] implies
      s.evidence = c.historical.evidence and s.policy = c.historical.policy
}

pred evidenceRollbackCanViolateExactHistoricalIdentity {
  some c : Case, s : Selection |
    laterPolicyGrowth[c]
    and evidenceRollback[c, s]
    and s.policy != c.historical.policy
}

-- If historical and current policies are extensionally equal, the two
-- operations become observationally equal with respect to this model.
assert EqualPoliciesCollapseTheDifference {
  all c : Case, exact, rollback : Selection |
    c.historical.policy.approved = c.current.policy.approved
    and exactRestore[c, exact]
    and evidenceRollback[c, rollback]
      implies
        exact.evidence = rollback.evidence
        and exact.policy.approved = rollback.policy.approved
        and (admitted[exact.policy, c.draft] iff admitted[rollback.policy, c.draft])
}

run exactAndRollbackCanSelectDifferentPolicy for 5 but 4 Evidence, 4 Policy, 4 Locus, 2 Draft, 3 Generation, 2 Case, 3 Selection
run exactAndRollbackCanDisagreeOnWriteAdmission for 5 but 4 Evidence, 4 Policy, 4 Locus, 2 Draft, 3 Generation, 2 Case, 3 Selection
check BothRestoreTheSameHistoricalEvidence for 5 but 4 Evidence, 4 Policy, 4 Locus, 2 Draft, 3 Generation, 2 Case, 3 Selection
check ExactRestoreReconstructsHistoricalSelection for 5 but 4 Evidence, 4 Policy, 4 Locus, 2 Draft, 3 Generation, 2 Case, 3 Selection
run evidenceRollbackCanViolateExactHistoricalIdentity for 5 but 4 Evidence, 4 Policy, 4 Locus, 2 Draft, 3 Generation, 2 Case, 3 Selection
check EqualPoliciesCollapseTheDifference for 5 but 4 Evidence, 4 Policy, 4 Locus, 2 Draft, 3 Generation, 2 Case, 3 Selection
