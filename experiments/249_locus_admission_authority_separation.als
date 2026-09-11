module experiments/observation_249_locus_admission_authority_separation

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

/--
A writer may observe an older policy snapshot while a concurrent add-only policy
publication has already established a larger current set. The stale snapshot may
therefore reject a newly admitted Locus.
-/
pred staleOlderPolicyCanFalseReject {
  some old, current: Policy, d: Draft | {
    old != current
    old.approved in current.approved
    old.approved != current.approved
    not admitted[old, d]
    admitted[current, d]
  }
}

/--
Under the current add-only policy operation, admission against an older policy
cannot authorize anything that the later current policy rejects.
-/
assert AddOnlyStaleCannotOverAuthorize {
  all old, current: Policy, d: Draft |
    (old.approved in current.approved and admitted[old, d])
      implies admitted[current, d]
}

/--
If future policy semantics allow removal, the stale-read argument disappears: an
older snapshot can still authorize a Locus that the current policy revoked.
-/
pred revocationMakesStaleOverAuthorize {
  some old, current: Policy, d: Draft | {
    old != current
    some old.approved - current.approved
    admitted[old, d]
    not admitted[current, d]
  }
}

/-- Equal explicit policy sets determine the same admission answer. -/
assert EqualPolicySetsAgree {
  all left, right: Policy, d: Draft |
    left.approved = right.approved implies
      (admitted[left, d] iff admitted[right, d])
}

run staleOlderPolicyCanFalseReject for exactly 3 Locus, exactly 3 Policy, exactly 1 Draft
check AddOnlyStaleCannotOverAuthorize for exactly 3 Locus, exactly 3 Policy, exactly 1 Draft
run revocationMakesStaleOverAuthorize for exactly 3 Locus, exactly 3 Policy, exactly 1 Draft
check EqualPolicySetsAgree for exactly 3 Locus, exactly 3 Policy, exactly 1 Draft
