# Observation 051 — Does Matching Evidence Mean Reconciled?

## Question

Observation 050 separated movement initiation from later physical settlement:

```text
initiated
    !=
settled
```

That leaves a practical boundary open. After recording a claim about the world, and later observing evidence with the same coordinates and quantity, may the system infer that the claim has been reconciled merely because the values match?

The pressure for this observation is:

```text
matching content
    !=
reconciliation evidence
```

A matching observation may be coincidental, may concern another otherwise-identical claim, or may simply not have been used as evidence for the recorded claim under consideration.

## Why Alloy

The first question is relational rather than temporal:

1. keep Claim and Evidence content fixed;
2. vary only an explicit `supports : Evidence -> Claim` relation;
3. ask whether reconciliation answers can change.

No transition ordering is needed. TLA+ would add machinery without answering a different question. J and miniKanren are unnecessary, and Lean 4 remains premature until a reusable law emerges.

So Observation 051 uses **Alloy only**.

## Minimal vocabulary

The model deliberately contains only:

```text
Locus
Measure
Claim
Evidence
World
supports : Evidence -> Claim
```

A Claim says:

```text
claimLocus
claimMeasure
claimQuantity
```

Evidence says:

```text
evidenceLocus
evidenceMeasure
evidenceQuantity
```

Two pieces of content match only when all three coordinates agree.

The model does not introduce Account, institution, statement, payment rail, actor, authority, trust score, timestamp, settlement object, or reconciliation workflow.

## Support law

Explicit support is allowed only when Evidence content matches Claim content:

```text
supports(e, c)
    =>
content(e) = content(c)
```

The converse is intentionally **not** asserted:

```text
content(e) = content(c)
    does not imply
supports(e, c)
```

## Selected reconciliation vocabulary

A claim is reconciled exactly when some Evidence explicitly supports it:

```text
reconciledClaims[w]
    =
{ c | some e | e -> c in w.supports }
```

Everything else remains unreconciled in the selected vocabulary.

This does not claim that explicit support proves metaphysical truth. It only defines the small reconciliation answer being observed.

## Observed pressure

### 1. Coincident matching content need not reconcile

One Claim and one Evidence can have identical Locus, Measure, and Quantity while no support edge exists and the Claim remains unreconciled.

Observed: **SAT**.

So value equality alone is insufficient.

### 2. Identical claims can have different evidence status

Two distinct Claim identities can have identical selected content while one matching Evidence explicitly supports only one of them.

Observed: **SAT**.

So even complete equality of the selected Claim content does not erase Claim identity when reconciliation evidence is claim-specific.

### 3. Support overlay can change reconciliation while content stays fixed

Claim and Evidence content is global and therefore identical in the two modeled Worlds. Left and Right can differ only in `supports` and still disagree about which Claim is reconciled.

Observed: **SAT**.

This is the direct relational-independence witness.

### 4. Matching content determines reconciliation

Assertion:

```text
if some Evidence matches a Claim,
the Claim must be reconciled
```

Observed check result: **SAT counterexample**.

Matching content therefore does not determine reconciliation.

### 5. Reconciled claims have matching support

Assertion:

```text
reconciled
    =>
there exists explicit matching Evidence support
```

Observed check result: **UNSAT counterexample**.

Within this selected vocabulary, reconciliation cannot appear without a matching support witness.

### 6. Same support determines selected reconciliation

If two Worlds have exactly the same support relation, their reconciled and unreconciled Claim sets cannot differ.

Observed check result: **UNSAT counterexample**.

## Observed Alloy result

Alloy 6.2.0 + Sat4j on pull-request head `d9a13009a98ec160439f26f6804b81b52ecc0e80`:

```text
coincidentMatchNeedNotReconcile                 SAT
explicitSupportCanDistinguishIdenticalClaims    SAT
supportOverlayCanChangeReconciliation           SAT
MatchingContentDeterminesReconciliation         SAT
ReconciledClaimsHaveMatchingSupport             UNSAT
SameSupportDeterminesSelectedReconciliation     UNSAT
```

The complete expected result set passed in CI.

## Interpretation

The bounded separation is:

```text
same observed value
    !=
this evidence supports this claim
```

and therefore:

```text
matching value
    !=
reconciled
```

A future vocabulary that asks whether a particular recorded claim has been reconciled cannot, in general, recover that answer from Claim and Evidence values alone. It needs at least some relation retaining which evidence supports which claim.

The strongest small witness is identity-sensitive. Two Claims can have the same selected content, while the same matching Evidence supports only one. If Claim identity were discarded merely because values coincide, the reconciliation question would become unanswerable.

This continues LOAM's recurring pattern:

```text
exists      != selected
held        != allocatable
located     != accounting role
initiated   != settled
matching    != reconciled
```

The recurring theme remains vocabulary-relative memory: if the future asks an evidential question, the present must retain an evidential relation rather than only matching quantities.

## Important boundaries

This observation does **not** establish:

- that matching evidence is trustworthy;
- who is authorized to create a support relation;
- whether evidence is complete;
- whether a supported claim is objectively true;
- evidence provenance;
- evidence source identity;
- timestamps or ordering of observations;
- institution-specific reconciliation;
- statement import semantics;
- tolerance or rounding rules;
- partial reconciliation;
- many-to-one or one-to-many production policy;
- revocation or correction of evidence;
- conflict between evidence sources;
- historical reconciliation state;
- eventual reconciliation or any liveness property.

Those questions are intentionally outside this minimal model.

## Next move

The planned formal-observation sequence has reached its current stopping point.

The next move is not to add another speculative domain object. It is to descend into a small Lean 4 program and see whether any of these observed laws become useful when proving something concrete.
