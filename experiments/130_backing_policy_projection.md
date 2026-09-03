# Observation 130 — Can current Backing be a policy projection instead of retained state?

## Question

Observation 129 established:

```text
Actual consumption
    !=
Backing evolution
```

The same Actual, routing, prior Backing, post-Actual holdings, and Remaining can admit more than one physically valid Backing response.

That leaves a smaller implementation possibility:

> Instead of retaining Backing as its own mutable/current fact, can LOAM derive current Backing from current household facts plus one explicit deterministic Backing policy?

This observation is deliberately limited to **current-state** budget answers. Observation 071 already established the generic historical-policy boundary: current policy identity/definition is not automatically historical policy provenance. Observation 130 does not re-prove that chapter.

## Candidate compression

Candidate A retains current Backing state:

```text
current Holdings
current Remaining
retained Backing allocation
    -> current Backed / Funded / Gap
```

Candidate B removes retained current Backing:

```text
current Holdings
current Remaining
explicit deterministic Backing policy
    -> projected current Backing
    -> current Backed / Funded / Gap
```

The question is whether B can preserve the selected current answers, and what semantic authority merely moves into the policy if it can.

## Fixed current household facts

The specimen uses the post-Actual state from Observation 129:

```text
Holdings
  Bank = 3
  Cash = 6

Remaining
  Food   = 5
  Travel = 4
```

No `World.backing` relation exists in the Alloy model.

## Two deterministic policies

### AffinityPolicy

Keep each Holding on its established purpose:

```text
Bank -> Travel 3
Cash -> Food   6
```

Projection:

```text
Food   Backed 6, Funded 5, Gap 0
Travel Backed 3, Funded 3, Gap 1
```

### CoveragePolicy

Use the same physical stock but globally cover current Remaining:

```text
Bank -> Travel 3
Cash -> Food   5
Cash -> Travel 1
```

Projection:

```text
Food   Backed 5, Funded 5, Gap 0
Travel Backed 4, Funded 4, Gap 0
```

Both policies assign exactly the same nine physical units. No stored Backing state is needed to compute either result because the allocation is defined by policy.

`CoveragePolicyCopy` has the same definition as `CoveragePolicy` under a distinct policy identity so that sufficiency is checked on an inhabited equal-definition pair rather than only one singleton.

## Pressure 1: can current Backing state disappear?

The positive candidate says yes, but only conditionally:

```text
current facts
+ fixed deterministic policy definition
    -> one selected current Backing projection
```

The model therefore checks that equal policy definitions over the same current facts cannot disagree on:

```text
Backing
Backed
Funded
Gap
```

and that projected Backing conserves every Holding quantity.

## Pressure 2: did Backing really disappear, or did authority move?

The household facts are identical in `AffinityWorld` and `CoverageWorld`.

Only policy differs.

Yet Travel is:

```text
AffinityPolicy: Gap 1
CoveragePolicy: Gap 0
```

and the selected Cash backing coordinates differ as well.

Therefore if Alloy finds those worlds, then:

```text
current household facts alone
    do not determine
current Backing / Gap
```

The policy is not merely an optimization implementation detail. It selects a household answer.

## Qualification targets

Expected witnesses:

```text
backingCanBeProjectedWithoutStoredState                 SAT
sameCurrentFactsDifferentPolicyDifferentGap             SAT
sameCurrentFactsDifferentPolicyDifferentHoldingAnswer   SAT
coveragePolicyClosesCurrentGap                           SAT
inhabitedSameDefinitionCopy                              SAT
```

Expected counterexamples to policy-free derivation:

```text
CurrentFactsAloneDetermineBacking                       SAT counterexample
CurrentFactsAloneDetermineGap                           SAT counterexample
```

Expected sufficiency / conservation checks for the current-state candidate:

```text
CurrentFactsPlusPolicyDefinitionDetermineProjection     UNSAT counterexample
ProjectedBackingConservesHoldings                       UNSAT counterexample
```

## Interpretation if qualified

The strongest useful conclusion would be narrower than “Backing is unnecessary.”

It would be:

```text
retained current Backing state
    may be unnecessary
for the selected current-only projection

IF
an explicit deterministic Backing policy is accepted as authority
```

That is a genuine code-reduction candidate because LOAM may avoid a mutable Backing store, Backing writer, and a second update after every Actual.

But the semantic distinction has not vanished:

```text
Backing allocation authority
```

has moved into the policy definition.

So the next design question would become whether that policy may safely be replaceable application configuration, or whether user-authored / historical Backing intent forces durable provenance.

## Relationship to Observation 071

Observation 071 already established, in another domain, that current policy definition is not automatically sufficient historical provenance when policy behavior changes through time.

Observation 130 therefore does not claim that a current Backing policy can reconstruct historical Backing answers. It only asks whether **current Backing state** can be omitted for a selected current budget view.

## Boundaries

Observation 130 does not establish:

- a production Backing policy type;
- which policy a household should use;
- that policy should automatically change existing user-authored Backing intent;
- historical Backing reconstruction;
- policy-version persistence;
- that every current Backing question is covered by the selected projection;
- credit / liability handling;
- multi-Measure valuation;
- ownership / Agent semantics;
- Practical Core, persistence, CLI, or canonical household-data changes.

The question is only whether retained **current** Backing state can be compressed into a deterministic policy projection without losing the selected current answers, and whether doing so merely transfers semantic authority into that policy.
