# Observation 079 — Can a check result keep its meaning without its check contract?

## Question

LOAM routinely records formal-tool outcomes such as:

```text
SAT
UNSAT
SUCCESS
```

Those tokens look compact, but the repository already uses them in deliberately different ways.

For an Alloy `run`, `SAT` means that the requested witness exists in the bounded scope.

For an Alloy `check`, `SAT` means that a counterexample to the asserted claim exists in the bounded scope.

For CI, `SUCCESS` usually means something still different: the raw tool result matched the result the workflow expected. A successful workflow can therefore preserve either a SAT result or an UNSAT result, and those results can themselves have different semantic interpretations.

This creates a question about the human/AI/formal-method work surface rather than a new household-domain object:

> If a formal check result is retained while the proposition, command mode, or expected polarity is forgotten, does the retained result still determine what was learned?

## Why this is not Observation 051 again

Observation 051 separated a domain Claim from later Evidence and an explicit `supports` relation:

```text
matching value != this evidence supports this claim
```

Observation 079 does not add another domain Evidence object or revisit reconciliation.

The subject here is the formal checking apparatus itself. The candidate record is a check receipt with four coordinates:

```text
claim
command mode
raw result
expected result
```

The question is what semantic or qualification information survives when some of those coordinates are projected away.

## Tool choice

Alloy only.

This is an information-loss / relational-determinacy question. We want two check receipts that agree on a proposed retained projection but disagree on the answer we care about.

J could also express the quotienting shape, but it would not add a distinct answer yet. Lean is premature because no general law has been earned. TLA+ is unnecessary because transition order is not the question.

## Minimal vocabulary

The model distinguishes two Alloy command modes:

```text
WitnessSearch
AssertionCheck
```

and two raw results:

```text
Sat
Unsat
```

Their bounded interpretations are deliberately explicit:

```text
WitnessSearch + Sat   -> WitnessFound
WitnessSearch + Unsat -> NoWitnessInScope

AssertionCheck + Sat   -> CounterexampleFound
AssertionCheck + Unsat -> NoCounterexampleInScope
```

This wording avoids turning bounded `UNSAT` into an unbounded proof claim.

A separate expected-result coordinate defines workflow qualification:

```text
raw = expected  -> Success
raw != expected -> Failure
```

So semantic interpretation and CI qualification are different questions even though both are derived from the same check receipt.

## Alloy result

Alloy 6.2.0 with Sat4j produced every requested collision:

```text
sameSatDifferentMeaning                SAT
sameSuccessDifferentRaw                SAT
sameSuccessDifferentMeaning            SAT
sameRawDifferentQualification          SAT
sameRawModeDifferentClaim              SAT

RawResultDeterminesMeaning             SAT counterexample
WorkflowSuccessDeterminesRaw           SAT counterexample
WorkflowSuccessDeterminesMeaning       SAT counterexample
RawResultDeterminesQualification       SAT counterexample
RawAndModeDetermineClaim               SAT counterexample
```

The deliberately stronger retained contexts had no counterexample in the bounded scope:

```text
RawAndModeDetermineMeaning             UNSAT counterexample
RawAndExpectedDetermineQualification   UNSAT counterexample
FullSemanticReceiptDeterminesMeaning   UNSAT counterexample
```

The branch push and pull-request Observation 079 runs both completed successfully on exact head `4525e9cbb927b46cd227333b0ddc2cc573ce2975` before this result-only documentation commit.

## Interpretation

A bare tool token is not self-interpreting.

The same raw result can carry opposite kinds of information depending on the check contract. In the smallest witness, `SAT` means either:

```text
WitnessSearch  -> WitnessFound
AssertionCheck -> CounterexampleFound
```

So:

```text
raw result
    !=
semantic interpretation
```

A workflow-level `SUCCESS` is coarser still. The model admits successful checks whose raw results differ, and successful checks whose semantic interpretations differ. `SUCCESS` therefore means only that the observed raw result matched the workflow's expected result in this model.

So:

```text
workflow SUCCESS
    !=
raw result
    !=
semantic interpretation
```

Expected polarity is also independent information. The same raw result can be a workflow success under one expectation and a failure under another. Thus a retained raw result cannot explain CI qualification by itself.

Finally, even `raw result + command mode` does not recover which Claim was checked. It determines the small interpretation category in this model, but the proposition identity remains a separate coordinate.

## Bounded sufficient contexts

The experiment identifies two different small contexts for two different future questions.

To answer:

```text
What did the checker say about this proposition?
```

this bounded vocabulary needs:

```text
claim + command mode + raw result
```

To answer:

```text
Why did the workflow call this check successful?
```

it needs:

```text
raw result + expected result
```

These are not one universal record schema. They are vocabulary-relative sufficient projections for the two questions modeled here.

## Result

Observation 079 earns a negative boundary rather than a new formal object:

> A formal check outcome should not be treated as semantic evidence merely by retaining a bare result token or CI success status.

If a future human/AI work surface needs to revisit what was learned, it must retain enough of the check contract to interpret the result for that later question.

This is distinct from Observation 051. Observation 051 says a domain Claim needs an explicit relation to the Evidence that supports it. Observation 079 says the checking apparatus itself can lose meaning if its proposition/mode/expectation context is projected away.

The result does **not** yet earn a generic `CheckReceipt`, `Evidence`, `Proof`, `Proposal`, or semantic-OS kernel type. It only prevents `SAT`, `UNSAT`, or `SUCCESS` from being promoted into context-free semantic facts.

## Practical Core impact

None.

- no Core type change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no new household Evidence or Authority semantics;
- no claim that Alloy `UNSAT` is an unbounded proof;
- no generic five-stage runtime.

## Next pressure

Do not build a generic check-receipt framework yet.

A later experiment should add another formal tool only if it asks a question that Alloy's two command modes cannot already expose. If Lean proof success, TLA+ behavior exploration, or another checker introduces a genuinely new interpretation coordinate, compare that concrete pressure then rather than inventing a cross-tool ontology now.
