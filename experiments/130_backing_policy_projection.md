# Observation 130 — Can current Backing be a policy projection instead of retained state?

Status: qualified bounded Alloy observation

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

## Executed result

Alloy 6.2.0 + Sat4j:

```text
backingCanBeProjectedWithoutStoredState                 SAT
sameCurrentFactsDifferentPolicyDifferentGap             SAT
sameCurrentFactsDifferentPolicyDifferentHoldingAnswer   SAT
coveragePolicyClosesCurrentGap                           SAT
inhabitedSameDefinitionCopy                              SAT

CurrentFactsAloneDetermineBacking                       SAT counterexample
CurrentFactsAloneDetermineGap                           SAT counterexample

CurrentFactsPlusPolicyDefinitionDetermineProjection     UNSAT counterexample
ProjectedBackingConservesHoldings                       UNSAT counterexample
```

The complete expected-result checker passed on the PR merge ref against `main`.

## Finding 1: retained current Backing state can disappear in the selected bounded view

The model contains no retained Backing relation. Nevertheless, once current facts and one deterministic policy definition are fixed, the selected current projection is fixed.

The inhabited `CoveragePolicy` / `CoveragePolicyCopy` pair confirms that equal policy definitions produce equal:

```text
Holding x Purpose Backing
Backed
Funded
Gap
```

and the policy-derived allocation conserves every physical Holding quantity.

So the selected bounded result supports:

```text
current Holdings
+ current Remaining
+ deterministic Backing policy definition
    -> current Backing projection
```

without a separately retained current Backing state.

## Finding 2: the semantic authority did not disappear

The same current household facts under different policies produce different household answers:

```text
AffinityPolicy
  Travel Gap = 1

CoveragePolicy
  Travel Gap = 0
```

The selected Cash backing coordinates also differ.

Therefore:

```text
current household facts alone
    do not determine
current Backing / Gap
```

A Backing policy that selects between these worlds is not merely an implementation optimization. It carries information-equivalent allocation authority for the selected current answer.

The compression is therefore not:

```text
Backing disappears completely
```

but rather:

```text
retained current Backing state
    -> potentially removable

Backing allocation authority
    -> still required, here carried by policy
```

## Product interpretation

This opens a genuinely smaller implementation path for ordinary envelope-style use.

LOAM may be able to avoid:

```text
mutable current Backing store
Backing update after every Actual
stored Funded
stored Gap
```

and instead calculate the current budget screen from:

```text
Holdings
Capacity / Remaining
Actual consumption
selected Backing policy
```

But policy choice must be visible in the design because changing policy can change whether a purpose appears under-backed without changing any household Actual.

This does not imply that a user should see a complicated policy editor. A future practical surface could use one small explicit household rule if dogfood shows that it is stable and understandable.

## Relationship to Observation 071

Observation 071 already established, in another domain, that current policy definition is not automatically sufficient historical provenance when policy behavior changes through time.

Observation 130 therefore does not claim that a current Backing policy can reconstruct historical Backing answers. It only qualifies omission of **retained current Backing state** for the selected current budget view.

The next pressure is therefore narrower and practical:

> Can one small replaceable current Backing policy serve household use, or does user-authored allocation intent make the policy itself historical/canonical evidence?

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

The qualified result is only that retained **current** Backing state can be compressed into a deterministic policy projection for the selected bounded answers, while the missing semantic authority reappears in the policy definition rather than vanishing.
