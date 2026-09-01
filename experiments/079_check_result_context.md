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

## Candidate witnesses

The model asks for these positive examples:

1. the same raw `SAT` result can mean `WitnessFound` for `run` and `CounterexampleFound` for `check`;
2. two successful workflow checks can have different raw results;
3. two successful workflow checks can have different semantic interpretations;
4. the same raw result can be workflow-successful under one expectation and workflow-failing under another;
5. the same raw result and command mode can belong to different checked Claims.

## Candidate determinacy checks

The model then tests whether the following compressed records are sufficient.

Expected to fail with a counterexample:

```text
raw result alone -> semantic interpretation
SUCCESS alone -> raw result
SUCCESS alone -> semantic interpretation
raw result alone -> workflow qualification
raw result + mode -> checked Claim
```

Expected to survive the bounded check:

```text
raw result + mode -> interpretation category
raw result + expected result -> workflow qualification
claim + mode + raw result -> semantic interpretation of that claim
```

The last three are properties of this deliberately tiny interpretation table. They are not yet proposed as a generic LOAM proof object or runtime schema.

## What would count as a result?

If Alloy finds the expected collisions, then a bare result token such as `SAT`, `UNSAT`, or `SUCCESS` is not a self-interpreting semantic artifact.

A useful distinction would be:

```text
raw tool result
    !=
meaning of the result
    !=
qualification status of the workflow
```

The experiment would also identify two different minimal contexts for two different questions:

```text
What did the checker say about the proposition?
    claim + command mode + raw result

Why did CI call this run successful?
    raw result + expected result
```

That would not yet earn a `CheckReceipt`, `Evidence`, `Proof`, or `Proposal` type in Practical Core. It would only show that a future human/AI work surface must not collapse these coordinates if it needs to answer both questions later.

## Practical Core impact

None.

- no Core type change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no new household Evidence or Authority semantics;
- no claim that Alloy `UNSAT` is an unbounded proof;
- no generic five-stage runtime.
