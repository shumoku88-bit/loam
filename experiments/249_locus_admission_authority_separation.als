module experiments/observation_249_locus_admission_authority_separation

-- Observation 249
--
-- Test whether the current add-only Locus admission policy needs to be atomically
-- co-selected with Movement evidence merely to prevent false authorization.

sig Locus {}

sig Policy {
  approved: set Locus
}

sig Draft {
  uses: some Locus
}

pred admitted[p: Policy, d: Draft] {
  d.uses in p.approved
}

-- A stale older snapshot may reject a Locus added by the current policy.
pred staleOlderPolicyCanFalseReject {
  some old, current: Policy, d: Draft | {
    old != current
    old.approved in current.approved
    old.approved != current.approved
    not admitted[old, d]
    admitted[current, d]
  }
}

-- Under add-only evolution, stale-old admission cannot over-authorize relative
-- to the later current policy.
assert AddOnlyStaleCannotOverAuthorize {
  all old, current: Policy, d: Draft |
    (old.approved in current.approved and admitted[old, d])
      implies admitted[current, d]
}

-- If future semantics permit removal, an older snapshot can over-authorize a
-- Locus that the current policy has revoked.
pred revocationMakesStaleOverAuthorize {
  some old, current: Policy, d: Draft | {
    old != current
    some old.approved - current.approved
    admitted[old, d]
    not admitted[current, d]
  }
}

-- Equal explicit policy sets determine the same admission answer.
assert EqualPolicySetsAgree {
  all left, right: Policy, d: Draft |
    left.approved = right.approved implies
      (admitted[left, d] iff admitted[right, d])
}

run staleOlderPolicyCanFalseReject for exactly 3 Locus, exactly 3 Policy, exactly 1 Draft
check AddOnlyStaleCannotOverAuthorize for exactly 3 Locus, exactly 3 Policy, exactly 1 Draft
run revocationMakesStaleOverAuthorize for exactly 3 Locus, exactly 3 Policy, exactly 1 Draft
check EqualPolicySetsAgree for exactly 3 Locus, exactly 3 Policy, exactly 1 Draft
