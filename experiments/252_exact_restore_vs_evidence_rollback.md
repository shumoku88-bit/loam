# Observation 252 — Exact restore vs evidence rollback

## Question

Can the recomposed recovery law from Observation 251 replace today's Movement
recovery operation as a smaller implementation of the same meaning?

Production already gives the existing operation a stronger contract:

```text
doctor restore DIGEST
  -> select one exact retained recovery generation
```

The recovery regression also requires `CURRENT` to become byte-identical to the
requested retained manifest. That operation is therefore authority restoration,
not merely household-evidence rollback.

Observation 251 studies a different candidate:

```text
evidence rollback
  -> historical household evidence
  -> current Locus policy
```

Observation 252 asks whether those two operations are observationally equivalent.

## Model

Both operations deliberately choose the same historical household evidence.
They differ only in policy selection:

```text
exact restore:
  evidence = historical.evidence
  policy   = historical.policy

evidence rollback:
  evidence = historical.evidence
  policy   = current.policy
```

The relevant observables are selected-authority identity and new-write admission.

## Expected results

- `BothRestoreTheSameHistoricalEvidence`: no counterexample
  - the disagreement is not about which household evidence is recovered.
- `exactAndRollbackCanSelectDifferentPolicy`: SAT
  - after later add-only policy growth, exact restore and evidence rollback select
    different policy state.
- `exactAndRollbackCanDisagreeOnWriteAdmission`: SAT
  - that difference reaches Q_write: the same draft can be refused after exact
    historical restore but admitted after evidence rollback.
- `ExactRestoreReconstructsHistoricalSelection`: no counterexample
  - the existing exact operation has the stronger historical-authority identity
    promise by construction.
- `evidenceRollbackCanViolateExactHistoricalIdentity`: SAT
  - recomposition intentionally violates that exact identity whenever policy has
    changed since the historical generation.
- `EqualPoliciesCollapseTheDifference`: no counterexample
  - if policy has not changed, the two operations become observationally equal in
    this model.

## Interpretation

If qualified, this observation blocks a tempting but incorrect "compression":
replacing current exact restore with recomposed evidence rollback would not merely
remove physical coupling. It would change an independently observable Q_write
answer and break the existing exact-generation identity contract.

That means the current coupled restore is not proven redundant by Observations 250
or 251.

Observation 250 still identified a real alternative operation that may be useful,
but it is a new semantic capability: rollback household evidence while preserving
current operational policy. It should not be smuggled into the existing exact
restore path under the name of simplification.

## Production consequence

For the current compression audit, the minimum design is therefore likely:

- keep `doctor restore DIGEST` exact;
- keep malformed-CURRENT disaster recovery intact;
- do not add an evidence-only rollback command unless a concrete household or
  maintenance workflow requires it;
- do not split LocusAdmission storage merely to make that unrequested operation
  convenient.

This is a useful negative result: formal pressure exposed a possible new operation,
then showed it is not a semantics-preserving replacement for the one already in
production.

## Stop rule

Do not create another recovery command, authority, file, or generic abstraction
from this observation alone. A distinct evidence-rollback operation needs an
observed use case before it earns production surface area.
