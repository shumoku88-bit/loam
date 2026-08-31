# Observation 070 — Does retained attribution determine which policy produced it?

## Question

Observation 068 separated a policy-generated attribution from an independently retained source relation. Observation 069 then showed that a later current-policy change must not be used to rewrite an already-retained historical attribution.

Observation 070 asks the next narrower question:

> If a historical attribution is retained, does that attribution itself tell us which policy was used when the attribution was selected?

The observation deliberately does not assume that policy identity, policy version, validity intervals, or policy persistence already belong in the practical core.

## Why Alloy

The question is structural rather than temporal.

We need two worlds with the same retained attribution and the same current policy, while the policy associated with the historical selection differs. We also need to ensure that the two policies are not merely duplicate labels.

Alloy can test both conditions directly:

```text
same historical output
    +
same current policy
    +
different historical policy provenance
```

while also requiring that the two policies differ on another case.

TLA+ is not added because Observation 069 already handled policy change through time. Observation 070 asks whether the historical output structurally determines its policy provenance.

## Minimal model

The bounded model keeps:

```text
Position
  Earlier
  Later

DisposalCase
  HistoricalCase
  DistinguishingCase

Policy
  PolicyA
  PolicyB

World
  recordedUnder
  currentPolicy
  retainedAttribution
```

Both policies produce the same attribution for the historical case:

```text
HistoricalCase
  PolicyA -> 3 + 1
  PolicyB -> 3 + 1
```

They are nevertheless behaviorally distinguishable because another case separates them:

```text
DistinguishingCase
  PolicyA -> 3 + 1
  PolicyB -> 1 + 3
```

So the ambiguity is not manufactured by giving two names to the same policy behavior.

`conformsToRecordedPolicy` is an experiment-local relation connecting the retained historical attribution to the policy under which that attribution is said to have been selected.

## Executed result

Alloy 6.2.0 with Sat4j returned:

```text
policiesAgreeOnHistoricalCase                                  SAT
policiesDifferOnAnotherCase                                   SAT
representativePolicyProvenanceAmbiguity                       SAT
sameAttributionSameCurrentDifferentRecordedUnder               SAT
RetainedAttributionDeterminesPolicyProvenance                  SAT counterexample
RetainedAndCurrentPolicyDeterminePolicyProvenance              SAT counterexample
AgreementOnOneCaseMeansPoliciesEquivalent                      SAT counterexample
SamePolicyProvenanceAndConformanceDetermineRetainedAttribution UNSAT counterexample
```

The representative witness keeps the retained attribution and current policy equal across two worlds while `recordedUnder` differs.

The two policy identities remain semantically distinguishable because their attribution functions disagree on the separate distinguishing case.

## Finding

The bounded separation is:

```text
retained historical attribution
    !=
policy provenance of that attribution
```

and even:

```text
retained historical attribution
    +
current policy

        does not determine

historical policy provenance
```

A policy can therefore be relevant to the explanation of a retained attribution even when another policy would have produced the same numerical attribution for that particular case.

This is the same information-loss shape seen elsewhere in LOAM: an output may preserve the answer to one question while forgetting the path or relation that produced it.

## Relation to Observation 069

Observation 069 established:

```text
retained historical attribution
    !=
current-policy attribution view
```

Observation 070 adds a different distinction. Even after the historical attribution itself survives, its value need not identify the policy under which it was selected.

So there are now three potentially distinct answers in the bounded vocabulary:

```text
what attribution was retained?
what policy is current now?
under which policy was that attribution selected?
```

None of these three is automatically a substitute for the others.

## What is not earned

Observation 070 does **not** establish:

- a Practical Core `Policy` type;
- a `PolicyId` or `PolicyVersion` type;
- that every policy needs stable durable identity;
- policy validity intervals;
- policy authorship, authority, or approval provenance;
- that every historical attribution must retain policy provenance;
- FIFO, LIFO, average-cost, specific-identification, tax, or inventory law;
- policy persistence or wire format;
- correction or supersession semantics for policy provenance;
- a first-class Lot or CostBasis type;
- gain/loss calculation.

The strongest earned statement is conditional on the retained vocabulary:

> If an application must later answer which behaviorally distinguishable policy was used to select a retained attribution, the attribution value and current policy are insufficient; the policy provenance distinction must survive in some representation.

That representation could be a stable policy reference, an immutable policy snapshot, a policy-version reference, or another information-equivalent encoding. Observation 070 does not choose among them.

## Practical Core boundary

No Practical Lean Core, Persistence, CLI, or wire-format change is earned by this bounded observation.

A future observation should not add policy versioning merely because it is familiar infrastructure. It should first ask what happens when the meaning of a named policy itself changes: does stable policy identity without versioned behavior preserve the historical answer, or can two different policy definitions occupy the same policy name through time?
